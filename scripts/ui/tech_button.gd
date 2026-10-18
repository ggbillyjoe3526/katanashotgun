class_name TechButton
extends Control
## A small clickable plate in the UI's tech style: dark fill, neon outline,
## filled with the accent while hovered. Sizes itself to its text.

signal pressed

var text := ""
var accent := Color(1.0, 0.2, 0.7)
var font_px := Ui.PIX
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
	size = Vector2(ceilf(Ui.font_bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px).x) + 16.0, 16.0)
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
		pressed.emit()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, accent if _hover else Color(0.03, 0.015, 0.07, 0.9))
	draw_rect(r, accent, false, 1.0)
	var f := Ui.font_bold
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px).x
	# capitals centred in the button
	var pos := Vector2((size.x - w) * 0.5, (size.y + Ui.PIX_CAP) * 0.5).round()
	draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px, Color(0.03, 0.015, 0.07) if _hover else Color.WHITE)
