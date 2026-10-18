class_name ProfileMigrations
## Upgrades an old profile, one version at a time, to Profile.VERSION.
## To change the format: bump Profile.VERSION, add a step here that turns
## the previous version into the new one, and a Gut test that loads a file
## written by the previous version. Never edit a step that has shipped.
##
## Version 0 is the prototype (v0.3), which only kept user://scores.json.

const LEGACY_SCORES := "scores.json"


static func steps() -> Dictionary:
	return {0: _v0_to_v1}


## Returns data upgraded to `target`, or {} if a step is missing.
static func migrate(data: Dictionary, from_version: int, target: int) -> Dictionary:
	var out := data.duplicate(true)
	var v := from_version
	var all := steps()
	while v < target:
		if not all.has(v):
			push_warning("save: no migration from profile version %d" % v)
			return {}
		out = all[v].call(out)
		v += 1
	return out


## The prototype's top 10 becomes a v0 profile, ready to migrate.
static func from_legacy_scores(text: String) -> Dictionary:
	var scores := []
	var parsed = JSON.parse_string(text)
	if parsed is Array:
		for e in parsed:
			if e is Dictionary and e.has("score"):
				scores.append(e)
	return {"high_scores": scores}


static func _v0_to_v1(d: Dictionary) -> Dictionary:
	return {
		"player": {"level": 1, "xp": 0},
		"unlocks": [],
		"equipped": {"katana": "", "shotgun": ""},
		"high_scores": d.get("high_scores", []),
		"lifetime": {},
		"settings": {},
	}
