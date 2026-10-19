class_name RunCardPanel
extends Control
## The run card on the results screen (spec §19.1 #10): P (picture) or the
## results row's RUN CARD saves it, then a note in the top right corner says
## where it went, and O or OPEN FOLDER shows it in the file manager, ready to
## drag into a chat. The HUD's results row carries the words to click.

enum State { IDLE, BUSY, SAVED, FAILED }

const SAVED_COLOR := Color(0.45, 1.0, 0.6)
const FAIL_COLOR := Color(1.0, 0.35, 0.35)

var state := State.IDLE
var path := "" # the saved card's full path
var note: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	note = Ui.label("", Ui.font_bold, 10, SAVED_COLOR, 2)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(note)
	reset()


## A new results screen: nothing saved yet.
func reset() -> void:
	state = State.IDLE
	path = ""
	_show()


## Draws the card and saves it. Once saved, pressing again changes nothing.
func make() -> void:
	if state == State.BUSY or state == State.SAVED or not is_visible_in_tree():
		return
	state = State.BUSY
	Sfx.play("ui_click", -4.0)
	_show()
	var f := RunCard.facts()
	var img: Image = await RunCard.render(self, f)
	if state != State.BUSY:
		return # a new results screen reset the panel while it drew
	path = RunCard.save(img, f) if img != null else ""
	if path == "":
		state = State.FAILED
		push_warning("run card: could not draw or save the card")
	else:
		state = State.SAVED
		print("[runcard] saved %s" % path)
		Sfx.play("stamp", -3.0)
	_show()
	if state == State.SAVED and Game.hud:
		note.size = Vector2.ZERO
		Game.hud.juice.burst(note.position + Vector2(note.size.x * 0.5, 6), SAVED_COLOR, 24, 90.0)


## Opens the folder in the file manager with the card selected.
func open_folder() -> void:
	if state != State.SAVED:
		return
	Sfx.play("ui_click", -4.0)
	OS.shell_show_in_file_manager(path, true)


func _show() -> void:
	note.visible = state != State.IDLE
	match state:
		State.BUSY:
			note.text = "SAVING RUN CARD..."
			note.add_theme_color_override("font_color", Color.WHITE)
		State.SAVED:
			note.text = "RUN CARD SAVED\n%s" % RunCard.folder_label(path)
			note.add_theme_color_override("font_color", SAVED_COLOR)
		State.FAILED:
			note.text = "COULD NOT SAVE THE RUN CARD"
			note.add_theme_color_override("font_color", FAIL_COLOR)


## The note goes in the top right corner of the results screen, beside the
## FLATLINED title, clear of the score and the plates.
func place(vs: Vector2) -> void:
	position = Vector2.ZERO
	size = vs
	note.size = Vector2.ZERO
	note.position = Vector2(roundf(vs.x - 6.0 - note.size.x), 4)


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.physical_keycode == KEY_P:
		make()
		get_viewport().set_input_as_handled()
	elif event.physical_keycode == KEY_O and state == State.SAVED:
		open_folder()
		get_viewport().set_input_as_handled()
