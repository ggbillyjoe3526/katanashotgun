class_name Graphics
## What the graphics presets do to the picture (spec §14.1). Quality owns the
## preset and its effect caps; this puts the rendering side of the preset on
## a map's Environment, moon and lamps, and keeps the renderer choice:
## - WEAK (`low`): the map exactly as built. The look every tier starts from.
## - MEDIOCRE (`medium`): ambient occlusion, moon shadows, wider neon glow.
## - INSANE (`high`): on top of that, on the Forward+ renderer, global
##   illumination (neon light bounces off the floors), screen-space
##   reflections on wet floors, indirect light, volumetric fog that the lamps
##   light up, shadows from every lamp and softer, sharper shadow maps.
## Every tier keeps the PS1 look: 960x540, vertex snap, Gouraud lighting, the
## run's palette and the dither post-process. Higher tiers add light, never
## realism. WEAK and MEDIOCRE run on Compatibility (OpenGL 3), INSANE on
## Forward+ (Vulkan or Direct3D 12). Godot picks the renderer at start-up, so
## the game writes the choice to renderer_file (read through the project
## setting application/config/project_settings_override) and a switch takes
## a restart. A PC that can't run Forward+ falls back to OpenGL by itself.

const COMPAT := "gl_compatibility"
const FORWARD_PLUS := "forward_plus"
## The renderer each preset wants.
const RENDERERS := {"low": COMPAT, "medium": COMPAT, "high": FORWARD_PLUS}

## Must match application/config/project_settings_override in project.godot
## (tests point it elsewhere).
static var renderer_file := "user://renderer.cfg"
static var _method := ""
static var _boot_file := "" # what renderer_file asked for when the game started
static var _boot_read := false


## The renderer this run of the game uses (fixed until it restarts):
## "gl_compatibility", "forward_plus", or something else headless.
static func renderer() -> String:
	if _method == "":
		_method = RenderingServer.get_current_rendering_method()
	return _method


## Whether the Forward+ features (GI, reflections, volumetric fog) exist now.
static func advanced() -> bool:
	return renderer() == FORWARD_PLUS


static func wanted_renderer(preset: String) -> String:
	return RENDERERS.get(preset, COMPAT)


## True when INSANE asked for Forward+ at start-up but this PC couldn't run
## it and Godot fell back to OpenGL.
static func fell_back() -> bool:
	_read_boot_file()
	return _boot_file == FORWARD_PLUS and renderer() == COMPAT


## Whether `preset` only fully applies after a restart (it wants the other
## renderer). Never after a fallback, nor on a headless or dummy renderer.
static func restart_needed(preset: String) -> bool:
	var now := renderer()
	if DisplayServer.get_name() == "headless" or (now != COMPAT and now != FORWARD_PLUS):
		return false
	var want := wanted_renderer(preset)
	if want == FORWARD_PLUS and fell_back():
		return false
	return want != now


## Writes the renderer `preset` wants for the next start. Only the player's
## choice calls this (the settings menu and boot), never `--quality=`.
static func save_renderer(preset: String) -> void:
	_read_boot_file()
	var want := wanted_renderer(preset)
	if _read_file() == want or (want == COMPAT and not FileAccess.file_exists(renderer_file)):
		return
	var cf := ConfigFile.new()
	cf.set_value("rendering", "renderer/rendering_method", want)
	var tmp := renderer_file + ".tmp"
	if cf.save(tmp) != OK:
		push_warning("Graphics: could not write %s" % tmp)
		return
	DirAccess.rename_absolute(tmp, renderer_file)


static func _read_boot_file() -> void:
	if not _boot_read:
		_boot_read = true
		_boot_file = _read_file()


static func _read_file() -> String:
	if not FileAccess.file_exists(renderer_file):
		return ""
	var cf := ConfigFile.new()
	if cf.load(renderer_file) != OK:
		return ""
	return str(cf.get_value("rendering", "renderer/rendering_method", ""))


# ---------------------------------------------------------------- the look
## Applies the current preset to `arena` now and whenever the preset changes,
## until the arena leaves the tree. Call once the map is built.
static func attach(arena: Arena) -> void:
	_remember_base(arena)
	apply(arena)
	var cb := func(_id: String) -> void:
		if is_instance_valid(arena):
			apply(arena)
	Quality.on_changed(cb)
	arena.tree_exiting.connect(func() -> void: Quality.off_changed(cb), CONNECT_ONE_SHOT)


## The map's own glow, kept so WEAK can always put it back exactly.
static func _remember_base(arena: Arena) -> void:
	var env := arena.env
	arena.set_meta(&"gfx_base", {
		"glow_intensity": env.glow_intensity, "glow_strength": env.glow_strength,
		"glow_bloom": env.glow_bloom, "glow_levels": _glow_levels(env),
		"ambient": env.ambient_light_energy,
	})


static func _glow_levels(env: Environment) -> Array:
	var out := []
	for i in 7:
		out.append(env.get_glow_level(i))
	return out


static func apply(arena: Arena) -> void:
	var tier := Quality.preset
	var env := arena.env
	var base: Dictionary = arena.get_meta(&"gfx_base", {})
	var mid := tier != "low"
	var top := tier == "high" and advanced()
	# glow: the map's own on WEAK; wider halos on MEDIOCRE, wider still on INSANE
	if not base.is_empty():
		env.glow_intensity = base.glow_intensity
		env.glow_strength = base.glow_strength
		env.glow_bloom = base.glow_bloom
		var lv: Array = base.glow_levels
		for i in lv.size():
			env.set_glow_level(i, lv[i])
	if mid and not advanced():
		for i in GLOW_MID.size():
			env.set_glow_level(i, maxf(env.get_glow_level(i), GLOW_MID[i]))
		env.glow_intensity = float(base.get("glow_intensity", 1.0)) * 1.3
	if advanced():
		# HDR: wide or bloom glow turns the whole picture milky, so only
		# light brighter than white glows, in the map's own halo sizes
		env.glow_bloom = 0.0
		env.glow_hdr_threshold = 1.0
		env.glow_intensity = float(base.get("glow_intensity", 1.0)) * (1.6 if top else 1.3)
	# ambient occlusion: contact shadow in every corner and under every foe
	env.ssao_enabled = mid
	env.ssao_radius = 1.6 if top else 1.2
	env.ssao_intensity = 2.2 if top else 1.8
	env.ssao_power = 1.6
	env.ssao_detail = 0.6
	env.ssao_light_affect = 0.0
	_apply_moon(arena.moon, mid, top)
	_apply_lamps(arena, mid, top)
	_apply_haze(arena, mid and not top)
	_apply_forward_plus(env, top, base)
	_apply_server(tier, top)


## Lamp haze on MEDIOCRE: quad size per metre of lamp range, and strength.
const HAZE_SIZE := 0.7
const HAZE_ALPHA := 0.18
## How many lamps cast shadows on MEDIOCRE (the OpenGL renderer draws every
## shadowed lamp in an extra pass, so only the brightest few).
const MID_SHADOW_LAMPS := 4
## Relative weights of the seven glow levels (small to wide halos).
const GLOW_MID: Array[float] = [0.0, 0.8, 1.0, 0.7, 0.3, 0.0, 0.0]


static func _apply_moon(moon: DirectionalLight3D, mid: bool, top: bool) -> void:
	if moon == null:
		return
	moon.shadow_enabled = mid
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if top else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	moon.directional_shadow_max_distance = 90.0 if top else 60.0
	moon.shadow_blur = 1.0
	moon.shadow_opacity = 0.85
	moon.light_volumetric_fog_energy = 0.6


## Lamps that cast shadows: the brightest few on MEDIOCRE, every one the map
## placed on INSANE (Forward+), where they also light the volumetric fog.
## Effect lights (muzzle flashes, explosions) never cast.
static func _apply_lamps(arena: Arena, mid: bool, top: bool) -> void:
	var lamps := arena.find_children("*", "OmniLight3D", true, false)
	lamps.sort_custom(func(a: OmniLight3D, b: OmniLight3D) -> bool: return a.light_energy * a.omni_range > b.light_energy * b.omni_range)
	for i in lamps.size():
		var l := lamps[i] as OmniLight3D
		l.shadow_enabled = top or (mid and i < MID_SHADOW_LAMPS)
		l.omni_shadow_mode = OmniLight3D.SHADOW_CUBE
		l.shadow_blur = 1.2
		l.light_volumetric_fog_energy = 2.5


## MEDIOCRE's stand-in for volumetric fog: a faint additive glow around each
## lamp, the old PS1 trick. Built once per map; INSANE on Forward+ has the
## real thing instead.
static func _apply_haze(arena: Arena, on: bool) -> void:
	var haze: Array = arena.get_meta(&"gfx_haze", [])
	if on and haze.is_empty():
		for n in arena.find_children("*", "OmniLight3D", true, false):
			var l := n as OmniLight3D
			var c := l.light_color
			var q := Psx.quad(Vector2.ONE * l.omni_range * HAZE_SIZE, Psx.fx(Color(c.r, c.g, c.b, HAZE_ALPHA), TexGen.get_tex("glow"), true, true, false, 1.0))
			l.add_child(q)
			haze.append(q)
		arena.set_meta(&"gfx_haze", haze)
	for q in haze:
		if is_instance_valid(q):
			q.visible = on


static func _apply_forward_plus(env: Environment, top: bool, base: Dictionary) -> void:
	if not advanced():
		return
	# psx_lit_hd leaves fog to the Environment: the shader's own curve over
	# the near world's range (Psx.NEAR_FOG_END), on every preset here
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Psx.fog_color
	env.fog_light_energy = 1.0
	env.fog_density = 1.0
	env.fog_depth_begin = 10.0
	env.fog_depth_end = 100.0
	env.fog_depth_curve = 1.0
	env.fog_sky_affect = 0.0
	env.fog_sun_scatter = 0.0
	# global illumination: neon bounces colour onto floors and walls
	env.sdfgi_enabled = top
	env.sdfgi_use_occlusion = true
	env.sdfgi_read_sky_light = true
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.2
	env.sdfgi_bounce_feedback = 0.4
	env.sdfgi_energy = 1.0
	env.sdfgi_normal_bias = 1.1
	# GI replaces the flat ambient colour, so the map keeps its brightness
	env.ambient_light_energy = float(base.get("ambient", env.ambient_light_energy))
	env.ssil_enabled = top
	env.ssil_radius = 6.0
	env.ssil_intensity = 1.2
	env.ssil_sharpness = 0.98
	# reflections on the wet floors (psx_lit_hd lowers their roughness)
	env.ssr_enabled = top
	env.ssr_max_steps = 96
	env.ssr_fade_in = 0.1
	env.ssr_fade_out = 2.0
	env.ssr_depth_tolerance = 0.3
	# volumetric fog: a thin haze the lamps and neon light up
	env.volumetric_fog_enabled = top
	env.volumetric_fog_density = 0.006
	env.volumetric_fog_albedo = Color(0.85, 0.85, 0.9)
	env.volumetric_fog_emission = Color.BLACK
	env.volumetric_fog_gi_inject = 0.3
	env.volumetric_fog_ambient_inject = 0.0
	env.volumetric_fog_anisotropy = 0.4
	env.volumetric_fog_length = 80.0
	env.volumetric_fog_detail_spread = 2.0
	env.volumetric_fog_sky_affect = 0.0
	env.volumetric_fog_temporal_reprojection_enabled = true


## Renderer-wide quality knobs (shadow filtering, effect resolutions).
static func _apply_server(tier: String, top: bool) -> void:
	var soft := RenderingServer.SHADOW_QUALITY_SOFT_HIGH if top else (RenderingServer.SHADOW_QUALITY_SOFT_LOW if tier == "medium" else RenderingServer.SHADOW_QUALITY_HARD)
	RenderingServer.directional_soft_shadow_filter_set_quality(soft)
	RenderingServer.positional_soft_shadow_filter_set_quality(soft)
	RenderingServer.directional_shadow_atlas_set_size(4096 if top else 2048, true)
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		tree.root.positional_shadow_atlas_size = 4096 if top else 1024
		# smoother edges that still sit on the big 960x540 pixels
		tree.root.msaa_3d = {"low": Viewport.MSAA_DISABLED, "medium": Viewport.MSAA_2X}.get(tier, Viewport.MSAA_4X)
	if not advanced():
		return
	RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_HIGH if top else RenderingServer.ENV_SSAO_QUALITY_MEDIUM, true, 0.5, 2, 50.0, 300.0)
	RenderingServer.environment_set_ssil_quality(RenderingServer.ENV_SSIL_QUALITY_HIGH, true, 0.5, 4, 50.0, 300.0)
	RenderingServer.environment_set_sdfgi_ray_count(RenderingServer.ENV_SDFGI_RAY_COUNT_64)
	RenderingServer.environment_set_volumetric_fog_volume_size(96, 96)
	RenderingServer.gi_set_use_half_resolution(false)
