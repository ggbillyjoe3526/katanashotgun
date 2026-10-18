class_name TechButton
extends Control
## A small clickable plate in the UI's tech style: dark fill, neon outline,
## filled with the accent while hovered. Sizes itself to its text.
## With confirm_text set, the first press only arms it (showing that text)
## and a second press within ARM_S goes through, so it can't be hit by accident.

signal pressed

const ARM_S := 3.0

var text := ""
var accent := Color(1.0, 0.2, 0.7)
var font_px := Ui.PIX
var confirm_text := ""
var _label := ""
var _armed_t := 0.0 # seconds left to confirm, in real time
var _hover := false


static func make(label: String, col: Color) -> TechButton:
	var b := TechButton.new()
	b.text = label
	b.accent = col
	return b


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	Ui.init()
	_label = text
	_fit()
	mouse_entered.connect(func():
		_hover = true
		Sfx.play("ui_hover", -10.0)
		queue_redraw())
	mouse_exited.connect(func():
		_hover = false
		queue_redraw())


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		press()


## A click, or the button's key from the screen that owns it.
func press() -> void:
	if confirm_text == "" or armed():
		disarm()
		pressed.emit()
		return
	_armed_t = ARM_S
	text = confirm_text
	_fit()
	Sfx.play("ui_click", -6.0)


func armed() -> bool:
	return _armed_t > 0.0


func disarm() -> void:
	if _armed_t <= 0.0 and text == _label:
		return
	_armed_t = 0.0
	text = _label
	_fit()


func _process(_delta: float) -> void:
	if _armed_t > 0.0:
		_armed_t -= Game.real_dt
		if _armed_t <= 0.0:
			disarm()


func _fit() -> void:
	size = Vector2(ceilf(Ui.font_bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px).x) + 16.0, 16.0)
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, accent if _hover else Color(0.03, 0.015, 0.07, 0.9))
	draw_rect(r, accent, false, 1.0)
	var f := Ui.font_bold
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px).x
	# capitals centred in the button
	var pos := Vector2((size.x - w) * 0.5, (size.y + Ui.PIX_CAP) * 0.5).round()
	draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px, Color(0.03, 0.015, 0.07) if _hover else Color.WHITE)
