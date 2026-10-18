class_name Rewards
## Boss rewards (spec §11.2): the only unlocks in the game, and cosmetic
## only, so seeded scores stay comparable. Each boss has an ordered list;
## every time it is felled, its next locked reward unlocks (the default drop
## rule until the owner picks one, spec §19). Nothing here draws from the
## run's seeded RNG.
##
## slot "katana" tints the DOJIGIRI's edge and wrap; slot "shotgun" tints the
## RAIJIN-12's coils, cells and idle crackle. "" in a slot is the stock look.

const STOCK := {
	"katana": {"name": "STOCK EDGE", "edge": Color(0.4, 0.95, 1.0), "trim": Color(1.0, 0.2, 0.6)},
	"shotgun": {"name": "STOCK COIL", "coil": Color(0.35, 0.75, 1.0), "core": Color(0.75, 0.92, 1.0), "glow": Color(0.25, 0.45, 1.0)},
}

const LIST := [
	{"id": "edge_kagerou", "boss": "ninja", "slot": "katana", "name": "KAGEROU EDGE",
		"desc": "HEAT-HAZE FIRMWARE FOR THE DOJIGIRI", "edge": Color("ff9a2a"), "trim": Color("ffd23f")},
	{"id": "coil_kitsunebi", "boss": "ninja", "slot": "shotgun", "name": "KITSUNEBI COIL",
		"desc": "FOXFIRE BURNS IN THE RAIJIN-12", "coil": Color("3dff8a"), "core": Color("c8ffe0"), "glow": Color("19c46a")},
	{"id": "edge_kanayago", "boss": "mech", "slot": "katana", "name": "KANAYAGO EDGE",
		"desc": "FORGED IN THE IRON GOD'S KERNEL", "edge": Color("ffd23f"), "trim": Color("ff5a2a")},
	{"id": "coil_akagane", "boss": "mech", "slot": "shotgun", "name": "AKAGANE COIL",
		"desc": "SALVAGED COPPER FROM TETSUGUMO", "coil": Color("ff6a2a"), "core": Color("ffd0a0"), "glow": Color("ff3d1a")},
	{"id": "edge_onibi", "boss": "oni", "slot": "katana", "name": "ONIBI EDGE",
		"desc": "GHOST-FIRE FROM MOUNT OE", "edge": Color("ff2b4a"), "trim": Color("2af6ff")},
	{"id": "coil_raiko", "boss": "oni", "slot": "shotgun", "name": "RAIKO COIL",
		"desc": "THE OGRE-SLAYER'S SIGNAL", "coil": Color("ff3df2"), "core": Color("ffc8f8"), "glow": Color("c41ad0")},
]

const SLOT_LABELS := {"katana": "KATANA EDGE", "shotgun": "SHOTGUN COIL"}


static func get_def(id: String) -> Dictionary:
	for r in LIST:
		if r.id == id:
			return r
	return {}


## The next reward felling `boss` would unlock, or {} once it has none left.
static func next_for_boss(boss: String, owned: Array) -> Dictionary:
	for r in LIST:
		if r.boss == boss and not owned.has(r.id):
			return r
	return {}


## The look for a slot: the equipped reward's colours, or stock.
static func look(slot: String, id: String) -> Dictionary:
	var def := get_def(id)
	if def.is_empty() or def.slot != slot:
		return STOCK[slot]
	return def


## Ids a slot can cycle through: stock ("") then every owned reward for it.
static func choices(slot: String, owned: Array) -> Array:
	var out := [""]
	for r in LIST:
		if r.slot == slot and owned.has(r.id):
			out.append(r.id)
	return out


static func count_for_slot(slot: String) -> int:
	var n := 0
	for r in LIST:
		if r.slot == slot:
			n += 1
	return n
