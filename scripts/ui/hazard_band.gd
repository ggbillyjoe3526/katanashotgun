class_name HazardBand
extends Control
## HIJACK's warning (spec §9.8): an emergency band across the whole screen
## in the warning lane, solid red with scrolling hazard stripes above and
## below. The head ("MISSILES INBOUND") is dark on the red and lands with a
## short horizontal stretch; the rest of the sentence sits on a dark chip
## under it in white. It opens from a scan line and collapses back into one.
## Readability (spec §9.9): the words hold level and still once landed;
## only the stripes move, and they stay off the text.

const INK := Color(0.03, 0.024, 0.07)
const RED := Color(1.0, 0.16, 0.22)
const OPEN := 0.07
const OUT := 0.14

var head := ""
var rest := ""
var life := 4.5 # seconds on screen
var bottom := 246.0 # the band's lower stripe ends here
var _t := 99.0
var _font: Font
var _fs := 20


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func play(h: String, r: String, dur: float) -> void:
	head = h
	rest = r
	life = dur
	_font = Ui.face(Ui.font_big, 16)
	_fs = Ui.px(_font, 16)
	if _font.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs).x > size.x - 40.0:
		_font = Ui.face(Ui.font_big, 13)
		_fs = Ui.px(_font, 13)
	_t = 0.0
	visible = true
	queue_redraw()


func showing() -> bool:
	return _t < life


func stop() -> void:
	_t = 99.0
	visible = false


## The band's height without its stripes.
func band_h() -> float:
	return roundf(_fs * 0.72) + 10.0 + (15.0 if rest != "" else 0.0)


func _process(_delta: float) -> void:
	if _t > 50.0:
		return
	_t += Game.real_dt
	if not showing():
		stop()
		return
	queue_redraw()


func _draw() -> void:
	if not showing():
		return
	var ok := minf(Juice.ease_out(_t / OPEN), clampf((life - _t) / OUT, 0.0, 1.0))
	var full := band_h()
	var y1 := bottom - 6.0
	var mid := roundf(y1 - full * 0.5)
	var hh := maxf(1.0, roundf(full * 0.5 * ok))
	var w := size.x
	_stripes(mid - hh - 6.0, -1.0)
	_stripes(mid + hh + 2.0, 1.0)
	draw_rect(Rect2(0, mid - hh, w, hh * 2.0), RED)
	if ok < 0.8:
		return
	var cap := roundf(_fs * 0.72)
	var ty := mid - full * 0.5 + 5.0
	var sk := clampf(_t / 0.12, 0.0, 1.0)
	var sx := lerpf(1.8, 1.0, sk * sk) if _t < 0.12 else 1.0
	var hw := _font.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs).x
	draw_set_transform(Vector2(roundf(w * 0.5), ty + cap), 0.0, Vector2(sx, 1.0))
	draw_string(_font, Vector2(-roundf(hw * 0.5), 0), head, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs, INK)
	draw_set_transform(Vector2.ZERO)
	if rest != "":
		var jf := Ui.font_bold
		var rw := jf.get_string_size(rest, HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.PIX).x
		var cx := roundf((w - rw) * 0.5)
		var cy := ty + cap + 3.0
		draw_rect(Rect2(cx - 6.0, cy, rw + 12.0, 13), INK)
		draw_string(jf, Vector2(cx, cy + 10.0), rest, HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.PIX, Color.WHITE)


## A row of hazard stripes, 4 pixels high, scrolling `dir`ward.
func _stripes(y: float, dir: float) -> void:
	draw_rect(Rect2(0, y, size.x, 4), INK)
	var off := fmod(_t * 50.0 * dir, 8.0)
	var x := -12.0 + off
	while x < size.x + 8.0:
		draw_colored_polygon(PackedVector2Array([Vector2(x, y + 4.0), Vector2(x + 4.0, y + 4.0), Vector2(x + 8.0, y), Vector2(x + 4.0, y)]), RED)
		x += 8.0
