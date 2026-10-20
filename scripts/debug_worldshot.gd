extends Node
## Debug: the Well's world detail from fixed eye-level views, with frozen
## enemies, one PNG per view (and the puddle mirror's picture next to it),
## with the frame's draw calls and primitives (the mirror's pass included).
## `--worldshot --out=DIR [--views=roof,pit]`; quits when done.

const VIEWS := {
	# name: position, yaw (0 north, PI/2 west), pitch
	"roof": [Vector3(-21, 0.1, 19), -0.62, -0.02],
	"pit": [Vector3(2.5, -9.9, 4.5), 0.12, 0.38],
	"service": [Vector3(7, -4.9, 10.5), 1.02, -0.02],
	"deck": [Vector3(-25, 5.1, -23.2), -1.3, 0.1],
	"puddle": [Vector3(0, 0.1, 20.5), 0.0, -0.75],
	"tower": [Vector3(4, 10.1, -26), PI + 0.25, -0.22],
}
const FOES := [
	["grunt", Vector3(-2, 0, 14), 0.3], ["gunner", Vector3(6, 5, -20), 0.2],
	["brute", Vector3(-10, 0, 17), 2.0], ["grunt", Vector3(2.5, -5, 10.5), 0.4],
	["grunt", Vector3(-1, -10, 2), -0.4], ["gunner", Vector3(12, 5, -2), -1.4],
	["grunt", Vector3(-16, 0, 2), 0.8], ["grunt", Vector3(-14, 0, 9), 1.8],
	["grunt", Vector3(5, 0, -16), 2.6], ["gunner", Vector3(-6, 0, -18), 2.9],
]

var out := "user://worldshot"
var names: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--views="):
			names = Array(a.substr(8).split(","))
	if names.is_empty():
		names = VIEWS.keys()
	DirAccess.make_dir_recursive_absolute(out)
	Game.state = "playing"
	Game.hud.hide_title()
	var dir: Node = Game.main.director
	for f in FOES:
		var e := Enemy.new()
		e.setup(f[0])
		e.position = f[1]
		e.rotation.y = f[2]
		e.frozen = true
		dir.add_child(e)
	var well := Game.arena as WellMap
	if well and well.detail:
		print("WORLDSHOT detail: %d props, %d puddles, %d glass, rain %d" % [well.detail.props, well.detail.puddles, well.detail.glass, well.rain_level])
	_run.call_deferred()


func _run() -> void:
	var p: Player = Game.player
	for n in names:
		var v: Array = VIEWS[n]
		for i in 40:
			p.global_position = v[0]
			p.velocity = Vector3.ZERO
			p.yaw = v[1]
			p.pitch = v[2]
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/%s.png" % [out, n])
		var well := Game.arena as WellMap
		if well and well.detail and well.detail.mirror:
			well.detail.mirror.vp.get_texture().get_image().save_png("%s/%s_mirror.png" % [out, n])
		print("WORLDSHOT %s %s: %d draw calls, %d primitives" % [n, img.get_size(), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
	get_tree().quit()
