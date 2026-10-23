extends GutTest
## The wave director's flow (spec §6): a wave is clear only when its line-up
## is spent and nobody from it is still standing.


## A director whose spawns are bare stand-ins in the "enemies" group: the
## flow test needs who is in the fight, not bodies, a map or a HUD.
class FlowDirector:
	extends WaveDirector

	func _ready() -> void:
		_spawn_rng = RandomNumberGenerator.new()
		_spawn_rng.seed = 7

	func _pick_spawn() -> Vector3:
		return Vector3.ZERO

	func _spawn(_kind: String, _scale: float, _pos: Vector3, _before_ready := Callable()) -> Enemy:
		var n := Node3D.new()
		n.add_to_group("enemies")
		add_child(n)
		Enemy.list_dirty = true
		return null


var _state := ""


func before_each() -> void:
	_state = Game.state
	Game.state = "playing"
	Game.mutator = {}
	Game.enemy_list = []
	Enemy.list_dirty = false


func after_each() -> void:
	Game.state = _state
	Game.enemy_list = []
	Enemy.list_dirty = true


func test_the_last_group_onto_an_empty_field_does_not_clear_the_wave() -> void:
	var d := FlowDirector.new()
	add_child_autofree(d)
	d.wave = 1
	d.phase = "spawning"
	d.spawn_t = 0.0
	d.queue = [["grunt", 1.0]]
	d._physics_process(1.0 / 60.0)
	assert_true(d.queue.is_empty(), "the last group spawned")
	assert_eq(Game.enemy_list.size(), 1, "and it is counted at once")
	assert_eq(d.phase, "spawning", "so the wave is not over while it stands")


func test_a_group_never_takes_the_field_past_the_cap() -> void:
	# spec §6: max alive min(8 + 2w, 22); a group arriving one under it brings one
	var d := FlowDirector.new()
	add_child_autofree(d)
	d.wave = 1
	var cap := d._max_alive()
	for i in cap - 1:
		d._spawn("grunt", 1.0, Vector3.ZERO)
	d._sync_enemy_list()
	for n in 20:
		d.phase = "spawning"
		d.spawn_t = 0.0
		d.queue = [["grunt", 1.0], ["grunt", 1.0], ["grunt", 1.0]]
		d._physics_process(1.0 / 60.0)
		assert_lte(Game.enemy_list.size(), cap, "never past the cap (try %d)" % n)
		# back to one under the cap for the next roll of the group size
		while Game.enemy_list.size() > cap - 1:
			var e: Node = Game.enemy_list.pop_back()
			e.remove_from_group("enemies")
			e.queue_free()


func test_a_cleared_wave_defuses_shockwaves_still_rolling_out() -> void:
	var fx := Fx.new()
	add_child_autofree(fx)
	fx.shockwave(Vector3.ZERO, 24.0, 15.0, 26.0)
	fx.clear_strikes()
	assert_eq(fx._waves.size(), 1, "the ring finishes its roll")
	assert_true(fx._waves[0].hit, "but can no longer hurt the player")


func test_a_suspended_run_keeps_its_combo() -> void:
	# spec §11.3: the snapshot between waves holds the combo state
	var d := WaveDirector.new()
	var p := Player.new()
	var keep := [Game.combo, Game.combo_timer]
	Game.combo = 23
	Game.combo_timer = 2.5
	var snap := RunSnapshot.capture(4, d, p)
	Game.combo = keep[0]
	Game.combo_timer = keep[1]
	# through the file and back, as CONTINUE reads it
	var back: Dictionary = JSON.parse_string(JSON.stringify(snap))
	assert_eq(int(back.game.combo), 23)
	assert_almost_eq(float(back.game.combo_timer), 2.5, 0.001)
	d.free()
	p.free()


func test_a_boss_reward_is_paid_once_per_snapshot() -> void:
	# quit after the wave 3 boss fell, CONTINUE (the snapshot from before the
	# boss wave, saved again with its mark), fell it again: no second reward
	var snap := {"next_wave": 3}
	assert_false(RunSnapshot.boss_paid(snap, 3), "first kill pays")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(snap))
	assert_true(RunSnapshot.boss_paid(saved, 3), "the continued run's kill does not")
	assert_false(RunSnapshot.boss_paid(saved, 6), "a later boss still pays")
	assert_false(RunSnapshot.boss_paid({"next_wave": 3}, 3), "an older snapshot without the mark pays")
