extends Node
## Debug-only tour of The City Is Watching (spec §19.1 #9): fixed views while
## a fake combo calls the news drones in, the screens swap pages, the score
## passes a made-up seed record (NEW BEST), then the combo breaks and the
## drones fly off. Run with:  godot --path . -- --citytour [--quality=low]
## Quits at the end. Nothing here is saved.

const VIEWS := [
	# position, yaw (0 north, PI/2 west), pitch, seconds
	[Vector3(0, 0.1, 24), 0.0, 0.28, 7.0], # the spawn, looking north: drones fly in
	[Vector3(0, 0.1, 24), 0.6, 0.85, 4.0], # looking up at the drones
	[Vector3(4, 10.1, -26), PI, 0.25, 5.0], # the shrine tower, looking south over the roof
	[Vector3(0, 5.1, 0), PI * 0.5, 0.2, 5.0], # the bridge, looking west
	[Vector3(0, 0.1, 24), 0.0, 0.2, 5.0], # back north: NEW BEST on the screens
	[Vector3(0, 0.1, 24), 0.6, 0.85, 11.0], # the combo breaks: the drones leave
]
const RECORD := 60000

var t := 0.0
var view := -1
var _watch: CityWatch


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.state = "playing"
	Game.hud.hide_title()
	var bd: Variant = Game.arena.get("backdrop")
	if bd is CityBackdrop:
		_watch = bd.watch
		_watch.demo_record("WIL", RECORD)
	Game.score = 41250


func _process(_delta: float) -> void:
	t += Game.real_dt
	var start := 0.0
	var want := VIEWS.size()
	for i in VIEWS.size():
		if t < start + float(VIEWS[i][3]):
			want = i
			break
		start += float(VIEWS[i][3])
	if want >= VIEWS.size():
		get_tree().quit()
		return
	if want != view:
		view = want
		print("CITY TOUR view %d (%s)" % [view, Quality.NAMES[Quality.preset]])
	# the combo climbs to 36 over the first view and holds, the score passes
	# the record in view 4, and the combo breaks at view 5
	if view < 5:
		Game.combo = mini(36, int(t * 6.0))
		Game.combo_timer = Game.combo_window()
		Game.kills = Game.combo + 112
	if view == 4 and Game.score <= RECORD:
		Game.score = RECORD + 1850
	var v: Array = VIEWS[view]
	var p: Player = Game.player
	p.global_position = v[0]
	p.velocity = Vector3.ZERO
	p.yaw = v[1]
	p.pitch = v[2]
