class_name ShotgunModel
## The RAIJIN-12 arc shotgun modelled in Blender (assets/models/shotgun, made
## by source/export_raijin.py). Its nodes and surfaces are named in the .glb:
## "body" (with the textured "body" and "shell" surfaces and the glowing
## "coil", "core" and "emitter"), "drum" (turns about its axle, its "cell"
## surface glows), "led_0".."led_9" (the charge lights), and the empty nodes
## "muzzle" and "arc_point_0".."arc_point_2". The textured surfaces take the
## baked textures through psx_model (retro and plain looks); the glowing ones
## take the viewmodel's materials, so the equipped look tints them and the
## viewmodel pulses them like the code-built gun's.

const DIR := "res://assets/models/shotgun/"
const SCENE := DIR + "raijin12.glb"
const SLOTS := ["body", "shell"]
const GLOW_SLOTS := ["coil", "core", "emitter", "cell", "led"]
const LED_COUNT := 10
const ARC_POINTS := 3


## A node holding the model, or an empty node if it can't be loaded (the
## viewmodel then keeps the code-built gun). `glow` maps each glowing
## surface name (GLOW_SLOTS) to the material it takes.
static func build(glow: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "ShotgunModel"
	var packed := load(SCENE) as PackedScene
	if packed == null:
		push_warning("ShotgunModel: %s did not load" % SCENE)
		return root
	var scene := packed.instantiate()
	var textured := {}
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			var slot := src.resource_name if src else ""
			var m: Material = glow.get(slot)
			if m == null:
				if not textured.has(slot):
					textured[slot] = _material(slot)
				m = textured[slot]
			mi.set_surface_override_material(i, m)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(scene)
	return root


## The model's node called `name` (drum, muzzle, led_3, arc_point_1...), or
## null.
static func part(model: Node, name: String) -> Node3D:
	return model.find_child(name, true, false) as Node3D


static func _material(slot: String) -> ShaderMaterial:
	if slot not in SLOTS:
		push_warning("ShotgunModel: unknown surface '%s'" % slot)
		slot = SLOTS[0]
	var m := ShaderMaterial.new()
	m.shader = Psx.shader("psx_model")
	m.set_shader_parameter("albedo_tex", load(DIR + "textures/raijin_%s_basecolor.png" % slot))
	m.set_shader_parameter("orm_tex", load(DIR + "textures/raijin_%s_orm.png" % slot))
	m.set_shader_parameter("normal_tex", load(DIR + "textures/raijin_%s_normal.png" % slot))
	m.set_shader_parameter("retro_tex", load(DIR + "textures/raijin_%s_retro.png" % slot))
	return m
