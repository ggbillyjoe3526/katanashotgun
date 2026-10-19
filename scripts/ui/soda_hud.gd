class_name SodaHud
extends Control
## The soda cans on the fight HUD (spec §19.1 #11), drawn round the vitals
## frame like the cells: the cans in hand as small blocks beside the cell
## number (the selected one bright and underlined), and the can being drunk
## as a timer along the frame's top edge, between the corner brackets. In
## its crash the bar turns grey-red with CRASH over it. Opening a can flashes
## the frame's corners in its colour. Shown only while soda cans are on.

const SLOT := Vector2i(4, 7)
const SLOT_GAP := 2
const SLOTS_AT := Vector2i(29, 10) # from the crosshair: right of the frame, under the cell number
const BAR_HALF := 15 # the timer runs between the top corner brackets
const INK := Color(0.02, 0.0, 0.05, 0.85)
const EMPTY := Color(0.17, 0.2, 0.32)
const CRASH := Color(0.75, 0.32, 0.36)

var crash_label: Label
var _pop: Array[float] = [0.0, 0.0, 0.0]
var _flash := 0.0
var _flash_col := Color.WHITE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	crash_label = Ui.label("CRASH", Ui.font_bold, 10, CRASH.lerp(Color.WHITE, 0.25), 2)
	crash_label.visible = false
	add_child(crash_label)


## A can just went into slot `i`: it pops.
func pop(i: int) -> void:
	if i >= 0 and i < _pop.size():
		_pop[i] = 1.0


## A can was opened: the frame's corners flash its colour.
func flash(col: Color) -> void:
	_flash = 1.0
	_flash_col = col


## Placed on the crosshair each frame; `on` is whether the vitals frame shows.
func refresh(c: Vector2, on: bool, delta: float) -> void:
	var cans := Game.cans
	visible = on and is_instance_valid(cans) and cans.enabled and Game.state != "title"
	position = c
	for i in _pop.size():
		_pop[i] = move_toward(_pop[i], 0.0, delta * 4.0)
	_flash = move_toward(_flash, 0.0, delta * 2.5)
	if not visible:
		return
	crash_label.visible = cans.phase == "crash"
	if crash_label.visible:
		crash_label.size = Vector2.ZERO
		crash_label.position = Vector2(roundf(-crash_label.size.x * 0.5), -Hud.Crosshair.H - 4.0 - roundf(crash_label.size.y * 0.85))
	queue_redraw()


func _draw() -> void:
	var cans := Game.cans
	if not is_instance_valid(cans):
		return
	var h := Hud.Crosshair.H
	# the cans in hand
	for i in Soda.MAX_HELD:
		var r := Rect2(SLOTS_AT.x + i * (SLOT.x + SLOT_GAP), SLOTS_AT.y, SLOT.x, SLOT.y)
		draw_rect(r.grow(1), INK)
		if i >= cans.held.size():
			draw_rect(r, EMPTY)
			continue
		var col: Color = Soda.get_def(cans.held[i]).color
		var sel := i == cans.selected
		var body := col if sel else col.darkened(0.4)
		draw_rect(r, body.lerp(Color.WHITE, _pop[i]))
		draw_rect(Rect2(r.position, Vector2(SLOT.x, 1)), Color(0.85, 0.88, 0.95) if sel else Color(0.5, 0.52, 0.6))
		if sel and cans.held.size() > 1:
			draw_rect(Rect2(r.position.x, r.end.y + 2, SLOT.x, 1), Color.WHITE)
	# the can being drunk: a timer along the top edge, shrinking to the middle
	if cans.phase != "":
		var k := clampf(cans.phase_t / maxf(cans.phase_len, 0.01), 0.0, 1.0)
		var buff := cans.phase == "buff"
		var col: Color = Soda.get_def(cans.active).color if buff else CRASH
		draw_rect(Rect2(-BAR_HALF - 1, -h - 2, 2 * BAR_HALF + 3, 5), INK)
		draw_rect(Rect2(-BAR_HALF, -h - 1, 2 * BAR_HALF + 1, 3), Color(col, 0.25))
		var w := roundi((2 * BAR_HALF + 1) * k)
		var x0 := -BAR_HALF + roundi(((2 * BAR_HALF + 1) - w) * 0.5)
		draw_rect(Rect2(x0, -h - 1, w, 3), col)
	# opening a can: the corners flash its colour
	if _flash > 0.0:
		var fc := Color(_flash_col, _flash)
		var arm := Hud.Crosshair.ARM + 2
		for cn: Vector2i in [Vector2i(-h, -h), Vector2i(h, -h), Vector2i(-h, h), Vector2i(h, h)]:
			var x := cn.x - 1 if cn.x < 0 else cn.x - arm + 2
			var y := cn.y - 1 if cn.y < 0 else cn.y - arm + 2
			draw_rect(Rect2(x, cn.y - (1 if cn.y < 0 else 0), arm, 2), fc)
			draw_rect(Rect2(cn.x - (1 if cn.x < 0 else 0), y, 2, arm), fc)
