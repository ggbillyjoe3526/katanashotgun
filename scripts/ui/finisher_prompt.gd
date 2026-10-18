class_name FinisherPrompt
extends Control
## The glory kill prompt just under the crosshair: a gold key cap with the
## bound key ("F") and the move's name on a dark plate. It leans left, ending
## just past the crosshair, so it never runs into the kill tags stacking down
## the right (and sits under "NO CHARGE" on the left). It shows while a staggered
## enemy is in reach, so the prompt and the world always agree (spec §3.4).
## Readability (spec §9.9): it pops in fast and then holds perfectly still in
## one fixed spot. Only the key cap's glow pulses; the words never move,
## flicker or scramble.

const GOLD := Color(1.0, 0.8, 0.15)
const DEATHBLOW_RED := Color(1.0, 0.15, 0.2)
const INK := Color(0.03, 0.0, 0.06)
const GAP_BELOW_CROSSHAIR := 16.0
const RIGHT_OF_CROSSHAIR := 8.0 # the kill tags start 18 px right of it
const POP_TIME := 0.1
const FADE_TIME := 0.08

var _cap: Shard
var _key: Label
var _plate: Shard
var _text: Label
var _t := 0.0 # seconds since it appeared
var _fade := 0.0 # seconds since the target was lost
var _shown := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cap = Shard.make(GOLD, 3.0, Color(0, 0, 0, 0), Color.WHITE)
	add_child(_cap)
	_key = Ui.label("F", Ui.font_big, 10, INK, 0)
	_cap.add_child(_key)
	_plate = Shard.make(Color(0.02, 0.0, 0.05, 0.88), 3.0, Color(0, 0, 0, 0), GOLD)
	add_child(_plate)
	_text = Ui.label("GLORY KILL", Ui.font_bold, 10, Color.WHITE, 0)
	_plate.add_child(_text)
	visible = false


## Called by the HUD every frame with the move F would do right now
## ("GLORY KILL", "DEATHBLOW", or "" when no enemy is in reach), the
## crosshair position and real (unscaled) delta time.
func refresh(move: String, crosshair: Vector2, rd: float) -> void:
	if move != "":
		if not _shown:
			_shown = true
			_t = 0.0
			_key.text = Ui.key_name("finisher")
		_fade = 0.0
		_text.text = move
		_plate.outline = DEATHBLOW_RED if move == "DEATHBLOW" else GOLD
	elif _shown:
		_fade += rd
		if _fade >= FADE_TIME:
			_shown = false
	visible = _shown
	if not _shown:
		return
	_t += rd
	_layout(crosshair)
	var pop := Juice.ease_out(_t / POP_TIME)
	scale = Vector2.ONE * lerpf(1.3, 1.0, pop)
	modulate.a = clampf(_t / (POP_TIME * 0.5), 0.0, 1.0) * (1.0 - _fade / FADE_TIME)
	# the cap glows; dark ink on gold or white reads on every frame
	_cap.color = GOLD.lerp(Color.WHITE, 0.3 * (0.5 + 0.5 * sin(_t * 10.0)))


func _layout(crosshair: Vector2) -> void:
	_key.size = Vector2.ZERO
	_text.size = Vector2.ZERO
	var h := maxf(_key.size.y, _text.size.y) + 2.0
	_cap.size = Vector2(maxf(_key.size.x + 8.0, h), h)
	_key.position = ((_cap.size - _key.size) * 0.5).round()
	_plate.size = Vector2(_text.size.x + 10.0, h)
	_text.position = Vector2(5.0, roundf((h - _text.size.y) * 0.5))
	_plate.position = Vector2(_cap.size.x + 3.0, 0.0)
	size = Vector2(_plate.position.x + _plate.size.x, h)
	pivot_offset = (size * 0.5).round()
	position = Vector2(roundf(crosshair.x + RIGHT_OF_CROSSHAIR - size.x), crosshair.y + GAP_BELOW_CROSSHAIR)
