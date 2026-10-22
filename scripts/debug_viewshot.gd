extends Node
## Debug: the first-person view (weapons, hands, eye height) from fixed spots
## with frozen enemies at 3, 7, 12 and 18 m, one PNG per view. The view's
## numbers can be overridden to try a change before making it:
## `--viewshot --out=DIR [--views=roof,street,deck] [--eye=1.72] [--fov=88]
## [--vm=0.42] [--kpos=x,y,z] [--krot=x,y,z] [--kscale=1.5] [--kroll=1.9]
## [--spos=x,y,z] [--srot=x,y,z] [--slash=0|1|2 --at=0.06] [--pose=NAME]`.
## `--slash` holds a katana swing `--at` seconds in; `--pose` holds a glory
## kill pose (Viewmodel K_POSES / S_POSES). Quits when done.

const VIEWS := {
	# name: position, yaw (0 north, PI/2 west), pitch
	"roof": [Vector3(-21, 0.1, 19), -0.62, -0.02],
	"street": [Vector3(-6, 0.1, 20), 0.15, -0.05],
	"deck": [Vector3(-25, 5.1, -23.2), -1.3, 0.1],
}
# kind, metres ahead, metres to the right
const FOES := [["grunt", 3.2, -0.9], ["gunner", 7.0, 2.2], ["brute", 12.0, -3.0], ["grunt", 18.0, 1.5]]

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
	for f in FOES:
		var e := Enemy.new()
		e.setup(f[0])
		e.position = v[0] + fwd * float(f[1]) + right * float(f[2])
		e.position.y = Game.arena.floor_height_at(e.position.x, e.position.z, v[0].y + 1.0)
		e.rotation.y = v[1]
		e.frozen = true
		Game.main.director.add_child(e)
		made.append(e)
	return made


func _apply(p: Player) -> void:
	var vm := p.vm
	p.eye_height = float(opt.get("eye", p.eye_height))
	if opt.has("fov"):
		Settings.fov = float(opt.fov)
	if opt.has("vm"):
		vm.scale = Vector3.ONE * float(opt.vm)
	if opt.has("kpos"):
		vm.katana_idle_pos = _vec(opt.kpos)
	if opt.has("krot"):
		vm.katana_idle_rot = _vec(opt.krot)
	if opt.has("kscale"):
		vm._model_blade.scale = Vector3.ONE * float(opt.kscale)
	if opt.has("kroll"):
		vm._model_blade.rotation.y = float(opt.kroll)
	if opt.has("spos"):
		vm.shotgun_idle_pos = _vec(opt.spos)
	if opt.has("srot"):
		vm.shotgun_idle_rot = _vec(opt.srot)
	if opt.has("pose"):
		vm.glory_begin()
		vm.glory_pose(opt.pose)


func _run() -> void:
	var p: Player = Game.player
	_apply(p)
	for n in names:
		var v: Array = VIEWS[n]
		var foes := _foes(v)
		for i in 50:
			p.global_position = v[0]
			p.velocity = Vector3.ZERO
			p.yaw = v[1]
			p.pitch = v[2]
			if opt.has("slash") and i >= 40:
				if i == 40:
					p.vm.slash(int(opt.slash))
				p.vm._slash_t = float(opt.get("at", "0.06"))
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, n])
		print("VIEWSHOT %s" % n)
		for e in foes:
			e.queue_free()
	get_tree().quit()
