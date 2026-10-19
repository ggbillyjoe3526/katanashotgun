class_name LevelBar
extends Control
## The persistent Player Level (spec §11.1) on the results screen's level
## plate: "PLAYER LV n" with the run's XP gain at the right, the XP bar
## under it and the XP numbers under the bar's right end. roll() counts a
## run's XP into the bar, Balatro-style, and emits leveled(level) as the bar
## fills, so the HUD can celebrate each level.
## The numbers count but never scramble (spec §9.9).

signal leveled(level: int)
signal finished(levels_gained: int)

const H := 36.0
const BAR_Y := 17.0
const FILL_TIME := 1.1 # seconds to fill the bar once
const MAX_TIME := 3.2 # a big run never holds up the results longer than this

var lv_label: Label
var xp_label: Label
var gain_label: Label
var pop_label: Label # "LEVEL UP" stamped in the gain's place as each level fills
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


func _init(w := 172.0) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(w, H)
	lv_label = Ui.label("", Ui.font_bold, 10, Color.WHITE)
	add_child(lv_label)
	xp_label = Ui.label("", Ui.font_mono, 9, MenuList.REST)
	add_child(xp_label)
	gain_label = Ui.label("", Ui.font_mono, 9, Color(1.0, 0.85, 0.25))
	add_child(gain_label)
	pop_label = Ui.label("LEVEL UP", Ui.font_bold, 10, Color(1.0, 0.85, 0.25))
	pop_label.visible = false
	add_child(pop_label)
	bar_bg = Ui.rect(Color(0.16, 0.13, 0.26, 1.0), Vector2(0, BAR_Y), Vector2(w, 3))
	add_child(bar_bg)
	bar_fill = Ui.rect(Color.WHITE, bar_bg.position, Vector2(0, 3))
	add_child(bar_fill)
	bar_flash = Ui.rect(Color(1, 1, 1, 0), bar_bg.position - Vector2(1, 1), bar_bg.size + Vector2(2, 2))
	add_child(bar_flash)


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
	if not is_visible_in_tree():
		return
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
	xp_label.text = "%d / %d XP" % [int(xp), need]
	xp_label.size = Vector2.ZERO
	xp_label.position = Vector2(size.x - xp_label.size.x, BAR_Y + 4.0)
	# while a level lands, LEVEL UP takes the gain's place (one message there)
	pop_label.visible = _flash > 0.0
	gain_label.visible = _gained > 0 and not pop_label.visible
	gain_label.text = "+%d XP" % _gained
	gain_label.size = Vector2.ZERO
	gain_label.position = Vector2(size.x - gain_label.size.x, 0)
	pop_label.size = Vector2.ZERO
	pop_label.position = Vector2(size.x - pop_label.size.x, 0)
	pop_label.pivot_offset = pop_label.size * 0.5
	var slam := clampf((1.0 - _flash) / 0.08, 0.0, 1.0) # slams in over 0.07 s
	pop_label.scale = Vector2.ONE * lerpf(1.8, 1.0, slam)
	var k := clampf(xp / float(need), 0.0, 1.0)
	bar_fill.size = Vector2(roundf(size.x * k), 3)
	bar_fill.color = col.lerp(Color.WHITE, _flash * 0.8)
	bar_flash.color = Color(1, 1, 1, 0.6 * _flash)
