class_name HijackBlock
extends Control
## HIJACK, "the broadcast takeover" (spec §9.8): a message on a solid neon
## block with dark letters and a hard offset shadow, like a pirate
## broadcast's caption. One frame of test-card colour bars where the block
## will be, then the block opens from a scan line and the word lands with a
## short horizontal stretch. On the way out it is torn into strips that whip
## left and right. Optional: a tag chip above (dark, a red dot) and a sub
## chip below.
## Readability (spec §9.9): straight lines only; the word only stretches
## during its 0.08 s landing, then holds level and still for its read time.
## Used for KAMAE BROKEN and the boss name card. Drawn in code, on real time.

const INK := Color(0.03, 0.024, 0.07)
const BARS := 0.05 # the colour-bar frame
const OPEN := 0.06 # the scan-line open
const OUT := 0.14 # the tear
const STRIPS := 7
const BAR_COLS := [Color("f4f4ff"), Color("ffd940"), Color("40f2ff"), Color("96ff60"), Color("ff33b2"), Color("ff2838"), Color("4682ff")]

var text := ""
var col := Color(1, 0.72, 0.15) # the block
var shadow := Color(1, 0.55, 0.19) # its hard shadow and the tag's words
var ink := INK # the word
var tag := ""
var sub := ""
var sub_col := Color.WHITE
var size_px := 20
var pad := 26.0
var top := 30.0 # the lane's top edge
var _t := 99.0
var _hold := 1.0
var _font: Font
var _fs := 25
var _seed := 0
var _strips: Array[Control] = []
var _tear: PackedFloat32Array = PackedFloat32Array()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# the block paints into horizontal clipped strips so the exit can tear it
	for i in STRIPS:
		var s := Control.new()
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s.clip_contents = true
		s.draw.connect(_paint.bind(s))
		add_child(s)
		_strips.append(s)
		_tear.append(1.0)


## Starts a block. Options: ink, tag, sub, sub_col, size, pad, hold.
func play(word: String, c: Color, sh: Color, o := {}) -> void:
	text = word
	col = c
	shadow = sh
	ink = o.get("ink", INK)
	tag = str(o.get("tag", ""))
	sub = str(o.get("sub", ""))
	sub_col = o.get("sub_col", Color.WHITE)
	size_px = int(o.get("size", 20))
	pad = float(o.get("pad", 26.0))
	_font = Ui.face(Ui.font_big, size_px)
	_fs = Ui.px(_font, size_px)
	_hold = maxf(float(o.get("hold", 0.0)), Juice.read_time(word + sub) + 0.15)
	_seed = Game.rng_fx.randi() % 997
	for i in STRIPS:
		_tear[i] = Game.rng_fx.randf_range(0.6, 1.4)
	_t = 0.0
	visible = true
	_redraw()


func showing() -> bool:
	return _t < BARS + OPEN + _hold + OUT


## Ends the block at once (a newer message takes the lane).
func stop() -> void:
	_t = 99.0
	visible = false


## The block's rectangle.
func block_rect() -> Rect2:
	var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs).x if _font else 0.0
	var cap := roundf(_fs * 0.72)
	var x0 := roundf(size.x * 0.5 - tw * 0.5 - pad)
	var y0 := top + (14.0 if tag != "" else 0.0)
	return Rect2(x0, y0, roundf(tw + pad * 2.0), cap + 12.0)


func _redraw() -> void:
	for s in _strips:
		s.queue_redraw()


func _process(_delta: float) -> void:
	if _t > 50.0:
		return
	_t += Game.real_dt
	if not showing():
		_t = 99.0
		visible = false
		return
	# the strips cover the tag chip, the block and the sub chip
	var r := block_rect()
	var y0 := r.position.y - 16.0
	var y1 := r.end.y + 20.0
	var step := ceilf((y1 - y0) / STRIPS)
	var ot := _t - BARS - OPEN - _hold
	var k := clampf(ot / OUT, 0.0, 1.0) if ot > 0.0 else 0.0
	for i in STRIPS:
		var s := _strips[i]
		var o := roundf((1.0 if i % 2 == 0 else -1.0) * k * k * 120.0 * _tear[i])
		s.position = Vector2(o, y0 + i * step)
		s.size = Vector2(size.x, step)
		s.modulate.a = 1.0 - k * 0.7
	_redraw()


## Paints the block into one strip (clipped to it).
func _paint(s: Control) -> void:
	if not showing():
		return
	# each strip moves with its content: undo only its vertical place
	var back := Vector2(0, -s.position.y)
	s.draw_set_transform(back)
	var r := block_rect()
	var x0 := r.position.x
	var x1 := r.end.x
	var y0 := r.position.y
	var y1 := r.end.y
	if _t < BARS:
		# one frame of colour bars where the block will be, rows torn sideways
		var bw := (x1 - x0 + 40.0) / BAR_COLS.size()
		var y := y0 - 6.0
		var row := 0
		while y < y1 + 6.0:
			var o := roundf(fmod(sin((row + _seed) * 12.9898) * 43758.5453, 1.0) * 14.0)
			for i in BAR_COLS.size():
				s.draw_rect(Rect2(x0 - 20.0 + roundf(i * bw) + o, y, ceilf(bw), 2), BAR_COLS[i])
			y += 3.0
			row += 1
		s.draw_set_transform(Vector2.ZERO)
		return
	var ok := Juice.ease_out((_t - BARS) / OPEN)
	var mid := roundf((y0 + y1) * 0.5)
	var hh := maxf(1.0, roundf((y1 - y0) * 0.5 * ok))
	s.draw_rect(Rect2(x0 + 6.0, mid - hh + 5.0, x1 - x0, hh * 2.0), shadow)
	s.draw_rect(Rect2(x0, mid - hh, x1 - x0, hh * 2.0), col)
	if ok > 0.9:
		s.draw_rect(Rect2(x0 + 2.0, y0 + 2.0, x1 - x0 - 4.0, y1 - y0 - 4.0), Color(INK, 0.47), false, 1.0)
	if ok > 0.6:
		# the word lands with a horizontal stretch, then holds still
		var sk := clampf((_t - BARS) / 0.08, 0.0, 1.0)
		var sx := lerpf(2.2, 1.0, sk * sk)
		var cap := roundf(_fs * 0.72)
		var ww := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs).x
		s.draw_set_transform(Vector2(roundf(size.x * 0.5) + 1.0, mid + 1.0) + back, 0.0, Vector2(sx, 1.0))
		s.draw_string(_font, Vector2(-roundf(ww * 0.5), roundf(cap * 0.5)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs, ink)
		s.draw_set_transform(back)
	var jf := Ui.font_bold
	if tag != "" and ok > 0.9:
		var tw := jf.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.PIX).x
		s.draw_rect(Rect2(x0, y0 - 14.0, tw + 14.0, 13), INK)
		s.draw_rect(Rect2(x0 + 3.0, y0 - 10.0, 4, 5), Color(1.0, 0.16, 0.22))
		s.draw_string(jf, Vector2(x0 + 10.0, y0 - 4.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.PIX, shadow)
	if sub != "" and ok > 0.9:
		var sw := jf.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.PIX).x
		var sx0 := roundf(size.x * 0.5 - sw * 0.5 - 6.0)
		s.draw_rect(Rect2(sx0 + 4.0, y1 + 4.0, sw + 12.0, 14), INK)
		s.draw_rect(Rect2(sx0, y1, sw + 12.0, 14), sub_col)
		s.draw_string(jf, Vector2(sx0 + 6.0, y1 + 10.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.PIX, INK)
	s.draw_set_transform(Vector2.ZERO)
