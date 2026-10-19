class_name RetroLook
## How strong the PS1/PS2 look is: the player's RETRO LOOK setting (spec
## §9.1, Settings.retro_look). Every level keeps the run's palette, the
## per-vertex lighting, glow and the pixel-font UI; what changes is how
## much of the old-console roughness sits on top.
## - FULL: the original look. The whole window draws at 480x270 (the
##   project's 960x540 at stretch scale 2) and scales up with sharp pixels,
##   vertices snap to a coarse grid (wobble), textures warp (affine) and pick
##   the nearest texel, colours band with a Bayer dither, faint scanlines and
##   an edge fringe.
## - LIGHT (default): a hint of it. The 3D view draws at about 540 lines
##   (the window divided by a whole number, so pixels stay square and sharp:
##   960x540 on 1080p and 4K, about 853x480 on 1440p), with a gentle wobble, a
##   trace of warp, a faint dither and fringe. Textures filter smoothly, as on
##   the PS2. The UI draws at the window's size with its pixel font.
## - OFF: the plain look. Full window resolution, smooth textures, none of
##   the above.
## The shaders read four globals declared in project.godot (their values
## there are FULL's): `psx_retro` (the amount: scales warp, fringe and
## scanlines; above 0.5 textures pick the nearest texel), `psx_snap`
## (the vertex grid as a share of the 3D view's own pixels, 0 = no wobble), `psx_levels` (colour
## levels per channel, 0 = no banding) and `psx_pixel_lines` (the post-process
## cuts the picture into blocks of about this many lines, 0 = none).

const IDS: Array[String] = ["off", "light", "full"]
const NAMES := {"off": "OFF", "light": "LIGHT", "full": "FULL"}
## The default for new players and saves from before the setting existed
## (owner, 2026-10-19: the full look was too strong, the plain one too clean).
const DEFAULT := "light"
## What each level puts on screen. `lines`: the 3D view's height in pixels
## (0 = the window's own; FULL's 270 comes from the project's stretch).
const LEVELS := {
	"off": {"amount": 0.0, "snap": 0.0, "levels": 0.0, "lines": 0},
	"light": {"amount": 0.35, "snap": 0.67, "levels": 64.0, "lines": 540},
	"full": {"amount": 1.0, "snap": 0.6, "levels": 48.0, "lines": 270},
}
## FULL's 3D height: the project's 960x540 base at its stretch scale of 2.
const FULL_LINES := 270

static var current := DEFAULT


## Puts level `id` on screen now (an unknown id counts as the default).
static func apply(id: String) -> void:
	current = id if LEVELS.has(id) else DEFAULT
	var lv: Dictionary = LEVELS[current]
	RenderingServer.global_shader_parameter_set(&"psx_retro", float(lv.amount))
	RenderingServer.global_shader_parameter_set(&"psx_snap", float(lv.snap))
	RenderingServer.global_shader_parameter_set(&"psx_levels", float(lv.levels))
	var blocks: bool = lv.lines != 0 and lv.lines != FULL_LINES
	RenderingServer.global_shader_parameter_set(&"psx_pixel_lines", float(lv.lines) if blocks else 0.0)
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var cb := Callable(RetroLook, &"fit")
	if not tree.root.size_changed.is_connected(cb):
		tree.root.size_changed.connect(cb)
	fit()


## Sets the window's stretch and the 3D view's scale for the current level
## and window size. Runs again whenever the window changes size.
static func fit() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var root := tree.root
	var lines: int = LEVELS[current].lines
	var mode := Window.CONTENT_SCALE_MODE_VIEWPORT if lines == FULL_LINES else Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	if root.content_scale_mode != mode:
		root.content_scale_mode = mode
	var scale := Settings.render_scale
	if mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS and lines > 0:
		# draw the 3D at the block size; the post-process point-samples it
		scale /= block(root.size.y, lines)
	scale = maxf(scale, 0.25) # Godot's lowest 3D scale
	if not is_equal_approx(root.scaling_3d_scale, scale):
		root.scaling_3d_scale = scale


## How many screen pixels tall one 3D pixel is when a window `height` pixels
## tall shows about `lines` lines: the whole number that comes closest (at
## least 1). 2160 -> 4 (540 lines), 1440 -> 3 (480), 1080 -> 2 (540).
static func block(height: int, lines: int) -> int:
	if height <= 0 or lines <= 0:
		return 1
	return maxi(1, roundi(float(height) / lines))
