// Body of the PS1 lit surface, shared by psx_lit (every preset) and
// psx_lit_hd (INSANE on Forward+, which defines PSX_HD).
uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform bool use_texture = false;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform bool use_vertex_color = false;
// World-space planar UVs (perfect for boxes: no UV unwrapping needed).
uniform bool world_uv = false;
uniform float uv_scale = 0.25;
uniform vec2 uv_tiling = vec2(1.0);
uniform vec3 emission_color : source_color = vec3(0.0);
uniform float emission_strength = 0.0;
// When set, emission is masked by the albedo texture brightness (lit windows).
uniform float emission_from_texture = 0.0;
uniform vec3 emission_tint : source_color = vec3(1.0);
uniform float flash = 0.0;
uniform vec3 flash_color : source_color = vec3(1.0);
// 1.0 = default wobble, 0.0 = off, >1 = more jitter.
uniform float snap = 1.0;
uniform float affine = 0.55;
uniform vec3 fog_color : source_color = vec3(0.12, 0.05, 0.2);
uniform float fog_start = 10.0;
uniform float fog_end = 90.0;
#ifdef PSX_HD
// How wet flat floors look: low roughness feeds screen-space reflections.
uniform float wet = 0.7;
#endif

varying vec3 v_uvw;
varying float v_fog;
#ifdef PSX_HD
varying float v_up;
#endif

void vertex() {
	vec2 uv = UV * uv_tiling;
	if (world_uv) {
		vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		vec3 wn = abs(normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz));
		if (wn.y >= wn.x && wn.y >= wn.z) {
			uv = wp.xz;
		} else if (wn.x >= wn.z) {
			uv = vec2(wp.z, -wp.y);
		} else {
			uv = vec2(wp.x, -wp.y);
		}
		uv *= uv_scale;
	}
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	if (snap > 0.0 && clip.w > 0.001) {
		vec2 grid = VIEWPORT_SIZE * 0.6 / snap;
		clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	}
	POSITION = clip;
	float w = mix(1.0, max(clip.w, 0.001), affine);
	v_uvw = vec3(uv * w, w);
	vec3 vpos = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_fog = clamp((length(vpos) - fog_start) / (fog_end - fog_start), 0.0, 1.0);
#ifdef PSX_HD
	v_up = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y;
#endif
}

void fragment() {
	vec2 uv = v_uvw.xy / v_uvw.z;
	vec4 c = albedo_color;
	vec4 t = vec4(1.0);
	if (use_texture) {
		t = texture(albedo_tex, uv);
		c *= t;
	}
	if (use_vertex_color) {
		c *= COLOR;
	}
	ALBEDO = mix(c.rgb, flash_color, flash);
	vec3 em = emission_color * emission_strength;
	if (emission_from_texture > 0.0) {
		float lum = max(t.r, max(t.g, t.b));
		em += t.rgb * emission_tint * smoothstep(0.45, 0.9, lum) * emission_from_texture;
	}
	EMISSION = em + flash_color * flash * 1.5;
#ifdef PSX_HD
	// the Environment's depth fog (the same curve, 10 to 100 m; surfaces
	// with a longer range of their own keep the plain shader) stands in for
	// FOG, so volumetric fog can reach this surface too
	float puddle = wet * smoothstep(0.8, 0.98, v_up);
	ROUGHNESS = mix(1.0, 0.12, puddle);
	METALLIC = puddle * 0.6;
	SPECULAR = mix(0.5, 1.0, puddle);
#else
	FOG = vec4(fog_color, v_fog * v_fog * (3.0 - 2.0 * v_fog));
#endif
}
