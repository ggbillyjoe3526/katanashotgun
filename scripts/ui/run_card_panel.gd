class_name RunCardPanel
extends Control
## The run card's corner of the results screen (spec §19.1 #10): a SAVE RUN
## CARD button (or P, for picture), then where the card went and an OPEN
## FOLDER button (or O) that shows it in the file manager, ready to drag
## into a chat.
## The HUD shows it once the results have counted up.

enum State { IDLE, BUSY, SAVED, FAILED }

const SAVED_COLOR := Color(0.45, 1.0, 0.6)
const FAIL_COLOR := Color(1.0, 0.35, 0.35)

var state := State.IDLE
var path := "" # the saved card's full path
var save_button: TechButton
var open_button: TechButton
var note: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	save_button = TechButton.make("SAVE RUN CARD  [P]", Color(Game.palette.neon_b))
	save_button.pressed.connect(make)
	add_child(save_button)
	open_button = TechButton.make("OPEN FOLDER  [O]", Color(Game.palette.neon_a))
	open_button.pressed.connect(open_folder)
	add_child(open_button)
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
	if state != State.IDLE or not is_visible_in_tree():
		return
	state = State.BUSY
	Sfx.play("ui_click", -4.0)
	_show()
	var f := RunCard.facts()
	var img: Image = await RunCard.render(self, f)
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
	save_button.visible = state == State.IDLE
	open_button.visible = state == State.SAVED
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


## Top right of the results screen, beside the FLATLINED title (the rest
## of the screen is full): the button, and once saved the note under it.
func place(vs: Vector2) -> void:
	position = Vector2.ZERO
	size = vs
	note.size = Vector2.ZERO
	var right := vs.x - 6.0
	save_button.position = Vector2(roundf(right - save_button.size.x), 6)
	open_button.position = Vector2(roundf(right - open_button.size.x), 6)
	var y := 6.0 if state != State.SAVED else 24.0
	note.position = Vector2(roundf(right - note.size.x), y)


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.physical_keycode == KEY_P:
		make()
		get_viewport().set_input_as_handled()
	elif event.physical_keycode == KEY_O and state == State.SAVED:
		open_folder()
		get_viewport().set_input_as_handled()
