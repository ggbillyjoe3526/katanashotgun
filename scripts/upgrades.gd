class_name Upgrades
## Level-up augments. Each changes HOW a weapon behaves (not +2% damage).
## Effects are read live through Game.rank(id) wherever they apply.

const LIST := [
	{"id": "edge", "name": "MASAMUNE EDGE", "tag": "KATANA", "max": 3,
		"desc": "Katana damage +35%. Cuts through armor more easily."},
	{"id": "reach", "name": "LONG REACH", "tag": "KATANA", "max": 2,
		"desc": "Katana range +0.8m and a wider arc."},
	{"id": "wave", "name": "SUSANOO'S WAVE", "tag": "KATANA", "max": 3,
		"desc": "Every few slashes launch a blood blade that pierces enemies. More ranks: more often."},
	{"id": "vamp", "name": "VAMPIRIC STEEL", "tag": "KATANA", "max": 3,
		"desc": "Heal 1 HP for every enemy your katana hits."},
	{"id": "battery", "name": "BLOOD BATTERY", "tag": "SYNERGY", "max": 2,
		"desc": "Katana kills charge +1 extra cell."},
	{"id": "pellets", "name": "RAIJIN'S FORK", "tag": "SHOTGUN", "max": 3,
		"desc": "+3 arcs per blast."},
	{"id": "tube", "name": "FUJIN BANK", "tag": "SHOTGUN", "max": 3,
		"desc": "+2 max cells. Charges them now."},
	{"id": "dragon", "name": "KAGUTSUCHI FLAME", "tag": "SHOTGUN", "max": 2,
		"desc": "Arcs set enemies alight. Burning enemies take damage over time."},
	{"id": "concuss", "name": "HIGH VOLTAGE", "tag": "SHOTGUN", "max": 2,
		"desc": "Blasts stagger 60% harder and hurl enemies back."},
	{"id": "dash", "name": "IDATEN DRIVE", "tag": "MOBILITY", "max": 2,
		"desc": "+1 dash charge and faster dash recharge."},
	{"id": "dashcut", "name": "KAGE STEP", "tag": "MOBILITY", "max": 2,
		"desc": "Dashing through enemies slices them."},
	{"id": "chain", "name": "HYAKUNIN-GIRI", "tag": "SYNERGY", "max": 1,
		"desc": "Glory kills stagger every enemy within 9m. Glory kill them all."},
	{"id": "hotbarrel", "name": "FEEDBACK LOOP", "tag": "SYNERGY", "max": 1,
		"desc": "Shotgun kills refund a dash charge."},
	{"id": "chrome", "name": "KONGO HEART", "tag": "BODY", "max": 3,
		"desc": "+25 max HP and a full heal."},
]

const TAG_COLORS := {
	"KATANA": Color(0.4, 0.95, 1.0),
	"SHOTGUN": Color(0.45, 0.7, 1.0),
	"SYNERGY": Color(1.0, 0.25, 0.55),
	"MOBILITY": Color(0.6, 1.0, 0.45),
	"BODY": Color(0.95, 0.9, 0.5),
}


static func get_def(id: String) -> Dictionary:
	for u in LIST:
		if u.id == id:
			return u
	return {}


static func roll(owned: Dictionary, n: int) -> Array:
	var pool := []
	for u in LIST:
		if owned.get(u.id, 0) < u.max:
			pool.append(u)
	# seeded Fisher-Yates so the same run seed offers the same augments
	var rng: RandomNumberGenerator = Game.rng_upgrades
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	return pool.slice(0, mini(n, pool.size()))
