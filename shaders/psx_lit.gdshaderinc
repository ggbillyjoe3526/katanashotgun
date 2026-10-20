// Body of the PS1 lit surface, shared by psx_lit (every preset) and
// psx_lit_hd (INSANE on Forward+, which defines PSX_HD).
// Linear, so RETRO LOOK OFF and LIGHT smooth textures; FULL picks the
// nearest texel itself (psx_texel), exactly as filter_nearest would.
uniform sampler2D albedo_tex : source_color, filter_linear, repeat_enable;
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
// A soft "baked" glow in the surface's own colour (the PS1 pre-lit trick),
// so detail still reads away from the lamps.
uniform float self_light = 0.0;
uniform vec3 self_tint : source_color = vec3(1.0);
uniform float flash = 0.0;
uniform vec3 flash_color : source_color = vec3(1.0);
// 1.0 = default wobble, 0.0 = off, >1 = more jitter.
uniform float snap = 1.0;
uniform float affine = 0.55;
uniform vec3 fog_color : source_color = vec3(0.12, 0.05, 0.2);
uniform float fog_start = 10.0;
uniform float fog_end = 90.0;
// The RETRO LOOK setting (RetroLook): how much affine warp (0 = none, 1 =
// full); above 0.5 (FULL) textures pick the nearest texel. psx_snap: the vertex
// snap grid as a share of the 3D view's own pixels (0 = no wobble).
global uniform float psx_retro;
global uniform float psx_snap;
varying vec3 v_uvw;
varying float v_fog;

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
	if (snap * psx_snap > 0.0 && clip.w > 0.001) {
		vec2 grid = VIEWPORT_SIZE * psx_snap / snap;
		clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	}
	POSITION = clip;
	float w = mix(1.0, max(clip.w, 0.001), affine * psx_retro);
	v_uvw = vec3(uv * w, w);
	vec3 vpos = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_fog = clamp((length(vpos) - fog_start) / (fog_end - fog_start), 0.0, 1.0);
}

#if CURRENT_RENDERER != RENDERER_COMPATIBILITY
// Compatibility shades in sRGB space; Forward+ in linear. Emission is worked
// out in sRGB (as Compatibility sees the colours) and turned linear at the
// end, so a faint glow stays faint and lit windows keep their mask.
vec3 psx_srgb(vec3 c) {
	c = max(c, vec3(0.0));
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}

vec3 psx_linear(vec3 c) {
	vec3 lo = min(c, vec3(1.0));
	lo = mix(lo / 12.92, pow((lo + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), lo));
	return lo + max(c - vec3(1.0), vec3(0.0));
}
#endif

// The centre of the texel `uv` falls in: a linear sampler read there gives
// that texel alone, like a nearest one.
vec2 psx_texel(vec2 uv, sampler2D tex) {
	vec2 size = vec2(textureSize(tex, 0));
	return (floor(uv * size) + 0.5) / size;
}

void fragment() {
	vec2 uv = v_uvw.xy / v_uvw.z;
	vec4 c = albedo_color;
	vec4 t = vec4(1.0);
	if (use_texture) {
		t = texture(albedo_tex, psx_retro > 0.5 ? psx_texel(uv, albedo_tex) : uv);
		c *= t;
	}
	if (use_vertex_color) {
		c *= COLOR;
	}
	ALBEDO = mix(c.rgb, flash_color, flash);
#if CURRENT_RENDERER != RENDERER_COMPATIBILITY
	vec3 em_col = psx_srgb(emission_color);
	vec3 em_tex = psx_srgb(t.rgb);
	vec3 em_tint = psx_srgb(emission_tint);
	vec3 self_c = psx_srgb(c.rgb) * psx_srgb(self_tint);
#else
	vec3 em_col = emission_color;
	vec3 em_tex = t.rgb;
	vec3 em_tint = emission_tint;
	vec3 self_c = c.rgb * self_tint;
#endif
	vec3 em = em_col * emission_strength + self_c * self_light;
	if (emission_from_texture > 0.0) {
		float lum = max(em_tex.r, max(em_tex.g, em_tex.b));
		em += em_tex * em_tint * smoothstep(0.45, 0.9, lum) * emission_from_texture;
	}
#if CURRENT_RENDERER != RENDERER_COMPATIBILITY
	if (emission_strength > 0.0 || emission_from_texture > 0.0 || self_light > 0.0) {
		em = psx_linear(em);
	}
#endif
	EMISSION = em + flash_color * flash * 1.5;
#ifdef PSX_HD
	// the Environment's depth fog (the same curve, 10 to 100 m; surfaces
	// with a longer range of their own keep the plain shader) stands in for
	// FOG, so volumetric fog can reach this surface too. Dry surfaces stay
	// matte: only real water and glass reflect (puddle.gdshader).
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
#else
	FOG = vec4(fog_color, v_fog * v_fog * (3.0 - 2.0 * v_fog));
#endif
}
