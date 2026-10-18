class_name Mutators
## Seeded wave modifiers. Most regular waves roll one; each trades risk for a
## score multiplier, so the same seed always plays out the same way.

const LIST := [
	{"id": "overdrive", "name": "IDATEN'S HASTE", "desc": "ENEMIES MOVE 25% FASTER", "score": 1.5, "enemy_speed": 1.25},
	{"id": "glass", "name": "MURAMASA'S CURSE", "desc": "YOU DEAL AND TAKE +50% DAMAGE", "score": 1.3, "dmg_out": 1.5, "dmg_in": 1.5},
	{"id": "bloodmoon", "name": "AKATSUKI", "desc": "TOUGHER ENEMIES - GLORY KILLS HEAL DOUBLE", "score": 1.4, "enemy_hp": 1.4, "exec_heal": 2.0},
	{"id": "drymag", "name": "YOMI BLACKOUT", "desc": "NO PASSIVE CELL RECHARGE", "score": 1.3, "regen": false},
	{"id": "swarm", "name": "HYAKKI YAKO", "desc": "60% MORE GRUNTS, BUT WEAKER", "score": 1.2, "grunt_count": 1.6, "grunt_hp": 0.7},
	{"id": "snipers", "name": "TEPPO VOLLEY", "desc": "DOUBLE THE GUNNERS", "score": 1.3, "gunner_count": 2.0},
	{"id": "ironclad", "name": "KANABO VANGUARD", "desc": "TWO EXTRA BRUTES", "score": 1.4, "extra_brutes": 2},
	{"id": "storm", "name": "RAIJIN'S STORM", "desc": "LIGHTNING AND HEAVY RAIN", "score": 1.25, "storm": true},
	{"id": "vampire", "name": "JOROGUMO'S BITE", "desc": "KILLS HEAL 2 HP - ENEMIES HIT 30% HARDER", "score": 1.2, "heal_kill": 2.0, "dmg_in": 1.3},
]


static func roll(rng: RandomNumberGenerator, wave: int) -> Dictionary:
	if wave < 2 or rng.randf() > 0.65:
		return {}
	return LIST[rng.randi() % LIST.size()]
