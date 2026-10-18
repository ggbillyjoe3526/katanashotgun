extends GutTest
## The settings screen driven from the keyboard, the way a player without a
## mouse would: move, change values, switch tabs, rebind a key, back out.

const TEST_PATH := "user://test_settings_menu.json"

var menu: SettingsMenu
var _saved := {}
var _real_path := ""


func before_each() -> void:
	_saved = Settings.to_dict()
	_real_path = Settings.path
	Settings.path = TEST_PATH
	Settings.reset_all()
	Game.state = "title"
	menu = SettingsMenu.new()
	add_child_autofree(menu)


func after_each() -> void:
	for p in [TEST_PATH, TEST_PATH + ".bak", TEST_PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	Settings.path = _real_path
	Settings.reset_all()
	Settings.from_dict(_saved)
	Settings.apply_all()


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
	_press(KEY_DOWN) # MUSIC
	_press(KEY_LEFT)
	_press(KEY_LEFT)
	assert_almost_eq(float(Settings.volume["Music"]), 0.9, 0.001)


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
	menu.sel = _row("QUALITY")
	_press(KEY_RIGHT) # high -> low
	assert_eq(Settings.quality, "low")
	assert_eq(Settings.render_scale, Settings.QUALITY_RENDER_SCALE["low"])


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
	assert_true(FileAccess.file_exists(TEST_PATH))


func test_reset_tab() -> void:
	menu.tab = SettingsMenu.TABS.find("COMFORT")
	menu.open()
	Settings.shake = 0.2
	_press(KEY_R)
	assert_eq(Settings.shake, 1.0)
