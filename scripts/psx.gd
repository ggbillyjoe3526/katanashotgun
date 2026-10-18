class_name Psx
## Material factory for the PS1 look. All world, enemy and weapon materials
## come through here so the look can be tuned in one place.

static var _shaders := {}
## Set by the map from the run's palette before anything is built.
static var fog_color := Color(0.12, 0.05, 0.2)


static func shader(name: String) -> Shader:
	if not _shaders.has(name):
		_shaders[name] = load("res://shaders/%s.gdshader" % name)
	return _shaders[name]


static func lit(color: Color, tex: Texture2D = null, world_uv := false, uv_scale := 0.25, params := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader("psx_lit")
	m.set_shader_parameter("albedo_color", color)
	if tex:
		m.set_shader_parameter("albedo_tex", tex)
		m.set_shader_parameter("use_texture", true)
	m.set_shader_parameter("world_uv", world_uv)
	m.set_shader_parameter("uv_scale", uv_scale)
	m.set_shader_parameter("fog_color", fog_color)
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


static func unlit(color: Color, energy := 1.0, tex: Texture2D = null, params := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader("psx_unlit")
	m.set_shader_parameter("albedo_color", color)
	m.set_shader_parameter("energy", energy)
	if tex:
		m.set_shader_parameter("albedo_tex", tex)
		m.set_shader_parameter("use_texture", true)
	m.set_shader_parameter("fog_color", fog_color)
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


static func cutout(color: Color, tex: Texture2D) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader("psx_cutout")
	m.set_shader_parameter("albedo_color", color)
	m.set_shader_parameter("albedo_tex", tex)
	m.set_shader_parameter("fog_color", fog_color)
	return m


static func fx(color: Color, tex: Texture2D = null, additive := true, billboard := false, overlay := false, intensity := 1.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	if additive:
		m.shader = shader("fx_add_overlay" if overlay else "fx_add")
		m.set_shader_parameter("intensity", intensity)
	else:
		m.shader = shader("fx_blend")
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("billboard", billboard)
	if tex:
		m.set_shader_parameter("tex", tex)
		m.set_shader_parameter("use_texture", true)
	return m


## Convenience: a box MeshInstance3D with a material.
static func box(size: Vector3, mat: Material, pos := Vector3.ZERO, subdiv := 0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	if subdiv > 0:
		bm.subdivide_width = maxi(0, int(size.x / subdiv))
		bm.subdivide_height = maxi(0, int(size.y / subdiv))
		bm.subdivide_depth = maxi(0, int(size.z / subdiv))
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	return mi


static func quad(size: Vector2, mat: Material, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = size
	mi.mesh = qm
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
