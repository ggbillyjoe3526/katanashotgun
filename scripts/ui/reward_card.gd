class_name RewardCard
extends Control
## The boss-reward item card (spec §11.2): after the boss tally a cut-in
## announces it, then this card deals in with the unlock's name, what it
## changes and its colours, holds long enough to read, and leaves. The words
## sit on a plain dark plate and hold still (spec §9.9).

const W := 230.0
const H := 96.0
const DEAL := 0.28
const HOLD := 3.4
const OUT := 0.3

var plate: Shard
var ribbon: Shard
var tag: Label
var name_label: Label
var slot_label: Label
var desc_label: Label
var hint_label: Label
var swatch_a: ColorRect
var swatch_b: ColorRect
var _t := 99.0
var _on := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	size = Vector2(W, H)
	plate = Shard.make(Color(0.02, 0.01, 0.06, 0.94), 10.0)
	plate.size = size
	plate.brackets = Color.WHITE
	plate.bracket_len = 10.0
	add_child(plate)
	ribbon = Shard.make(Color.WHITE, 0.0)
	ribbon.set_skew(0.12)
	ribbon.position = Vector2(10, -8)
	ribbon.size = Vector2(120, 16)
	add_child(ribbon)
	tag = Ui.label("BOSS REWARD", Ui.font_bold, 10, Color(0.02, 0.0, 0.03))
	tag.position = Vector2(22, -9)
	add_child(tag)
	name_label = Ui.label("", Ui.font_big, 14, Color.WHITE, 2)
	add_child(name_label)
	slot_label = Ui.label("", Ui.font_bold, 10, Color.WHITE, 2)
	add_child(slot_label)
	desc_label = Ui.label("", Ui.font_bold, 10, Color(0.9, 0.88, 1.0), 2)
	add_child(desc_label)
	hint_label = Ui.label("EQUIP IT IN THE ARMORY: PAUSE OR TITLE", Ui.font_bold, 10, Color(0.75, 0.72, 0.9), 2)
	add_child(hint_label)
	swatch_a = Ui.rect(Color.WHITE, Vector2.ZERO, Vector2(10, 46))
	add_child(swatch_a)
	swatch_b = Ui.rect(Color.WHITE, Vector2.ZERO, Vector2(4, 46))
	add_child(swatch_b)


func play(def: Dictionary) -> void:
	var main_col: Color = def.get("edge", def.get("coil", Color.WHITE))
	var second: Color = def.get("trim", def.get("core", Color.WHITE))
	name_label.text = str(def.get("name", ""))
	slot_label.text = "NEW %s" % str(Rewards.SLOT_LABELS.get(def.get("slot", ""), "LOOK"))
	slot_label.add_theme_color_override("font_color", main_col)
	desc_label.text = str(def.get("desc", ""))
	ribbon.color = main_col
	plate.outline = main_col
	plate.shadow = main_col.darkened(0.4)
	swatch_a.color = main_col
	swatch_b.color = second
	# wide enough for the longest line
	var w := W
	for l in [name_label, slot_label, desc_label, hint_label]:
		w = maxf(w, 40.0 + l.get_minimum_size().x + 14.0)
	size = Vector2(w, H)
	plate.size = size
	_t = 0.0
	_on = true
	visible = true
	Sfx.play("levelup", -3.0, 1.15, 0.0)


func ready_to_continue() -> bool:
	return not _on or _t >= DEAL + HOLD


func _process(_delta: float) -> void:
	if not _on:
		return
	_t += Game.real_dt
	var vs := get_parent_area_size() if get_parent() is Control else Vector2(480, 270)
	var k := Juice.ease_out_back(clampf(_t / DEAL, 0.0, 1.0))
	var out_k := clampf((_t - DEAL - HOLD) / OUT, 0.0, 1.0)
	var base := Vector2(roundf((vs.x - size.x) * 0.5), roundf(vs.y * 0.5 - H * 0.5 + 18))
	position = base + Vector2(0, roundf((1.0 - k) * 160.0 + out_k * out_k * 200.0))
	pivot_offset = size * 0.5
	rotation = (1.0 - k) * 0.25
	modulate.a = (1.0 if _t > 0.0 else 0.0) * (1.0 - out_k)
	# layout inside the card: colour swatch on the left, words on the right
	swatch_a.position = Vector2(14, 18)
	swatch_b.position = Vector2(26, 18)
	for l in [name_label, slot_label, desc_label, hint_label]:
		l.size = Vector2.ZERO
	slot_label.position = Vector2(40, 12)
	name_label.position = Vector2(40, 26)
	desc_label.position = Vector2(40, 50)
	hint_label.position = Vector2(40, 72)
	if out_k >= 1.0:
		_on = false
		visible = false
