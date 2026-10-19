class_name RunSnapshot
## Suspend and resume (spec §11.3): everything a run needs to carry on from
## the start of its next wave. Taken between waves only, after the tally has
## paid out. The map, palette and music come back from the seed, and the
## wave streams reseed from the seed and the wave number when the next wave
## starts; the map and augment streams are restored to their exact state, so
## the rest of the run plays out as if it had never stopped. RNG states are
## 64-bit, so they are stored as strings (JSON numbers lose precision past
## 2^53). Older snapshots also carry a "waves" state, which is ignored.

const GAME_INTS := ["score", "best_combo", "kills", "executions", "headshots", "deflects", "bosses_killed", "level", "pending_levelups", "best_tally", "best_tally_wave"]


## `next_wave` is the wave the run resumes on.
static func capture(next_wave: int, director: WaveDirector, player: Player) -> Dictionary:
	var g := {}
	for k in GAME_INTS:
		g[k] = int(Game.get(k))
	g["xp"] = Game.xp
	g["xp_next"] = Game.xp_next
	g["run_time"] = Game.run_time
	return {
		"seed": Game.run_seed,
		"next_wave": next_wave,
		"game": g,
		"upgrades": Game.upgrades.duplicate(),
		"hints": Game.hints_shown.keys(),
		"boss_kinds": Game.bosses_felled.duplicate(),
		"rng": {
			"map": str(Game.rng_map.state),
			"upgrades": str(Game.rng_upgrades.state),
		},
		"director": {"boss_cycle": director._boss_cycle.duplicate(), "cycle_count": director._cycle_count, "last_mutator": director.last_mutator},
		"player": {
			"hp": player.hp, "cells": player.cells, "dash_charges": player.dash_charges,
			"slash_count": player.slash_count,
		},
		"version": str(ProjectSettings.get_setting("application/config/version", "")),
	}


## Restores a snapshot onto a freshly built run (same seed, map already
## built). Returns the wave to start on.
static func apply(snap: Dictionary, director: WaveDirector, player: Player) -> int:
	var g: Dictionary = snap.get("game", {})
	for k in GAME_INTS:
		Game.set(k, int(g.get(k, Game.get(k))))
	Game.xp = float(g.get("xp", Game.xp))
	Game.xp_next = float(g.get("xp_next", Game.xp_next))
	Game.run_time = float(g.get("run_time", 0.0))
	Game.upgrades = {}
	var ups: Dictionary = snap.get("upgrades", {})
	for id in ups:
		if not Upgrades.get_def(str(id)).is_empty():
			Game.upgrades[str(id)] = int(ups[id])
	Game.hints_shown = {}
	for h in snap.get("hints", []):
		Game.hints_shown[str(h)] = true
	Game.bosses_felled = []
	for b in snap.get("boss_kinds", []):
		Game.bosses_felled.append(str(b))
	var rng: Dictionary = snap.get("rng", {})
	Game.rng_map.state = str(rng.get("map", str(Game.rng_map.state))).to_int()
	Game.rng_upgrades.state = str(rng.get("upgrades", str(Game.rng_upgrades.state))).to_int()
	var d: Dictionary = snap.get("director", {})
	director._boss_cycle = []
	for k in d.get("boss_cycle", []):
		director._boss_cycle.append(str(k))
	director._cycle_count = int(d.get("cycle_count", 0))
	director.last_mutator = str(d.get("last_mutator", ""))
	# augments that raise maximums (HP, cells, dashes) re-apply rank by rank,
	# then the exact values on the snapshot win
	for id in Game.upgrades:
		for i in int(Game.upgrades[id]):
			player.on_upgrade(id)
	var p: Dictionary = snap.get("player", {})
	player.hp = clampf(float(p.get("hp", player.max_hp)), 1.0, player.max_hp)
	player.cells = clampi(int(p.get("cells", player.cells)), 0, player.max_cells)
	player.dash_charges = clampf(float(p.get("dash_charges", player.max_dash)), 0.0, float(player.max_dash))
	player.slash_count = int(p.get("slash_count", 0))
	player.vm.set_cells(player.cells, player.max_cells)
	return maxi(int(snap.get("next_wave", 1)), 1)
