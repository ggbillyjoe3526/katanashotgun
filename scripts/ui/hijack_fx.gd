class_name HijackFx
extends Control
## HIJACK's screen-wide pieces (spec §9.8). `takeover()` seizes the signal:
## test-card colour bars over the whole screen with torn rows, then a beat
## of static. `scroll()` runs huge outlined letters across the screen (the
## boss's name), as decoration only: the instance that scrolls sits under
## the HUD, so no word or number is ever covered (spec §9.9).
## Both are flashes, so they follow the flash comfort slider (off at 0).

const BARS_LEN := 0.06
const STATIC_LEN := 0.06
const GIANT_PX := 96

var _bars_t := 99.0
var _seed := 0
var _giant := ""
var _giant_t := 99.0
var _giant_len := 0.0
var _giant_col := Color(1, 0.16, 0.22)
var _giant_w := 0.0
var giant_y := 150.0 # the letters' baseline


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func takeover() -> void:
	if Settings.flash <= 0.0:
		return
	_bars_t = 0.0
	_seed = Game.rng_fx.randi() % 997


## Scrolls `text` in huge outlined letters for `dur` seconds.
func scroll(text: String, dur: float, c: Color) -> void:
	if Settings.flash <= 0.0:
		return
	_giant = text + "   "
	_giant_t = 0.0
	_giant_len = dur
	_giant_col = c
	_giant_w = Ui.font_big.get_string_size(_giant, HORIZONTAL_ALIGNMENT_LEFT, -1, GIANT_PX).x


func stop_scroll() -> void:
	_giant_t = 99.0
	queue_redraw()


func _process(_delta: float) -> void:
	var rd := Game.real_dt
	var on := _bars_t < BARS_LEN + STATIC_LEN or _giant_t < _giant_len
	_bars_t += rd
	_giant_t += rd
	if on:
		queue_redraw()


func _hash(i: int) -> float:
	return absf(fmod(sin((i + _seed) * 12.9898) * 43758.5453, 1.0))


func _draw() -> void:
	if _giant_t < _giant_len and _giant_w > 0.0:
		var a := clampf(_giant_t / 0.2, 0.0, 1.0) * clampf((_giant_len - _giant_t) / 0.3, 0.0, 1.0) * 0.55 * Settings.flash
		var x := -fmod(_giant_t * 70.0, _giant_w)
		while x < size.x:
			draw_string_outline(Ui.font_big, Vector2(roundf(x), giant_y), _giant, HORIZONTAL_ALIGNMENT_LEFT, -1, GIANT_PX, 2, Color(_giant_col, a))
			x += _giant_w
	if _bars_t >= BARS_LEN + STATIC_LEN:
		return
	var fa := Settings.flash
	if _bars_t < BARS_LEN:
		# the test card: seven bars, a strip of their darker mirror, a dark
		# foot; rows shoved sideways like a lost signal
		var cols: Array = HijackBlock.BAR_COLS
		var bw := size.x / cols.size()
		var row := 0
		var y := 0.0
		while y < size.y:
			var o := roundf((_hash(row) - 0.5) * 60.0) if _hash(row + 50) > 0.6 else 0.0
			var rh := 6.0
			for i in cols.size():
				var c: Color = cols[i]
				if y >= size.y * 0.8:
					c = Color(0.04, 0.03, 0.08)
				elif y >= size.y * 0.72:
					c = Color(cols[cols.size() - 1 - i]).darkened(0.5)
				# the bar shoved off one edge comes back in at the other
				var x := roundf(i * bw) + o
				draw_rect(Rect2(x, y, ceilf(bw) + 1.0, rh), Color(c, fa))
				if x < 0.0:
					draw_rect(Rect2(x + size.x, y, ceilf(bw) + 1.0, rh), Color(c, fa))
				elif x + bw > size.x:
					draw_rect(Rect2(x - size.x, y, ceilf(bw) + 1.0, rh), Color(c, fa))
			y += rh
			row += 1
		return
	# static: grey blocks over a red-tinted dark
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.02, 0.04, 0.6 * fa))
	var n := 0
	var by := 0.0
	while by < size.y:
		var bx := 0.0
		while bx < size.x:
			var v := _hash(n + int(_bars_t * 997.0))
			if v > 0.45:
				draw_rect(Rect2(bx, by, 6, 6), Color(v, v, v, 0.5 * fa))
			bx += 6.0
			n += 1
		by += 6.0
