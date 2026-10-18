extends Node
## Debug-only camera tour for checking palettes and colour spread.
## Run with:  godot --path . -- --palettetour [--palette=SUNSET DRIVE|0..4]
## Holds four fixed views of the arena, 1.5 s each, then quits.

const VIEWS := [
	[Vector3(0, 0.1, 26), 0.0, 0.06],
	[Vector3(-24.5, 3.3, 10), -PI * 0.6, -0.08],
	[Vector3(22, 0.1, -24), PI * 0.75, 0.1],
	[Vector3(0, 2.5, -2), PI, 0.02],
]
const HOLD := 1.5

var t := 0.0
var view := -1


func _ready() -> void:
	Game.state = "playing"
	Game.hud.hide_title()


func _process(delta: float) -> void:
	t += delta
	var want := int(t / HOLD)
	if want >= VIEWS.size():
		get_tree().quit()
		return
	if want != view:
		view = want
		print("PALETTE TOUR view %d (%s)" % [view, Game.palette.name])
	var v: Array = VIEWS[view]
	var p: Player = Game.player
	p.global_position = v[0]
	p.velocity = Vector3.ZERO
	p.yaw = v[1]
	p.pitch = v[2]
