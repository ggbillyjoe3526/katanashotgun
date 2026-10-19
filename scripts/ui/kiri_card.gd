class_name KiriCard
extends Control
## KIRI, "the cut" (spec §9.8): the top-lane card for combos, glory kills,
## KAMAE BROKEN and ONIKIRI. A blade slash crosses the lane first, the plate
## is drawn along it leaning forward with a solid colour echo behind it, and
## the word slams on big and tilted and lands level. On the way out the
## plate is sliced along its middle and the two halves slide apart.
## Readability (spec §9.9): shapes lean, words don't. The word only scales
## and tilts during the slam; while held it is level and still on a dark
## plate, for at least its read time. Drawn in code, on real time.

const SKEW := 10.0 # how far the plate's top edge leans right
const INK := Color(0.03, 0.024, 0.07)
const SLAM := 0.08
const OUT := 0.16
const SUB_IN := 0.06 # a points line that joins later opens this fast

var text := ""
var col := Color.WHITE
var accent := Color(1, 0.2, 0.7)
var tag := ""
var tag_col := Color(1, 0.2, 0.7)
var sub := ""
var sub_col := Color.WHITE
var size_px := 20 # design size of the word (Ui.font_big)
var rot0 := -0.21 # the slam's starting tilt, radians
var top := 30.0 # the lane's top edge
var _t := 99.0
var _hold := 1.0
var _sub_t := 99.0 # time since the points line joined
var _halves: Array[Control] = []
var _font: Font
var _fs := 25


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# the card paints into two clipped halves so the exit can slice it
	for i in 2:
		var h := Control.new()
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.clip_contents = true
		h.draw.connect(_paint.bind(h, i))
		add_child(h)
		_halves.append(h)


## Starts a card. Options: tag, tag_col, sub, sub_col, size, rot, hold.
func play(word: String, c: Color, acc: Color, o := {}) -> void:
	text = word
	col = c
	accent = acc
	tag = str(o.get("tag", ""))
	tag_col = o.get("tag_col", acc)
	sub = str(o.get("sub", ""))
	sub_col = o.get("sub_col", Color.WHITE)
	size_px = int(o.get("size", 20))
	rot0 = float(o.get("rot", -0.21))
	_font = Ui.face(Ui.font_big, size_px)
	_fs = Ui.px(_font, size_px)
	_hold = maxf(float(o.get("hold", 0.0)), Juice.read_time(word) + 0.15)
	_sub_t = 0.0 if sub != "" else 99.0
	_t = 0.0
	visible = true
	_redraw()


## A points line joins a card that is already up ("+380" under GLORY KILL);
## the card holds long enough to read it.
func set_sub(s: String, c: Color) -> void:
	if not showing():
		return
	sub = s
	sub_col = c
	_sub_t = 0.0
	_hold = maxf(_hold, _t - SLAM + Juice.read_time(s) + 0.2)
	_t = minf(_t, SLAM + _hold) # an exit already under way comes back


func showing() -> bool:
	return _t < SLAM + _hold + OUT


func live_text() -> String:
	return text if showing() else ""


## Ends the card at once (a newer message takes the lane).
func stop() -> void:
	_t = 99.0
	visible = false


## The plate's rectangle (before the lean), for sparks and the cut.
func plate_rect() -> Rect2:
	var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs).x if _font else 0.0
	var cap := roundf(_fs * 0.72)
	var x0 := roundf(size.x * 0.5 - tw * 0.5 - 16.0)
	var h := cap + 12.0 + 13.0 * _sub_k()
	return Rect2(x0, top, roundf(tw) + 32.0, roundf(h))


func _sub_k() -> float:
	return Juice.ease_out(_sub_t / SUB_IN) if sub != "" else 0.0


func _redraw() -> void:
	queue_redraw()
	for h in _halves:
		h.queue_redraw()


func _process(_delta: float) -> void:
	if _t > 50.0:
		return
	var rd := Game.real_dt
	_t += rd
	_sub_t += rd
	if not showing():
		_t = 99.0
		visible = false
		return
	var r := plate_rect()
	var mid := roundf(r.get_center().y)
	var o := 0.0
	var a := 1.0
	var ot := _t - SLAM - _hold
	if ot > 0.0:
		var k := clampf(ot / OUT, 0.0, 1.0)
		o = roundf(k * k * 46.0)
		a = 1.0 - k
	_halves[0].position = Vector2(o, 0)
	_halves[0].size = Vector2(size.x, mid)
	_halves[1].position = Vector2(-o, mid)
	_halves[1].size = Vector2(size.x, maxf(1.0, size.y - mid))
	for h in _halves:
		h.modulate.a = a
	_redraw()


## The lead slash: from below left to above right of the plate, the head
## racing ahead of a trailing tail.
func _draw() -> void:
	if not showing() or _t >= 0.12:
		return
	var r := plate_rect()
	var p0 := Vector2(r.position.x - 70.0, r.end.y + 16.0)
	var p1 := Vector2(r.end.x + 70.0, r.position.y - 16.0)
	var alpha := 1.0 if _t < 0.08 else 0.5
	slash(self, p0, p1, _t / 0.06, accent, 3.0, alpha)


## Draws a blade slash on `ci` up to fraction `k`, its tail trailing.
static func slash(ci: CanvasItem, p0: Vector2, p1: Vector2, k: float, c: Color, w: float, alpha := 1.0) -> void:
	var head := p0.lerp(p1, clampf(k, 0.0, 1.0))
	var tail := p0.lerp(p1, clampf(k - 0.45, 0.0, 1.0))
	if head.distance_to(tail) < 1.0:
		return
	ci.draw_line(tail, head, Color(c, alpha), w + 2.0)
	ci.draw_line(tail, head, Color(1, 1, 1, alpha), maxf(1.0, w - 1.0))


## Paints the card into one half (clipped to it).
func _paint(h: Control, _i: int) -> void:
	if not showing():
		return
	# each half moves with its content: undo only its vertical place
	var back := Vector2(0, -h.position.y)
	h.draw_set_transform(back)
	var r := plate_rect()
	var x0 := r.position.x
	var x1 := r.end.x
	var y0 := r.position.y
	var y1 := r.end.y
	var wipe := Juice.ease_out(_t / 0.07)
	var xr := roundf(lerpf(x0, x1, wipe))
	if xr > x0 + 2.0:
		var eo := 9.0 if _t < SLAM else 5.0
		h.draw_colored_polygon(_lean(x0 + eo, y0 + eo - 1.0, xr + eo, y1 + eo - 1.0, SKEW), accent)
		h.draw_colored_polygon(_lean(x0, y0, xr, y1, SKEW), Color(INK, 0.94))
		# neon edges: the top in the accent, the bottom in the word's colour,
		# and a blade tip on the left
		h.draw_rect(Rect2(x0 + SKEW, y0, xr - x0, 2), accent)
		h.draw_rect(Rect2(x0, y1 - 1.0, xr - x0, 1), col)
		h.draw_colored_polygon(PackedVector2Array([Vector2(x0 - 9.0, y1), Vector2(x0 + SKEW - 1.0, y0), Vector2(x0 + SKEW + 5.0, y0), Vector2(x0 - 3.0, y1)]), col)
	var jf := Ui.font_bold
	if tag != "" and wipe > 0.6:
		var tw := jf.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.PIX).x
		h.draw_colored_polygon(_lean(x0 + 6.0, y0 - 12.0, x0 + 14.0 + tw, y0 - 1.0, 4.0), tag_col)
		h.draw_string(jf, Vector2(x0 + 9.0, y0 - 3.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.PIX, INK)
	# the word: slams in big and tilted, lands level, a short squash, then still
	var cap := roundf(_fs * 0.72)
	var c := Vector2(roundf(size.x * 0.5) + 3.0, y0 + 6.0 + roundf(cap * 0.5) + 2.0)
	var sc := 1.0
	var rot := 0.0
	if _t < SLAM:
		var k := _t / SLAM
		sc = lerpf(2.6, 1.0, k * k)
		rot = lerpf(rot0, 0.0, k * k)
	else:
		var sq := (_t - SLAM) / 0.12
		if sq < 1.0:
			sc = 1.0 + 0.12 * (1.0 - Juice.ease_out(sq))
	var ww := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs).x
	var base := Vector2(-roundf(ww * 0.5), roundf(cap * 0.5))
	h.draw_set_transform(c + back, rot, Vector2(sc, sc))
	h.draw_string_outline(_font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs, 3, INK)
	h.draw_string(_font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs, col)
	h.draw_set_transform(back)
	if sub != "" and _sub_k() > 0.9:
		var sw := jf.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.PIX).x
		var sp := Vector2(roundf(size.x * 0.5 - sw * 0.5) + 2.0, y1 - 4.0)
		h.draw_string_outline(jf, sp, sub, HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.PIX, 2, INK)
		h.draw_string(jf, sp, sub, HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.PIX, sub_col)
	h.draw_set_transform(Vector2.ZERO)


## A parallelogram: the top edge shifted right by `skew`, the bottom flat.
static func _lean(x0: float, y0: float, x1: float, y1: float, skew: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0 + skew, y0), Vector2(x1 + skew, y0), Vector2(x1, y1), Vector2(x0, y1)])
