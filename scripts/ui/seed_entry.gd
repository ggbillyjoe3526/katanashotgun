class_name SeedEntry
extends Control
## PLAY A SEED, opened from the title (spec §7.5): type or paste a friend's
## seed and start a run on it. Worked with the mouse alone (PASTE, CLEAR,
## BACK, PLAY) or the keyboard alone (type, Ctrl+V, Backspace, Enter, Esc).
## While open it holds every key, so nothing reaches the title behind it.

signal chosen(seed_v: int)

const DIGITS := 8
const MAX_SEED := 0x7fffffff # seeds are 31-bit (Game.reset_run)
const W := 290.0
const H := 150.0
const NOTE_COL := Color(0.85, 0.8, 0.95)
const WARN_COL := Color(1.0, 0.55, 0.35)
const HINT := "TYPE OR PASTE THE 8 CHARACTERS: 0-9, A-F"

## Text a player can paste: "0BAD-C0DE", "0bad c0de", "0BADC0DE" or a line
## that holds one, like "SEED 0BAD-C0DE" copied from the results screen.
static var _dashed: RegEx
static var _loose: RegEx

var digits := "" # what has been typed so far, upper case, no dash
## A suspended run is waiting: playing a seed ends it, so PLAY asks twice.
var ends_saved_run := false

var plate: Shard
var field: Shard
var header: Label
var slots: Label
var note: Label
var paste_btn: TechButton
var clear_btn: TechButton
var back_btn: TechButton
var play_btn: TechButton
var _note_t := 0.0 # seconds a warning stays before the hint comes back


## The seed in `text`, or -1 when it holds none.
static func parse(text: String) -> int:
	if _dashed == null:
		var edge := "(?i)(?<![0-9a-f])([0-9a-f]{4})%s([0-9a-f]{4})(?![0-9a-f])"
		_dashed = RegEx.create_from_string(edge % "-")
		_loose = RegEx.create_from_string(edge % " ?")
	# the shown form first, so a word like "dead" or "cafe" before the seed
	# isn't read as its first half
	var m := _dashed.search(text)
	if m == null:
		m = _loose.search(text)
	if m == null:
		return -1
	var v := (m.get_string(1) + m.get_string(2)).hex_to_int()
	return v if v >= 0 and v <= MAX_SEED else -1


func _init() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP # clicks beside the panel do nothing
	var a: Color = Game.palette.neon_a
	var b: Color = Game.palette.neon_b
	var shade := Ui.rect(Color(0.02, 0.0, 0.05, 0.55), Vector2.ZERO, Vector2(480, 270))
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	plate = Shard.make(Color(0.02, 0.01, 0.06, 0.94), 10.0, a, b)
	plate.brackets = Color.WHITE
	plate.size = Vector2(W, H)
	add_child(plate)
	header = Ui.label("PLAY A SEED", Ui.font_big, 13, Color(Game.palette.neon_c), 2)
	plate.add_child(header)
	field = Shard.make(Color(0.0, 0.0, 0.0, 0.85), 4.0, Color(0, 0, 0, 0), a)
	plate.add_child(field)
	slots = Ui.label("", Ui.font_mono, 31, Color.WHITE, 2)
	field.add_child(slots)
	note = Ui.label(HINT, Ui.font_bold, 9, NOTE_COL, 2)
	plate.add_child(note)
	paste_btn = TechButton.make("PASTE  [CTRL+V]", b)
	paste_btn.pressed.connect(paste)
	plate.add_child(paste_btn)
	clear_btn = TechButton.make("CLEAR", b)
	clear_btn.pressed.connect(func():
		digits = ""
		Sfx.play("type", -6.0, 0.8)
		_refresh())
	plate.add_child(clear_btn)
	back_btn = TechButton.make("BACK  [ESC]", b)
	back_btn.pressed.connect(close)
	plate.add_child(back_btn)
	play_btn = TechButton.make("PLAY  [ENTER]", a)
	play_btn.pressed.connect(_play)
	plate.add_child(play_btn)


func open(saved_run: bool) -> void:
	ends_saved_run = saved_run
	digits = ""
	_note_t = 0.0
	visible = true
	Sfx.play("ui_click", -4.0)
	_refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	play_btn.disarm()
	Sfx.play("ui_click", -6.0, 0.8)


## Fills the box from the clipboard; a seed found there replaces what was typed.
func paste() -> void:
	var s := parse(DisplayServer.clipboard_get())
	if s < 0:
		_warn("NO SEED ON THE CLIPBOARD")
		return
	digits = Game.seed_string(s).replace("-", "")
	Sfx.play("type", -6.0)
	_refresh()


func seed_value() -> int:
	return digits.hex_to_int() if digits.length() == DIGITS else -1


func _play() -> void:
	if digits.length() < DIGITS:
		_warn("TYPE ALL 8 CHARACTERS FIRST")
		return
	visible = false
	chosen.emit(seed_value())


func _type(ch: String) -> void:
	if digits.length() >= DIGITS:
		return
	if digits.is_empty() and ch.hex_to_int() > 7:
		# the top bit is not part of a seed (31 bits), so 8000-0000 and up
		# would never come out of a results screen
		_warn("A SEED STARTS WITH 0 TO 7")
		return
	digits += ch
	Sfx.play("type", -6.0)
	_refresh()


func _warn(text: String) -> void:
	note.text = text
	note.add_theme_color_override("font_color", WARN_COL)
	_note_t = 2.4
	Sfx.play("type", -4.0, 0.6)


func _refresh() -> void:
	var shown := ""
	for i in DIGITS:
		if i == 4:
			shown += "-"
		shown += digits[i] if i < digits.length() else "_"
	slots.text = shown
	# PLAY asks twice only once it would really start (and end the saved run)
	var ready_to_play := digits.length() == DIGITS
	play_btn.confirm_text = "AGAIN: SAVED RUN ENDS" if ends_saved_run and ready_to_play else ""
	if not ready_to_play:
		play_btn.disarm()
	if _note_t <= 0.0:
		note.text = "PLAYING A SEED ENDS YOUR SAVED RUN" if ends_saved_run else HINT
		note.add_theme_color_override("font_color", WARN_COL if ends_saved_run else NOTE_COL)


func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey:
		return
	var k := event as InputEventKey
	if k.physical_keycode == KEY_F11 or (k.physical_keycode == KEY_ENTER and k.alt_pressed):
		return # main toggles fullscreen
	get_viewport().set_input_as_handled()
	if not k.pressed:
		return
	var ctrl := k.ctrl_pressed or k.meta_pressed
	if ctrl and k.keycode == KEY_V: # the layout's V, wherever it sits
		if not k.echo:
			paste()
		return
	match k.physical_keycode:
		KEY_ESCAPE:
			close()
			return
		KEY_ENTER, KEY_KP_ENTER:
			if k.echo:
				pass
			elif digits.length() == DIGITS:
				play_btn.press() # asks twice when a saved run would end
			else:
				_play()
			return
		KEY_BACKSPACE, KEY_DELETE:
			if not digits.is_empty():
				digits = digits.left(-1)
				Sfx.play("type", -6.0, 0.8)
				_refresh()
			return
	if ctrl or k.echo or k.unicode == 0:
		return
	# the typed character, so every keyboard layout types what it shows
	var ch := String.chr(k.unicode).to_upper()
	if ch.length() == 1 and "0123456789ABCDEF".contains(ch):
		_type(ch)


func _process(_delta: float) -> void:
	if not visible:
		return
	if _note_t > 0.0:
		_note_t -= Game.real_dt
		if _note_t <= 0.0:
			_refresh()
	var vs := get_rect().size
	if vs.x < 10:
		vs = Vector2(480, 270)
	plate.position = ((vs - plate.size) * 0.5).round()
	for l: Label in [header, slots, note]:
		l.size = Vector2.ZERO
	header.position = Vector2(roundf((W - header.size.x) * 0.5), 8)
	field.size = Vector2(slots.size.x + 24.0, 34.0)
	field.position = Vector2(roundf((W - field.size.x) * 0.5), 32)
	slots.position = Vector2(12, roundf((field.size.y - slots.size.y) * 0.5))
	note.position = Vector2(roundf((W - note.size.x) * 0.5), 72)
	var row1 := paste_btn.size.x + 8.0 + clear_btn.size.x
	paste_btn.position = Vector2(roundf((W - row1) * 0.5), 96)
	clear_btn.position = Vector2(paste_btn.position.x + paste_btn.size.x + 8.0, 96)
	var row2 := back_btn.size.x + 8.0 + play_btn.size.x
	back_btn.position = Vector2(roundf((W - row2) * 0.5), 120)
	play_btn.position = Vector2(back_btn.position.x + back_btn.size.x + 8.0, 120)
