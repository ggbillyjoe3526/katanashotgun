class_name SpeedLines
extends Control
## Data streaks: thin dashed neon lines rushing in from the screen edges
## toward the centre (a cyberpunk take on anime focus lines), redrawn every
## couple of frames. kick() sets how strong they are.

var amount := 0.0
var color := Color(0.3, 0.95, 1.0, 1)
var color2 := Color(1.0, 0.2, 0.7, 1)
var _lines: Array = []
var _t := 0.0
var _hold := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func kick(strength: float, hold := 0.0) -> void:
	amount = maxf(amount, strength)
	_hold = maxf(_hold, hold)
	if Game.palette.has("neon_b"):
		color = Color(Game.palette.neon_b)
		color2 = Color(Game.palette.neon_a)


func _process(_delta: float) -> void:
	var rd := Game.real_dt
	_t -= rd
	if _hold > 0.0:
		_hold -= rd
	else:
		amount = move_toward(amount, 0.0, rd * 3.5)
	if _t <= 0.0:
		_t = 0.033
		_reroll()
	queue_redraw()


func _reroll() -> void:
	_lines.clear()
	var n := int(70 * amount)
	for i in n:
		_lines.append([Game.rng_fx.randf() * TAU, Game.rng_fx.randf_range(0.45, 0.8), Game.rng_fx.randf_range(0.6, 2.2), Game.rng_fx.randf_range(0.35, 1.0), Game.rng_fx.randi() % 4])


func _draw() -> void:
	if amount <= 0.01:
		return
	var c := size * 0.5
	var R := c.length() * 1.05
	for l in _lines:
		var a: float = l[0]
		var dirv := Vector2(cos(a), sin(a))
		var perp := Vector2(-dirv.y, dirv.x)
		var inner: Vector2 = c + dirv * R * l[1]
		var outer: Vector2 = c + dirv * R
		var w: float = l[2] * (0.6 + amount)
		var col: Color = Color.WHITE if l[4] == 0 else (color if l[4] < 3 else color2)
		col.a = amount * l[3] * (0.9 if l[4] == 0 else 0.75)
		# three dashes per streak, thinning toward the centre
		for k in 3:
			var a0 := 0.08 + k * 0.32
			var a1 := a0 + 0.22
			var p0 := inner.lerp(outer, a0)
			var p1 := inner.lerp(outer, a1)
			var w0 := w * a0
			var w1 := w * a1
			draw_colored_polygon(PackedVector2Array([p0 + perp * w0, p1 + perp * w1, p1 - perp * w1, p0 - perp * w0]), col)
