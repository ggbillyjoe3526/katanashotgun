// Full-screen retro post-process: light colour quantisation with Bayer dither,
// a touch of VHS (scanlines + chromatic fringe at the edges), saturation boost,
// vignette and a red damage pulse. Plus the anime layer: "impact frames"
// (the picture crushed to black / accent / white for a few frames on big hits)
// and combo "heat" (more fringe, saturation and halftone dots at the edges).
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float color_levels = 48.0;
uniform float dither_strength = 0.6;
uniform float saturation = 1.22;
uniform float contrast = 1.08;
uniform float vignette = 0.5;
uniform float scanlines = 0.07;
uniform float aberration = 1.2;
uniform float damage = 0.0;
uniform float flash = 0.0;
uniform float desaturate = 0.0;
uniform float impact = 0.0;
uniform bool impact_invert = false;
uniform vec3 impact_color : source_color = vec3(1.0, 0.1, 0.25);
uniform float heat = 0.0;
uniform vec3 heat_color : source_color = vec3(1.0, 0.1, 0.4);
// 1 = the PS1 look; 0 = the dev menu's plain look: no colour banding,
// dither, scanlines or resting edge fringe. Damage, flashes, impact frames
// and combo heat stay, they are the game's feedback.
global uniform float psx_retro;

float bayer2(int x, int y) {
	return float(((x ^ y) & 1) * 2 + (y & 1));
}

float bayer4(ivec2 p) {
	int x = p.x & 3;
	int y = p.y & 3;
	return (4.0 * bayer2(x & 1, y & 1) + bayer2((x >> 1) & 1, (y >> 1) & 1)) / 16.0;
}

void fragment() {
	vec2 d = SCREEN_UV - 0.5;
	// the plain look renders at the window's size: pixel sizes count in
	// 540-line pixels, as in the retro look
	float px = psx_retro > 0.5 ? 1.0 : max(1.0, 1.0 / (540.0 * SCREEN_PIXEL_SIZE.y));
	vec2 off = d * SCREEN_PIXEL_SIZE * px * (aberration * psx_retro + heat * 1.6 + impact * 3.0) * 6.0 * length(d);
	vec3 c;
	c.r = texture(screen_tex, SCREEN_UV + off).r;
	c.g = texture(screen_tex, SCREEN_UV).g;
	c.b = texture(screen_tex, SCREEN_UV - off).b;
	c = (c - 0.5) * contrast + 0.5;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, (saturation + heat * 0.25) * (1.0 - desaturate));
	c *= 1.0 - vignette * dot(d, d) * 1.6;
	c *= 1.0 - scanlines * psx_retro * step(0.5, fract(FRAGCOORD.y * 0.5));
	float edge = smoothstep(0.15, 0.55, length(d));
	c = mix(c, vec3(0.75, 0.0, 0.05), damage * edge);
	c = mix(c, vec3(1.0), flash);
	// combo heat: halftone dots creeping in from the edges
	if (heat > 0.0) {
		vec2 hp = FRAGCOORD.xy / (6.0 * px);
		vec2 cell = fract(vec2(hp.x + hp.y, hp.y - hp.x) * 0.7071) - 0.5;
		float edge2 = smoothstep(0.32, 0.75, length(d));
		float dot_r = 0.5 * edge2 * heat;
		float dotm = step(length(cell), dot_r);
		c = mix(c, heat_color * 1.1, dotm * 0.55);
		c = mix(c, c * heat_color * 1.6, edge2 * heat * 0.35);
	}
	// impact frame: three flat tones
	if (impact > 0.0) {
		float li = dot(clamp(c, 0.0, 1.0), vec3(0.299, 0.587, 0.114));
		vec3 t3 = li < 0.22 ? vec3(0.0) : (li < 0.55 ? impact_color : vec3(1.0));
		if (impact_invert) {
			t3 = li < 0.22 ? vec3(1.0) : (li < 0.55 ? vec3(0.0) : impact_color);
		}
		c = mix(c, t3, impact);
	}
	c = clamp(c, 0.0, 1.0);
	if (psx_retro > 0.5) {
		float b = bayer4(ivec2(FRAGCOORD.xy)) - 0.5;
		c = floor(c * color_levels + b * dither_strength + 0.5) / color_levels;
	}
	COLOR = vec4(c, 1.0);
}
