class_name GlitchText
extends Control
## Cyberpunk display text: heavy wide letters with a cyan/magenta RGB split,
## a decode-in (random characters resolving left to right), and short glitch
## bursts (letters swap, jump and tear) every so often. Optional corner
## brackets and a small data tag.

const SCRAMBLE := "#$%&*+<>=/\\0123456789ABCDEFHKMNRSTUVXZ"

var text := ""
var px := 24
var color := Color.WHITE
var accent := Color(1, 0.2, 0.6)
var accent2 := Color(0.2, 0.9, 1.0)
var brackets := false
var tag := ""
var decode := 0.25
var font: Font

var _t := 0.0
var _seed := 0
var _shown := ""
var _jit: Array = []
var _burst := 0.0
var _next_burst := 1.0
var _tears: Array = []
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(t: String, size_px := 24, col := Color.WHITE, acc := Color(1, 0.2, 0.6), seed_v := 0, o := {}) -> GlitchText:
	Ui.init()
	text = t
	px = size_px
	color = col
	accent = acc
	accent2 = o.get("accent2", Color(0.2, 0.9, 1.0))
	brackets = o.get("brackets", false)
	tag = o.get("tag", "")
	decode = float(o.get("decode", 0.25))
	font = o.get("font", Ui.font_big)
	_seed = seed_v
	_rng.seed = hash(t) + seed_v
	_t = 0.0
	_burst = 0.12
	_next_burst = _rng.randf_range(0.6, 1.6)
	_jit.clear()
	for i in t.length():
		_jit.append(Vector2.ZERO)
	var ss := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, px)
	var pad := Vector2(px * 0.45, px * 0.25) if brackets else Vector2(px * 0.12, px * 0.1)
	custom_minimum_size = ss + pad * 2.0 + Vector2(0, maxf(11.0, px * 0.36) + 1.0 if tag != "" else 0.0)
	if tag != "":
		custom_minimum_size.x = maxf(custom_minimum_size.x, Ui.font_mono.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, int(maxf(11.0, px * 0.36))).x + 4.0)
	size = custom_minimum_size
	_shown = _scramble(0)
	queue_redraw()
	return self


func _scramble(resolved: int) -> String:
	var out := ""
	for i in text.length():
		var ch := text[i]
		if ch == " " or i < resolved:
			out += ch
		else:
			out += SCRAMBLE[_rng.randi() % SCRAMBLE.length()]
	return out


func _process(_delta: float) -> void:
	var rd := Game.real_dt
	_t += rd
	var resolved := text.length()
	if decode > 0.0 and _t < decode:
		resolved = int(_t / decode * text.length())
	_shown = _scramble(resolved) if resolved < text.length() else text
	# glitch bursts
	_next_burst -= rd
	if _next_burst <= 0.0:
		_next_burst = _rng.randf_range(0.7, 1.8)
		_burst = _rng.randf_range(0.05, 0.1)
	_burst -= rd
	var bursting := _burst > 0.0
	for i in _jit.size():
		_jit[i] = Vector2(_rng.randf_range(-1, 1) * px * 0.08, _rng.randf_range(-1, 1) * px * 0.05) if (bursting and _rng.randf() < 0.3) else Vector2.ZERO
	if bursting and _rng.randf() < 0.4 and text.length() > 0:
		var i := _rng.randi() % text.length()
		if text[i] != " ":
			_shown = _shown.substr(0, i) + SCRAMBLE[_rng.randi() % SCRAMBLE.length()] + _shown.substr(i + 1)
	_tears.clear()
	if bursting:
		for k in _rng.randi_range(1, 3):
			_tears.append(Vector3(_rng.randf_range(0.1, 0.9), _rng.randf_range(0.05, 0.14), _rng.randf_range(-1, 1)))
	queue_redraw()


func _draw() -> void:
	var bursting := _burst > 0.0 or _t < decode
	var pad := Vector2(px * 0.45, px * 0.25) if brackets else Vector2(px * 0.12, px * 0.1)
	var top := maxf(11.0, px * 0.36) + 1.0 if tag != "" else 0.0
	var base := Vector2(pad.x, pad.y + top + font.get_ascent(px))
	var split := px * (0.09 if bursting else 0.035)
	var a := color.a
	# RGB split ghosts
	_draw_line_text(base + Vector2(-split, 0), Color(accent2.r, accent2.g, accent2.b, 0.6 * a))
	_draw_line_text(base + Vector2(split, split * 0.3), Color(accent.r, accent.g, accent.b, 0.6 * a))
	# main
	_draw_line_text(base, color)
	# tear bars
	for tr in _tears:
		var y: float = size.y * tr.x
		var hh: float = maxf(1.0, size.y * tr.y)
		draw_rect(Rect2(Vector2(size.x * 0.05 + tr.z * px * 0.3, y), Vector2(size.x * 0.9, hh)), Color(accent2.r, accent2.g, accent2.b, 0.55 * a) if tr.z > 0 else Color(1, 1, 1, 0.5 * a))
	# corner brackets + tag
	if brackets:
		var L := px * 0.4
		var c := accent2
		c.a = a
		var w := maxf(1.0, px * 0.06)
		var r := Rect2(Vector2(0, top), Vector2(size.x, size.y - top))
		for corner in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
			var sx := 1.0 if corner.x <= r.position.x + 0.1 else -1.0
			var sy := 1.0 if corner.y <= r.position.y + 0.1 else -1.0
			draw_rect(Rect2(corner + Vector2(0 if sx > 0 else -L, 0 if sy > 0 else -w), Vector2(L, w)), c)
			draw_rect(Rect2(corner + Vector2(0 if sx > 0 else -w, 0 if sy > 0 else -L), Vector2(w, L)), c)
	if tag != "":
		var tf := Ui.font_mono
		var ts := int(maxf(11.0, px * 0.36))
		draw_string(tf, Vector2(2, tf.get_ascent(ts)), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, ts, Color(accent2.r, accent2.g, accent2.b, 0.9 * a))


func _draw_line_text(base: Vector2, col: Color) -> void:
	var x := 0.0
	for i in _shown.length():
		var ch := _shown[i]
		var j: Vector2 = _jit[i] if i < _jit.size() else Vector2.ZERO
		draw_string(font, base + Vector2(x, 0) + j, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
		# advance by the final text's glyph so scrambled letters don't jitter the layout
		var final_ch := text[i] if i < text.length() else ch
		x += font.get_string_size(final_ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
