class_name CutIn
extends Control
## Cyberpunk cut-in: a holographic comm-feed window snaps in from the side.
## Inside, a scanlined neon wireframe of the protagonist's visored mask with a
## scan bar sweeping over it; beside it, a data tag and big glitch text.
## Everything is drawn in code (no art assets).

const LEN := 0.66

var accent := Color(1, 0.15, 0.6)
var visor := Color(0.3, 0.95, 1.0)
var _t := 99.0
var _text: GlitchText
var _flip := false
var _code := ""


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func play(text: String, acc: Color, vis: Color, flip := false) -> void:
	accent = acc
	visor = vis
	_flip = flip
	_t = 0.0
	_code = "LINK//KAGE-07  %04X:%04X" % [randi() & 0xFFFF, randi() & 0xFFFF]
	if _text:
		_text.queue_free()
	_text = GlitchText.new().setup(text, 26, Color.WHITE, acc, 3, {"accent2": vis, "decode": 0.18, "tag": "> SYS.EVENT"})
	add_child(_text)
	Sfx.play("cutin", -2.0, 1.0, 0.0)
	queue_redraw()


func active() -> bool:
	return _t < LEN


func _process(_delta: float) -> void:
	if _t >= LEN:
		if _text:
			_text.visible = false
		return
	_t += Game.real_dt
	queue_redraw()


## Window offset: snap in, hold with a slight drift, snap out.
func _slide() -> float:
	var t := _t
	var w := size.x
	if t < 0.08:
		var k := t / 0.08
		return lerpf(-w, 0.0, 1.0 - pow(1.0 - k, 3.0))
	if t < LEN - 0.09:
		return (t - 0.08) * 18.0
	var k2 := (t - (LEN - 0.09)) / 0.09
	return lerpf((LEN - 0.17) * 18.0, w * 1.1, k2 * k2)


func _draw() -> void:
	if _t >= LEN:
		return
	var w := size.x
	var h := 70.0
	var y0 := roundf(size.y * 0.3 - h * 0.5)
	var x0 := _slide() * (-1.0 if _flip else 1.0)
	var glitch := _t < 0.12 or fmod(_t, 0.23) < 0.03
	# the window: a full-width strip with chamfered ends
	var r := Rect2(Vector2(-20 + x0, y0), Vector2(w + 40, h))
	if glitch:
		_strip(r.position + Vector2(-4, 1), r.size, Color(visor.r, visor.g, visor.b, 0.25), false)
		_strip(r.position + Vector2(4, -1), r.size, Color(accent.r, accent.g, accent.b, 0.25), false)
	_strip(r.position, r.size, Color(0.02, 0.01, 0.06, 0.88), true)
	# hex grid backdrop
	var hc := Color(visor.r, visor.g, visor.b, 0.1)
	var yy := y0 + 4.0
	var row := 0
	while yy < y0 + h - 2:
		var xx := r.position.x + (7.0 if row % 2 else 0.0)
		while xx < r.end.x:
			draw_arc(Vector2(xx, yy), 4.0, 0.0, TAU, 6, hc, 1.0)
			xx += 14.0
		yy += 7.0
		row += 1
	# portrait box (codec style) with the mask as a neon wireframe hologram
	var bw := 78.0
	var bh := h - 12.0
	var bx := r.position.x + 26.0 if not _flip else r.end.x - 26.0 - bw
	var box := Rect2(Vector2(bx, y0 + 6), Vector2(bw, bh))
	draw_rect(box, Color(0.0, 0.03, 0.06, 0.95))
	_clip = PackedVector2Array([box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)])
	var c := box.get_center() + Vector2(0, 6)
	var s := 0.42
	var wire := Color(visor.r, visor.g, visor.b, 0.9)
	_poly(c, s, [Vector2(-110, -80), Vector2(80, -84), Vector2(118, -14), Vector2(98, 46), Vector2(36, 90), Vector2(-70, 90), Vector2(-118, 24)], Color(0.03, 0.05, 0.1, 0.95), wire, 1.0)
	_poly(c, s, [Vector2(-96, 12), Vector2(-30, 18), Vector2(-40, 60), Vector2(-86, 50)], Color(0, 0, 0, 0), Color(wire.r, wire.g, wire.b, 0.55), 1.0)
	_poly(c, s, [Vector2(30, 14), Vector2(96, 6), Vector2(84, 46), Vector2(40, 58)], Color(0, 0, 0, 0), Color(wire.r, wire.g, wire.b, 0.55), 1.0)
	_poly(c, s, [Vector2(-104, -26), Vector2(110, -36), Vector2(114, -10), Vector2(-100, 0)], Color(accent.r, accent.g, accent.b, 0.6), Color(accent.r, accent.g, accent.b, 1.0), 1.0)
	_poly(c, s, [Vector2(-70, -12), Vector2(-26, -22), Vector2(-14, -12), Vector2(-58, -6)], Color(1, 1, 1), Color(0, 0, 0, 0), 1.0)
	_poly(c, s, [Vector2(18, -24), Vector2(66, -30), Vector2(76, -18), Vector2(24, -14)], Color(1, 1, 1), Color(0, 0, 0, 0), 1.0)
	var sb2 := box.position.y + fmod(_t * 140.0, box.size.y)
	draw_rect(Rect2(Vector2(box.position.x, sb2), Vector2(box.size.x, 2)), Color(visor.r, visor.g, visor.b, 0.45))
	var bl := 7.0
	for corner in [box.position, Vector2(box.end.x - bl, box.position.y), Vector2(box.position.x, box.end.y - 1), Vector2(box.end.x - bl, box.end.y - 1)]:
		draw_rect(Rect2(corner, Vector2(bl, 1)), Color.WHITE)
	_clip = PackedVector2Array()
	# scanlines + a scan bar sweeping down the feed
	var sl := y0 + 1.0
	while sl < y0 + h:
		draw_rect(Rect2(Vector2(r.position.x, sl), Vector2(r.size.x, 1)), Color(0, 0, 0, 0.28))
		sl += 2.0
	var sb := y0 + fmod(_t * 160.0, h)
	draw_rect(Rect2(Vector2(r.position.x, sb), Vector2(r.size.x, 2)), Color(visor.r, visor.g, visor.b, 0.35))
	# data readout
	var mf := Ui.font_mono
	var dx := bx + bw + 8.0 if not _flip else r.position.x + 30.0
	draw_string(mf, Vector2(dx, y0 + 14), _code, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(visor.r, visor.g, visor.b, 0.85))
	draw_string(mf, Vector2(dx, y0 + h - 5), "SYNC %d%%  //  NEURAL LINK STABLE" % (60 + int(_t * 60.0) % 40), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(accent.r, accent.g, accent.b, 0.8))
	# glitch text beside the mask
	if _text:
		_text.visible = true
		var tx := (bx + bw + 10.0) if not _flip else (bx - 12.0 - _text.size.x)
		_text.position = Vector2(tx, y0 + h * 0.5 - _text.size.y * 0.5 + 2).round()


func _strip(p: Vector2, sz: Vector2, fill: Color, edges: bool) -> void:
	var c := 10.0
	var pts := PackedVector2Array([p + Vector2(c, 0), p + Vector2(sz.x, 0), p + Vector2(sz.x, sz.y - c), p + Vector2(sz.x - c, sz.y), p + Vector2(0, sz.y), p + Vector2(0, c)])
	draw_colored_polygon(pts, fill)
	if edges:
		draw_rect(Rect2(p + Vector2(c, 0), Vector2(sz.x - c, 1)), visor)
		draw_rect(Rect2(p + Vector2(0, sz.y - 1), Vector2(sz.x - c, 1)), accent)
		# hazard ticks along the bottom edge
		var x := p.x + 20.0
		while x < p.x + sz.x - 20.0:
			draw_rect(Rect2(Vector2(x, p.y + sz.y + 2), Vector2(6, 2)), Color(accent.r, accent.g, accent.b, 0.8))
			x += 12.0


var _clip := PackedVector2Array()


func _poly(c: Vector2, s: float, pts: Array, fill: Color, line: Color, lw: float) -> void:
	var pp := PackedVector2Array()
	for p in pts:
		pp.append(c + Vector2(p.x if not _flip else -p.x, p.y) * s)
	var parts: Array = [pp]
	if _clip.size() >= 3:
		parts = Geometry2D.intersect_polygons(pp, _clip)
	for part in parts:
		if part.size() < 3:
			continue
		if fill.a > 0.0:
			draw_colored_polygon(part, fill)
		if line.a > 0.0:
			var ol: PackedVector2Array = part.duplicate()
			ol.append(part[0])
			draw_polyline(ol, line, lw)
