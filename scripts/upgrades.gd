class_name Upgrades
## Level-up augments. Each changes a rule of the loop (blast, stagger, slash,
## glory kill, recharge), never a plain +% number. Cards that share a BUILD
## link: an offered card that links to one you own is marked RECOMMENDED, and
## every offer after your first pick holds at least one of them when it can.
## Effects are read live through Game.rank(id) wherever they apply.

const LIST := [
	# ---- shotgun
	{"id": "fork", "name": "RAIJIN'S FORK", "tag": "SHOTGUN", "max": 1,
		"desc": "Arcs leap from every enemy you blast to 2 more nearby."},
	{"id": "ikazuchi", "name": "IKAZUCHI SURGE", "tag": "SHOTGUN", "max": 2,
		"desc": "Blasts stagger 60% harder and hurl enemies back."},
	{"id": "inazuma", "name": "INAZUMA OVERLOAD", "tag": "SHOTGUN", "max": 1,
		"desc": "+2 cells. The blast that spends your last cell fires double arcs and staggers all it hits."},
	{"id": "dragon", "name": "KAGUTSUCHI FLAME", "tag": "SHOTGUN", "max": 2,
		"desc": "Arcs set enemies alight. Burning enemies take damage over time."},
	{"id": "onibi", "name": "ONIBI CHAIN", "tag": "SHOTGUN", "max": 1, "requires": ["dragon", "homura"],
		"desc": "Burning enemies that die burst and set everyone within 5m alight."},
	{"id": "hachiman", "name": "HACHIMAN FOCUS", "tag": "SHOTGUN", "max": 1,
		"desc": "A tight choke: arcs fly closer together and hit full strength out to 18m."},
	{"id": "yoichi", "name": "YOICHI'S MARK", "tag": "SHOTGUN", "max": 1,
		"desc": "A headshot blast gives its cell back."},
	{"id": "gasha", "name": "GASHADOKURO BURST", "tag": "SHOTGUN", "max": 1,
		"desc": "Headshot kills explode, staggering and hurting enemies within 5m."},
	# ---- katana
	{"id": "edge", "name": "MASAMUNE EDGE", "tag": "KATANA", "max": 1,
		"desc": "The third cut of every combo hits twice as hard, cuts through armor and staggers most enemies."},
	{"id": "wave", "name": "SUSANOO'S WAVE", "tag": "KATANA", "max": 2,
		"desc": "Every few slashes launch a blood blade that pierces enemies. More ranks: more often."},
	{"id": "yata", "name": "YATA MIRROR", "tag": "KATANA", "max": 1,
		"desc": "Deflected bolts split into three."},
	{"id": "homura", "name": "HOMURA EDGE", "tag": "KATANA", "max": 1,
		"desc": "The katana sets enemies alight and cuts burning enemies 50% deeper."},
	{"id": "chimatsuri", "name": "CHIMATSURI STEEL", "tag": "KATANA", "max": 2,
		"desc": "Katana hits heal you. At full health the healing charges cells instead."},
	{"id": "battery", "name": "BLOOD BATTERY", "tag": "KATANA", "max": 2,
		"desc": "Katana kills charge +1 extra cell."},
	# ---- glory kills
	{"id": "kurama", "name": "KURAMA LEAP", "tag": "GLORY", "max": 1,
		"desc": "Glory kill reach doubles to 9m. You leap across to the target."},
	{"id": "chain", "name": "HYAKUNIN-GIRI", "tag": "GLORY", "max": 1,
		"desc": "Glory kills stagger every enemy within 9m. Glory kill them all."},
	{"id": "kamaitachi", "name": "KAMAITACHI RING", "tag": "GLORY", "max": 1,
		"desc": "Glory kills fire a ring of 8 blood blades out around you."},
	{"id": "taiko", "name": "TAIKO FRENZY", "tag": "GLORY", "max": 1,
		"desc": "Glory kills add +5 combo and freeze the combo timer for 3 seconds."},
	# ---- dash
	{"id": "idaten", "name": "IDATEN DRIVE", "tag": "DASH", "max": 1,
		"desc": "+1 dash, and every dash charges a cell."},
	{"id": "fujin", "name": "FUJIN'S RETURN", "tag": "DASH", "max": 1,
		"desc": "Shotgun kills give you a dash back."},
	{"id": "dashcut", "name": "KAGE STEP", "tag": "DASH", "max": 2,
		"desc": "Dashing through enemies slices them."},
	{"id": "utsusemi", "name": "UTSUSEMI SHELL", "tag": "DASH", "max": 1,
		"desc": "A hit that would hurt you spends a dash instead. Once every 3 seconds."},
	# ---- body
	{"id": "chrome", "name": "KONGO HEART", "tag": "BODY", "max": 3,
		"desc": "+25 max HP and a full heal."},
	{"id": "sanzu", "name": "SANZU REPRIEVE", "tag": "BODY", "max": 1,
		"desc": "Once per wave, a killing blow leaves you on 1 HP instead."},
]

## Three cards that play as one style. A card can sit in two builds. Owning
## two of a build links it; owning all three completes it. Names are labels
## only: no hidden bonus, the cards themselves are the payoff.
const BUILDS := [
	{"id": "storm", "name": "STORM RUNNER", "cards": ["idaten", "fujin", "inazuma"]},
	{"id": "thunder", "name": "THUNDER CHAIN", "cards": ["fork", "ikazuchi", "inazuma"]},
	{"id": "inferno", "name": "INFERNO", "cards": ["dragon", "homura", "onibi"]},
	{"id": "headhunter", "name": "HEADHUNTER", "cards": ["hachiman", "yoichi", "gasha"]},
	{"id": "ronin", "name": "RONIN", "cards": ["edge", "wave", "yata"]},
	{"id": "blood", "name": "BLOOD ENGINE", "cards": ["chimatsuri", "battery", "sanzu"]},
	{"id": "executioner", "name": "EXECUTIONER", "cards": ["kurama", "chain", "kamaitachi"]},
	{"id": "showstopper", "name": "SHOWSTOPPER", "cards": ["taiko", "chain", "ikazuchi"]},
	{"id": "ghost", "name": "GHOST", "cards": ["dashcut", "utsusemi", "idaten"]},
]

const TAG_COLORS := {
	"KATANA": Color(0.4, 0.95, 1.0),
	"SHOTGUN": Color(0.45, 0.7, 1.0),
	"GLORY": Color(1.0, 0.25, 0.55),
	"DASH": Color(0.6, 1.0, 0.45),
	"BODY": Color(0.95, 0.9, 0.5),
}

## The RECOMMENDED chip and the build lines on a card.
const LINK_COLOR := Color(1.0, 0.85, 0.25)


static func get_def(id: String) -> Dictionary:
	for u in LIST:
		if u.id == id:
			return u
	return {}


## The builds a card belongs to.
static func builds_of(id: String) -> Array:
	var out := []
	for b in BUILDS:
		if id in b.cards:
			out.append(b)
	return out


## How many of a build's cards are owned.
static func build_count(build: Dictionary, owned: Dictionary) -> int:
	var n := 0
	for c in build.cards:
		if owned.get(c, 0) > 0:
			n += 1
	return n


## True when the card shares a build with a different card already owned:
## picking it moves a build forward. (A rank-up of an owned card isn't a link.)
static func is_recommended(id: String, owned: Dictionary) -> bool:
	if owned.get(id, 0) > 0:
		return false
	for b in builds_of(id):
		for c in b.cards:
			if c != id and owned.get(c, 0) > 0:
				return true
	return false


static func _offerable(u: Dictionary, owned: Dictionary) -> bool:
	if owned.get(u.id, 0) >= u.max:
		return false
	var req: Array = u.get("requires", [])
	if req.is_empty():
		return true
	for r in req:
		if owned.get(r, 0) > 0:
			return true
	return false


## The augments to offer. A seeded Fisher-Yates over the cards not yet at max
## rank, so the same seed and the same picks always give the same offers.
## When you own a build card and a linking card is still available, at least
## one of the offers links to your build.
static func roll(owned: Dictionary, n: int, rng: RandomNumberGenerator = null) -> Array:
	if rng == null:
		rng = Game.rng_upgrades
	var pool := []
	for u in LIST:
		if _offerable(u, owned):
			pool.append(u)
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var out := pool.slice(0, mini(n, pool.size()))
	if out.is_empty():
		return out
	for u in out:
		if is_recommended(u.id, owned):
			return out
	# no link among the first n: the first linking card in the shuffled order
	# takes the last slot (no extra draw, so the stream stays in step)
	for k in range(out.size(), pool.size()):
		if is_recommended(pool[k].id, owned):
			out[out.size() - 1] = pool[k]
			break
	return out


## What a pick does to your builds, for the popup: "" when it changes none,
## otherwise "<BUILD> LINKED" (2 of 3) or "<BUILD> COMPLETE" (3 of 3).
## `owned` already includes the pick.
static func build_news(id: String, owned: Dictionary) -> String:
	if owned.get(id, 0) != 1:
		return ""
	var best := ""
	var best_n := 1
	for b in builds_of(id):
		var c := build_count(b, owned)
		if c > best_n:
			best_n = c
			best = b.name
	if best == "":
		return ""
	return "%s %s" % [best, "COMPLETE" if best_n >= 3 else "LINKED"]


## One line per build that has at least one card owned, e.g. "RONIN 2/3".
static func build_lines(owned: Dictionary) -> Array:
	var out := []
	for b in BUILDS:
		var c := build_count(b, owned)
		if c > 0:
			out.append("%s %d/3" % [b.name, c])
	return out
