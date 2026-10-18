extends GutTest
## Graphics presets (spec §14.1): WEAK leaves a map exactly as built,
## MEDIOCRE adds ambient occlusion, shadows, wider glow and lamp haze, and
## switching back puts everything back. INSANE asks for Forward+ at the next
## start; headless there is no renderer to switch.

var arena: Arena


func before_each() -> void:
	Quality.apply("low")
	arena = Arena.new()
	arena.pal = {"fog": Color(0.1, 0.05, 0.2)}
	arena.env = Environment.new()
	arena.env.glow_enabled = true
	arena.env.glow_intensity = 1.05
	arena.env.glow_bloom = 0.06
	arena.moon = DirectionalLight3D.new()
	arena.add_child(arena.moon)
	for i in 6:
		var l := OmniLight3D.new()
		l.light_energy = 1.0 + i
		l.omni_range = 10.0
		arena.add_child(l)
	add_child_autofree(arena)
	Graphics.attach(arena)


func after_each() -> void:
	Quality.apply(Quality.DEFAULT)


func _shadowed_lamps() -> int:
	var n := 0
	for l in arena.find_children("*", "OmniLight3D", true, false):
		if (l as OmniLight3D).shadow_enabled:
			n += 1
	return n


func _haze_visible() -> bool:
	for q in arena.get_meta(&"gfx_haze", []):
		if q.visible:
			return true
	return false


func test_weak_is_the_map_as_built() -> void:
	assert_false(arena.env.ssao_enabled)
	assert_false(arena.moon.shadow_enabled)
	assert_eq(_shadowed_lamps(), 0)
	assert_false(_haze_visible())
	assert_almost_eq(arena.env.glow_intensity, 1.05, 0.001)
	assert_almost_eq(arena.env.glow_bloom, 0.06, 0.001)


func test_mediocre_adds_light_and_weak_takes_it_back() -> void:
	var levels := []
	for i in 7:
		levels.append(arena.env.get_glow_level(i))
	Quality.apply("medium")
	assert_true(arena.env.ssao_enabled)
	assert_true(arena.moon.shadow_enabled)
	assert_eq(_shadowed_lamps(), Graphics.MID_SHADOW_LAMPS, "only the brightest lamps cast")
	assert_true(_haze_visible())
	assert_gt(arena.env.glow_intensity, 1.05)
	Quality.apply("low")
	test_weak_is_the_map_as_built()
	for i in 7:
		assert_eq(arena.env.get_glow_level(i), levels[i], "glow level %d restored" % i)


func test_brightest_lamps_cast_first() -> void:
	Quality.apply("medium")
	for l in arena.find_children("*", "OmniLight3D", true, false):
		var lamp := l as OmniLight3D
		assert_eq(lamp.shadow_enabled, lamp.light_energy > 2.5, "lamp %.0f" % lamp.light_energy)


func test_presets_want_their_renderer() -> void:
	assert_eq(Graphics.wanted_renderer("low"), Graphics.COMPAT)
	assert_eq(Graphics.wanted_renderer("medium"), Graphics.COMPAT)
	assert_eq(Graphics.wanted_renderer("high"), Graphics.FORWARD_PLUS)
	for q in Quality.PRESETS:
		assert_false(Graphics.restart_needed(q), "no restart without a real renderer: %s" % q)


func test_renderer_file_is_read_by_the_engine() -> void:
	# the override file must be where project.godot tells Godot to look
	assert_eq(ProjectSettings.get_setting("application/config/project_settings_override"), Graphics.renderer_file)


func test_every_preset_has_a_name() -> void:
	assert_eq_deep(Quality.PRESETS.map(func(q): return Quality.NAMES[q]), ["WEAK", "MEDIOCRE", "INSANE"])
