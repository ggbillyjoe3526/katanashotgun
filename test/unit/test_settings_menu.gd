extends GutTest
## The settings screen driven from the keyboard, the way a player without a
## mouse would: move, change values, switch tabs, rebind a key, back out.

const TEST_PATH := "user://test_settings_menu.json"
const PROFILE_DIR := "user://test-settings-menu"

var menu: SettingsMenu
var _saved := {}
var _real_path := ""


func before_each() -> void:
	_saved = Settings.to_dict()
	_real_path = Settings.path
	Settings.path = TEST_PATH
	Profile.use_dir(PROFILE_DIR) # saves never reach the player's profile
	Settings.reset_all()
	Game.state = "title"
	menu = SettingsMenu.new()
	add_child_autofree(menu)


func after_each() -> void:
	for p in [TEST_PATH, TEST_PATH + ".bak", TEST_PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	_remove_dir(PROFILE_DIR)
	Profile.use_dir("user://test")
	Settings.path = _real_path
	Settings.reset_all()
	Settings.from_dict(_saved)
	Settings.apply_all()


func _remove_dir(d: String) -> void:
	if DirAccess.dir_exists_absolute(d):
		for f in DirAccess.get_files_at(d):
			DirAccess.remove_absolute(d.path_join(f))
		DirAccess.remove_absolute(d)


func _press(code: Key, shift := false) -> void:
	var k := InputEventKey.new()
	k.physical_keycode = code
	k.shift_pressed = shift
	k.pressed = true
	menu._input(k)
	k = k.duplicate()
	k.pressed = false
	menu._input(k)


func _row(label: String) -> int:
	for i in menu.rows.size():
		if menu.rows[i].label == label:
			return i
	return -1


func test_tab_opens_from_title_only() -> void:
	Game.state = "playing"
	_press(KEY_TAB)
	assert_false(menu.visible)
	Game.state = "title"
	_press(KEY_TAB)
	assert_true(menu.visible)


func test_arrows_change_a_slider() -> void:
	menu.open()
	menu.sel = _row("MASTER")
	_press(KEY_LEFT)
	_press(KEY_LEFT)
	assert_almost_eq(float(Settings.volume["Master"]), 0.9, 0.001)


func test_sliders_for_missing_buses_are_hidden() -> void:
	menu.open()
	for b in Settings.BUSES:
		var shown := _row(SettingsMenu.AUDIO_NAMES[b]) >= 0
		assert_eq(shown, Settings.has_bus(b), b)


func test_tabs_cycle_both_ways() -> void:
	menu.open()
	_press(KEY_E)
	assert_eq(SettingsMenu.TABS[menu.tab], "VIDEO")
	_press(KEY_TAB, true)
	assert_eq(SettingsMenu.TABS[menu.tab], "AUDIO")
	_press(KEY_Q)
	assert_eq(SettingsMenu.TABS[menu.tab], "COMFORT")


func test_option_wraps_through_values() -> void:
	menu.tab = SettingsMenu.TABS.find("VIDEO")
	menu.open()
	menu.sel = _row("FRAME CAP")
	_press(KEY_LEFT) # uncapped -> the highest cap
	assert_eq(Settings.fps_cap, Settings.FPS_CAPS[-1])
	_press(KEY_RIGHT)
	assert_eq(Settings.fps_cap, 0)


func test_quality_row_only_with_a_quality_system() -> void:
	menu.tab = SettingsMenu.TABS.find("VIDEO")
	menu.open()
	assert_eq(_row("QUALITY") >= 0, Settings.quality_system() != null)


func test_every_word_fits_its_box() -> void:
	# labels, values and help lines stay inside their columns at pixel size
	Ui.init()
	for t in SettingsMenu.TABS.size():
		menu.tab = t
		menu.open()
		assert_lt(menu._w(SettingsMenu.TABS[t], Ui.font_bold, SettingsMenu.LABEL_PX), menu._tab_rect(t).size.x - 4)
		for r in menu.rows:
			assert_lt(menu._w(r.label, Ui.font_bold, SettingsMenu.LABEL_PX), SettingsMenu.VALUE_X - SettingsMenu.LABEL_X - 6, r.label)
			assert_lt(menu._w(r.help, Ui.font_bold, SettingsMenu.LABEL_PX), SettingsMenu.PANEL.x - 28, r.help)
			if r.type == "option":
				for n in r.names:
					assert_lt(menu._w(n, Ui.font_mono, SettingsMenu.VALUE_PX), menu._value_rect(0).size.x - 24, n)
	for lbl in ["ESC  BACK", "R  DEFAULTS"]:
		assert_lt(menu._w(lbl, Ui.font_bold, SettingsMenu.LABEL_PX), menu._foot_rect(0).size.x - 4, lbl)
	assert_lt(menu._w("PRESS A KEY OR MOUSE BUTTON.  ESC CANCELS", Ui.font_bold, SettingsMenu.LABEL_PX), SettingsMenu.PANEL.x - 28)


func test_rebind_from_the_keyboard() -> void:
	menu.tab = SettingsMenu.TABS.find("CONTROLS")
	menu.open()
	menu.sel = _row("JUMP")
	_press(KEY_RIGHT) # second slot
	_press(KEY_ENTER)
	assert_true(menu.capturing)
	_press(KEY_ESCAPE) # Esc can't be bound: it cancels
	assert_false(menu.capturing)
	assert_true(menu.visible)
	_press(KEY_ENTER)
	_press(KEY_V)
	assert_false(menu.capturing)
	var names := []
	for ev in Settings.action_events("jump"):
		names.append(Settings.event_name(ev))
	assert_eq(names, ["SPACE", "V"])


func test_escape_closes_and_saves() -> void:
	menu.open()
	_press(KEY_LEFT) # master volume down, saved on close
	_press(KEY_ESCAPE)
	assert_false(menu.visible)
	var stored := Profile.get_settings_dict()
	assert_almost_eq(float(stored.get("volume", {}).get("Master", 1.0)), 0.95, 0.001)


func test_reset_tab() -> void:
	menu.tab = SettingsMenu.TABS.find("COMFORT")
	menu.open()
	Settings.shake = 0.2
	_press(KEY_R)
	assert_eq(Settings.shake, 1.0)
