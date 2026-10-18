extends GutTest
## Settings (spec §15.4, §11.3): saved values come back the same, damaged or
## hostile files never break the game, the file is replaced atomically with a
## backup, and rebinding never leaves one key on two actions.

const TEST_PATH := "user://test_settings.json"

var _saved := {}
var _real_path := ""


func before_each() -> void:
	_saved = Settings.to_dict()
	_real_path = Settings.path
	Settings.path = TEST_PATH
	_remove_files()
	Settings.reset_all()


func after_each() -> void:
	_remove_files()
	Settings.path = _real_path
	Settings.reset_all()
	Settings.from_dict(_saved)
	Settings.apply_controls()


func _remove_files() -> void:
	for p in [TEST_PATH, TEST_PATH + ".bak", TEST_PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


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
	Settings.reset_all()
	assert_true(Settings.load_file())
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
	assert_eq(Settings.window_mode, "windowed")
	assert_eq(Settings.quality, "high")
	assert_eq(Settings.shake, 1.0)
	assert_eq(Settings.volume["Music"], 1.0)
	assert_eq(Settings.volume["SFX"], 0.0)
	assert_true(Settings.vsync)


func test_corrupt_file_falls_back_to_backup() -> void:
	Settings.fov = 95.0
	Settings.save()
	Settings.fov = 105.0
	Settings.save() # the 95 file is now the backup
	_write(TEST_PATH, "{ this is not json")
	Settings.reset_all()
	assert_true(Settings.load_file())
	assert_eq(Settings.fov, 95.0)


func test_crash_mid_write_keeps_last_good_settings() -> void:
	# a crash after the old file became the backup but before the new one
	# was renamed into place: only the .bak and a half-written .tmp exist
	Settings.fov = 99.0
	Settings.save()
	DirAccess.rename_absolute(TEST_PATH, TEST_PATH + ".bak")
	_write(TEST_PATH + ".tmp", "{\"v\": 1, \"fo")
	Settings.reset_all()
	assert_true(Settings.load_file())
	assert_eq(Settings.fov, 99.0)


func test_missing_files_keep_defaults() -> void:
	assert_false(Settings.load_file())
	assert_eq(Settings.fov, Settings.DEFAULT_FOV)


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
	Settings.load_file()
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
