class_name ArmoryPanel
extends Control
## The armory, on the title and pause screens (spec §11.2): the boss-reward looks, picked with 1
## (katana edge) and 2 (shotgun coil), or a click on the row. Each row shows
## the equipped look's colour, its name and how many of that slot's looks
## are owned. Redraws when the profile changes.

const SLOTS := ["katana", "shotgun"]
const ROW_H := 13.0

var rows: Array[Label] = []
var swatches: Array[ColorRect] = []
var header: Label


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	header = Ui.label("ARMORY", Ui.font_big, 10, Color(1.0, 0.85, 0.25), 2)
	add_child(header)
	for i in SLOTS.size():
		var sw := Ui.rect(Color.WHITE, Vector2.ZERO, Vector2(7, 7))
		add_child(sw)
		swatches.append(sw)
		var l := Ui.label("", Ui.font_bold, 10, Color(0.95, 0.92, 1.0), 2)
		add_child(l)
		rows.append(l)


func _ready() -> void:
	Profile.changed.connect(refresh)
	refresh()


func refresh() -> void:
	var owned := 0
	for i in SLOTS.size():
		var slot: String = SLOTS[i]
		var look := Rewards.look(slot, Profile.get_equipped(slot))
		var have := Rewards.choices(slot, Profile.unlocks).size() - 1
		owned += have
		rows[i].text = "[%d] %s  %d/%d" % [i + 1, look.name, have, Rewards.count_for_slot(slot)]
		swatches[i].color = look.get("edge", look.get("coil", Color.WHITE))
	if owned == 0:
		rows[0].text = "FELL BOSSES TO UNLOCK"
		rows[1].text = "NEW WEAPON LOOKS"
	for sw in swatches:
		sw.visible = owned > 0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		for i in rows.size():
			var r := Rect2(0, rows[i].position.y, size.x, ROW_H)
			if r.has_point(event.position) and swatches[i].visible:
				Profile.cycle_equipped(SLOTS[i])
				Sfx.play("ui_click", -4.0)


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	var w := 0.0
	header.size = Vector2.ZERO
	header.position = Vector2.ZERO
	w = header.size.x
	for i in rows.size():
		var l := rows[i]
		l.size = Vector2.ZERO
		var x := 11.0 if swatches[i].visible else 0.0
		l.position = Vector2(x, header.size.y - 1 + i * ROW_H)
		swatches[i].position = Vector2(0, l.position.y + 5)
		w = maxf(w, x + l.size.x)
	size = Vector2(w, header.size.y - 1 + rows.size() * ROW_H + 2)
