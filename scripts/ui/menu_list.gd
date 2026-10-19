class_name MenuList
extends Control
## The Focus menus' list of choices (spec §9.7): plain words, grey at rest,
## white with a cyan marker bar beside the item the mouse points at. Every
## item is a click target; an item's key shows dim beside it ("[S]"), or in
## front of it on a row ("[R] RETRY SEED").
## An item with confirm text only arms on the first press (showing that
## text) and goes through on a second press within ARM_S, so QUIT can't be
## hit by accident.

const ARM_S := 3.0
const FLASH_S := 1.5
const MARK := Color(0.25, 0.95, 1.0)
const REST := Color(0.63, 0.62, 0.75)
const KEY_DIM := Color(0.45, 0.43, 0.58)
const WARN := Color(1.0, 0.35, 0.4)
const MARK_W := 2.0
const TEXT_X := 10.0 # text starts this far right of the marker
const KEY_GAP := 8.0

var pitch := 20.0 # vertical: one item every this many pixels
var horizontal := false # a row instead of a column, with keys in front
var gap := 18.0 # space between items on a row
var current := 0 # the item marked while the mouse points at none (-1: none)
var _items: Array[Dictionary] = []
var _hover := -1
var _mark: ColorRect


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.init()
	_mark = Ui.rect(MARK, Vector2.ZERO, Vector2(MARK_W, 12))
	add_child(_mark)


## Adds an item. `key` is the key's name ("S"), `o` may hold "confirm"
## (the armed text) and "col" (the item's colour at rest).
func add(text: String, cb: Callable, key := "", o := {}) -> int:
	var row := Control.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# outlined: the words sit straight on the busy scene
	var l := Ui.label(text, Ui.font_bold, 10, REST, 2)
	row.add_child(l)
	var k := Ui.label("[%s]" % key if key != "" else "", Ui.font_bold, 10, KEY_DIM, 2)
	k.visible = key != ""
	row.add_child(k)
	var line := Ui.rect(MARK, Vector2.ZERO, Vector2(1, 1))
	line.visible = false
	row.add_child(line)
	add_child(row)
	var i := _items.size()
	_items.append({"row": row, "label": l, "key": k, "line": line, "text": text, "cb": cb,
		"confirm": o.get("confirm", ""), "col": o.get("col", REST), "armed": 0.0, "flash": 0.0})
	row.mouse_entered.connect(func():
		_hover = i
		Sfx.play("ui_hover", -10.0))
	row.mouse_exited.connect(func():
		if _hover == i:
			_hover = -1)
	row.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			row.accept_event()
			press(i))
	layout()
	return i


func count() -> int:
	return _items.size()


func item_text(i: int) -> String:
	return _items[i].text


func set_text(i: int, text: String) -> void:
	if _items[i].text == text:
		return
	_items[i].text = text
	if _items[i].armed <= 0.0 and _items[i].flash <= 0.0:
		_items[i].label.text = text
	layout()


func set_key(i: int, key: String) -> void:
	var k: Label = _items[i].key
	if k.text == "[%s]" % key:
		return
	k.text = "[%s]" % key
	layout()


func set_visible_item(i: int, on: bool) -> void:
	_items[i].row.visible = on
	layout()


## A click, or the item's key from the screen that owns the list.
func press(i: int) -> void:
	if i < 0 or i >= _items.size() or not _items[i].row.visible:
		return
	var it: Dictionary = _items[i]
	if it.confirm != "" and it.armed <= 0.0:
		it.armed = ARM_S
		it.label.text = it.confirm
		layout()
		Sfx.play("ui_click", -6.0)
		return
	disarm()
	Sfx.play("ui_click", -4.0)
	(it.cb as Callable).call()


func armed(i: int) -> bool:
	return _items[i].armed > 0.0


func disarm() -> void:
	for it in _items:
		if it.armed > 0.0:
			it.armed = 0.0
			it.label.text = it.text
	layout()


## Shows `note` in place of an item's words for a moment ("COPIED").
func flash(i: int, note: String) -> void:
	_items[i].armed = 0.0
	_items[i].flash = FLASH_S
	_items[i].label.text = note
	layout()


## Places the rows and sizes the list; called whenever an item changes.
func layout() -> void:
	var x := 0.0
	var y := 0.0
	var w := 0.0
	for it in _items:
		var row: Control = it.row
		if not row.visible:
			continue
		var l: Label = it.label
		var k: Label = it.key
		l.size = Vector2.ZERO
		k.size = Vector2.ZERO
		var h := l.size.y
		if horizontal:
			# "[R] RETRY SEED": the key in front, in the item's colour
			k.position = Vector2.ZERO
			l.position = Vector2(k.size.x + 4.0 if k.visible else 0.0, 0.0)
			row.position = Vector2(x, 0.0)
			row.size = Vector2(l.position.x + l.size.x, h)
			x += row.size.x + gap
			w = x - gap
		else:
			l.position = Vector2(TEXT_X, 0.0)
			k.position = Vector2(TEXT_X + l.size.x + KEY_GAP, 0.0)
			row.position = Vector2(0.0, y)
			row.size = Vector2((k.position.x + k.size.x) if k.visible else (TEXT_X + l.size.x), h)
			y += pitch
			w = maxf(w, row.size.x)
		var line: ColorRect = it.line
		line.position = Vector2(l.position.x, roundf(h * 0.5 + Ui.PIX_CAP * 0.5) + 1.0)
		line.size = Vector2(l.size.x, 1.0)
	var lh := Ui.font_bold.get_height(Ui.PIX)
	size = Vector2(w, lh if horizontal else maxf(0.0, y - pitch + lh))


func _notification(what: int) -> void:
	# a hidden list forgets the pointer and any armed item
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree() and not _items.is_empty():
		_hover = -1
		disarm()


func _process(_delta: float) -> void:
	var rd := Game.real_dt
	var changed := false
	for it in _items:
		if it.armed > 0.0:
			it.armed -= rd
			if it.armed <= 0.0:
				it.label.text = it.text
				changed = true
		if it.flash > 0.0:
			it.flash -= rd
			if it.flash <= 0.0:
				it.label.text = it.text
				changed = true
	if changed:
		layout()
	if not is_visible_in_tree():
		return
	var on := _hover if _hover >= 0 else current
	for i in _items.size():
		var it: Dictionary = _items[i]
		var lit: bool = i == on
		var col: Color = WARN if it.armed > 0.0 else (Color.WHITE if lit else it.col)
		if it.get("shown") != col:
			it.shown = col
			it.label.add_theme_color_override("font_color", col)
			if horizontal:
				it.key.add_theme_color_override("font_color", col)
			# on a row the pointed-at item is underlined instead of marked
			it.line.visible = i == _hover
	_mark.visible = not horizontal and on >= 0 and on < _items.size() and _items[on].row.visible
	if _mark.visible:
		var row: Control = _items[on].row
		_mark.position = Vector2(0.0, row.position.y + roundf((row.size.y - Ui.PIX_CAP) * 0.5) - 1.0)
