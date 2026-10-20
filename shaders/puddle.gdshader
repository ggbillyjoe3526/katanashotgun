// Rain puddles and skylight glass (WorldDetail): the only surfaces that
// reflect. PuddleMirror's camera draws the bright things mirrored under the
// player's floor into refl_tex; water on another level, or with the mirror
// off (WEAK), shows a dark sheen of the sky instead.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

uniform sampler2D mask_tex : filter_linear, repeat_disable;
uniform bool use_mask = false;
uniform sampler2D refl_tex : source_color, filter_linear, repeat_disable;
uniform sampler2D ripple : filter_linear, repeat_enable;
uniform bool mirror = true;
uniform float refl_plane = 0.0;
// Water this far from the mirror plane is on another level.
uniform float plane_reach = 0.8;
uniform float amount = 1.7;
uniform float alpha_max = 0.96;
uniform vec3 water : source_color = vec3(0.008, 0.008, 0.02);
uniform vec3 sky_tint : source_color = vec3(0.15, 0.08, 0.25);
uniform vec3 fog_color : source_color = vec3(0.12, 0.05, 0.2);
uniform float fog_start = 10.0;
uniform float fog_end = 90.0;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float m = use_mask ? texture(mask_tex, UV).a : 1.0;
	if (m < 0.02) {
		discard;
	}
	float ndv = abs(dot(normalize(NORMAL), normalize(-VERTEX)));
	float fres = mix(0.3, 1.0, pow(1.0 - ndv, 2.5));
	vec3 r = sky_tint;
	if (mirror && abs(v_world.y - refl_plane) < plane_reach) {
		vec2 ruv = vec2(SCREEN_UV.x, 1.0 - SCREEN_UV.y);
		ruv.x += (texture(ripple, v_world.xz * 0.5).a - 0.5) * 0.004;
		r = texture(refl_tex, ruv).rgb;
	}
	vec3 c = water + r * fres * amount;
	float f = clamp((length(VERTEX) - fog_start) / (fog_end - fog_start), 0.0, 1.0);
	ALBEDO = mix(c, fog_color, f * f * (3.0 - 2.0 * f));
	ALPHA = m * alpha_max;
}
