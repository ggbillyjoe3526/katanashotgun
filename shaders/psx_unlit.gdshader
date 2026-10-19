// PS1-style unlit surface: neon tubes, signs, blood droplets.
// Colours above 1.0 feed the glow (bloom).
shader_type spatial;
render_mode unshaded, cull_back;

// Linear for the plain look; the retro look picks the nearest texel itself.
uniform sampler2D albedo_tex : source_color, filter_linear, repeat_enable;
uniform bool use_texture = false;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float energy = 1.0;
uniform bool use_vertex_color = false;
uniform vec2 uv_tiling = vec2(1.0);
uniform vec2 uv_scroll = vec2(0.0);
uniform float flicker = 0.0;
uniform float snap = 1.0;
uniform float fog_amount = 0.6;
uniform vec3 fog_color : source_color = vec3(0.12, 0.05, 0.2);
uniform float fog_start = 10.0;
uniform float fog_end = 110.0;
// Discard fragments closer than this to the camera (0 = off).
uniform float near_discard = 0.0;
// 1 = the PS1 look, 0 = the dev menu's plain look (DevSettings.retro).
global uniform float psx_retro;

varying vec3 v_uvw;
varying float v_fog;

void vertex() {
	vec2 uv = UV * uv_tiling + uv_scroll * TIME;
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	if (snap * psx_retro > 0.0 && clip.w > 0.001) {
		vec2 grid = VIEWPORT_SIZE * 0.6 / snap;
		clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	}
	POSITION = clip;
	float w = mix(1.0, max(clip.w, 0.001), 0.4 * psx_retro);
	v_uvw = vec3(uv * w, w);
	vec3 vpos = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_fog = clamp((length(vpos) - fog_start) / (fog_end - fog_start), 0.0, 1.0) * fog_amount;
}

void fragment() {
	if (near_discard > 0.0 && -VERTEX.z < near_discard) {
		discard;
	}
	vec2 uv = v_uvw.xy / v_uvw.z;
	vec4 c = albedo_color;
	if (use_texture) {
		vec2 size = vec2(textureSize(albedo_tex, 0));
		c *= texture(albedo_tex, psx_retro > 0.5 ? (floor(uv * size) + 0.5) / size : uv);
	}
	if (use_vertex_color) {
		c *= COLOR;
	}
	float f = 1.0;
	if (flicker > 0.0) {
		float n = fract(sin(floor(TIME * 14.0) * 91.7 + NODE_POSITION_WORLD.x * 13.1) * 4375.85);
		f = mix(1.0, step(0.12, n) * 0.85 + 0.15, flicker);
	}
	ALBEDO = c.rgb * energy * f;
	FOG = vec4(fog_color, v_fog);
}
