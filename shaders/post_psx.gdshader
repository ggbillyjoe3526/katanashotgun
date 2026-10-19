// Full-screen retro post-process: light colour quantisation with Bayer dither,
// a touch of VHS (scanlines + chromatic fringe at the edges), saturation boost,
// vignette and a red damage pulse. Plus the anime layer: "impact frames"
// (the picture crushed to black / accent / white for a few frames on big hits)
// and combo "heat" (more fringe, saturation and halftone dots at the edges).
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
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
// The RETRO LOOK setting (RetroLook). psx_retro scales the scanlines and the
// resting edge fringe (1 = FULL, 0 = OFF); psx_levels is the colour levels
// per channel for the banding and Bayer dither (0 = none). Damage, flashes,
// impact frames and combo heat stay at every level: they are the game's
// feedback.
// psx_pixel_lines: when the 3D view draws at the window's size (LIGHT), the
// picture is cut into square blocks so it reads as about that many lines,
// with sharp pixels at any screen size (0 = no blocks).
global uniform float psx_retro;
global uniform float psx_levels;
global uniform float psx_pixel_lines;

float bayer2(int x, int y) {
	return float(((x ^ y) & 1) * 2 + (y & 1));
}

float bayer4(ivec2 p) {
	int x = p.x & 3;
	int y = p.y & 3;
	return (4.0 * bayer2(x & 1, y & 1) + bayer2((x >> 1) & 1, (y >> 1) & 1)) / 16.0;
}

void fragment() {
	// LIGHT: one sample per block of whole screen pixels (the block centre
	// lands on a texel centre of the 3D view, which RetroLook draws at
	// 1/block scale, so it stays sharp)
	vec2 uv = SCREEN_UV;
	vec2 cell = FRAGCOORD.xy;
	if (psx_pixel_lines > 0.0) {
		float block = max(1.0, round(1.0 / (SCREEN_PIXEL_SIZE.y * psx_pixel_lines)));
		cell = floor(FRAGCOORD.xy / block);
		uv = (cell + 0.5) * block * SCREEN_PIXEL_SIZE;
	}
	vec2 d = uv - 0.5;
	// LIGHT and OFF render more than 540 lines: pixel sizes count in
	// 540-line pixels, as in FULL
	float px = max(1.0, 1.0 / (540.0 * SCREEN_PIXEL_SIZE.y));
	vec2 off = d * SCREEN_PIXEL_SIZE * px * (aberration * psx_retro + heat * 1.6 + impact * 3.0) * 6.0 * length(d);
	vec3 c;
	c.r = texture(screen_tex, uv + off).r;
	c.g = texture(screen_tex, uv).g;
	c.b = texture(screen_tex, uv - off).b;
	c = (c - 0.5) * contrast + 0.5;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, (saturation + heat * 0.25) * (1.0 - desaturate));
	c *= 1.0 - vignette * dot(d, d) * 1.6;
	c *= 1.0 - scanlines * psx_retro * step(0.5, fract(FRAGCOORD.y * 0.5 / px));
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
	if (psx_levels > 0.0) {
		float b = bayer4(ivec2(cell)) - 0.5;
		c = floor(c * psx_levels + b * dither_strength + 0.5) / psx_levels;
	}
	COLOR = vec4(c, 1.0);
}
