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


## Anime impact frame: the picture snaps to three flat tones for `dur` seconds.
func impact_frame(dur: float) -> void:
	_impact = maxf(_impact, dur)
	if Game.palette.has("neon_a"):
		mat.set_shader_parameter("impact_color", Color(Game.palette.neon_a))
		mat.set_shader_parameter("heat_color", Color(Game.palette.neon_a))


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
	var low := 0.0
	var p := Game.player
	if p and not p.dead and p.hp / p.max_hp < 0.3:
		low = 0.22 + 0.12 * sin(_t * 7.0)
	mat.set_shader_parameter("damage", maxf(_hurt, low))
	mat.set_shader_parameter("flash", _flash * Settings.flash)
	mat.set_shader_parameter("desaturate", 0.75 if (p and p.dead) else 0.0)
