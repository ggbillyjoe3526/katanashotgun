class_name MapRegistry
## Every playable map. To add one: make a new script in scripts/maps/ that
## extends Arena, build its layout in _build_layout(), then add it here.
## Runs pick a map from their seed (only Shin-Kagura exists for now).
## The flat rooftop (rooftop.gd) stays as the base class of the vertical map.

const MAPS := [
	{"id": "shin_kagura", "script": preload("res://scripts/maps/well.gd")},
]


static func create_for_seed(rng: RandomNumberGenerator) -> Arena:
	var def: Dictionary = MAPS[rng.randi() % MAPS.size()]
	return def.script.new()


static func create(id: String) -> Arena:
	for def in MAPS:
		if def.id == id:
			return def.script.new()
	return MAPS[0].script.new()
