// Additive glow for effects: muzzle flash, neon halos, tracers, slash trails.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform sampler2D tex : source_color, filter_nearest, repeat_enable;
uniform bool use_texture = false;
uniform vec4 color : source_color = vec4(1.0);
uniform float intensity = 1.0;
uniform bool billboard = false;
uniform bool use_vertex_color = false;
// Fragments with UV.x above this are hidden (used to "draw" slash arcs).
uniform float reveal = 1.0;

void vertex() {
	if (billboard) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
			vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
	}
}

void fragment() {
	if (UV.x > reveal) {
		discard;
	}
	vec4 c = color;
	if (use_texture) {
		c *= texture(tex, UV);
	}
	if (use_vertex_color) {
		c *= COLOR;
	}
	ALBEDO = c.rgb * intensity;
	ALPHA = c.a;
}
