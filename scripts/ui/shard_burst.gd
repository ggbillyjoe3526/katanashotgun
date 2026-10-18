class_name ShardBurst
extends Control
## Kills burst into neon pixel fragments, with a target-lock ring and four
## ticks snapping shut at the centre. Drawn on the HUD, in screen space.

var _bits: Array = []
var _rings: Array = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func burst(p: Vector2, accent: Color, n := 7, speed := 160.0, big := false, accent2 := Color(0.3, 0.95, 1.0)) -> void:
	for i in n * 2:
		var a := randf() * TAU
		var col: Color = [Color.WHITE, accent, accent2][i % 3]
		_bits.append({"p": p, "v": Vector2(cos(a), sin(a)) * speed * randf_range(0.4, 1.0), "s": float(randi_range(1, 3 if not big else 5)), "c": col, "t": 0.0, "life": randf_range(0.2, 0.45)})
	_rings.append({"p": p, "t": 0.0, "life": 0.14 if not big else 0.24, "r": 10.0 if not big else 28.0, "c": accent2 if not big else accent})
	while _bits.size() > 400:
		_bits.pop_front()


func _process(_delta: float) -> void:
	var rd := Game.real_dt
	var i := 0
	while i < _bits.size():
		var s: Dictionary = _bits[i]
		s.t += rd
		if s.t >= s.life:
			_bits.remove_at(i)
			continue
		s.p += s.v * rd
		s.v *= exp(-rd * 5.0)
		i += 1
	i = 0
	while i < _rings.size():
		_rings[i].t += rd
		if _rings[i].t >= _rings[i].life:
			_rings.remove_at(i)
			continue
		i += 1
	queue_redraw()


func _draw() -> void:
	for rg in _rings:
		var k: float = rg.t / rg.life
		var c: Color = rg.c
		c.a = 1.0 - k
		var r: float = rg.r * (0.6 + k * 0.8)
		draw_arc(rg.p, r, 0.0, TAU, 6, c, 1.5)
		var tick: float = r * (1.4 - k * 0.5)
		for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			draw_line(rg.p + d * tick, rg.p + d * (tick + 4.0), Color(1, 1, 1, c.a), 1.0)
	for s in _bits:
		var k: float = s.t / s.life
		var c: Color = s.c
		c.a = 1.0 - k * k
		if fmod(s.t * 30.0, 1.0) < 0.2:
			c.a *= 0.3
		draw_rect(Rect2(s.p.round(), Vector2(s.s, s.s)), c)
