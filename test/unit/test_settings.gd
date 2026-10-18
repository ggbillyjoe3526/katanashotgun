extends GutTest
## Settings (spec §15.4, §11.3): saved values come back the same through the
## profile, the old settings.json is imported once, damaged or hostile files
## never break the game, and rebinding never leaves one key on two actions.

const TEST_PATH := "user://test_settings.json"
const PROFILE_DIR := "user://test-settings"

var _saved := {}
var _real_path := ""


func before_each() -> void:
	_saved = Settings.to_dict()
	_real_path = Settings.path
	Settings.path = TEST_PATH
	_remove_files()
	Profile.use_dir(PROFILE_DIR)
	Settings.reset_all()


func after_each() -> void:
	_remove_files()
	DirAccess.remove_absolute(PROFILE_DIR)
	Profile.use_dir("user://test")
	Settings.path = _real_path
	Settings.reset_all()
	Settings.from_dict(_saved)
	Settings.apply_controls()


func _remove_files() -> void:
	for p in [TEST_PATH, TEST_PATH + ".bak", TEST_PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	if DirAccess.dir_exists_absolute(PROFILE_DIR):
		for f in DirAccess.get_files_at(PROFILE_DIR):
			DirAccess.remove_absolute(PROFILE_DIR.path_join(f))


## Writes an old stand-in settings file by hand, as the settings menu used to.
func _write_legacy(p: String, d: Dictionary) -> void:
	_write(p, JSON.stringify(d))


func _write(p: String, text: String) -> void:
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _key(code: Key) -> InputEventKey:
	var k := InputEventKey.new()
	k.physical_keycode = code
	return k


func _names(action: String) -> Array:
	var out := []
	for ev in Settings.action_events(action):
		out.append(Settings.event_name(ev))
	return out


func test_save_and_load_round_trip() -> void:
	Settings.volume["Music"] = 0.35
	Settings.fov = 101.0
	Settings.sensitivity = 2.5
	Settings.window_mode = "fullscreen"
	Settings.vsync = false
	Settings.fps_cap = 144
	Settings.quality = "low"
	Settings.render_scale = 0.75
	Settings.shake = 0.0
	Settings.flash = 0.4
	var before := Settings.to_dict()
	assert_true(Settings.save())
	assert_true(Profile.save_now())
	Profile.use_dir(PROFILE_DIR) # read back from disk, not memory
	Settings.reset_all()
	assert_true(Settings.load_saved())
	assert_eq_deep(Settings.to_dict(), before)


func test_json_floats_come_back_as_ints() -> void:
	# JSON has no ints: the frame cap must still match the list of caps
	Settings.from_dict({"v": 1.0, "fps_cap": 240.0})
	assert_eq(Settings.fps_cap, 240)
	assert_typeof(Settings.fps_cap, TYPE_INT)


func test_bad_values_are_clamped_or_ignored() -> void:
	Settings.from_dict({"v": 1, "fov": 500, "sensitivity": -3, "render_scale": 0.01,
		"fps_cap": 999, "window_mode": "huge", "quality": "ultra", "shake": 7,
		"volume": {"Music": "loud", "SFX": -1}, "vsync": "yes"})
	assert_eq(Settings.fov, Settings.FOV_MAX)
	assert_eq(Settings.sensitivity, Settings.SENS_MIN)
	assert_eq(Settings.render_scale, Settings.RENDER_SCALE_MIN)
	assert_eq(Settings.fps_cap, 0)
	assert_eq(Settings.window_mode, "fullscreen")
	assert_eq(Settings.quality, "high")
	assert_eq(Settings.shake, 1.0)
	assert_eq(Settings.volume["Music"], 1.0)
	assert_eq(Settings.volume["SFX"], 0.0)
	assert_false(Settings.vsync)


func test_corrupt_legacy_file_falls_back_to_backup() -> void:
	Settings.fov = 95.0
	_write_legacy(TEST_PATH + ".bak", Settings.to_dict())
	_write(TEST_PATH, "{ this is not json")
	Settings.reset_all()
	assert_true(Settings.load_file())
	assert_eq(Settings.fov, 95.0)


func test_half_written_legacy_file_keeps_last_good_settings() -> void:
	# an old crash left only the .bak and a half-written .tmp
	Settings.fov = 99.0
	_write_legacy(TEST_PATH + ".bak", Settings.to_dict())
	_write(TEST_PATH + ".tmp", "{\"v\": 1, \"fo")
	Settings.reset_all()
	assert_true(Settings.load_file())
	assert_eq(Settings.fov, 99.0)


func test_missing_files_keep_defaults() -> void:
	assert_false(Settings.load_saved())
	assert_eq(Settings.fov, Settings.DEFAULT_FOV)


func test_legacy_file_is_imported_once() -> void:
	# settings saved before the profile existed move into it on first load
	Settings.fov = 104.0
	_write_legacy(TEST_PATH, Settings.to_dict())
	Settings.reset_all()
	assert_true(Settings.load_saved())
	assert_eq(Settings.fov, 104.0)
	assert_eq(float(Profile.get_settings_dict().get("fov", 0.0)), 104.0)
	# from now on the profile wins over the old file
	Settings.fov = 88.0
	Settings.save()
	Settings.reset_all()
	assert_true(Settings.load_saved())
	assert_eq(Settings.fov, 88.0)


func test_rebinding_to_a_used_key_swaps() -> void:
	# J is the katana's second key; put it on the shotgun's first slot
	var swapped := Settings.bind("shotgun", 0, _key(KEY_J))
	assert_eq(swapped, "KATANA")
	assert_eq(_names("shotgun")[0], "J")
	# the katana takes the shotgun's old button, so nothing is unbound
	assert_has(_names("katana"), "RMB")
	assert_does_not_have(_names("katana"), "J")


func test_bindings_survive_save_and_load() -> void:
	Settings.bind("jump", 1, _key(KEY_C))
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_XBUTTON1
	Settings.bind("dash", 0, mb)
	Settings.save()
	Settings.reset_all()
	assert_does_not_have(_names("jump"), "C")
	Settings.load_saved()
	Settings.apply_controls()
	assert_has(_names("jump"), "C")
	assert_eq(_names("dash")[0], "MOUSE 4")


func test_reset_controls_restores_defaults() -> void:
	Settings.bind("katana", 0, _key(KEY_X))
	Settings.reset_controls()
	assert_eq(_names("katana")[0], "LMB")


func test_clear_binding() -> void:
	Settings.clear_binding("dash", 1)
	assert_eq(_names("dash"), ["SHIFT"])


func test_sensitivity_drives_mouse_look() -> void:
	Settings.sensitivity = 2.0
	Settings.apply_controls()
	assert_almost_eq(Game.mouse_sensitivity, Settings.SENS_BASE * 2.0, 0.000001)
	Settings.nudge_sensitivity(0.1)
	assert_almost_eq(Settings.sensitivity, 2.1, 0.0001)


func test_saved_bindings_are_checked() -> void:
	# a hand-edited file can't bind Esc, bind unknown actions or use a key twice
	Settings.from_dict({"v": 1, "bindings": {
		"jump": [{"k": KEY_ESCAPE}, {"k": KEY_C}],
		"dash": [{"k": KEY_C}, {"k": KEY_X}, {"k": KEY_Z}],
		"ui_accept": [{"k": KEY_Y}],
	}})
	assert_eq_deep(Settings.bindings["jump"], [{"k": KEY_C}])
	assert_eq_deep(Settings.bindings["dash"], [{"k": KEY_X}, {"k": KEY_Z}])
	assert_false(Settings.bindings.has("ui_accept"))


func test_defaults_are_full_screen_and_unlimited() -> void:
	# a new player starts full screen at the screen's own resolution, with no
	# frame cap and VSync off, so a 240 Hz screen gets every frame
	assert_eq(Settings.window_mode, "fullscreen")
	assert_false(Settings.vsync)
	assert_eq(Settings.fps_cap, 0)


func test_version_1_defaults_move_to_full_screen() -> void:
	Settings.from_dict({"v": 1, "window_mode": "windowed", "vsync": true, "fps_cap": 144})
	assert_eq(Settings.window_mode, "fullscreen")
	assert_false(Settings.vsync)
	assert_eq(Settings.fps_cap, 144, "a cap the player picked is kept")


func test_version_1_choices_are_kept() -> void:
	Settings.from_dict({"v": 1, "window_mode": "exclusive", "vsync": false})
	assert_eq(Settings.window_mode, "exclusive")
	Settings.reset_all()
	Settings.from_dict({"v": 2, "window_mode": "windowed", "vsync": true})
	assert_eq(Settings.window_mode, "windowed")
	assert_true(Settings.vsync)


func test_windowed_size_is_a_whole_multiple() -> void:
	# usable screen area (minus the taskbar) -> times 960x540
	assert_eq(Settings.window_scale_for(Vector2i(3840, 2100)), 3) # 4K: 2880x1620
	assert_eq(Settings.window_scale_for(Vector2i(2560, 1400)), 2) # 1440p
	assert_eq(Settings.window_scale_for(Vector2i(1920, 1040)), 1) # 1080p
	assert_eq(Settings.window_scale_for(Vector2i(800, 600)), 1) # never below 1
