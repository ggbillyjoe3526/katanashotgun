extends GutTest
## Quality-of-life helpers (owner, 2026-10-24): markers that point to the
## last few foes and an off-screen boss, and HOW TO PLAY showing the
## player's own keys.

const VS := Vector2(480, 270)


## An enemy with no body or brain: the markers only need where it stands.
class StandIn:
	extends Enemy

	func _ready() -> void:
		pass

	func _physics_process(_delta: float) -> void:
		pass


var _cam: Camera3D
var _arrows: TargetArrows
var _saved_list: Array


func before_each() -> void:
	_saved_list = Game.enemy_list
	Game.enemy_list = []
	_cam = Camera3D.new()
	_cam.fov = 70.0
	add_child_autofree(_cam)
	_cam.global_position = Vector3(0, 1.7, 0) # looking down -Z
	_cam.make_current()
	_arrows = TargetArrows.new()
	add_child_autofree(_arrows)


func after_each() -> void:
	Game.enemy_list = _saved_list


func _foe(pos: Vector3, boss := false) -> Enemy:
	var e := StandIn.new()
	e.setup("grunt")
	e.is_boss = boss
	add_child_autofree(e)
	e.global_position = pos
	return e


func test_a_foe_behind_you_gets_an_arrow_on_the_bottom_edge() -> void:
	_arrows._mark(_cam, _foe(Vector3(0, 0, 12)), VS)
	assert_eq(_arrows._n, 1)
	assert_gt(_arrows._dir[0].y, 0.9, "points down: behind you")
	assert_almost_eq(_arrows._pos[0].y, VS.y - TargetArrows.EDGE, 1.0, "on the bottom edge")


func test_a_foe_off_to_the_right_gets_an_arrow_on_the_right_edge() -> void:
	_arrows._mark(_cam, _foe(Vector3(30, 0, -5)), VS)
	assert_eq(_arrows._n, 1)
	assert_gt(_arrows._dir[0].x, 0.8, "points right")
	assert_almost_eq(_arrows._pos[0].x, VS.x - TargetArrows.EDGE, 1.0, "on the right edge")


func test_a_far_foe_on_screen_gets_a_chevron_and_a_near_one_nothing() -> void:
	_arrows._mark(_cam, _foe(Vector3(0, 0, -30)), VS)
	assert_eq(_arrows._n, 1)
	assert_eq(_arrows._dir[0], Vector2.ZERO, "a chevron over its head, not an arrow")
	assert_lt(absf(_arrows._pos[0].x - VS.x * 0.5), 2.0, "right over it, mid-screen")
	_arrows._mark(_cam, _foe(Vector3(0, 0, -6)), VS)
	assert_eq(_arrows._n, 1, "a foe this close needs no marker")


func test_the_boss_gets_a_big_arrow_only_off_screen() -> void:
	_arrows._mark(_cam, _foe(Vector3(0, 0, -30), true), VS)
	assert_eq(_arrows._n, 0, "on screen the boss is never lost")
	_arrows._mark(_cam, _foe(Vector3(-25, 0, 8), true), VS)
	assert_eq(_arrows._n, 1)
	assert_eq(_arrows._big[0], 1)
	assert_lt(_arrows._dir[0].x, 0.0, "points left")


func test_markers_never_pass_their_cap() -> void:
	for i in TargetArrows.MAX_MARKS + 3:
		_arrows._mark(_cam, _foe(Vector3(0, 0, 12 + i)), VS)
	assert_eq(_arrows._n, TargetArrows.MAX_MARKS)


func test_markers_wait_for_the_last_few_foes() -> void:
	var d := WaveDirector.new()
	d.phase = "spawning"
	d.queue = [["grunt", 1.0]]
	Game.enemy_list = [null, null]
	assert_false(TargetArrows.stragglers(d), "foes still to come")
	d.queue = []
	assert_true(TargetArrows.stragglers(d), "two left, none to come")
	Game.enemy_list = [null, null, null, null]
	assert_false(TargetArrows.stragglers(d), "four left is still a fight")
	Game.enemy_list = [null]
	d.phase = "boss"
	assert_false(TargetArrows.stragglers(d), "a boss wave marks the boss alone")
	d.free()


func test_how_to_play_shows_the_players_own_keys() -> void:
	var jump := InputMap.action_get_events("jump").duplicate()
	var k := InputEventKey.new()
	k.physical_keycode = KEY_V
	InputMap.action_erase_events("jump")
	InputMap.action_add_event("jump", k)
	var hud := Hud.new()
	add_child_autofree(hud)
	var box := Control.new()
	add_child_autofree(box)
	hud._fill_howto(box)
	var words := []
	for l: Label in box.get_children():
		words.append(l.text)
	InputMap.action_erase_events("jump")
	for ev in jump:
		InputMap.action_add_event("jump", ev)
	assert_has(words, "V", "the rebound jump key")
	assert_has(words, "LMB", "the katana's button")
	assert_has(words, "HIGH ABOVE A FOE: PLUNGE ONTO IT")
	assert_false(words.has("SPACE"), "never the default once rebound")
