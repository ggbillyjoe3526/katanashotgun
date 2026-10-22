class_name HandsModel
## The player's armoured cyber hands modelled in Blender (assets/models/hands,
## made by source/export_hands.py). The .glb holds two meshes, each built in
## the space of the weapon model it holds: "hand_katana" (left hand on the
## DOJIGIRI's handle) and "hand_shotgun" (right hand on the RAIJIN-12's grip,
## finger on the trigger), so each is parented to its weapon model and follows
## every swing and kick. Surfaces: "armor" (plates), "joint" (the dark
## under-suit) and "glow" (light lines, which take the weapon's trim material
## so the equipped look tints them).

const SCENE := "res://assets/models/hands/hands.glb"
const ARMOR := Color(0.5, 0.53, 0.6)
const ARMOR_GLOW := Color(0.55, 0.6, 0.75)
const JOINT := Color(0.1, 0.1, 0.12)


## The hand mesh called `hand`, or null if the model can't be loaded (the
## viewmodel then keeps the code-built gloves).
static func build(hand: String, glow: Material) -> MeshInstance3D:
	var packed := load(SCENE) as PackedScene
	if packed == null:
		push_warning("HandsModel: %s did not load" % SCENE)
		return null
	var scene := packed.instantiate()
	var mi := scene.find_child(hand, true, false) as MeshInstance3D
	if mi == null:
		push_warning("HandsModel: no '%s' mesh" % hand)
		scene.free()
		return null
	var p := {"snap": 0.35, "affine": 0.0, "fog_start": 50.0}
	var armor := Psx.lit(ARMOR, TexGen.get_tex("panel"), false, 1.0, p.merged({"emission_color": ARMOR_GLOW, "emission_strength": 0.12}))
	var joint := Psx.lit(JOINT, TexGen.get_tex("cloth"), false, 1.0, p)
	for i in mi.mesh.get_surface_count():
		var src := mi.mesh.surface_get_material(i)
		var slot := src.resource_name if src else ""
		mi.set_surface_override_material(i, glow if slot == "glow" else (joint if slot == "joint" else armor))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.owner = null
	mi.get_parent().remove_child(mi)
	scene.free()
	return mi
