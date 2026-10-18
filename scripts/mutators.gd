class_name Mutators
## Seeded wave modifiers. Most regular waves roll one; each trades risk for a
## score multiplier, so the same seed always plays out the same way.
## `min_wave` keeps the harsher ones out of the opening waves (spec §6.1).

const LIST := [
	{"id": "overdrive", "name": "OKURI-INU HUNT", "desc": "ENEMIES MOVE 25% FASTER", "score": 1.5, "enemy_speed": 1.25},
	{"id": "glass", "name": "MURAMASA'S CURSE", "desc": "YOU DEAL AND TAKE +50% DAMAGE", "score": 1.3, "dmg_out": 1.5, "dmg_in": 1.5},
	{"id": "bloodmoon", "name": "AKATSUKI", "desc": "TOUGHER ENEMIES - GLORY KILLS HEAL DOUBLE", "score": 1.4, "enemy_hp": 1.4, "exec_heal": 2.0},
	{"id": "drymag", "name": "YOMI BLACKOUT", "desc": "NO PASSIVE CELL RECHARGE", "score": 1.3, "regen": false},
	{"id": "swarm", "name": "HYAKKI YAKO", "desc": "60% MORE GRUNTS, BUT WEAKER", "score": 1.2, "grunt_count": 1.6, "grunt_hp": 0.7},
	{"id": "snipers", "name": "TEPPO VOLLEY", "desc": "DOUBLE THE GUNNERS", "score": 1.3, "gunner_count": 2.0},
	{"id": "ironclad", "name": "KANABO VANGUARD", "desc": "TWO EXTRA BRUTES", "score": 1.4, "extra_brutes": 2},
	{"id": "storm", "name": "RAIJIN'S STORM", "desc": "LIGHTNING STRIKES THE ROOF - LEAVE THE RED RINGS", "score": 1.4, "storm": true, "strikes": true},
	{"id": "grudge", "name": "ONRYO'S GRUDGE", "desc": "THE DEAD BURST A MOMENT LATER - LEAVE THE RED RINGS", "score": 1.3, "grudge": true, "min_wave": 3},
	{"id": "plated", "name": "KABUTO PLATE", "desc": "GRUNTS AND GUNNERS WEAR ARMOR - BLAST THEN SLASH", "score": 1.3, "light_armor": 0.4},
	{"id": "matsuri", "name": "MATSURI RUSH", "desc": "THE COMBO TIMER RUNS TWICE AS FAST", "score": 1.4, "combo_window": 0.5},
	{"id": "kanashibari", "name": "KANASHIBARI", "desc": "DASHES RECHARGE HALF AS FAST", "score": 1.3, "dash_recharge": 2.0, "min_wave": 3},
	{"id": "hannya", "name": "HANNYA'S WRATH", "desc": "WOUNDED ENEMIES ENRAGE: FASTER AND HARDER HITTING", "score": 1.3, "enrage": true, "min_wave": 4},
	{"id": "umibozu", "name": "UMIBOZU SWELL", "desc": "THE WHOLE WAVE COMES AT ONCE", "score": 1.4, "max_alive": 1.6, "spawn_rate": 0.5, "min_wave": 4},
	{"id": "senryo", "name": "SENRYO BOUNTY", "desc": "HEADSHOTS AND GLORY KILLS PAY DOUBLE - OTHER KILLS HALF", "score": 1.2, "bounty": true},
]


static func get_def(id: String) -> Dictionary:
	for m in LIST:
		if m.id == id:
			return m
	return {}


## The mutator for `wave`, never the same as the wave before (`last_id`).
## Always two draws from `rng` (or none on wave 1), so the wave line-ups that
## follow stay in step whichever mutator comes up.
static func roll(rng: RandomNumberGenerator, wave: int, last_id := "") -> Dictionary:
	if wave < 2:
		return {}
	var chance := rng.randf()
	var pick := rng.randi()
	if chance > 0.65:
		return {}
	var pool := []
	for m in LIST:
		if int(m.get("min_wave", 2)) <= wave and m.id != last_id:
			pool.append(m)
	return pool[pick % pool.size()]
