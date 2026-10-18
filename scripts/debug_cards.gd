extends Node
## Debug-only tour of every level-up card, three at a time, for checking that
## each name, description and build line fits and reads cleanly.
## Run with:  godot --path . -- --cardtour
## Each hand holds 1.2 s; the last card of each hand is shown RECOMMENDED.

const HOLD := 1.2

var t := 0.0
var hand := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.state = "playing"
	Game.hud.hide_title()


func _process(_delta: float) -> void:
	t += Game.real_dt
	var want := int(t / HOLD)
	var hands := ceili(Upgrades.LIST.size() / 3.0)
	if want >= hands:
		get_tree().quit()
		return
	if want == hand:
		return
	hand = want
	var cards := Upgrades.LIST.slice(hand * 3, hand * 3 + 3)
	# own one partner of the last card so it shows as RECOMMENDED
	Game.upgrades = {}
	var last: Dictionary = cards[-1]
	for b in Upgrades.builds_of(last.id):
		for c in b.cards:
			if c != last.id and not cards.any(func(u): return u.id == c):
				Game.upgrades[c] = 1
				break
		if not Game.upgrades.is_empty():
			break
	print("CARD TOUR hand %d: %s" % [hand, ", ".join(cards.map(func(u): return u.id))])
	Game.hud.show_levelup(cards, func(_id): pass)
