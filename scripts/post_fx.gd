class_name PostFx
extends CanvasLayer
## Full-screen PS1 post-process (dither, colour depth, vignette, damage pulse).

var rect: ColorRect
var mat: ShaderMaterial
var _hurt := 0.0
var _flash := 0.0
var _t := 0.0
var _impact := 0.0
var heat := 0.0
# the juice layer's short effects (spec §9.8), all on real time
var _cut_t := 99.0
var _cut_len := 0.22
var _cut_off := 0.0
var _seam_len := 0.1
var _roll := 0.0
var _neg := 0.0
var _neg_t := 99.0
var _inv := 0.0


func _ready() -> void:
	layer = 1
	process_mode = Node.PROCESS_MODE_ALWAYS
	rect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/post_psx.gdshader")
	rect.material = mat
	add_child(rect)
	if Game.palette.has("neon_a"):
		mat.set_shader_parameter("impact_color", Color(Game.palette.neon_a))
		mat.set_shader_parameter("heat_color", Color(Game.palette.neon_a))


func hurt(k: float) -> void:
	_hurt = maxf(_hurt, k)


func flash(k: float) -> void:
	_flash = maxf(_flash, k)


## Anime impact frame: the picture snaps to three flat tones for `dur`
## seconds; the middle tone is `col`, or the palette's accent.
func impact_frame(dur: float, col := Color(0, 0, 0, 0)) -> void:
	_impact = maxf(_impact, dur)
	if col.a > 0.0:
		mat.set_shader_parameter("impact_color", col)
	elif Game.palette.has("neon_a"):
		mat.set_shader_parameter("impact_color", Color(Game.palette.neon_a))
		mat.set_shader_parameter("heat_color", Color(Game.palette.neon_a))


## KIRI: the picture is cut along a line through `at` (fraction of the
## screen) leaning `angle` radians. The two sides slip `off` pixels apart and
## close again over `dur`; the line glows for `seam` seconds.
func cut(at: Vector2, angle: float, off := 12.0, dur := 0.22, seam := 0.1, seam_color := Color.WHITE) -> void:
	_cut_t = 0.0
	_cut_len = maxf(dur, 0.01)
	_cut_off = off
	_seam_len = seam
	mat.set_shader_parameter("cut_p", at)
	mat.set_shader_parameter("cut_dir", Vector2.from_angle(angle))
	mat.set_shader_parameter("cut_color", seam_color)


## HIJACK: a tracking roll, bands of the picture shoved sideways.
func roll(dur := 0.1) -> void:
	_roll = maxf(_roll, dur)
	mat.set_shader_parameter("roll_seed", float(Game.rng_fx.randi() % 1000))


## HIJACK: a frame of negative.
func invert_flash(dur := 0.05) -> void:
	_inv = maxf(_inv, dur)


## FINISH: the picture goes two-tone, dark ink and red, for `dur` seconds;
## at full flash it is inverted for a moment first.
func negative(dur: float) -> void:
	_neg = maxf(_neg, dur)
	_neg_t = 0.0


func _process(delta: float) -> void:
	_t += delta
	var rd := delta / maxf(Engine.time_scale, 0.05)
	_hurt = move_toward(_hurt, 0.0, rd * 1.8)
	_flash = move_toward(_flash, 0.0, rd * 3.0)
	_impact -= rd
	# the comfort slider softens impact frames; below full they stop strobing
	mat.set_shader_parameter("impact", Settings.flash if _impact > 0.0 else 0.0)
	mat.set_shader_parameter("impact_invert", Settings.flash >= 0.99 and fmod(_t, 0.06) < 0.03)
	mat.set_shader_parameter("heat", heat)
	_cut_t += rd
	var ck := clampf(1.0 - _cut_t / _cut_len, 0.0, 1.0)
	# the cut is movement, so it follows the shake slider; the seam is a flash
	mat.set_shader_parameter("cut_off", _cut_off * ck * ck * Settings.shake)
	mat.set_shader_parameter("cut_seam", Settings.flash if _cut_t < _seam_len else 0.0)
	_roll -= rd
	mat.set_shader_parameter("roll", Settings.shake if _roll > 0.0 else 0.0)
	if _roll > 0.0 and fmod(_t, 0.05) < rd:
		mat.set_shader_parameter("roll_seed", float(Game.rng_fx.randi() % 1000))
	_inv -= rd
	mat.set_shader_parameter("invert", Settings.flash * 0.9 if _inv > 0.0 else 0.0)
	_neg -= rd
	_neg_t += rd
	mat.set_shader_parameter("neg", Settings.flash if _neg > 0.0 else 0.0)
	mat.set_shader_parameter("neg_invert", Settings.flash >= 0.99 and _neg_t >= 0.05 and _neg_t < 0.1)
	var low := 0.0
	var p := Game.player
	if p and not p.dead and p.hp / p.max_hp < 0.3:
		low = 0.22 + 0.12 * sin(_t * 7.0)
	mat.set_shader_parameter("damage", maxf(_hurt, low))
	mat.set_shader_parameter("flash", _flash * Settings.flash)
	mat.set_shader_parameter("desaturate", 0.75 if (p and p.dead) else 0.0)
