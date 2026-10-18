class_name LevelBar
extends Control
## The persistent Player Level (spec §11.1): "PLAYER LV n", the XP bar and
## the XP still needed, on a dark plate. Still on the title; on the results
## screen roll() counts a run's XP into the bar, Balatro-style, and emits
## leveled(level) as the bar fills, so the HUD can celebrate each level.
## The numbers count but never scramble (spec §9.9).

signal leveled(level: int)
signal finished(levels_gained: int)

const W := 320.0
const H := 30.0
const SLIM_H := 18.0
const FILL_TIME := 1.1 # seconds to fill the bar once
const MAX_TIME := 3.2 # a big run never holds up the results longer than this

var plate: Shard
var lv_label: Label
var xp_label: Label
var gain_label: Label
var pop_label: Label # "LEVEL UP" stamped inside the plate as each level fills
var bar_bg: ColorRect
var bar_fill: ColorRect
var bar_flash: ColorRect

var level := 1
var xp := 0.0
var _target_level := 1
var _target_xp := 0
var _speed := 0.0 # XP per second while rolling
var _rolling := false
var _flash := 0.0
var _tick_t := 0.0
var _gained := 0
var _start_level := 1
var slim := false # one row with the bar inline, for the title screen


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(W, H)
	plate = Shard.make(Color(0.02, 0.01, 0.06, 0.88), 6.0, Color(0, 0, 0, 0), Color(1, 1, 1, 0.25))
	plate.size = size
	add_child(plate)
	lv_label = Ui.label("", Ui.font_big, 10, Color.WHITE, 2)
	lv_label.position = Vector2(8, 1)
	add_child(lv_label)
	xp_label = Ui.label("", Ui.font_mono, 9, Color(0.9, 0.88, 1.0), 2)
	add_child(xp_label)
	gain_label = Ui.label("", Ui.font_mono, 9, Color(1.0, 0.85, 0.25), 2)
	add_child(gain_label)
	pop_label = Ui.label("LEVEL UP", Ui.font_big, 10, Color(1.0, 0.85, 0.25), 2)
	pop_label.visible = false
	add_child(pop_label)
	bar_bg = Ui.rect(Color(0.16, 0.13, 0.26, 1.0), Vector2(8, 20), Vector2(W - 16, 5))
	add_child(bar_bg)
	bar_fill = Ui.rect(Color.WHITE, bar_bg.position, Vector2(0, 5))
	add_child(bar_fill)
	bar_flash = Ui.rect(Color(1, 1, 1, 0), bar_bg.position - Vector2(1, 1), bar_bg.size + Vector2(2, 2))
	add_child(bar_flash)


func make_slim() -> LevelBar:
	slim = true
	size = Vector2(W, SLIM_H)
	plate.size = size
	bar_bg.size.y = 4
	bar_fill.size.y = 4
	return self


## Shows a level and XP without animation.
func show_static(lv: int, x: int) -> void:
	level = lv
	xp = x
	_target_level = lv
	_target_xp = x
	_rolling = false
	_gained = 0
	_refresh()


## Counts a finished run's XP (Profile.finish_run's result) into the bar.
func roll(result: Dictionary) -> void:
	level = int(result.get("level_before", 1))
	xp = float(result.get("xp_before", 0))
	_target_level = int(result.get("level_after", level))
	_target_xp = int(result.get("xp_after", xp))
	_gained = int(result.get("xp_gained", 0))
	_start_level = level
	var bars := float(_target_level - level) + _target_xp / float(Progression.xp_to_next(_target_level)) - xp / float(Progression.xp_to_next(level))
	var dur := clampf(bars * FILL_TIME, 0.6, MAX_TIME)
	_speed = maxf(_gained / dur, 1.0)
	_rolling = _gained > 0
	_refresh()


func done() -> bool:
	return not _rolling


func _process(_delta: float) -> void:
	var rd := Game.real_dt
	if _rolling:
		xp += _speed * rd
		var need := Progression.xp_to_next(level)
		if level < _target_level and xp >= need:
			xp -= need
			level += 1
			_flash = 1.0
			leveled.emit(level)
		elif level == _target_level and xp >= _target_xp:
			xp = _target_xp
			_rolling = false
			finished.emit(level - _start_level)
		_tick_t -= rd
		if _tick_t <= 0.0 and _rolling:
			_tick_t = 0.06
			Sfx.play("tick", -12.0, 0.9 + xp / need * 0.8, 0.0)
	_flash = move_toward(_flash, 0.0, rd * 1.1) # LEVEL UP holds ~0.9 s, long enough to read
	_refresh()


func _refresh() -> void:
	var need := Progression.xp_to_next(level)
	var col: Color = Game.palette.get("neon_b", Color(0.3, 0.95, 1.0)) if Game.palette else Color(0.3, 0.95, 1.0)
	lv_label.text = "PLAYER LV %d" % level
	lv_label.size = Vector2.ZERO
	xp_label.text = "%d / %d XP" % [int(xp), need]
	xp_label.size = Vector2.ZERO
	xp_label.position = Vector2(W - 8 - xp_label.size.x, 3)
	# while a level lands, LEVEL UP takes the gain's place (one message there)
	pop_label.visible = _flash > 0.0
	gain_label.visible = _gained > 0 and not pop_label.visible
	gain_label.text = "+%d XP" % _gained
	gain_label.size = Vector2.ZERO
	gain_label.position = Vector2(lv_label.position.x + lv_label.size.x + 10, 3)
	pop_label.size = Vector2.ZERO
	pop_label.position = Vector2(lv_label.position.x + lv_label.size.x + 10, 2)
	pop_label.pivot_offset = pop_label.size * 0.5
	var slam := clampf((1.0 - _flash) / 0.08, 0.0, 1.0) # slams in over 0.07 s
	pop_label.scale = Vector2.ONE * lerpf(1.8, 1.0, slam)
	var k := clampf(xp / float(need), 0.0, 1.0)
	if slim:
		var x0 := lv_label.position.x + lv_label.size.x + 8.0
		bar_bg.position = Vector2(x0, roundf(SLIM_H * 0.5) - 2)
		bar_bg.size.x = xp_label.position.x - 8.0 - x0
		bar_fill.position = bar_bg.position
		bar_fill.size = Vector2(roundf(bar_bg.size.x * k), 4)
		bar_flash.position = bar_bg.position - Vector2(1, 1)
		bar_flash.size = bar_bg.size + Vector2(2, 2)
	else:
		bar_fill.size = Vector2(roundf((W - 16) * k), 5)
	bar_fill.color = col.lerp(Color.WHITE, _flash * 0.8)
	bar_flash.color = Color(1, 1, 1, 0.6 * _flash)
	plate.outline = col.lerp(Color.WHITE, _flash) if _flash > 0.0 else Color(col.r, col.g, col.b, 0.5)
