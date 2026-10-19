class_name DevSettings
## The hidden developer settings (spec §16), flipped in the DEV menu (F10,
## scripts/ui/dev_menu.gd). Not a player feature: nothing on screen points
## to it.
## Only the look is saved (inside the player's settings, under "dev"). Every
## setting that changes a run lasts until the game closes, so a cheat left on
## never slips into tomorrow's real run. A run played with any of them on is
## a dev run (Game.dev_run): no top 10 entry, no XP, no unlocks.

## The key that opens the menu, in the title, a run and the pause screen.
## Kept out of key rebinding (Settings.RESERVED_KEYS).
const KEY := KEY_F10
const SPEEDS: Array[float] = [0.25, 0.5, 1.0, 1.5, 2.0]
const MAX_START_WAVE := 30

## false: the plain look. The 3D view renders at the window's full size
## instead of 960x540, textures are smooth, and the vertex wobble, affine
## texture warp, colour banding, dither, scanlines and edge fringe are off.
## The UI keeps its pixel font. Applied at once.
static var retro := true
static var speed := 1.0 # game speed while playing (UI and juice keep real time)
static var start_wave := 1 # the wave the next run starts at
static var boss := "" # every boss wave brings this boss ("" = the seed's)
static var mutator := "" # every regular wave gets this mutator ("" = the seed's)
static var hide_hud := false # the in-run HUD hides (for clean captures)
## true: the katana is the Blender model (assets/models/katana) instead of the
## code-built one. Off until the owner approves the model (spec §9.6); not
## saved, like the run settings.
static var katana_model := false


## Puts every dev setting back to normal (the menu's DEFAULTS).
static func reset() -> void:
	retro = true
	speed = 1.0
	start_wave = 1
	boss = ""
	mutator = ""
	hide_hud = false
	katana_model = false
	Game.debug_god = false
	Game.set_autoplay(false)
	Game.debug_palette = ""
	apply_look()


## Whether any setting that changes how a run plays is on. While one is,
## the run in progress becomes a dev run.
static func cheating() -> bool:
	return Game.debug_god or Game.debug_autoplay or speed != 1.0 or start_wave > 1 \
		or boss != "" or mutator != ""


## Whether any dev setting is on at all (the corner tag shows then).
static func any_on() -> bool:
	return not retro or cheating() or hide_hud or katana_model or Game.debug_palette != ""


## Short names of the dev settings that are on, for the corner tag.
static func active_tags() -> PackedStringArray:
	var out := PackedStringArray()
	if not retro:
		out.append("PLAIN LOOK")
	if Game.debug_god:
		out.append("GOD")
	if Game.debug_autoplay:
		out.append("BOT")
	if speed != 1.0:
		out.append("SPEED %d%%" % roundi(speed * 100.0))
	if start_wave > 1:
		out.append("START W%d" % start_wave)
	if boss != "":
		out.append("BOSS %s" % boss.to_upper())
	if mutator != "":
		out.append("MUTATOR %s" % str(Mutators.get_def(mutator).get("name", mutator)))
	if Game.debug_palette != "":
		out.append("PALETTE")
	if hide_hud:
		out.append("NO HUD")
	if katana_model:
		out.append("NEW KATANA")
	return out


## Applies the look: the shaders read the global `psx_retro` (declared in
## project.godot), and the window either renders at 960x540 and scales up
## with sharp pixels (retro) or renders at full size (plain).
static func apply_look() -> void:
	RenderingServer.global_shader_parameter_set(&"psx_retro", 1.0 if retro else 0.0)
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var mode := Window.CONTENT_SCALE_MODE_VIEWPORT if retro else Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	if tree.root.content_scale_mode != mode:
		tree.root.content_scale_mode = mode


# ---------------------------------------------------------------- save data
static func to_dict() -> Dictionary:
	return {"retro": retro}


static func from_dict(d: Dictionary) -> void:
	if d.get("retro") is bool:
		retro = d.retro
