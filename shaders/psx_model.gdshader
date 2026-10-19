// Surfaces of the modelled weapons (the DOJIGIRI katana's steel and grip),
// built from textures baked in Blender (assets/models/katana/source).
// RETRO LOOK FULL: the PS1 treatment of psx_lit (vertex snap, affine warp,
// nearest texels) on a small texture with its light painted in, matte.
// LIGHT and OFF: per-pixel light with the full 2048 px colour,
// roughness/metal and normal maps, so the fine detail shows (LIGHT keeps
// psx_lit's gentle wobble).
shader_type spatial;
render_mode cull_back, diffuse_lambert;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_disable;
// the retro look's texture: linear, read at texel centres (psx_texel)
uniform sampler2D retro_tex : source_color, filter_linear, repeat_disable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float normal_depth = 1.0;
uniform float snap = 0.35;
uniform float affine = 0.0;
// The RETRO LOOK setting (RetroLook), as in psx_lit: psx_retro scales the
// affine warp (above 0.5, FULL, the small texture is used), psx_snap is the
// vertex grid (0 = no wobble).
global uniform float psx_retro;
global uniform float psx_snap;

varying vec3 v_uvw;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	if (snap * psx_snap > 0.0 && clip.w > 0.001) {
		vec2 grid = VIEWPORT_SIZE * psx_snap / snap;
		clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	}
	POSITION = clip;
	float w = mix(1.0, max(clip.w, 0.001), affine * psx_retro);
	v_uvw = vec3(UV * w, w);
}

vec2 psx_texel(vec2 uv, sampler2D tex) {
	vec2 size = vec2(textureSize(tex, 0));
	return (floor(uv * size) + 0.5) / size;
}

void fragment() {
	vec2 uv = v_uvw.xy / v_uvw.z;
	if (psx_retro > 0.5) {
		ALBEDO = texture(retro_tex, psx_texel(uv, retro_tex)).rgb * albedo_color.rgb;
		ROUGHNESS = 1.0;
		METALLIC = 0.0;
		SPECULAR = 0.0;
	} else {
		ALBEDO = texture(albedo_tex, uv).rgb * albedo_color.rgb;
		vec3 orm = texture(orm_tex, uv).rgb;
		AO = orm.r;
		ROUGHNESS = orm.g;
		METALLIC = orm.b;
		NORMAL_MAP = texture(normal_tex, uv).rgb;
		NORMAL_MAP_DEPTH = normal_depth;
	}
}
