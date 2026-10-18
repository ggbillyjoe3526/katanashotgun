class_name Shard
extends Control
## A cyberpunk tech panel: a translucent plate with chamfered (cut) corners,
## a thin neon outline, optional corner brackets, scanlines and a soft offset
## glow. `chamfer` > 0 cuts the top-left and bottom-right corners by that many
## pixels; otherwise `points` (fractions of the size) give the outline.
## `color` mirrors ColorRect so it can stand in for one.

var points := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
var chamfer := 0.0
var color := Color.BLACK:
	set(v):
		color = v
		queue_redraw()
var outline := Color(0, 0, 0, 0):
	set(v):
		outline = v
		queue_redraw()
var outline_w := 1.0
var shadow := Color(0, 0, 0, 0):
	set(v):
		shadow = v
		queue_redraw()
var shadow_off := Vector2(3, 3)
var brackets := Color(0, 0, 0, 0)
var bracket_len := 6.0
var scan := 0.0


static func make(fill: Color, cut := 6.0, glow := Color(0, 0, 0, 0), line := Color(0, 0, 0, 0)) -> Shard:
	var s := Shard.new()
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.color = fill
	s.shadow = glow
	s.outline = line
	s.chamfer = cut
	return s


## Legacy helper: a parallelogram leaning by `k` (fraction of the width).
func set_skew(k: float) -> void:
	chamfer = 0.0
	points = PackedVector2Array([Vector2(k, 0), Vector2(1, 0), Vector2(1.0 - k, 1), Vector2(0, 1)])
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _shape() -> PackedVector2Array:
	var pts := PackedVector2Array()
	if chamfer > 0.0:
		var c := minf(chamfer, minf(size.x, size.y) * 0.45)
		pts = PackedVector2Array([Vector2(c, 0), Vector2(size.x, 0), Vector2(size.x, size.y - c), Vector2(size.x - c, size.y), Vector2(0, size.y), Vector2(0, c)])
	else:
		for p in points:
			pts.append(p * size)
	return pts


func _draw() -> void:
	if size.x < 1.0 or size.y < 1.0:
		return
	var pts := _shape()
	if pts.size() < 3:
		return
	if shadow.a > 0.0:
		var sp := PackedVector2Array()
		for p in pts:
			sp.append(p + shadow_off)
		var sc := shadow
		sc.a *= 0.55
		draw_colored_polygon(sp, sc)
	draw_colored_polygon(pts, color)
	if scan > 0.0:
		var y := 1.0
		while y < size.y - 1.0:
			draw_rect(Rect2(Vector2(1, y), Vector2(size.x - 2, 1)), Color(1, 1, 1, scan))
			y += 3.0
	if outline.a > 0.0:
		var ol := pts.duplicate()
		ol.append(pts[0])
		draw_polyline(ol, outline, outline_w)
	if brackets.a > 0.0:
		var L := bracket_len
		var o := 2.0
		var r := Rect2(Vector2(-o, -o), size + Vector2(o, o) * 2.0)
		draw_rect(Rect2(r.position, Vector2(L, 1)), brackets)
		draw_rect(Rect2(r.position, Vector2(1, L)), brackets)
		draw_rect(Rect2(Vector2(r.end.x - L, r.position.y), Vector2(L, 1)), brackets)
		draw_rect(Rect2(Vector2(r.end.x - 1, r.position.y), Vector2(1, L)), brackets)
		draw_rect(Rect2(Vector2(r.position.x, r.end.y - 1), Vector2(L, 1)), brackets)
		draw_rect(Rect2(Vector2(r.position.x, r.end.y - L), Vector2(1, L)), brackets)
		draw_rect(Rect2(r.end - Vector2(L, 1), Vector2(L, 1)), brackets)
		draw_rect(Rect2(r.end - Vector2(1, L), Vector2(1, L)), brackets)
