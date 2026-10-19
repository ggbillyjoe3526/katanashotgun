class_name KatanaModel
## The DOJIGIRI katana modelled in Blender (assets/models/katana, made by
## source/export_dojigiri.py). Its three surfaces are named in the .glb:
## "steel" and "grip" take the baked textures through psx_model (retro and
## plain looks), "edge" takes the viewmodel's glowing edge material, so the
## equipped look tints it and every swing flares it like the code-built blade.

const DIR := "res://assets/models/katana/"
const SCENE := DIR + "dojigiri.glb"
const SLOTS := ["steel", "grip"]


## A node holding the model, or an empty node if it can't be loaded (the
## viewmodel then keeps the code-built blade).
static func build(edge_mat: Material) -> Node3D:
	var root := Node3D.new()
	root.name = "KatanaModel"
	var packed := load(SCENE) as PackedScene
	if packed == null:
		push_warning("KatanaModel: %s did not load" % SCENE)
		return root
	var scene := packed.instantiate()
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			var slot := src.resource_name if src else ""
			mi.set_surface_override_material(i, edge_mat if slot == "edge" else _material(slot))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(scene)
	return root


static func _material(slot: String) -> ShaderMaterial:
	if slot not in SLOTS:
		push_warning("KatanaModel: unknown surface '%s'" % slot)
		slot = SLOTS[0]
	var m := ShaderMaterial.new()
	m.shader = Psx.shader("psx_model")
	m.set_shader_parameter("albedo_tex", load(DIR + "textures/dojigiri_%s_basecolor.png" % slot))
	m.set_shader_parameter("orm_tex", load(DIR + "textures/dojigiri_%s_orm.png" % slot))
	m.set_shader_parameter("normal_tex", load(DIR + "textures/dojigiri_%s_normal.png" % slot))
	m.set_shader_parameter("retro_tex", load(DIR + "textures/dojigiri_%s_retro.png" % slot))
	return m
