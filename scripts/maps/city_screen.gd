class_name CityScreen
extends Node3D
## One of the city's big screens (The City Is Watching, spec §19.1 #9): three
## lines of clean pixel text on a dark plate. CityWatch decides what it shows;
## the screen only swaps pages with a short squash (glitch on the way in and
## out only, spec §9.9) and refits a line when its text changes. Text is
## rebuilt only when a value changes, never every frame.

const SIZE := Vector2(36.0, 19.0) # metres, the plate behind the text
const MAX_W := 32.0 # widest a line may be; longer lines shrink to fit
const SWAP := 0.08 # seconds to squash out, then the same back in
## [y on the plate, font size (whole multiples of Jersey 10's 19 px), metres per pixel]
const LINES := [[6.4, 38, 0.13], [0.5, 76, 0.115], [-5.9, 57, 0.115]]

var lines: Array[Label3D] = []
var _next: PackedStringArray = []
var _swap_t := -1.0 # < 0: still; else seconds into a page swap


func build(accent: Color, accent2: Color) -> void:
	Ui.init() # the HUD loads the fonts later than the map
	var colors := [accent * 1.5, Color(1.0, 1.0, 1.0) * 1.3, accent2 * 1.5]
	for i in LINES.size():
		var spec: Array = LINES[i]
		var l := Label3D.new()
		l.font = Ui.font_mono
		l.font_size = spec[1]
		l.pixel_size = spec[2]
		l.outline_size = 0
		l.shaded = false
		l.double_sided = false
		l.alpha_cut = Label3D.ALPHA_CUT_DISCARD # a pixel face needs no blending
		l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		l.modulate = colors[i]
		l.position = Vector3(0, spec[0], 0.15)
		add_child(l)
		lines.append(l)


## Shows `texts` (one per line). With `swap`, the old page squashes out and
## the new one opens; otherwise the lines change in place (a number ticking).
func show_page(texts: PackedStringArray, swap: bool) -> void:
	if swap and is_visible_in_tree():
		_next = texts
		if _swap_t < 0.0 or _swap_t > SWAP:
			_swap_t = 0.0
		return
	if _swap_t >= 0.0 and _swap_t < SWAP:
		_next = texts # mid squash-out: the new page lands when it reopens
		return
	_apply(texts)


func _apply(texts: PackedStringArray) -> void:
	for i in mini(texts.size(), lines.size()):
		var l := lines[i]
		if l.text == texts[i]:
			continue
		l.text = texts[i]
		var w := l.font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.font_size).x * l.pixel_size
		var k := minf(1.0, MAX_W / maxf(w, 0.001))
		l.scale = Vector3(k, k, 1.0)


func tick(real_dt: float) -> void:
	if _swap_t < 0.0:
		return
	_swap_t += real_dt
	if _swap_t >= SWAP and not _next.is_empty():
		_apply(_next)
		_next = PackedStringArray()
	if _swap_t >= SWAP * 2.0:
		_swap_t = -1.0
		scale.y = 1.0
		return
	# a CRT-style squash to a line and back, 0.16 s in all
	var f := _swap_t / SWAP
	scale.y = maxf(0.04, absf(1.0 - f))
