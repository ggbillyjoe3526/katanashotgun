extends GutTest
## The RETRO LOOK setting (OFF / LIGHT / FULL): what each level puts on the
## shaders and the window, that LIGHT is the default, that old saves move
## over, and that the settings screen switches it with a click.

const PROFILE_DIR := "user://test-retro-look"

var _saved := {}


func before_each() -> void:
	_saved = Settings.to_dict()
	Profile.use_dir(PROFILE_DIR) # saves never reach the player's profile
	Graphics.renderer_file = "user://test_retro_renderer.cfg"
	Settings.reset_all()
	Game.state = "title"


func after_each() -> void:
	for f in DirAccess.get_files_at(PROFILE_DIR):
		DirAccess.remove_absolute(PROFILE_DIR.path_join(f))
	DirAccess.remove_absolute(PROFILE_DIR)
	Profile.use_dir("user://test")
	DirAccess.remove_absolute(Graphics.renderer_file)
	Graphics.renderer_file = "user://renderer.cfg"
	Settings.reset_all()
	Settings.from_dict(_saved)
	Settings.apply_all()


func test_light_is_the_default() -> void:
	assert_eq(RetroLook.DEFAULT, "light")
	assert_eq(Settings.retro_look, "light")


func test_full_is_the_original_look() -> void:
	RetroLook.apply("full")
	var root := get_tree().root
	assert_eq(root.content_scale_mode, Window.CONTENT_SCALE_MODE_VIEWPORT)
	assert_eq(root.content_scale_size, Vector2i(960, 540))
	assert_eq(root.content_scale_factor, 2.0)
	assert_eq(root.scaling_3d_scale, Settings.render_scale)
	# the shader globals (headless can't read them back): FULL's values are
	# project.godot's, and match the shaders before the setting existed
	# (snap grid 0.6 of the view's pixels, 48 colour levels, no blocks)
	assert_eq_deep(RetroLook.LEVELS.full, {"amount": 1.0, "snap": 0.6, "levels": 48.0, "lines": 270})
	var keys := {"psx_retro": "amount", "psx_snap": "snap", "psx_levels": "levels"}
	for n in keys:
		assert_eq(float(ProjectSettings.get_setting("shader_globals/" + n).value), float(RetroLook.LEVELS.full[keys[n]]), n)
	assert_eq(float(ProjectSettings.get_setting("shader_globals/psx_pixel_lines").value), 0.0)


func test_light_is_milder_than_full() -> void:
	RetroLook.apply("light")
	var lv: Dictionary = RetroLook.LEVELS.light
	var full: Dictionary = RetroLook.LEVELS.full
	assert_eq(get_tree().root.content_scale_mode, Window.CONTENT_SCALE_MODE_CANVAS_ITEMS)
	assert_gt(lv.amount, 0.0) # still some warp and fringe
	assert_lt(lv.amount, 0.5) # smooth textures (FULL alone picks the nearest texel)
	assert_gt(lv.snap * lv.lines, full.snap * full.lines) # a finer grid: less wobble
	assert_gt(lv.levels, full.levels) # more colour levels: fainter banding
	assert_gt(lv.lines, full.lines) # a sharper 3D view


func test_light_draws_the_3d_at_the_block_size() -> void:
	RetroLook.apply("light")
	var root := get_tree().root
	var k := RetroLook.block(root.size.y, RetroLook.LEVELS.light.lines)
	assert_almost_eq(root.scaling_3d_scale, maxf(Settings.render_scale / k, 0.25), 0.001)


func test_off_is_the_plain_look() -> void:
	RetroLook.apply("off")
	var root := get_tree().root
	assert_eq(root.content_scale_mode, Window.CONTENT_SCALE_MODE_CANVAS_ITEMS)
	assert_eq(root.content_scale_factor, 2.0)
	assert_eq(root.scaling_3d_scale, Settings.render_scale)
	assert_eq_deep(RetroLook.LEVELS.off, {"amount": 0.0, "snap": 0.0, "levels": 0.0, "lines": 0})


func test_the_ui_keeps_its_size_at_every_level() -> void:
	# 480x270 canvas units on a 16:9 screen (an xvfb run at 3840x2160 gave
	# 480x270 for all three); headless the window differs, so compare
	RetroLook.apply("full")
	var want := get_tree().root.get_visible_rect().size
	for id in RetroLook.IDS:
		RetroLook.apply(id)
		assert_eq(get_tree().root.get_visible_rect().size, want, id)


func test_blocks_are_whole_screen_pixels_near_540_lines() -> void:
	assert_eq(RetroLook.block(2160, 540), 4) # 4K: 960x540
	assert_eq(RetroLook.block(1440, 540), 3) # 1440p: 480 lines
	assert_eq(RetroLook.block(1080, 540), 2) # 1080p: 960x540
	assert_eq(RetroLook.block(1620, 540), 3) # the 4K window: 540 lines
	assert_eq(RetroLook.block(540, 540), 1)
	assert_eq(RetroLook.block(300, 540), 1)
	assert_eq(RetroLook.block(0, 540), 1)


func test_render_scale_still_works_on_light() -> void:
	Settings.render_scale = 0.5
	Settings.retro_look = "light"
	Settings.apply_video()
	var k := RetroLook.block(get_tree().root.size.y, 540)
	assert_almost_eq(get_tree().root.scaling_3d_scale, maxf(0.5 / k, 0.25), 0.001)


func test_unknown_level_falls_back_to_the_default() -> void:
	RetroLook.apply("ultra")
	assert_eq(RetroLook.current, RetroLook.DEFAULT)


func test_saved_and_loaded() -> void:
	Settings.retro_look = "full"
	var d := Settings.to_dict()
	Settings.reset_all()
	assert_eq(Settings.retro_look, "light")
	Settings.from_dict(d)
	assert_eq(Settings.retro_look, "full")
	Settings.from_dict({"v": Settings.VERSION, "retro_look": "neon"})
	assert_eq(Settings.retro_look, "full") # a bad value keeps the current one


func test_version_3_saves_move_to_light() -> void:
	Settings.from_dict({"v": 3, "quality": "medium", "dev": {"retro": true}})
	assert_eq(Settings.retro_look, "light")


func test_version_3_plain_look_stays_off() -> void:
	Settings.from_dict({"v": 3, "dev": {"retro": false}})
	assert_eq(Settings.retro_look, "off")


func test_the_settings_screen_switches_it() -> void:
	Ui.init()
	var menu := SettingsMenu.new()
	add_child_autofree(menu)
	menu.tab = SettingsMenu.TABS.find("VIDEO")
	menu.open()
	var row := -1
	for i in menu.rows.size():
		if menu.rows[i].label == "RETRO LOOK":
			row = i
	assert_true(row >= 0)
	assert_eq_deep(menu.rows[row].names, ["OFF", "LIGHT", "FULL"])
	menu._process(0.0) # places the panel
	var vr: Rect2 = menu._value_rect(row)
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = down
		ev.position = menu._origin + vr.end - Vector2(4, 4) # right side: next level
		menu._gui_input(ev)
	assert_eq(Settings.retro_look, "full")
	assert_eq(RetroLook.current, "full")
	assert_eq(get_tree().root.content_scale_size, Vector2i(960, 540))
