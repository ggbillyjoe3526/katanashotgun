extends GutTest
## Saving is rock solid (spec §11.3): atomic writes, one backup, corrupt and
## half-written files, version migration, and a profile that is never wiped
## because a load failed. Each test gets its own empty folder.

const ROOT := "user://test-save"

var dir := ""
var _n := 0


func before_each() -> void:
	_n += 1
	dir = "%s/%d" % [ROOT, _n]
	_wipe(dir)
	DirAccess.make_dir_recursive_absolute(dir)


func after_all() -> void:
	_wipe(ROOT)
	Profile.use_dir("user://test")


func _wipe(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for d in DirAccess.get_directories_at(path):
		_wipe(path.path_join(d))
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)


func _path() -> String:
	return dir.path_join("thing.json")


func _write_raw(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _corrupt(path: String) -> void:
	var text := SaveFile.read_text(path)
	_write_raw(path, text.substr(0, text.length() - 7) + "garbage")


# ---------------------------------------------------------------- SaveFile
func test_round_trip() -> void:
	assert_true(SaveFile.write(_path(), "thing", 3, {"a": 1, "b": "two"}))
	var r := SaveFile.read(_path(), "thing")
	assert_true(r.ok)
	assert_eq(r.version, 3)
	assert_eq(r.source, "main")
	assert_eq(int(r.data.a), 1)
	assert_eq(r.data.b, "two")
	assert_false(FileAccess.file_exists(_path() + ".tmp"), "no temp file left behind")


func test_second_write_keeps_a_backup() -> void:
	SaveFile.write(_path(), "thing", 1, {"n": 1})
	SaveFile.write(_path(), "thing", 1, {"n": 2})
	assert_eq(int(SaveFile.decode(SaveFile.read_text(_path() + ".bak"), "thing").data.n), 1)
	assert_eq(int(SaveFile.read(_path(), "thing").data.n), 2)


func test_checksum_catches_damage() -> void:
	SaveFile.write(_path(), "thing", 1, {"n": 1})
	_corrupt(_path())
	assert_false(SaveFile.decode(SaveFile.read_text(_path()), "thing").ok)


func test_damaged_file_falls_back_to_backup() -> void:
	SaveFile.write(_path(), "thing", 1, {"n": 1})
	SaveFile.write(_path(), "thing", 1, {"n": 2})
	_corrupt(_path())
	var r := SaveFile.read(_path(), "thing")
	assert_true(r.ok)
	assert_eq(r.source, "backup")
	assert_eq(int(r.data.n), 1)


func test_half_written_file_falls_back() -> void:
	# a crash or full disk mid-write leaves a short file
	SaveFile.write(_path(), "thing", 1, {"n": 1})
	SaveFile.write(_path(), "thing", 1, {"n": 2, "pad": "x".repeat(200)})
	var text := SaveFile.read_text(_path())
	_write_raw(_path(), text.substr(0, text.length() / 2))
	var r := SaveFile.read(_path(), "thing")
	assert_true(r.ok)
	assert_eq(int(r.data.n), 1)


func test_crash_during_temp_write_keeps_the_old_file() -> void:
	SaveFile.write(_path(), "thing", 1, {"n": 1})
	_write_raw(_path() + ".tmp", SaveFile.encode("thing", 1, {"n": 2}).substr(0, 30))
	var r := SaveFile.read(_path(), "thing")
	assert_eq(r.source, "main")
	assert_eq(int(r.data.n), 1)


func test_crash_between_rotate_and_rename_uses_the_temp_file() -> void:
	# the old file became the backup, the new one is complete in .tmp, and
	# the game died before renaming it
	SaveFile.write(_path(), "thing", 1, {"n": 1})
	DirAccess.rename_absolute(_path(), _path() + ".bak")
	_write_raw(_path() + ".tmp", SaveFile.encode("thing", 1, {"n": 2}))
	var r := SaveFile.read(_path(), "thing")
	assert_eq(r.source, "tmp")
	assert_eq(int(r.data.n), 2)
	# and the next write cleans up
	assert_true(SaveFile.write(_path(), "thing", 1, {"n": 3}))
	assert_eq(int(SaveFile.read(_path(), "thing").data.n), 3)
	assert_false(FileAccess.file_exists(_path() + ".tmp"))


func test_a_damaged_file_never_replaces_a_good_backup() -> void:
	SaveFile.write(_path(), "thing", 1, {"n": 1})
	SaveFile.write(_path(), "thing", 1, {"n": 2})
	_corrupt(_path())
	SaveFile.write(_path(), "thing", 1, {"n": 3})
	assert_eq(int(SaveFile.decode(SaveFile.read_text(_path() + ".bak"), "thing").data.n), 1)
	var kept := Array(DirAccess.get_files_at(dir)).filter(func(f): return f.begins_with("thing.json.corrupt-"))
	assert_eq(kept.size(), 1, "the damaged copy is moved aside, never deleted")


func test_wrong_kind_is_rejected() -> void:
	SaveFile.write(_path(), "run", 1, {"n": 1})
	assert_false(SaveFile.read(_path(), "profile").ok)


func test_garbage_and_empty_files_are_rejected() -> void:
	for text in ["", "{}", "KSAVE thing 1\n{}", "KSAVE thing x abc\n{}", "not a save at all"]:
		assert_false(SaveFile.decode(text, "thing").ok, "accepted: %s" % text)


func test_nothing_on_disk_reports_not_found() -> void:
	var r := SaveFile.read(_path(), "thing")
	assert_false(r.ok)
	assert_false(r.found)


# ---------------------------------------------------------------- Profile
func test_new_profile_is_written_at_once() -> void:
	Profile.use_dir(dir)
	assert_eq(Profile.loaded_from, "new")
	assert_eq(Profile.player_level, 1)
	assert_true(SaveFile.read(Profile.profile_path(), "profile").ok)


func test_progress_survives_a_reload() -> void:
	Profile.use_dir(dir)
	var res := Profile.finish_run({"score": 50000, "wave": 7, "bosses": 2, "kills": 120, "glory_kills": 30})
	assert_gt(res.xp_gained, 0)
	Profile.boss_felled("ninja")
	Profile.equip("katana", "edge_kagerou")
	Profile.store_settings({"v": 1, "fov": 95})
	Profile.save_now()
	var lv := Profile.player_level
	var xp := Profile.player_xp
	Profile.use_dir(dir)
	assert_eq(Profile.loaded_from, "main")
	assert_eq(Profile.player_level, lv)
	assert_eq(Profile.player_xp, xp)
	assert_true(Profile.is_unlocked("edge_kagerou"))
	assert_eq(Profile.get_equipped("katana"), "edge_kagerou")
	assert_eq(int(Profile.get_settings_dict().fov), 95)
	assert_eq(int(Profile.lifetime.runs), 1)


func test_corrupt_profile_loads_the_backup() -> void:
	Profile.use_dir(dir)
	Profile.finish_run({"wave": 10, "kills": 100})
	var lv := Profile.player_level
	Profile.finish_run({"wave": 2})
	_corrupt(Profile.profile_path())
	Profile.use_dir(dir)
	assert_eq(Profile.loaded_from, "backup")
	assert_eq(Profile.player_level, lv)
	assert_eq(int(Profile.lifetime.runs), 1)
	# and the good copy is written back as the main file
	assert_true(SaveFile.decode(SaveFile.read_text(Profile.profile_path()), "profile").ok)


func test_unreadable_profile_is_kept_aside_not_deleted() -> void:
	_write_raw(dir.path_join(Profile.PROFILE_FILE), "this is not json")
	Profile.use_dir(dir)
	assert_eq(Profile.loaded_from, "new")
	var kept := Array(DirAccess.get_files_at(dir)).filter(func(f): return f.contains(".corrupt-"))
	assert_eq(kept.size(), 1, "the damaged file is kept for recovery")


func test_settings_save_is_debounced_and_flushed() -> void:
	Profile.use_dir(dir)
	Profile.store_settings({"v": 1, "music": 0.5})
	Profile.store_settings({"v": 1, "music": 0.6})
	assert_eq(SaveFile.read(Profile.profile_path(), "profile").data.settings, {}, "not written yet")
	Profile.tick(1.0)
	assert_almost_eq(float(SaveFile.read(Profile.profile_path(), "profile").data.settings.music), 0.6, 0.001)


func test_hand_edited_profile_still_loads() -> void:
	SaveFile.write(dir.path_join(Profile.PROFILE_FILE), "profile", Profile.VERSION, {
		"player": "oops", "unlocks": ["edge_onibi", "made_up", 7], "equipped": {"katana": "made_up"},
		"high_scores": [{"score": 10}, "junk"], "lifetime": {"runs": -4},
	})
	Profile.use_dir(dir)
	assert_eq(Profile.player_level, 1)
	assert_eq(Profile.unlocks, ["edge_onibi"])
	assert_eq(Profile.get_equipped("katana"), "")
	assert_eq(Profile.high_scores.size(), 1)
	assert_eq(int(Profile.lifetime.runs), 0)


# ---------------------------------------------------------------- migration
func test_prototype_scores_become_a_profile() -> void:
	_write_raw(dir.path_join("scores.json"), JSON.stringify([
		{"name": "AAA", "score": 900, "wave": 4, "seed": "0000-0001"},
		{"name": "BBB", "score": 1500, "wave": 6, "seed": "0000-0002"},
	]))
	Profile.use_dir(dir)
	assert_eq(Profile.loaded_from, "legacy")
	assert_eq(Profile.high_scores.size(), 2)
	assert_eq(Profile.high_scores[0].name, "BBB")
	assert_eq(Profile.best_score(), 1500)
	assert_true(FileAccess.file_exists(dir.path_join("scores.json")), "the old file is left alone")
	Profile.use_dir(dir)
	assert_eq(Profile.loaded_from, "main")
	assert_eq(Profile.high_scores.size(), 2)


func test_migration_chain_reaches_current_version() -> void:
	var v1 := ProfileMigrations.migrate({"high_scores": [{"score": 5}]}, 0, Profile.VERSION)
	assert_eq(int(v1.player.level), 1)
	assert_eq(v1.high_scores.size(), 1)
	assert_eq(ProfileMigrations.migrate({}, 99, 100), {}, "a missing step fails instead of guessing")


func test_older_profile_is_migrated_and_kept() -> void:
	SaveFile.write(dir.path_join(Profile.PROFILE_FILE), "profile", 0, {"high_scores": [{"name": "OLD", "score": 77}]})
	Profile.use_dir(dir)
	assert_eq(Profile.high_scores[0].name, "OLD")
	assert_true(FileAccess.file_exists(Profile.profile_path() + ".v0"), "a copy of the old version is kept")


func test_newer_profile_loads_and_is_kept() -> void:
	SaveFile.write(dir.path_join(Profile.PROFILE_FILE), "profile", Profile.VERSION + 1, {"player": {"level": 12, "xp": 5}, "future_field": true})
	Profile.use_dir(dir)
	assert_eq(Profile.player_level, 12)
	assert_true(FileAccess.file_exists(Profile.profile_path() + ".v%d" % (Profile.VERSION + 1)))


# ---------------------------------------------------------------- high scores
func test_top_ten_keeps_the_best_and_names_them() -> void:
	Profile.use_dir(dir)
	for i in 12:
		Profile.add_score({"name": "---", "score": (i + 1) * 100, "wave": i, "seed": ""})
	assert_eq(Profile.high_scores.size(), 10)
	assert_eq(Profile.best_score(), 1200)
	assert_false(Profile.qualifies(150))
	assert_true(Profile.qualifies(5000))
	Profile.rename_score(0, "WIL")
	Profile.use_dir(dir)
	assert_eq(Profile.high_scores[0].name, "WIL")


func test_a_replayed_score_gets_its_own_row() -> void:
	# a seed replayed to the same score: both rows wait for initials as "---",
	# and the rank returned must be the new row, not the first equal one
	Profile.use_dir(dir)
	for i in 3:
		Profile.add_score({"name": "---", "score": 500, "wave": 4, "seed": "1234-ABCD"})
	var again := {"name": "---", "score": 500, "wave": 4, "seed": "1234-ABCD"}
	var rank := Profile.add_score(again)
	assert_true(is_same(Profile.high_scores[rank], again), "the rank is the new row's")


# ---------------------------------------------------------------- rewards
func test_boss_rewards_unlock_in_order_and_only_once() -> void:
	Profile.use_dir(dir)
	var first := Profile.boss_felled("oni")
	var second := Profile.boss_felled("oni")
	var third := Profile.boss_felled("oni")
	assert_eq(first.id, "edge_onibi")
	assert_eq(second.id, "coil_raiko")
	assert_eq(third, {}, "no reward once a boss's list is done")
	assert_eq(int(Profile.boss_kills.oni), 3)
	assert_eq(Profile.unlocks.size(), 2)


func test_only_owned_looks_can_be_equipped() -> void:
	Profile.use_dir(dir)
	Profile.equip("shotgun", "coil_akagane")
	assert_eq(Profile.get_equipped("shotgun"), "")
	Profile.boss_felled("mech")
	Profile.boss_felled("mech")
	assert_eq(Profile.cycle_equipped("shotgun"), "coil_akagane")
	assert_eq(Profile.cycle_equipped("shotgun"), "")


func test_rewards_are_cosmetic_only() -> void:
	# spec §11.2: no stat boosts, ever
	for r in Rewards.LIST:
		assert_true(r.slot in ["katana", "shotgun"], r.id)
		for k in r:
			assert_true(k in ["id", "boss", "slot", "name", "desc", "edge", "trim", "coil", "core", "glow"], "%s has %s" % [r.id, k])


# ---------------------------------------------------------------- suspended run
func test_suspended_run_lifecycle() -> void:
	Profile.use_dir(dir)
	assert_false(Profile.has_suspended_run())
	assert_true(Profile.suspend_run({"seed": 42, "next_wave": 4}))
	Profile.use_dir(dir)
	assert_true(Profile.has_suspended_run())
	assert_eq(int(Profile.load_suspended_run().next_wave), 4)
	Profile.clear_suspended_run()
	assert_false(Profile.has_suspended_run())
	Profile.use_dir(dir)
	assert_false(Profile.has_suspended_run(), "a finished run can't come back")


func test_damaged_run_file_is_not_offered() -> void:
	Profile.use_dir(dir)
	Profile.suspend_run({"seed": 42, "next_wave": 4})
	_write_raw(Profile.run_path(), "junk")
	SaveFile.remove(Profile.run_path() + ".bak")
	DirAccess.remove_absolute(Profile.run_path() + ".bak")
	Profile.use_dir(dir)
	assert_false(Profile.has_suspended_run())


func test_rng_state_survives_the_file() -> void:
	# 64-bit RNG states lose precision as JSON numbers; they go as strings
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(123456789)
	for i in 17:
		rng.randi()
	var path := _path()
	SaveFile.write(path, "run", 1, {"state": str(rng.state)})
	var expect := [rng.randi(), rng.randi(), rng.randi()]
	var again := RandomNumberGenerator.new()
	again.state = str(SaveFile.read(path, "run").data.state).to_int()
	assert_eq([again.randi(), again.randi(), again.randi()], expect)


# ---------------------------------------------------------------- Player Level
func test_xp_formula_rows() -> void:
	var rows := Progression.run_xp({"score": 10000, "wave": 3, "bosses": 0, "kills": 20, "glory_kills": 2})
	assert_eq(Progression.total(rows), 2 * Progression.XP_PER_WAVE + 20 * Progression.XP_PER_KILL + 2 * Progression.XP_PER_GLORY + 10000 / Progression.SCORE_PER_XP)
	assert_eq(Progression.run_xp({}), [], "an empty run shows no rows")


func test_levels_carry_over() -> void:
	var need1 := Progression.xp_to_next(1)
	var need2 := Progression.xp_to_next(2)
	assert_eq(Progression.apply(1, 0, need1 + need2 + 5), [3, 5])
	assert_eq(Progression.apply(1, 10, 0), [1, 10])
	assert_gt(need2, need1)
	assert_eq(Progression.xp_to_next(500), Progression.xp_to_next(Progression.LEVEL_STEP_CAP + 1), "the need stops growing")


func test_player_level_never_touches_the_run() -> void:
	# spec §11.1: it unlocks nothing and never changes difficulty
	Profile.use_dir(dir)
	Game.next_seed = 77
	Game.reset_run()
	var before := [Game.rng_waves.randi(), Game.level, Game.xp_next]
	Profile.finish_run({"wave": 30, "bosses": 10, "kills": 900, "score": 9000000})
	assert_gt(Profile.player_level, 5)
	Game.next_seed = 77
	Game.reset_run()
	assert_eq([Game.rng_waves.randi(), Game.level, Game.xp_next], before)


func test_equipping_recolours_the_live_weapons() -> void:
	Profile.use_dir(dir)
	var vm := Viewmodel.new()
	add_child_autofree(vm)
	var stock: Color = vm.blade_edge_mat.get_shader_parameter("albedo_color")
	Profile.boss_felled("oni")
	Profile.equip("katana", "edge_onibi")
	assert_ne(vm.blade_edge_mat.get_shader_parameter("albedo_color"), stock)
	assert_eq(vm.blade_edge_mat.get_shader_parameter("albedo_color"), Rewards.get_def("edge_onibi").edge)
	Profile.equip("katana", "")
	assert_eq(vm.blade_edge_mat.get_shader_parameter("albedo_color"), stock)
