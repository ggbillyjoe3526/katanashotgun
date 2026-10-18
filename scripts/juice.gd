class_name Juice
extends Control
## Presentation-only game feel ("juice"). Text stamps that slam onto the
## screen, HUD shake, pixel fireworks, the wave-intro countdown, the
## end-of-wave tally (chips x mult, in the spirit of Balatro) and the slow,
## solemn "boss felled" / "flatlined" cards (in the spirit of FromSoftware).
## The visual language on top is cyberpunk, with the energy of an anime
## action show: tech panels with brackets and scanlines, glitch text that
## decodes itself, holographic cut-ins, data streaks, impact frames and a
## "system breach" FINISH splash.
## It never decides anything: the director hands it the numbers and it shows
## them off. Everything runs on real time (Game.real_dt), so slow-mo and
## hitstop never stretch an animation.

const CHIPS_COL := Color(0.15, 0.7, 1.0)
const MULT_COL := Color(1.0, 0.18, 0.32)
const GOLD := Color(1.0, 0.85, 0.25)
const MAX_SPARKS := 1400
const MAX_ROWS := 7
# tally layout (UI pixels): narrow enough to clear the HUD corner panels
const TALLY_W := 260.0
const ROW_Y0 := 40.0
const ROW_H := 15.0
const BOX_H := 26.0

var hud: Hud
var vs := Vector2(480, 270)
var shake := 0.0

var _t := 0.0
var _events: Array = [] # [{t, f}]
var _stamps: Array = []
var _sparks: Array = []
var _spark_layer: SparkLayer

# wave intro
var _intro_on := false
var _intro_t := 0.0
var _intro_ready := true
var _band: Shard
var _intro_title: GlitchText
var _intro_lines: Array[Label] = []
var _intro_out := false
var _typed := 0

# tally
var _tally_on := false
var _tally_ready := true
var _tt := 0.0
var _td: Dictionary = {}
var _panel: Control
var _panel_bg: Shard
var _panel_edges: Array[ColorRect] = []
var _tally_title: GlitchText
var _rows: Array = [] # [{name, detail, value}]
var _chips_box: Shard
var _chips_lbl: Label
var _x_lbl: Label
var _mult_box: Shard
var _mult_lbl: Label
var _note_lbl: Label
var _total_lbl: Label
var _mult_punch := 0.0
var _mult_shown := 1.0
var _note_t := 99.0
var _panel_size := Vector2(280, 160)
var _times := {}

# souls-style card
const CARD_SIZES := [24, 20, 18, 16]
var _card: Control
var _card_band: TextureRect
var _card_glow: TextureRect
var _card_lbl: Label
var _card_ghosts: Array[Label] = []
var _card_sub: Label
var _card_on := false
var _card_ready := true
var _card_t := 0.0
var _card_len := 4.6
var _card_text := ""
var _card_w := 0.0
var _card_px := 24

# persona layer
var _lines: SpeedLines
var _shards: ShardBurst
var _cutin: CutIn
var _bars_top: Shard
var _bars_bot: Shard
var _bars_t := 99.0
var _bars_len := 0.85
var _fin: FinishBG
var _fin_t := 99.0


## The FINISH backdrop, cyberpunk style: a "system breach" overlay. Red tint,
## a hex grid, scrolling warning chevrons top and bottom, columns of hex data
## and screen-tear slices. The middle band, where FINISH lands, is a dark
## plate with nothing busy behind the words (spec §9.9).
class FinishBG:
	extends Control
	var t := 0.0
	var accent := Color(1, 0.1, 0.3)
	var accent2 := Color(0.3, 0.95, 1.0)
	var band := Rect2() # the text plate, in this control's pixels
	var _data: Array = []
	var _data_t := 0.0
	var _rng := RandomNumberGenerator.new() # presentation only

	func _draw() -> void:
		var a := clampf(1.0 - maxf(0.0, t - 0.8) / 0.12, 0.0, 1.0)
		draw_rect(Rect2(Vector2.ZERO, size), Color(accent.r * 0.35, accent.g * 0.05, accent.b * 0.2, 0.78 * a))
		# hex grid
		var hc := Color(accent.r, accent.g, accent.b, 0.22 * a)
		var y := 0.0
		var row := 0
		while y < size.y + 10:
			var x := 9.0 if row % 2 else 0.0
			while x < size.x + 10:
				draw_arc(Vector2(x, y), 6.0, 0.0, TAU, 6, hc, 1.0)
				x += 18.0
			y += 9.0
			row += 1
		# warning chevrons, scrolling
		for band_y in [8.0, size.y - 24.0]:
			draw_rect(Rect2(Vector2(0, band_y), Vector2(size.x, 16)), Color(0.02, 0, 0.03, 0.9 * a))
			var off := fmod(t * 160.0, 24.0)
			var cx := -24.0 + off
			while cx < size.x + 24:
				draw_colored_polygon(PackedVector2Array([Vector2(cx, band_y + 2), Vector2(cx + 8, band_y + 2), Vector2(cx + 14, band_y + 8), Vector2(cx + 8, band_y + 14), Vector2(cx, band_y + 14), Vector2(cx + 6, band_y + 8)]), Color(accent.r, accent.g, accent.b, 0.9 * a))
				cx += 24.0
		# hex data columns at the edges (decoration only), refreshed at a
		# steady rate rather than every frame
		if _data.is_empty() or t >= _data_t:
			_data_t = t + 0.08
			_data.clear()
			for i in 18:
				_data.append("%04X %04X" % [_rng.randi() & 0xFFFF, _rng.randi() & 0xFFFF])
		var mf := Ui.font_mono
		for i in _data.size():
			var yy := 40.0 + i * 10.0
			if yy > size.y - 30:
				break
			draw_string(mf, Vector2(8, yy), _data[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(accent2.r, accent2.g, accent2.b, 0.45 * a))
			draw_string(mf, Vector2(size.x - 64, yy), _data[(i + 7) % _data.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(accent.r, accent.g, accent.b, 0.55 * a))
		# tear slices, kept off the text plate
		for k in 4:
			var ty := _rng.randf() * size.y
			if ty > band.position.y - 6.0 and ty < band.end.y + 1.0:
				continue
			draw_rect(Rect2(Vector2(_rng.randf_range(-30, 30), ty), Vector2(size.x, _rng.randf_range(1, 5))), Color(accent2.r, accent2.g, accent2.b, 0.35 * a) if k % 2 else Color(1, 1, 1, 0.25 * a))
		# the text plate: solid dark, neon edges, no pattern
		if band.size.y > 0.0:
			draw_rect(band, Color(0.03, 0.0, 0.03, 0.92 * a))
			draw_rect(Rect2(band.position, Vector2(band.size.x, 1)), Color(accent.r, accent.g, accent.b, a))
			draw_rect(Rect2(Vector2(band.position.x, band.end.y - 1), Vector2(band.size.x, 1)), Color(accent2.r, accent2.g, accent2.b, a))
			var sub := "TARGET SIGNAL LOST"
			var bf := Ui.font_bold
			var bs := 13
			var sw := bf.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, bs).x
			var sp := Vector2(roundf((size.x - sw) * 0.5), band.end.y - 6.0)
			draw_string_outline(bf, sp, sub, HORIZONTAL_ALIGNMENT_LEFT, -1, bs, 2, Color(0, 0, 0, a))
			draw_string(bf, sp, sub, HORIZONTAL_ALIGNMENT_LEFT, -1, bs, Color(1, 1, 1, 0.95 * a))


class SparkLayer:
	extends Control
	var sparks: Array = []

	func _draw() -> void:
		for s in sparks:
			var a := clampf(1.0 - s.t / s.life, 0.0, 1.0)
			if s.tw and fmod(s.t * 23.0 + s.ph, 1.0) < 0.35:
				a *= 0.25
			var c: Color = s.c
			c.a = a
			draw_rect(Rect2(s.p.round(), Vector2(s.s, s.s)), c)


func _full(c: Control) -> Control:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_lines = _full(SpeedLines.new())
	var pal := Game.palette
	# cinematic bars for glory kills: black, a neon edge and a scan texture
	_bars_top = Shard.make(Color(0.01, 0, 0.03, 0.96), 0.0, Color(0, 0, 0, 0), Color(pal.neon_b))
	_bars_top.scan = 0.04
	_bars_bot = Shard.make(Color(0.01, 0, 0.03, 0.96), 0.0, Color(0, 0, 0, 0), Color(pal.neon_a))
	_bars_bot.scan = 0.04
	_bars_top.visible = false
	_bars_bot.visible = false
	# the bars go under the HUD clusters, so the HUD stays readable on black
	# instead of being half covered
	hud.play_root.add_child(_bars_top)
	hud.play_root.move_child(_bars_top, 1)
	hud.play_root.add_child(_bars_bot)
	hud.play_root.move_child(_bars_bot, 2)
	_build_intro()
	_build_tally()
	_build_card()
	_fin = _full(FinishBG.new())
	_fin.visible = false
	_cutin = _full(CutIn.new())
	_shards = _full(ShardBurst.new())
	_spark_layer = SparkLayer.new()
	_spark_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spark_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_spark_layer.sparks = _sparks
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_spark_layer.material = m
	add_child(_spark_layer)


# ---------------------------------------------------------------- helpers
static func ease_out_back(x: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)


static func ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 3.0)


## Runs `f` after `delay` seconds of real time.
func later(delay: float, f: Callable) -> void:
	_events.append({"t": delay, "f": f})


func add_shake(amount: float) -> void:
	shake = minf(12.0, shake + amount)


func shake_offset() -> Vector2:
	if shake < 0.25:
		return Vector2.ZERO
	return Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * shake * randf_range(0.5, 1.0)


func _pair(text: String, f: Font, size: int, color: Color, shadow: Color, off := Vector2(2, 2)) -> Label:
	var sh := Ui.label(text, f, size, shadow)
	var l := Ui.label(text, f, size, color, 2 if size <= 16 else 3)
	sh.position = off
	sh.name = "Shadow"
	l.add_child(sh)
	sh.show_behind_parent = true
	return l


func _set_text(l: Label, text: String) -> void:
	l.text = text
	if l.has_node("Shadow"):
		var sh: Label = l.get_node("Shadow")
		sh.text = text
		sh.size = Vector2.ZERO
	l.size = Vector2.ZERO


# ---------------------------------------------------------------- stamps
## Slams `text` onto the screen. Options (all optional):
## anchor (fraction of the screen), off (pixels), from (start scale),
## slam (fly-in time), hold, fade, rot (radians), shake, sound, vol, pitch,
## burst (spark count on impact), shadow (colour), font, slot.
## One message per screen region (spec §9.9): a stamp replaces any stamp in
## the same `slot` ("center" by default), and a centre stamp replaces the
## cut-in. The hold is never shorter than the time it takes to read the text.
func stamp(text: String, color: Color, size := 24, o := {}) -> void:
	var slot: String = o.get("slot", "center")
	_clear_slot(slot)
	if slot == "center":
		_cutin.stop()
	var l: Control
	if o.get("glitch", false):
		l = GlitchText.new().setup(text, size, color, o.get("accent", Color(Game.palette.neon_a)), int(o.get("seed", 0)), {"accent2": o.get("accent2", Color(Game.palette.neon_b)), "brackets": o.get("brackets", false), "tag": o.get("tag", ""), "decode": o.get("decode", 0.1)})
	else:
		var f: Font = o.get("font", Ui.font_big)
		var shadow: Color = o.get("shadow", color.darkened(0.7))
		l = _pair(text, f, size, color, shadow, Vector2(1, 1) if size <= 16 else Vector2(2, 2))
	l.modulate.a = 0.0
	add_child(l)
	move_child(l, _spark_layer.get_index())
	_stamps.append({
		"l": l, "t": 0.0, "hit": false, "c": color, "slot": slot,
		"anchor": o.get("anchor", Vector2(0.5, 0.4)), "off": o.get("off", Vector2.ZERO),
		"from": float(o.get("from", 3.0)), "slam": float(o.get("slam", 0.09)),
		"hold": maxf(float(o.get("hold", 0.8)), read_time(text)), "fade": float(o.get("fade", 0.25)),
		"rot": float(o.get("rot", 0.0)), "shake": float(o.get("shake", 4.0)),
		"sound": str(o.get("sound", "stamp")), "vol": float(o.get("vol", -3.0)),
		"pitch": float(o.get("pitch", 1.0)), "burst": int(o.get("burst", 0)),
		"out": false,
	})


## How long a flash must stay still to be read (spec §9.9).
static func read_time(text: String) -> float:
	return 0.5 + 0.05 * text.length()


func _clear_slot(slot: String) -> void:
	var i := 0
	while i < _stamps.size():
		if _stamps[i].slot == slot:
			_stamps[i].l.queue_free()
			_stamps.remove_at(i)
			continue
		i += 1


func _update_stamps(rd: float) -> void:
	var i := 0
	while i < _stamps.size():
		var s: Dictionary = _stamps[i]
		s.t += rd
		var l: Control = s.l
		if s.t >= s.slam + s.hold + s.fade:
			l.queue_free()
			_stamps.remove_at(i)
			continue
		if not s.hit and s.t >= s.slam:
			s.hit = true
			add_shake(s.shake)
			if s.sound != "":
				Sfx.play(s.sound, s.vol, s.pitch, 0.0)
			if s.burst > 0:
				burst(vs * s.anchor + s.off, s.c, s.burst)
		var sc: float
		var rot: float = s.rot
		var a := 1.0
		if not s.hit:
			var k: float = s.t / s.slam
			sc = lerpf(s.from, 1.0, k * k)
			rot = s.rot * (1.0 + 2.0 * (1.0 - k))
			a = k
		else:
			# a short squash that settles fast, then the text holds still
			var u: float = s.t - s.slam
			sc = 1.0 - 0.08 * sin(u * 30.0) * exp(-u * 14.0)
			rot += sin(u * 26.0) * exp(-u * 14.0) * 0.04
		var ft: float = s.t - s.slam - s.hold
		if ft > 0.0:
			if not s.out:
				s.out = true
				if l is GlitchText:
					l.glitch_out(minf(0.12, s.fade))
			a = 1.0 - ft / s.fade
			sc *= 1.0 + 0.15 * ft / s.fade
		l.size = Vector2.ZERO
		l.pivot_offset = l.size * 0.5
		l.scale = Vector2.ONE * sc
		l.rotation = rot
		l.position = (vs * s.anchor + s.off - l.size * 0.5).round()
		l.modulate.a = clampf(a, 0.0, 1.0)
		i += 1


# ---------------------------------------------------------------- sparks
func burst(p: Vector2, col: Color, n := 30, speed := 90.0) -> void:
	for i in n:
		var a := randf() * TAU
		var sp := randf_range(0.3, 1.0) * speed
		_add_spark(p, Vector2(cos(a), sin(a)) * sp, col.lerp(Color.WHITE, randf() * 0.5), randf_range(0.35, 0.8), 1 if randf() < 0.7 else 2, 40.0, false)


## A synthwave firework: a white flash, then a ring of twinkling colour.
func firework(p: Vector2, col: Color, n := 46) -> void:
	_add_spark(p - Vector2(3, 3), Vector2.ZERO, Color.WHITE, 0.12, 6, 0.0, false)
	var col2 := Color(col.r, col.g, col.b).lerp(Color.WHITE, 0.35)
	for i in n:
		var a := TAU * float(i) / n + randf() * 0.1
		var sp: float = randf_range(0.8, 1.0) * 95.0 if i % 2 == 0 else randf_range(0.35, 0.7) * 95.0
		_add_spark(p, Vector2(cos(a), sin(a)) * sp, col if i % 3 else col2, randf_range(0.9, 1.5), 2 if i % 4 == 0 else 1, 55.0, true)


## Gold and cyan confetti thrown upward from `p` (the cash-out moment).
func fountain(p: Vector2, n := 70) -> void:
	for i in n:
		var c: Color = [GOLD, CHIPS_COL, MULT_COL, Color.WHITE][i % 4]
		_add_spark(p + Vector2(randf_range(-30, 30), 0), Vector2(randf_range(-70, 70), randf_range(-190, -70)), c, randf_range(0.8, 1.5), 2 if randf() < 0.5 else 1, 260.0, true)


func _add_spark(p: Vector2, v: Vector2, c: Color, life: float, s: int, g: float, tw: bool) -> void:
	if _sparks.size() >= MAX_SPARKS:
		_sparks.pop_front()
	_sparks.append({"p": p, "v": v, "c": c, "life": life, "t": 0.0, "s": s, "g": g, "tw": tw, "ph": randf()})


func _update_sparks(rd: float) -> void:
	var i := 0
	var drag := exp(-rd * 1.8)
	while i < _sparks.size():
		var s: Dictionary = _sparks[i]
		s.t += rd
		if s.t >= s.life:
			_sparks.remove_at(i)
			continue
		s.v *= drag
		s.v.y += s.g * rd
		s.p += s.v * rd
		i += 1
	_spark_layer.queue_redraw()


# ---------------------------------------------------------------- wave intro
func _build_intro() -> void:
	_band = Shard.make(Color(0.02, 0.0, 0.06, 0.88), 10.0, Color(Game.palette.neon_a), Color(Game.palette.neon_b))
	_band.shadow_off = Vector2(0, 3)
	_band.brackets = Color(Game.palette.neon_b)
	_band.visible = false
	add_child(_band)
	_intro_title = GlitchText.new()
	_intro_title.visible = false
	add_child(_intro_title)
	for i in 2:
		var l := Ui.label("", Ui.font_bold, 10, Color.WHITE, 2)
		l.visible = false
		add_child(l)
		_intro_lines.append(l)


func intro_ready() -> bool:
	return _intro_ready


## WAVE N slams in, the mutator types itself out, 3-2-1, then FIGHT.
## Boss waves skip the FIGHT stamp (the boss card takes over).
## `sub` is up to two lines ("NAME  //  SCORE xN" and its description).
func wave_intro(wave: int, sub: String, col: Color, boss: bool) -> void:
	var pal := Game.palette
	_intro_on = true
	_intro_ready = false
	_intro_t = 0.0
	_typed = 0
	var acc := Color(pal.neon_a) if not boss else Color(1.0, 0.1, 0.18)
	_intro_title.setup("WAVE %02d" % wave, 24, Color.WHITE, acc, wave, {"accent2": Color(pal.neon_b), "tag": "> SECTOR SHIN-KAGURA // HOSTILES INBOUND" if not boss else "> WARNING // HIGH-VALUE TARGET"})
	_band.shadow = acc
	var parts := sub.split("\n") if sub != "" else PackedStringArray()
	for i in _intro_lines.size():
		var l: Label = _intro_lines[i]
		l.text = parts[i] if i < parts.size() else ""
		l.visible_characters = 0
		l.visible = l.text != ""
	_intro_lines[0].add_theme_color_override("font_color", Color(pal.neon_c) if not boss else Color(1.0, 0.3, 0.35))
	_intro_lines[1].add_theme_color_override("font_color", Color(0.92, 0.9, 1.0))
	_band.visible = true
	_lines.kick(0.8, 0.15)
	_intro_title.visible = true
	later(0.09, func():
		add_shake(5.0)
		Sfx.play("stamp", -3.0, 1.0, 0.0))
	# the countdown and FIGHT sit below the band, never on top of it
	var count_at := Vector2(0.5, 0.71)
	var pitches := [1.0, 1.12, 1.26]
	for i in 3:
		later(1.2 + i * 0.55, func():
			if not _intro_on or _intro_ready:
				return
			stamp(str(3 - i), Color.WHITE, 32, {"glitch": true, "brackets": true, "accent": Color(pal.neon_a), "seed": i, "anchor": count_at, "from": 2.2, "hold": 0.3, "fade": 0.1, "shake": 2.0, "sound": "count", "vol": -4.0, "pitch": pitches[i], "slot": "intro"}))
	later(2.85, func():
		var cut := _intro_ready # the boss card already ended the intro
		_intro_ready = true
		if not boss and _intro_on and not cut:
			stamp("FIGHT", Color.WHITE, 40, {"glitch": true, "brackets": true, "tag": "> ENGAGE", "accent": Color(pal.neon_a), "anchor": count_at, "from": 3.0, "hold": 0.45, "fade": 0.2, "shake": 8.0, "sound": "go", "vol": -2.0, "burst": 40, "slot": "intro"})
			_lines.kick(1.0, 0.2)
			_shards.burst(vs * count_at, Color(pal.neon_a), 18, 300.0, true)
			if hud.post:
				hud.post.impact_frame(0.05))


## Cuts the wave intro short (the boss card replaces it).
func end_intro() -> void:
	if not _intro_on:
		return
	_intro_t = maxf(_intro_t, 2.85)
	_intro_ready = true
	_clear_slot("intro")


func _update_intro(rd: float) -> void:
	if not _intro_on:
		return
	_intro_t += rd
	var t := _intro_t
	# the band sits below the top HUD clusters and above the crosshair area
	var by := roundf(maxf(58.0, vs.y * 0.215))
	var title_h := _intro_title.size.y
	var lines_h := 0.0
	for l in _intro_lines:
		if l.visible:
			l.size = Vector2.ZERO
			lines_h += l.size.y
	var full_h := roundf(4.0 + title_h + lines_h + (4.0 if lines_h > 0.0 else 2.0))
	var bw := roundf(vs.x * 0.74)
	for l in _intro_lines:
		if l.visible:
			bw = maxf(bw, l.size.x + 28.0)
	bw = minf(bw, vs.x - 8.0)
	var open := ease_out(t / 0.14)
	var bh := roundf(full_h * open)
	_band.position = Vector2(roundf((vs.x - bw) * 0.5), by + roundf((full_h - bh) * 0.5))
	_band.size = Vector2(bw, maxf(bh, 1.0))
	# title: a stamp that stays put
	var sc: float
	if t < 0.09:
		var k := t / 0.09
		sc = lerpf(3.0, 1.0, k * k)
	else:
		var u := t - 0.09
		sc = 1.0 - 0.08 * sin(u * 30.0) * exp(-u * 14.0)
	_intro_title.pivot_offset = _intro_title.size * 0.5
	_intro_title.scale = Vector2.ONE * sc
	_intro_title.position = (Vector2(vs.x * 0.5 - _intro_title.size.x * 0.5, by + 4.0)).round()
	# the mutator types itself out (clean letters, no scramble), line by line
	var n := int(maxf(0.0, t - 0.32) * 55.0)
	var total := 0
	for l in _intro_lines:
		if l.visible:
			total += l.text.length()
	if n > _typed and _typed < total:
		if n / 2 != _typed / 2:
			Sfx.play("type", -15.0, 1.25, 0.08)
		_typed = mini(n, total)
	var y := by + 4.0 + title_h
	var left := n
	for l in _intro_lines:
		if not l.visible:
			continue
		l.visible_characters = clampi(left, 0, l.text.length())
		left -= l.text.length()
		l.position = Vector2(roundf((vs.x - l.size.x) * 0.5), roundf(y))
		y += l.size.y
	var a := 1.0 if t < 2.85 else clampf(1.0 - (t - 2.85) / 0.25, 0.0, 1.0)
	if t >= 2.85 and not _intro_out:
		_intro_out = true
		_intro_title.glitch_out(0.1)
	elif t < 2.85:
		_intro_out = false
	_band.modulate.a = a
	_intro_title.modulate.a = a
	for l in _intro_lines:
		l.modulate.a = a
	if t > 3.1:
		_intro_on = false
		_band.visible = false
		_intro_title.visible = false
		for l in _intro_lines:
			l.visible = false


# ---------------------------------------------------------------- tally
func _build_tally() -> void:
	_panel = Control.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	add_child(_panel)
	# no scanlines: nothing busy behind the numbers (spec §9.9)
	_panel_bg = Shard.make(Color(0.02, 0.0, 0.06, 0.9), 12.0, Color(Game.palette.neon_a), Color(Game.palette.neon_b))
	_panel_bg.shadow_off = Vector2(0, 4)
	_panel_bg.brackets = Color(Game.palette.neon_b)
	_panel_bg.bracket_len = 10.0
	_panel.add_child(_panel_bg)
	for i in 4:
		var e := Ui.rect(Color.WHITE, Vector2.ZERO, Vector2.ONE)
		e.visible = false
		_panel.add_child(e)
		_panel_edges.append(e)
	_tally_title = GlitchText.new()
	_panel.add_child(_tally_title)
	for i in MAX_ROWS:
		var r := {
			"name": Ui.label("", Ui.font_bold, 10, Color(0.92, 0.9, 1.0), 2),
			"detail": Ui.label("", Ui.font_mono, 9, Color(0.66, 0.66, 0.84), 2),
			"value": Ui.label("", Ui.font_mono, 10, CHIPS_COL.lerp(Color.WHITE, 0.5), 2),
		}
		for k in r:
			_panel.add_child(r[k])
		_rows.append(r)
	_chips_box = Shard.make(CHIPS_COL.darkened(0.6), 6.0, CHIPS_COL, CHIPS_COL)
	_chips_box.shadow_off = Vector2(0, 2)
	_panel.add_child(_chips_box)
	_chips_lbl = Ui.label("0", Ui.font_big, 13, Color.WHITE, 3, CHIPS_COL.darkened(0.75))
	_chips_box.add_child(_chips_lbl)
	_x_lbl = Ui.label("X", Ui.font_big, 13, Color.WHITE, 2)
	_panel.add_child(_x_lbl)
	_mult_box = Shard.make(MULT_COL.darkened(0.6), 6.0, MULT_COL, MULT_COL)
	_mult_box.shadow_off = Vector2(0, 2)
	_panel.add_child(_mult_box)
	_mult_lbl = Ui.label("1.0", Ui.font_big, 13, Color.WHITE, 3, MULT_COL.darkened(0.75))
	_mult_box.add_child(_mult_lbl)
	_note_lbl = Ui.label("", Ui.font_bold, 10, MULT_COL.lerp(Color.WHITE, 0.5), 2)
	_panel.add_child(_note_lbl)
	_total_lbl = _pair("", Ui.font_big, 16, GOLD, Color(0.4, 0.1, 0.0))
	_panel.add_child(_total_lbl)


func tally_ready() -> bool:
	return _tally_ready


## The wave intro (its panel, countdown or FIGHT) is on screen.
func intro_showing() -> bool:
	if _intro_on:
		return true
	for s in _stamps:
		if s.slot == "intro":
			return true
	return false


func tally_showing() -> bool:
	return _tally_on


## A big panel (FINISH, the wave payout or the boss-defeated card) has the
## middle of the screen.
func panel_showing() -> bool:
	return _fin.visible or _tally_on or _card_on


## True while a big centre-screen moment is up (a stamp, the cut-in, FINISH,
## the boss-defeated card, the wave intro or tally, the boss name card). The
## level-up screen waits for it so the two never share the screen.
func centre_busy() -> bool:
	for s in _stamps:
		if s.slot in ["center", "intro", "tally"]:
			return true
	return _cutin.active() or _fin.visible or _card_on or _intro_on or _tally_on or hud.boss_title.visible


## d = {title, rows: [[name, detail, value]], chips, mults: [[name, factor]],
##      total, flawless}. The score is already added; the HUD holds it back
## until the cash-out slam.
func show_tally(d: Dictionary) -> void:
	# the payout panel takes over the middle: a combo stamp still up goes
	_clear_slot("center")
	_cutin.stop()
	_td = d
	_tally_on = true
	_tally_ready = false
	_tt = 0.0
	_mult_punch = 0.0
	_note_t = 99.0
	var pal := Game.palette
	_tally_title.setup(d.title, 16, Color.WHITE, Color(pal.neon_a), int(d.get("wave", 0)), {"accent2": Color(pal.neon_b), "tag": "> COMBAT LOG // PAYOUT", "tag_right": true})
	# full panel width: the title stays centred, the tag sits at the right
	# and the FLAWLESS sticker has the left corner to itself
	_tally_title.custom_minimum_size.x = TALLY_W - 28.0
	_tally_title.size = _tally_title.custom_minimum_size
	_panel_bg.shadow = Color(pal.neon_a)
	_panel_edges[0].color = Color(pal.neon_a)
	_panel_edges[1].color = Color(pal.neon_b)
	_panel_edges[2].color = Color(pal.neon_a).lerp(Color(pal.neon_b), 0.5)
	_panel_edges[3].color = Color(pal.neon_a).lerp(Color(pal.neon_b), 0.5)
	var rows: Array = d.rows
	for i in MAX_ROWS:
		var r: Dictionary = _rows[i]
		var on := i < rows.size()
		for k in r:
			r[k].visible = false
		if on:
			r.name.text = rows[i][0]
			r.detail.text = rows[i][1]
	var n := mini(rows.size(), MAX_ROWS)
	var mults: Array = d.mults
	_mult_shown = float(mults[0][1])
	# layout
	var w := TALLY_W
	var yb := _boxes_y(n)
	_panel_size = Vector2(w, yb + BOX_H + 50.0)
	# timeline
	var t_rows := 0.32
	var step := 0.2
	var tc := t_rows + n * step + 0.1
	var tm := tc + 0.45
	var t_total := tm + (mults.size() - 1) * 0.35 + 0.15
	var t_slam := t_total + 0.8
	_times = {"rows": t_rows, "step": step, "tc": tc, "tm": tm, "total": t_total, "slam": t_slam}
	later(0.09, func():
		add_shake(4.0)
		Sfx.play("stamp", -4.0, 1.05, 0.0))
	if d.get("flawless", false):
		# a sticker on the panel's cut top-left corner, clear of the title and tag
		later(0.3, func():
			stamp("FLAWLESS", Color(pal.neon_c), 10, {"font": Ui.font_bold, "anchor": Vector2.ZERO, "off": _panel_origin() + Vector2(38, 8), "rot": -0.1, "from": 3.0, "hold": t_slam + 0.6, "fade": 0.3, "shake": 3.0, "vol": -6.0, "pitch": 1.3, "shadow": Color(0.0, 0.0, 0.0), "slot": "tally"}))
	for i in n:
		later(t_rows + i * step, func(): Sfx.play("deal", -5.0, 1.0 + i * 0.07, 0.0))
	later(tc, func():
		Sfx.play("deal", -4.0, 0.8, 0.0)
		add_shake(2.0))
	for j in 6:
		later(tc + 0.04 + j * 0.05, func(): Sfx.play("tick", -9.0, 1.0 + j * 0.1, 0.0))
	for j in range(1, mults.size()):
		later(tm + (j - 1) * 0.35, func():
			var f := 1.0
			for q in j + 1:
				f *= float(mults[q][1])
			_mult_shown = f
			_mult_punch = 1.0
			_note_lbl.text = "%s  X%s" % [mults[j][0], _fmt_mult(float(mults[j][1]))]
			_note_t = 0.0
			add_shake(2.5)
			Sfx.play("mult", -4.0, 1.0 + 0.15 * j, 0.0))
	for j in 16:
		var k := float(j) / 15.0
		later(t_total + 0.8 * sqrt(k), func(): Sfx.play("tick", -8.0, 0.9 + k * 1.5, 0.0))
	later(t_slam, func():
		Sfx.play("cash", -1.0, 1.0, 0.0)
		add_shake(9.0)
		# confetti flanks the total instead of burying it
		fountain(_panel_origin() + Vector2(24.0, yb + BOX_H + 44.0), 40)
		fountain(_panel_origin() + Vector2(w - 24.0, yb + BOX_H + 44.0), 40)
		if d.get("boss", false):
			var cols := [Color(pal.neon_a), Color(pal.neon_b), Color(pal.neon_c), GOLD]
			for i in 8:
				later(0.08 + i * 0.16, func():
					firework(Vector2(randf_range(0.1, 0.9) * vs.x, randf_range(0.08, 0.45) * vs.y), cols[i % 4])
					if i % 3 == 0:
						Sfx.play("chime", -12.0, randf_range(0.85, 1.3), 0.0))
		if hud.post:
			hud.post.flash(0.15)
		hud.release_score(int(d.total)))
	later(t_slam + 0.9, func(): _tally_ready = true)


func _boxes_y(n: int) -> float:
	return ROW_Y0 + n * ROW_H + 6.0


func _fmt_mult(f: float) -> String:
	return ("%.1f" % f) if f < 10.0 else ("%d" % int(f))


func _panel_origin() -> Vector2:
	return Vector2(roundf((vs.x - _panel_size.x) * 0.5), roundf(maxf(18.0, (vs.y - _panel_size.y) * 0.5 - 12.0)))


func _update_tally(rd: float) -> void:
	if not _tally_on:
		return
	_tt += rd
	var t := _tt
	var tm: Dictionary = _times
	var w := _panel_size.x
	var h := _panel_size.y
	_panel.visible = true
	var o := _panel_origin()
	var open := ease_out(t / 0.14)
	_panel.position = o + Vector2(0, roundf(h * 0.5 * (1.0 - open)))
	_panel.scale = Vector2(1.0, maxf(open, 0.02))
	_panel_bg.size = Vector2(w, h)
	_panel_edges[0].position = Vector2.ZERO
	_panel_edges[0].size = Vector2(w, 1)
	_panel_edges[1].position = Vector2(0, h - 1)
	_panel_edges[1].size = Vector2(w, 1)
	_panel_edges[2].position = Vector2.ZERO
	_panel_edges[2].size = Vector2(1, h)
	_panel_edges[3].position = Vector2(w - 1, 0)
	_panel_edges[3].size = Vector2(1, h)
	# title
	var sc: float
	if t < 0.09:
		sc = lerpf(2.6, 1.0, pow(t / 0.09, 2.0))
	else:
		sc = 1.0 - 0.14 * sin((t - 0.09) * 30.0) * exp(-(t - 0.09) * 9.0)
	_tally_title.pivot_offset = _tally_title.size * 0.5
	_tally_title.scale = Vector2.ONE * sc
	_tally_title.position = Vector2(roundf((w - _tally_title.size.x) * 0.5), 0)
	# rows deal in
	var rows: Array = _td.rows
	var n := mini(rows.size(), MAX_ROWS)
	for i in n:
		var r: Dictionary = _rows[i]
		var rt: float = tm.rows + i * tm.step
		var k := clampf((t - rt) / 0.1, 0.0, 1.0)
		var on := t >= rt
		for key in r:
			r[key].visible = on
		if not on:
			continue
		var y := ROW_Y0 + i * ROW_H
		var slide := roundf(-26.0 * pow(1.0 - k, 2.0))
		r.name.size = Vector2.ZERO
		r.name.position = Vector2(14 + slide, y)
		r.detail.size = Vector2.ZERO
		r.detail.position = Vector2(118 + slide, y + 1)
		var kv := clampf((t - rt) / 0.16, 0.0, 1.0)
		var val := int(float(rows[i][2]) * kv)
		r.value.text = _num(val)
		r.value.size = Vector2.ZERO
		r.value.pivot_offset = Vector2(r.value.size.x, r.value.size.y * 0.5)
		r.value.scale = Vector2.ONE * (1.0 + 0.3 * (1.0 - ease_out(kv)))
		r.value.position = Vector2(w - 14 - r.value.size.x, y)
	# chips x mult
	var yb := _boxes_y(n)
	var boxes_on: bool = t >= tm.tc
	_chips_box.visible = boxes_on
	_mult_box.visible = boxes_on
	_x_lbl.visible = boxes_on
	var bw := (w - 28.0 - 30.0) * 0.5
	if boxes_on:
		var kb := clampf((t - tm.tc) / 0.3, 0.0, 1.0)
		var pop := 1.0 + 0.35 * (1.0 - ease_out(clampf((t - tm.tc) / 0.14, 0.0, 1.0)))
		_chips_box.size = Vector2(bw, BOX_H)
		_chips_box.pivot_offset = _chips_box.size * 0.5
		_chips_box.scale = Vector2.ONE * pop
		_chips_box.position = Vector2(14, yb)
		_chips_lbl.text = _num(int(float(_td.chips) * kb))
		_chips_lbl.size = Vector2.ZERO
		_chips_lbl.position = ((_chips_box.size - _chips_lbl.size) * 0.5).round()
		_x_lbl.size = Vector2.ZERO
		_x_lbl.position = Vector2(roundf((w - _x_lbl.size.x) * 0.5), yb + roundf((BOX_H - _x_lbl.size.y) * 0.5))
		_mult_punch = move_toward(_mult_punch, 0.0, rd * 5.0)
		_mult_box.size = Vector2(bw, BOX_H)
		_mult_box.pivot_offset = _mult_box.size * 0.5
		_mult_box.scale = Vector2.ONE * (pop + 0.35 * _mult_punch * _mult_punch)
		_mult_box.rotation = sin(t * 40.0) * 0.03 * _mult_punch
		_mult_box.position = Vector2(w - 14 - bw, yb)
		_mult_box.color = MULT_COL.darkened(0.55).lerp(MULT_COL.lerp(Color.WHITE, 0.4), _mult_punch * _mult_punch)
		_mult_lbl.text = _fmt_mult(_mult_shown)
		_mult_lbl.size = Vector2.ZERO
		_mult_lbl.position = ((_mult_box.size - _mult_lbl.size) * 0.5).round()
	# the note under the mult box (FLAWLESS x1.5, mutator x1.3)
	_note_t += rd
	_note_lbl.visible = boxes_on and _note_t < 99.0
	if _note_lbl.visible:
		_note_lbl.size = Vector2.ZERO
		# centred under the multiplier box, but a long mutator name stays inside the panel
		var nx := clampf(w - 14 - bw * 0.5 - _note_lbl.size.x * 0.5, 10.0, w - 10 - _note_lbl.size.x)
		_note_lbl.position = Vector2(roundf(nx), yb + BOX_H + 3 - roundf(4.0 * (1.0 - ease_out(_note_t / 0.15))))
	# total: counts up faster and faster, shaking, then slams
	var total_on: bool = t >= tm.total
	_total_lbl.visible = total_on
	if total_on:
		var kt := clampf((t - tm.total) / (tm.slam - tm.total), 0.0, 1.0)
		var shown := int(float(_td.total) * kt * kt)
		var slammed: bool = t >= tm.slam
		_set_text(_total_lbl, "+" + _num(int(_td.total) if slammed else shown))
		# suspense comes from the accelerating count, the rising ticks and a
		# slow swell; the digits themselves never shake (spec §9.9)
		var s2 := 1.0 + 0.18 * kt
		if slammed:
			var u: float = t - tm.slam
			s2 = 1.0 + 0.5 * exp(-u * 14.0) - 0.08 * sin(u * 30.0) * exp(-u * 10.0)
		_total_lbl.pivot_offset = _total_lbl.size * 0.5
		_total_lbl.scale = Vector2.ONE * s2
		_total_lbl.position = Vector2((w - _total_lbl.size.x) * 0.5, yb + BOX_H + 20.0).round()
		_total_lbl.add_theme_color_override("font_color", GOLD.lerp(Color.WHITE, 0.6 * exp(-maxf(0.0, t - tm.slam) * 6.0) if slammed else 0.0))
	# fade out
	var end: float = tm.slam + 0.9
	var a := 1.0 if t < end else clampf(1.0 - (t - end) / 0.3, 0.0, 1.0)
	_panel.modulate.a = a
	if t > end + 0.3:
		_tally_on = false
		_panel.visible = false


static func _num(v: int) -> String:
	# 1234567 -> 1,234,567
	var s := str(absi(v))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if v < 0 else "") + out


# ---------------------------------------------------------------- moments
# ---------------------------------------------------------------- souls-style card
func _build_card() -> void:
	_card = Control.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.visible = false
	add_child(_card)
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0, 0, 0, 0))
	g.add_point(0.22, Color(0, 0, 0, 0.55))
	g.add_point(0.5, Color(0, 0, 0, 0.82))
	g.add_point(0.78, Color(0, 0, 0, 0.55))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 64
	_card_band = TextureRect.new()
	_card_band.texture = gt
	_card_band.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_card_band.stretch_mode = TextureRect.STRETCH_SCALE
	_card_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_card_band)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_card_glow = TextureRect.new()
	_card_glow.texture = TexGen.get_tex("glow")
	_card_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_card_glow.stretch_mode = TextureRect.STRETCH_SCALE
	_card_glow.material = add
	_card_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_card_glow)
	for c in [Color(0.15, 0.85, 1.0), Color(1.0, 0.15, 0.6)]:
		var gl := Ui.label("", Ui.font_card, 24, c)
		gl.material = add
		gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# letters appear in place: the line is laid out once, never re-centred
		gl.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
		_card.add_child(gl)
		_card_ghosts.append(gl)
	_card_lbl = Ui.label("", Ui.font_card, 24, Color.WHITE, 3, Color(0.0, 0.0, 0.0, 0.85))
	_card_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_lbl.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_card.add_child(_card_lbl)
	_card_sub = Ui.label("", Ui.font_card, 12, Color(0.85, 0.82, 0.95), 2)
	_card_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.add_child(_card_sub)


func card_ready() -> bool:
	return _card_ready


## Ends the card at once (the results screen replaces FLATLINED).
func end_card() -> void:
	_card_on = false
	_card_ready = true
	_card.visible = false


## The big slow card: a dark band, one line of glowing letter-spaced text
## that decodes itself out of glitch noise, a slow zoom, then a long fade.
## Used for "<BOSS> FELLED" lines and for FLATLINED when you die.
func souls_card(text: String, col: Color, sub := "", sound := "", length := 4.6) -> void:
	_card_on = true
	_card_ready = false
	_card_t = 0.0
	_card_len = length
	_card_text = text
	_card_lbl.add_theme_color_override("font_color", col)
	_card_glow.modulate = Color(col.r, col.g, col.b, 0.0)
	_card_sub.text = sub
	# fit by font size, never by scaling, so the pixel letters stay crisp
	_card_px = CARD_SIZES[CARD_SIZES.size() - 1]
	for s in CARD_SIZES:
		if Ui.font_card.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x <= vs.x * 0.9:
			_card_px = s
			break
	_card_w = Ui.font_card.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _card_px).x
	for l in [_card_lbl] + _card_ghosts:
		l.text = text
		l.add_theme_font_size_override("font_size", _card_px)
		l.visible_characters = 0
	_card.visible = true
	if sound != "":
		Sfx.play(sound, 0.0, 1.0, 0.0)
	add_shake(3.0)


func _update_card(rd: float) -> void:
	if not _card_on:
		return
	_card_t += rd
	var t := _card_t
	var L := _card_len
	var cy := roundf(vs.y * 0.5)
	# band
	var band_a := smoothstep(0.0, 0.45, t) * (1.0 - smoothstep(L - 1.0, L, t))
	_card_band.position = Vector2(0, cy - 44)
	_card_band.size = Vector2(vs.x, 88)
	_card_band.modulate.a = band_a
	# the letters appear left to right (clean letters, no scramble), then the
	# line holds perfectly still until it fades
	var k := clampf((t - 0.12) / 0.75, 0.0, 1.0)
	var shown := int(ceil(k * _card_text.length()))
	var text_a := smoothstep(0.05, 0.5, t) * (1.0 - smoothstep(L - 1.1, L - 0.15, t))
	var w := _card_w + 24.0
	for l in [_card_lbl] + _card_ghosts:
		l.visible_characters = shown
		l.size = Vector2(w, 0)
		l.size = Vector2(w, l.size.y)
		l.position = Vector2(roundf((vs.x - w) * 0.5), roundf(cy - l.size.y * 0.5 - 2.0))
	_card_lbl.modulate.a = text_a
	# cyan/magenta ghosts: wider while the line arrives, 1 px once it holds
	var g := 1.0 - smoothstep(0.1, 0.9, t)
	var off := 1.0 + roundf(3.0 * g)
	_card_ghosts[0].position.x -= off
	_card_ghosts[1].position.x += off
	for gl in _card_ghosts:
		gl.modulate.a = text_a * (0.25 + 0.35 * g)
	# soft light behind the words
	_card_glow.size = Vector2(_card_w * 1.5, 70)
	_card_glow.position = Vector2(roundf((vs.x - _card_glow.size.x) * 0.5), cy - 36)
	_card_glow.modulate.a = 0.2 * text_a
	# the name line fades in late
	_card_sub.size = Vector2(vs.x, 0)
	_card_sub.position = Vector2(0, cy + 19)
	_card_sub.modulate.a = smoothstep(0.9, 1.6, t) * (1.0 - smoothstep(L - 1.1, L - 0.2, t))
	if t >= L - 0.45:
		_card_ready = true
	if t >= L:
		_card_on = false
		_card.visible = false


func combo_stamp(n: int, idx: int) -> void:
	if hud.boss_title.visible or panel_showing():
		# the boss name card, FINISH, the payout or the boss-defeated card owns
		# the middle of the screen: sound only, and the HUD combo counter still
		# shows the number
		Sfx.play("mult", -5.0, 0.9 + idx * 0.1, 0.0)
		_lines.kick(0.5, 0.1)
		return
	if idx >= 1:
		# bigger milestones get the holographic cut-in instead of a stamp
		_lines.kick(0.5 + idx * 0.1, 0.1)
		Sfx.play("mult", -5.0, 0.9 + idx * 0.1, 0.0)
		cut_in("X%d COMBO" % n, idx % 2 == 1)
		_shards.burst(vs * Vector2(0.5, 0.3), Color(Game.palette.neon_a), 12, 260.0, true)
		return
	var hue := fmod(0.12 - idx * 0.11 + 1.0, 1.0)
	var col := Color.from_hsv(hue, 0.75, 1.0)
	stamp("X%d COMBO" % n, col, 24, {"glitch": true, "tag": "> CHAIN SYNC", "accent": Color(Game.palette.neon_a), "seed": idx, "anchor": Vector2(0.5, 0.5), "off": Vector2(0, -50), "from": 2.4, "hold": 0.55, "fade": 0.2, "shake": 3.0 + idx * 0.5, "sound": "mult", "vol": -5.0, "pitch": 0.9 + idx * 0.1, "burst": 24 + idx * 6})
	_lines.kick(0.5, 0.1)


## Passing the best score: one message (the cut-in), never a stamp and a
## cut-in on top of each other (spec §9.9).
func hiscore_stamp() -> void:
	var pal := Game.palette
	cut_in("NEW HI-SCORE")
	Sfx.play("highscore", -3.0, 1.0, 0.0)
	later(0.2, func(): firework(Vector2(vs.x * 0.16, vs.y * 0.62), Color(pal.neon_a)))
	later(0.4, func(): firework(Vector2(vs.x * 0.84, vs.y * 0.6), Color(pal.neon_b)))


# ---------------------------------------------------------------- persona layer
## Speed lines, cinematic bars and (for bosses) a cut-in while a glory kill
## plays.
func glory_start(kind: String) -> void:
	_lines.kick(1.0, 0.3)
	_bars_t = 0.0
	_bars_len = 1.0 if kind in ["brute", "boss"] else 0.85
	_bars_top.visible = true
	_bars_bot.visible = true
	if kind == "boss":
		cut_in("DEATHBLOW!")


func speed_lines(strength: float, hold := 0.0) -> void:
	_lines.kick(strength, hold)


## Persona-style cut-in strip with the protagonist's mask.
func cut_in(text: String, flip := false) -> void:
	var pal := Game.palette
	_clear_slot("center")
	_cutin.play(text, Color(pal.neon_a), Color(pal.neon_b), flip)
	_lines.kick(0.7, 0.25)
	add_shake(3.0)


## Shards bursting out of a kill, at its spot on screen.
func kill_burst(world_pos: Vector3, big := false) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or cam.is_position_behind(world_pos):
		return
	var sp := cam.unproject_position(world_pos)
	var vr := get_viewport().get_visible_rect().size
	sp = sp / vr * vs
	_shards.burst(sp, Color(Game.palette.neon_a), 9 if big else 6, 220.0 if big else 150.0, big)


## The all-out FINISH: red field, black rays, a white slash, FINISH! slams
## in, then everything cuts out at once.
func finish_splash() -> void:
	var pal := Game.palette
	_fin_t = 0.0
	_fin.accent = Color(1.0, 0.12, 0.22) # alert red, whatever the palette
	_fin.visible = true
	_lines.kick(1.0, 0.7)
	add_shake(12.0)
	Sfx.play("finish", 0.0, 1.0, 0.0)
	if hud.post:
		hud.post.impact_frame(0.12)
	_fin.accent2 = Color(pal.neon_b)
	var cy := roundf(vs.y * 0.46)
	_fin.band = Rect2(0, cy - 56, vs.x, 124)
	stamp("FINISH", Color.WHITE, 48, {"glitch": true, "brackets": true, "tag": "> TERMINATION CONFIRMED", "accent": Color(pal.neon_a), "accent2": Color(pal.neon_b), "seed": 9, "anchor": Vector2(0.5, 0.46), "from": 3.0, "slam": 0.07, "hold": 0.8, "fade": 0.04, "shake": 10.0, "sound": "", "burst": 0})
	_shards.burst(vs * 0.5, Color.WHITE, 30, 380.0, true)


func _update_finish(rd: float) -> void:
	if _fin_t > 50.0:
		return
	_fin_t += rd
	_fin.t = _fin_t
	_fin.queue_redraw()
	if OS.get_cmdline_user_args().has("--verbose-juice"):
		print("fin t=%.2f vis=%s size=%s pos=%s" % [_fin_t, _fin.visible, _fin.size, _fin.position])
	if _fin_t > 0.92:
		_fin.visible = false
		_fin_t = 99.0


func _update_bars(rd: float) -> void:
	if _bars_t > 50.0:
		return
	_bars_t += rd
	var k := minf(ease_out(_bars_t / 0.08), 1.0 - smoothstep(_bars_len - 0.12, _bars_len, _bars_t))
	var h := roundf(26.0 * k)
	_bars_top.position = Vector2(-4, -2)
	_bars_top.size = Vector2(vs.x + 8, h + 2)
	_bars_bot.position = Vector2(-4, vs.y - h)
	_bars_bot.size = Vector2(vs.x + 8, h + 2)
	if _bars_t > _bars_len:
		_bars_top.visible = false
		_bars_bot.visible = false
		_bars_t = 99.0


# ---------------------------------------------------------------- frame
func _process(_delta: float) -> void:
	var rd := Game.real_dt
	_t += rd
	var vr := get_parent_control().get_rect().size if get_parent_control() else Vector2.ZERO
	if vr.x > 10.0:
		vs = vr
	if not _events.is_empty():
		var due: Array = []
		for e in _events:
			e.t -= rd
			if e.t <= 0.0:
				due.append(e)
		for e in due:
			_events.erase(e)
			e.f.call()
	_update_intro(rd)
	_update_tally(rd)
	_update_card(rd)
	_update_bars(rd)
	_update_finish(rd)
	_update_stamps(rd)
	_update_sparks(rd)
	shake *= exp(-rd * 9.0)
	if shake < 0.25:
		shake = 0.0
