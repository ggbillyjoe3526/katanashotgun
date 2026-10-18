class_name GlitchText
extends Control
## Cyberpunk display text: heavy wide letters on a dark outline with a faint
## cyan/magenta RGB split, a quick decode-in (letters resolving left to
## right) and a glitch burst on the way out. Optional corner brackets and a
## small data tag.
## Readability rule (spec §9.9): the glitch only plays on the way in (the
## first ~0.1 s) and on the way out (glitch_out); while held, the text is
## clean and still. Digits and punctuation never scramble, so numbers read
## correctly on every frame.

const SCRAMBLE := "#$%&*<>=/ABCDEFHKMNRSTUVXZ"
const MAX_DECODE := 0.1 # seconds; spec §9.9

var text := ""
var px := 24
var color := Color.WHITE
var accent := Color(1, 0.2, 0.6)
var accent2 := Color(0.2, 0.9, 1.0)
var brackets := false
var tag := ""
var tag_right := false # tag at the right edge instead of centred
var decode := 0.1
var font: Font

var _t := 0.0
var _seed := 0
var _shown := ""
var _jit: Array = []
var _burst := 0.0
var _tears: Array = []
var _held_drawn := false # the clean, still frame is drawn once and kept
var _text_w := 0.0
var _tag_w := 0.0
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
	tag_right = o.get("tag_right", false)
	decode = minf(float(o.get("decode", MAX_DECODE)), MAX_DECODE)
	font = o.get("font", Ui.font_big)
	_seed = seed_v
	_rng.seed = hash(t) + seed_v
	_t = 0.0
	_burst = decode
	_jit.clear()
	for i in t.length():
		_jit.append(Vector2.ZERO)
	var ss := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, px)
	_text_w = ss.x
	_tag_w = Ui.font_bold.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, _tag_px()).x if tag != "" else 0.0
	var pad := _pad()
	custom_minimum_size = ss + pad * 2.0 + Vector2(0, _tag_h())
	custom_minimum_size.x = maxf(custom_minimum_size.x, _tag_w + 4.0)
	size = custom_minimum_size
	_shown = _scramble(0) if decode > 0.0 else text
	_held_drawn = false
	queue_redraw()
	return self


## A short glitch burst for the way out (letters swap, tear bars, a wider RGB
## split). Call it when the text starts to fade.
func glitch_out(dur := 0.12) -> void:
	_burst = maxf(_burst, dur)


func _pad() -> Vector2:
	return Vector2(px * 0.45, px * 0.25) if brackets else Vector2(px * 0.15, px * 0.1)


func _tag_px() -> int:
	return 12


func _tag_h() -> float:
	return 15.0 if tag != "" else 0.0


func _is_letter(ch: String) -> bool:
	return ch >= "A" and ch <= "Z"


func _scramble(resolved: int) -> String:
	var out := ""
	for i in text.length():
		var ch := text[i]
		if i < resolved or not _is_letter(ch):
			out += ch
		else:
			out += SCRAMBLE[_rng.randi() % SCRAMBLE.length()]
	return out


func _process(_delta: float) -> void:
	var rd := Game.real_dt
	_t += rd
	_burst -= rd
	var resolved := text.length()
	if decode > 0.0 and _t < decode:
		resolved = int(_t / decode * text.length())
	_shown = _scramble(resolved) if resolved < text.length() else text
	var bursting := _burst > 0.0
	for i in _jit.size():
		_jit[i] = Vector2(_rng.randf_range(-1, 1) * px * 0.06, _rng.randf_range(-1, 1) * px * 0.04) if (bursting and _rng.randf() < 0.3) else Vector2.ZERO
	if bursting and _t >= decode and _rng.randf() < 0.4 and text.length() > 0:
		var i := _rng.randi() % text.length()
		if _is_letter(text[i]):
			_shown = _shown.substr(0, i) + SCRAMBLE[_rng.randi() % SCRAMBLE.length()] + _shown.substr(i + 1)
	_tears.clear()
	if bursting:
		for k in _rng.randi_range(1, 2):
			_tears.append(Vector3(_rng.randf_range(0.1, 0.9), _rng.randf_range(0.04, 0.1), _rng.randf_range(-1, 1)))
	if bursting or _t < decode + 0.05:
		queue_redraw()
	elif not _held_drawn:
		_held_drawn = true
		queue_redraw()



func _draw() -> void:
	var bursting := _burst > 0.0
	if bursting:
		_held_drawn = false
	var pad := _pad()
	var top := _tag_h()
	# text and tag are centred, so a long tag never pushes the text aside
	var base := Vector2((size.x - _text_w) * 0.5, pad.y + top + font.get_ascent(px)).round()
	var a := color.a
	# a dark outline keeps the letters readable over any background
	var ol := maxi(2, int(round(px * 0.14)))
	_draw_line_text(base, Color(0.02, 0.0, 0.05, 0.92 * a), ol)
	# RGB split: a 1 px accent at rest, wider only during a burst
	var split := roundf(px * 0.08) if bursting else 1.0
	var ga := 0.6 if bursting else 0.4
	_draw_line_text(base + Vector2(-split, 0), Color(accent2.r, accent2.g, accent2.b, ga * a))
	_draw_line_text(base + Vector2(split, 0), Color(accent.r, accent.g, accent.b, ga * a))
	# main
	_draw_line_text(base, color)
	# tear bars (in and out only)
	for tr in _tears:
		var y: float = roundf(top + (size.y - top) * tr.x)
		var hh: float = maxf(1.0, roundf((size.y - top) * tr.y))
		draw_rect(Rect2(Vector2(roundf(size.x * 0.05 + tr.z * px * 0.3), y), Vector2(size.x * 0.9, hh)), Color(accent2.r, accent2.g, accent2.b, 0.5 * a) if tr.z > 0 else Color(1, 1, 1, 0.45 * a))
	# corner brackets + tag
	if brackets:
		var L := roundf(px * 0.4)
		var c := accent2
		c.a = a
		var w := maxf(1.0, roundf(px * 0.06))
		var r := Rect2(Vector2(0, top), Vector2(size.x, size.y - top))
		for corner in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
			var sx := 1.0 if corner.x <= r.position.x + 0.1 else -1.0
			var sy := 1.0 if corner.y <= r.position.y + 0.1 else -1.0
			draw_rect(Rect2(corner + Vector2(0 if sx > 0 else -L, 0 if sy > 0 else -w), Vector2(L, w)), c)
			draw_rect(Rect2(corner + Vector2(0 if sx > 0 else -w, 0 if sy > 0 else -L), Vector2(w, L)), c)
	if tag != "":
		# decoration only (spec §9.9): never carries information
		var tf := Ui.font_bold
		var ts := _tag_px()
		var tp := Vector2(roundf(size.x - _tag_w - 2.0) if tag_right else roundf((size.x - _tag_w) * 0.5), tf.get_ascent(ts))
		draw_string_outline(tf, tp, tag, HORIZONTAL_ALIGNMENT_LEFT, -1, ts, 2, Color(0.02, 0.0, 0.05, 0.85 * a))
		draw_string(tf, tp, tag, HORIZONTAL_ALIGNMENT_LEFT, -1, ts, Color(accent2.r, accent2.g, accent2.b, 0.85 * a))


func _draw_line_text(base: Vector2, col: Color, outline := 0) -> void:
	var x := 0.0
	for i in _shown.length():
		var ch := _shown[i]
		var j: Vector2 = (_jit[i] if i < _jit.size() else Vector2.ZERO).round()
		if outline > 0:
			draw_string_outline(font, base + Vector2(x, 0) + j, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px, outline, col)
		else:
			draw_string(font, base + Vector2(x, 0) + j, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
		# advance by the final text's glyph so scrambled letters don't jitter the layout
		var final_ch := text[i] if i < text.length() else ch
		x += font.get_string_size(final_ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
