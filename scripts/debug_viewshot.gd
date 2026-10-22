extends Node
## Debug (concepts): the first-person view from fixed spots with frozen
## enemies at known distances, with the view's numbers overridable, one PNG
## per view. `--viewshot --out=DIR [--eye=1.55] [--fov=88] [--vm=0.5]
## [--kpos=x,y,z] [--krot=x,y,z] [--kscale=1] [--kroll=0.9] [--spos=x,y,z]
## [--srot=x,y,z] [--sscale=1] [--views=a,b] [--slash=0.06]`; quits when done.

const VIEWS := {
	"roof": [Vector3(-21, 0.1, 19), -0.62, -0.02],
	"street": [Vector3(-6, 0.1, 20), 0.15, -0.05],
	"deck": [Vector3(-25, 5.1, -23.2), -1.3, 0.1],
}

var out := "user://viewshot"
var names: Array = []
var opt := {}


func _vec(s: String) -> Vector3:
	var p := s.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=", true, 1)
			opt[kv[0]] = kv[1]
	out = opt.get("out", out)
	names = Array(String(opt.get("views", "roof,street")).split(","))
	DirAccess.make_dir_recursive_absolute(out)
	Game.state = "playing"
	Game.hud.hide_title()
	_run.call_deferred()


func _foes(v: Array) -> Array[Enemy]:
	var made: Array[Enemy] = []
	var fwd := Vector3(-sin(v[1]), 0, -cos(v[1]))
	var right := Vector3(-fwd.z, 0, fwd.x)
	var spots := [["grunt", 3.2, -0.9], ["gunner", 7.0, 2.2], ["brute", 12.0, -3.0], ["grunt", 18.0, 1.5]]
	for s in spots:
		var e := Enemy.new()
		e.setup(s[0])
		e.position = v[0] + fwd * float(s[1]) + right * float(s[2])
		e.position.y = Game.arena.floor_height_at(e.position.x, e.position.z, v[0].y + 1.0)
		e.rotation.y = v[1]
		e.frozen = true
		Game.main.director.add_child(e)
		made.append(e)
	return made


func _run() -> void:
	var p: Player = Game.player
	var vm := p.vm
	p.eye_height = float(opt.get("eye", p.EYE_HEIGHT))
	if opt.has("fov"):
		Settings.fov = float(opt.fov)
	if opt.has("vm"):
		vm.scale = Vector3.ONE * float(opt.vm)
	if opt.has("kpos"):
		vm.katana_idle_pos = _vec(opt.kpos)
	if opt.has("krot"):
		vm.katana_idle_rot = _vec(opt.krot)
	if opt.has("kscale"):
		vm.katana.scale = Vector3.ONE * float(opt.kscale)
	if opt.has("kroll"):
		vm._model_blade.rotation.y = float(opt.kroll)
	if opt.has("spos"):
		vm.shotgun_idle_pos = _vec(opt.spos)
	if opt.has("srot"):
		vm.shotgun_idle_rot = _vec(opt.srot)
	if opt.has("sscale"):
		vm.shotgun.scale = Vector3.ONE * float(opt.sscale)
	if opt.has("hands"):
		_hands(vm)
	for n in names:
		var v: Array = VIEWS[n]
		var foes := _foes(v)
		for i in 50:
			p.global_position = v[0]
			p.velocity = Vector3.ZERO
			p.yaw = v[1]
			p.pitch = v[2]
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, n])
		print("VIEWSHOT %s" % n)
		for e in foes:
			e.queue_free()
	get_tree().quit()


func _hands(vm: Viewmodel) -> void:
	var packed := load("res://assets/models/hands/hands.glb") as PackedScene
	var scene := packed.instantiate()
	var armor := Psx.lit(Color(0.5, 0.53, 0.6), null, false, 1.0, {"snap": 0.35, "affine": 0.0, "fog_start": 50.0, "emission_color": Color(0.55, 0.6, 0.75), "emission_strength": 0.12})
	var joint := Psx.lit(Color(0.1, 0.1, 0.12), null, false, 1.0, {"snap": 0.35, "affine": 0.0, "fog_start": 50.0})
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		var glow: Material = vm.trim_mat if mi.name.begins_with("hand_katana") else vm.strip_mats[1]
		for i in mi.mesh.get_surface_count():
			var slot := mi.mesh.surface_get_material(i).resource_name
			mi.set_surface_override_material(i, armor if slot == "armor" else (joint if slot == "joint" else glow))
		var t := mi.global_transform if mi.is_inside_tree() else mi.transform
		mi.get_parent().remove_child(mi)
		mi.transform = t
		if mi.name.begins_with("hand_katana"):
			vm._model_blade.add_child(mi)
		else:
			vm._model_gun.add_child(mi)
	for c in vm.katana.get_children():
		if c != vm._code_blade and c != vm._model_blade:
			c.visible = false
	for c in vm.shotgun.get_children():
		if c != vm.spin_pivot:
			c.visible = false
	for c in vm.spin_pivot.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is BoxMesh:
			c.visible = false
