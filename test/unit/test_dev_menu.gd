extends GutTest
## The hidden DEV menu (F10) and its settings: it opens where it should, is
## worked with the mouse, keeps nothing across launches, and a run
## played with dev settings never reaches the top 10.

const PROFILE_DIR := "user://test-dev-menu"

var menu: DevMenu
var _saved := {}


func before_each() -> void:
	_saved = Settings.to_dict()
	Profile.use_dir(PROFILE_DIR) # saves never reach the player's profile
	Graphics.renderer_file = "user://test_dev_renderer.cfg"
	DevSettings.reset()
	Game.state = "title"
	Game.dev_run = false
	Ui.init()
	menu = DevMenu.new()
	add_child_autofree(menu)


func after_each() -> void:
	DevSettings.reset()
	Game.dev_run = false
	Game.state = "title"
	DirAccess.remove_absolute(Graphics.renderer_file)
	Graphics.renderer_file = "user://renderer.cfg"
	for f in DirAccess.get_files_at(PROFILE_DIR):
		DirAccess.remove_absolute(PROFILE_DIR.path_join(f))
	DirAccess.remove_absolute(PROFILE_DIR)
	Profile.use_dir("user://test")
	Settings.reset_all()
	Settings.from_dict(_saved)
	Settings.apply_all()


func _press(code: Key) -> void:
	var k := InputEventKey.new()
	k.physical_keycode = code
	k.pressed = true
	menu._input(k)


func _click(at: Vector2) -> void:
	menu._process(0.0) # places the panel
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = down
		ev.position = menu._origin + at
		menu._gui_input(ev)


func _row(label: String) -> int:
	for i in menu.rows.size():
		if menu.rows[i].label == label:
			return i
	return -1


func test_f10_opens_it_and_tab_does_not() -> void:
	_press(KEY_TAB)
	assert_false(menu.visible)
	_press(DevSettings.KEY)
	assert_true(menu.visible)
	_press(KEY_ESCAPE)
	assert_false(menu.visible)


func test_not_over_a_level_up_or_the_results() -> void:
	for s in ["levelup", "dead"]:
		Game.state = s
		_press(DevSettings.KEY)
		assert_false(menu.visible, s)


func test_f10_can_never_be_bound_to_an_action() -> void:
	assert_true(Settings.RESERVED_KEYS.has(DevSettings.KEY))
	var before := Settings.bindings.duplicate(true)
	Settings.from_dict({"v": Settings.VERSION, "bindings": {"jump": [{"k": DevSettings.KEY}]}})
	assert_eq_deep(Settings.bindings.get("jump", []), [])
	Settings.bindings = before


func test_no_dev_setting_is_saved() -> void:
	Game.debug_god = true
	DevSettings.speed = 2.0
	DevSettings.hide_hud = true
	var d := Settings.to_dict()
	assert_false(d.has("dev"))
	DevSettings.reset()
	Settings.from_dict(d)
	assert_false(Game.debug_god)
	assert_eq(DevSettings.speed, 1.0)
	assert_false(DevSettings.hide_hud)


func test_the_look_moved_to_the_player_settings() -> void:
	menu.open()
	assert_eq(_row("RETRO LOOK"), -1)


func test_all_off_resets_everything() -> void:
	DevSettings.hide_hud = true
	DevSettings.start_wave = 9
	DevSettings.boss = "oni"
	Game.debug_god = true
	Game.set_autoplay(true)
	menu.open()
	_click(menu._foot_rect(1).get_center())
	assert_false(DevSettings.hide_hud)
	assert_false(DevSettings.cheating())
	assert_false(Game.debug_autoplay)
	assert_false(DevSettings.any_on())


func test_hiding_the_hud_is_not_a_cheat() -> void:
	DevSettings.hide_hud = true
	assert_false(DevSettings.cheating())
	for s in [func(): Game.debug_god = true, func(): DevSettings.speed = 0.5,
			func(): DevSettings.start_wave = 4, func(): DevSettings.mutator = "storm"]:
		DevSettings.reset()
		s.call()
		assert_true(DevSettings.cheating())


func test_a_cheat_makes_the_run_a_dev_run_that_skips_the_top_10() -> void:
	Game.reset_run()
	Game.state = "playing"
	Game.debug_god = true
	Game._process(0.016)
	assert_true(Game.dev_run)
	Game.score = 999999
	Game.record_score()
	assert_eq(Game.last_rank, -1)
	assert_true(Profile.high_scores.is_empty())


func test_cheats_on_the_title_do_not_mark_the_run() -> void:
	Game.reset_run()
	Game.state = "title"
	Game.debug_god = true
	Game._process(0.016)
	assert_false(Game.dev_run)
	Game.score = 500
	Game.debug_god = false
	Game.record_score()
	assert_eq(Game.last_rank, 0)


func test_run_actions_need_a_run() -> void:
	menu.tab = DevMenu.DEV_TABS.find("ACTIONS")
	menu.open()
	_click(menu._value_rect(_row("LEVEL UP")).get_center())
	assert_eq(Game.pending_levelups, 0)
	assert_false(Game.dev_run)
	assert_eq(menu._note, "START A RUN FIRST")


func test_every_word_fits_its_box() -> void:
	for t in DevMenu.DEV_TABS.size():
		menu.tab = t
		menu.open()
		assert_lt(menu._w(DevMenu.DEV_TABS[t], Ui.font_bold, SettingsMenu.LABEL_PX), menu._tab_rect(t).size.x - 4)
		assert_lt(menu.rows.size(), DevMenu.STATUS_ROW + 1, "rows stay above the status line")
		for r in menu.rows:
			assert_lt(menu._w(r.label, Ui.font_bold, SettingsMenu.LABEL_PX), SettingsMenu.VALUE_X - SettingsMenu.LABEL_X - 6, r.label)
			assert_lt(menu._w(r.help, Ui.font_bold, SettingsMenu.LABEL_PX), SettingsMenu.PANEL.x - 28, r.help)
			var names: Array = r.names if r.type == "option" else ([r.button] if r.type == "action" else [])
			for n in names:
				assert_lt(menu._w(n, Ui.font_mono, SettingsMenu.VALUE_PX), menu._value_rect(0).size.x - 24, n)
	for line in ["RUN TAB OR ACTIONS MAKE A DEV RUN: NO TOP 10, XP, UNLOCKS", "THIS RUN IS A DEV RUN: NO TOP 10, XP OR UNLOCKS", "EVERY DEV SETTING IS OFF"]:
		assert_lt(menu._w(line, Ui.font_bold, SettingsMenu.LABEL_PX), SettingsMenu.PANEL.x - 28, line)
	assert_lt(menu._w(menu.foot_label(1), Ui.font_bold, SettingsMenu.LABEL_PX), menu._foot_rect(1).size.x - 4)
