// Body of the blood-decal surface, shared by psx_cutout and psx_cutout_hd
// (INSANE on Forward+: fogged by the Environment, like psx_lit_hd).
uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform bool use_vertex_color = true;
uniform float cutoff = 0.5;
uniform float snap = 1.0;
uniform vec3 fog_color : source_color = vec3(0.12, 0.05, 0.2);
uniform float fog_start = 10.0;
uniform float fog_end = 90.0;

varying float v_fog;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	if (snap > 0.0 && clip.w > 0.001) {
		vec2 grid = VIEWPORT_SIZE * 0.6 / snap;
		clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	}
	POSITION = clip;
	vec3 vpos = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_fog = clamp((length(vpos) - fog_start) / (fog_end - fog_start), 0.0, 1.0);
}

void fragment() {
	vec4 c = albedo_color * texture(albedo_tex, UV);
	if (use_vertex_color) {
		c *= COLOR;
	}
	ALBEDO = c.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = cutoff;
#ifndef PSX_HD
	FOG = vec4(fog_color, v_fog);
#endif
}
