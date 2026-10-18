extends GutTest
## The settings screen worked with the mouse alone, as the owner asked:
## click tabs, options and the footer, drag sliders, rebind and clear keys.
## The keyboard only types a new binding and backs out with Esc.

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
	Ui.init() # the panel draws when a frame passes
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


## A mouse press and release at a point on the panel (panel coordinates).
func _click(at: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	menu._process(0.0) # places the panel
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = button
		ev.pressed = down
		ev.position = menu._origin + at
		menu._gui_input(ev)


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


func test_screen_covers_the_window_so_clicks_land() -> void:
	# it used to be zero size, so every click fell through to the title
	menu.open()
	await wait_process_frames(1)
	assert_eq(menu.size, menu.get_viewport_rect().size)


func test_drag_a_slider() -> void:
	menu.open()
	var i := _row("MASTER")
	var sr: Rect2 = menu._slider_rect(i)
	_click(Vector2(sr.position.x + sr.size.x * 0.5, sr.get_center().y))
	assert_almost_eq(float(Settings.volume["Master"]), 0.5, 0.051)


func test_wheel_nudges_a_slider() -> void:
	menu.open()
	var i := _row("MASTER")
	_click(menu._row_rect(i).get_center(), MOUSE_BUTTON_WHEEL_DOWN)
	assert_almost_eq(float(Settings.volume["Master"]), 0.95, 0.001)


func test_sliders_for_missing_buses_are_hidden() -> void:
	menu.open()
	for b in Settings.BUSES:
		var shown := _row(SettingsMenu.AUDIO_NAMES[b]) >= 0
		assert_eq(shown, Settings.has_bus(b), b)


func test_click_a_tab() -> void:
	menu.open()
	_click(menu._tab_rect(SettingsMenu.TABS.find("COMFORT")).get_center())
	assert_eq(SettingsMenu.TABS[menu.tab], "COMFORT")


func test_click_either_side_of_an_option() -> void:
	menu.tab = SettingsMenu.TABS.find("VIDEO")
	menu.open()
	var vr: Rect2 = menu._value_rect(_row("FRAME CAP"))
	_click(vr.position + Vector2(4, 4)) # left: unlimited -> the highest cap
	assert_eq(Settings.fps_cap, Settings.FPS_CAPS[-1])
	_click(vr.end - Vector2(4, 4)) # right: back round to unlimited
	assert_eq(Settings.fps_cap, 0)


func test_keys_do_not_work_the_menu() -> void:
	menu.tab = SettingsMenu.TABS.find("VIDEO")
	menu.open()
	var before := Settings.to_dict()
	for code in [KEY_Q, KEY_E, KEY_TAB, KEY_LEFT, KEY_RIGHT, KEY_DOWN, KEY_ENTER, KEY_R, KEY_DELETE]:
		_press(code)
	assert_eq(SettingsMenu.TABS[menu.tab], "VIDEO")
	assert_eq_deep(Settings.to_dict(), before)
	assert_true(menu.visible)
	assert_false(menu.capturing)


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
	for i in 2:
		assert_lt(menu._w(menu.foot_label(i), Ui.font_bold, SettingsMenu.LABEL_PX), menu._foot_rect(i).size.x - 4, menu.foot_label(i))
	for lbl in ["QUIT GAME", SettingsMenu.QUIT_ARMED]:
		assert_lt(menu._w(lbl, Ui.font_bold, SettingsMenu.LABEL_PX), menu._foot_rect(2).size.x - 4, lbl)
	# QUIT GAME sits bottom left, clear of BACK and DEFAULTS
	assert_lt(menu._foot_rect(2).end.x, menu._foot_rect(0).position.x)
	assert_lt(menu._w(SettingsMenu.CAPTURE_HELP, Ui.font_bold, SettingsMenu.LABEL_PX), SettingsMenu.PANEL.x - 28)
	# the widest screen the window-mode help can name
	assert_lt(menu._w(menu._window_help("7680x4320 360 HZ"), Ui.font_bold, SettingsMenu.LABEL_PX), SettingsMenu.PANEL.x - 28)


func _names(action: String) -> Array:
	var out := []
	for ev in Settings.action_events(action):
		out.append(Settings.event_name(ev))
	return out


func test_rebind_by_clicking_a_slot() -> void:
	menu.tab = SettingsMenu.TABS.find("CONTROLS")
	menu.open()
	var row := _row("JUMP")
	var slot2: Rect2 = menu._slot_rect(row, 1)
	_click(slot2.get_center())
	assert_true(menu.capturing)
	_press(KEY_ESCAPE) # Esc can't be bound: it cancels
	assert_false(menu.capturing)
	assert_true(menu.visible)
	_click(slot2.get_center())
	_click(menu._row_rect(0).get_center()) # clicking away cancels too
	assert_false(menu.capturing)
	_click(slot2.get_center())
	_press(KEY_V)
	assert_false(menu.capturing)
	assert_eq(_names("jump"), ["SPACE", "V"])


func test_bind_a_mouse_button_on_the_slot() -> void:
	menu.tab = SettingsMenu.TABS.find("CONTROLS")
	menu.open()
	var slot2: Rect2 = menu._slot_rect(_row("DASH"), 1)
	_click(slot2.get_center())
	_click(slot2.get_center(), MOUSE_BUTTON_XBUTTON1)
	assert_false(menu.capturing)
	assert_eq(_names("dash")[1], "MOUSE 4")


func test_right_click_clears_a_slot() -> void:
	menu.tab = SettingsMenu.TABS.find("CONTROLS")
	menu.open()
	_click(menu._slot_rect(_row("DASH"), 1).get_center(), MOUSE_BUTTON_RIGHT)
	assert_eq(_names("dash"), ["SHIFT"])


func test_back_closes_and_saves() -> void:
	menu.open()
	Settings.volume["Master"] = 0.95
	menu._changed() # saved on close
	_click(menu._foot_rect(0).get_center())
	assert_false(menu.visible)
	var stored := Profile.get_settings_dict()
	assert_almost_eq(float(stored.get("volume", {}).get("Master", 1.0)), 0.95, 0.001)


func test_quit_needs_a_second_click() -> void:
	# one stray click on QUIT GAME only arms it; the game is still running
	menu.open()
	_click(menu._foot_rect(2).get_center())
	assert_true(menu.quit_armed())
	assert_eq(menu.foot_label(2), SettingsMenu.QUIT_ARMED)
	menu.close()
	menu.open()
	assert_false(menu.quit_armed(), "reopening starts disarmed")


func test_quit_button_arms_first() -> void:
	var b := TechButton.make("QUIT GAME  [Q]", Color.WHITE)
	b.confirm_text = "PRESS AGAIN TO QUIT"
	add_child_autofree(b)
	watch_signals(b)
	b.press()
	assert_signal_not_emitted(b, "pressed")
	assert_true(b.armed())
	assert_eq(b.text, "PRESS AGAIN TO QUIT")
	# the offer runs out after a few seconds of real time
	var rd := Game.real_dt
	Game.real_dt = TechButton.ARM_S + 0.1
	b._process(0.0)
	Game.real_dt = rd
	assert_false(b.armed())
	assert_eq(b.text, "QUIT GAME  [Q]")
	b.press()
	assert_signal_not_emitted(b, "pressed", "disarmed: arms again, still no quit")


func test_escape_still_backs_out() -> void:
	menu.open()
	_press(KEY_ESCAPE)
	assert_false(menu.visible)


func test_defaults_button_resets_the_tab() -> void:
	menu.tab = SettingsMenu.TABS.find("COMFORT")
	menu.open()
	Settings.shake = 0.2
	_click(menu._foot_rect(1).get_center())
	assert_eq(Settings.shake, 1.0)
