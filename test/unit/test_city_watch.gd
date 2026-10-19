extends GutTest
## The City Is Watching (CityWatch): news drones that follow the combo, city
## screens with the live feed and the seed's record, and the promise that none
## of it touches the run's random streams.

const SEED := 0x5EED0099
const FLY_TIME_PLUS := CityWatch.FLY_TIME + 0.5

var backdrop: CityBackdrop
var watch: CityWatch
var _saved_scores: Array


func before_each() -> void:
	_saved_scores = Profile.high_scores.duplicate(true)
	Quality.apply("medium")
	Game.next_seed = SEED
	Game.reset_run()
	backdrop = CityBackdrop.new()
	backdrop.accents = Game.palette.accents # what build() would take from the map
	add_child_autofree(backdrop)


func after_each() -> void:
	Profile.high_scores = _saved_scores
	Game.combo = 0
	Game.score = 0
	Game.kills = 0
	Quality.apply(Quality.DEFAULT)


func _build() -> void:
	watch = CityWatch.new()
	backdrop.add_child(watch)
	watch.build(backdrop)


func _run(seconds: float) -> void:
	var dt := 1.0 / 30.0
	for i in int(seconds / dt):
		watch.tick(dt, dt)


func test_drone_count_follows_the_combo() -> void:
	assert_eq(CityWatch.drones_for_combo(0, 8), 0)
	assert_eq(CityWatch.drones_for_combo(3, 8), 0, "no drone before the first step")
	assert_eq(CityWatch.drones_for_combo(4, 8), 1)
	assert_eq(CityWatch.drones_for_combo(21, 8), 5)
	assert_eq(CityWatch.drones_for_combo(200, 8), 8, "capped by the preset")


func test_seed_record_is_the_best_saved_score_on_this_seed() -> void:
	var scores := [
		{"name": "AAA", "score": 9000, "wave": 7, "seed": "1111-1111"},
		{"name": "WIL", "score": 5000, "wave": 5, "seed": "2222-2222"},
		{"name": "BOB", "score": 3000, "wave": 4, "seed": "2222-2222"},
	]
	assert_eq(str(CityWatch.seed_record(scores, "2222-2222").name), "WIL")
	assert_true(CityWatch.seed_record(scores, "3333-3333").is_empty())
	assert_true(CityWatch.seed_record([], "2222-2222").is_empty())


func test_building_never_draws_from_the_run_streams() -> void:
	var before := [Game.rng_map.state, Game.rng_waves.state, Game.rng_upgrades.state, Game.rng_hazards.state, backdrop.rng.state]
	_build()
	var after := [Game.rng_map.state, Game.rng_waves.state, Game.rng_upgrades.state, Game.rng_hazards.state, backdrop.rng.state]
	assert_eq(after, before)


func test_drones_gather_with_the_combo_then_leave() -> void:
	_build()
	Game.combo = 21
	_run(FLY_TIME_PLUS)
	assert_eq(watch.active_drones(), 5)
	assert_eq(watch.visible_drones(), 5)
	Game.combo = 0
	_run(CityWatch.LINGER - 1.0)
	assert_eq(watch.active_drones(), 5, "they linger after the combo breaks")
	_run(1.0 + CityWatch.LEAVE_GAP * 5.0 + CityWatch.FLY_TIME + 0.5)
	assert_eq(watch.active_drones(), 0)
	assert_eq(watch.visible_drones(), 0, "all flown back into the city")


func test_weak_preset_keeps_fewer_drones_and_screens() -> void:
	_build()
	Quality.apply("low")
	Game.combo = 60
	_run(FLY_TIME_PLUS)
	assert_eq(watch.active_drones(), Quality.cap("drones"))
	var shown := 0
	for s in watch.screens:
		shown += 1 if s.visible else 0
	assert_eq(shown, 2)
	Quality.apply("high")
	_run(FLY_TIME_PLUS)
	assert_eq(watch.active_drones(), 12)


func test_screens_show_the_seed_record() -> void:
	Profile.high_scores = [{"name": "WIL", "score": 5000, "wave": 5, "seed": Game.seed_string(SEED)}]
	_build()
	var texts := _all_lines()
	assert_true(texts.has("TSUKUYOMI LIVE"), "one screen opens on the live feed")
	assert_true(texts.has("WIL"), "the other on the seed's record")
	assert_true(texts.has("BEST 5,000"))


func test_screens_say_when_a_seed_has_no_record() -> void:
	Profile.high_scores = []
	_build()
	assert_true(_all_lines().has("NO RECORD YET"))


func test_passing_the_record_puts_new_best_on_every_screen() -> void:
	Profile.high_scores = [{"name": "WIL", "score": 5000, "wave": 5, "seed": Game.seed_string(SEED)}]
	_build()
	Game.score = 5001
	_run(0.5)
	for s in watch.screens:
		assert_eq(s.lines[1].text, "NEW BEST")
		assert_eq(s.lines[2].text, "WIL BEATEN")
	_run(CityWatch.NEW_BEST_TIME + 0.5)
	assert_ne(watch.screens[0].lines[1].text, "NEW BEST", "back to the normal pages")


func test_live_feed_follows_score_kills_and_combo() -> void:
	_build()
	var live: CityScreen = watch.screens[0]
	Game.score = 48210
	Game.kills = 31
	_run(0.1)
	assert_eq(live.lines[1].text, "48,210")
	assert_eq(live.lines[2].text, "31 KILLS")
	Game.combo = 12
	_run(0.1)
	assert_eq(live.lines[2].text, "x12 COMBO")


func _all_lines() -> Array:
	var out := []
	for s in watch.screens:
		for l in s.lines:
			out.append(l.text)
	return out
