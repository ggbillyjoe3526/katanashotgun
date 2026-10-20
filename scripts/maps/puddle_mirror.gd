class_name PuddleMirror
extends Node
## Reflections in rain puddles and skylight glass (WorldDetail), and nowhere
## else: the owner's rule is that only surfaces that would really reflect do.
## A second camera, mirrored under the floor the player stands on, draws only
## the bright things (neon, signs, lamps, the lit city) into a small texture;
## puddle.gdshader shows it where there is water. Water on another level
## shows a dark sheen instead. WEAK switches the camera off (sheen only);
## MEDIOCRE draws it at half the 3D view's size, INSANE at full size.

const LAYER := WorldDetail.MIRROR_LAYER
## The mirror plane sits this far below the floor height the map reports
## (the plates' top), between the plates and the open cells' water.
const PLANE_OFFSET := -0.025
const MAX_SIZE := Vector2i(1280, 720)

var arena: WellMap
var vp: SubViewport
var cam: Camera3D
var mats: Array[ShaderMaterial] = []
var bright: Array[GeometryInstance3D] = []
var scale := 0.5
var _plane := INF


func setup(a: WellMap, water: Array[ShaderMaterial]) -> void:
	arena = a
	mats = water
	process_priority = 100 # after the player has moved this frame
	vp = SubViewport.new()
	vp.size = Vector2i(480, 270)
	add_child(vp)
	cam = Camera3D.new()
	cam.cull_mask = LAYER
	# the night sky is dark in water: only lit things show in a puddle
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(a.pal.sky_top).darkened(0.55)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = a.pal.ambient
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	cam.environment = env
	vp.add_child(cam)
	for n in a.find_children("*", "GeometryInstance3D", true, false):
		var gi: GeometryInstance3D = n
		var m := gi.material_override as ShaderMaterial
		if m == null or m in mats:
			continue
		var glow: Variant = m.get_shader_parameter("emission_from_texture")
		if m.shader == Psx.shader("psx_unlit") or (n is MultiMeshInstance3D and a.backdrop.is_ancestor_of(n)) or (glow != null and float(glow) > 1.0 and m != a.m_grid):
			bright.append(gi)
	for m in mats:
		m.set_shader_parameter("refl_tex", vp.get_texture())
	Quality.on_changed(_on_quality)
	_on_quality(Quality.preset)


func _exit_tree() -> void:
	Quality.off_changed(_on_quality)


func _on_quality(id: String) -> void:
	var on := id != "low"
	scale = 1.0 if id == "high" else 0.5
	if vp:
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	for m in mats:
		m.set_shader_parameter("mirror", on)


func _process(_dt: float) -> void:
	var main := get_viewport().get_camera_3d()
	if main == null or vp.render_target_update_mode == SubViewport.UPDATE_DISABLED:
		return
	var p := main.global_position
	var plane := arena.floor_height_at(p.x, p.z, p.y) + PLANE_OFFSET
	if plane != _plane:
		_plane = plane
		# things under the water line would show through it: leave them out
		for g in bright:
			var low := g.global_position.y < plane - 0.2 and not arena.backdrop.is_ancestor_of(g)
			g.layers = (g.layers & ~LAYER) if low else (g.layers | LAYER)
		for m in mats:
			m.set_shader_parameter("refl_plane", plane)
	# the camera mirrored in the plane, turned upside down so its basis stays
	# a rotation; the shader flips the picture back
	var b := main.global_basis
	var up_r := Vector3(b.y.x, -b.y.y, b.y.z)
	var back_r := Vector3(b.z.x, -b.z.y, b.z.z)
	cam.global_transform = Transform3D(Basis(b.x, -up_r, back_r), Vector3(p.x, 2.0 * plane - p.y, p.z))
	cam.fov = main.fov
	cam.near = main.near
	cam.far = main.far
	var sz := Vector2(get_viewport().get_visible_rect().size) * scale
	var want := Vector2i(mini(int(sz.x), MAX_SIZE.x), mini(int(sz.y), MAX_SIZE.y)).max(Vector2i(64, 36))
	if vp.size != want:
		vp.size = want
