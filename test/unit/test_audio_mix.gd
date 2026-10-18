extends GutTest
## Audio mix (spec §10.1, §10.3): the five buses exist with music on top, every
## cue lands on the right bus, and the rain sits far back.

const BUSES := [&"Master", &"Music", &"SFX", &"Ambience", &"UI"]


func test_bus_layout_has_the_five_buses() -> void:
	for b in BUSES:
		assert_ne(AudioServer.get_bus_index(b), -1, "missing bus %s" % b)
	for b in BUSES.slice(1):
		var i := AudioServer.get_bus_index(b)
		assert_eq(AudioServer.get_bus_send(i), &"Master", "%s should feed Master" % b)


## The authored levels in the layout, not the live ones (the settings
## sliders move those).
func _authored_db() -> Dictionary:
	var layout: AudioBusLayout = load("res://default_bus_layout.tres")
	var out := {}
	for i in range(1, BUSES.size()):
		out[StringName(layout.get("bus/%d/name" % i))] = float(layout.get("bus/%d/volume_db" % i))
	return out


func test_music_is_the_loudest_bus() -> void:
	var db := _authored_db()
	for b in [&"SFX", &"Ambience", &"UI"]:
		assert_gt(db[&"Music"], db[b], "Music should sit above %s" % b)
	assert_gt(db[&"SFX"], db[&"Ambience"] - 0.01, "combat should not sit under the ambience")


func test_master_has_a_limiter() -> void:
	var found := false
	for i in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, i) is AudioEffectHardLimiter:
			found = true
	assert_true(found, "Master needs a limiter so the mix never clips")


func test_ambience_ducks_under_music() -> void:
	var amb := AudioServer.get_bus_index(&"Ambience")
	var ducked := false
	for i in AudioServer.get_bus_effect_count(amb):
		var fx := AudioServer.get_bus_effect(amb, i)
		if fx is AudioEffectCompressor and (fx as AudioEffectCompressor).sidechain == &"Music":
			ducked = true
	assert_true(ducked, "Ambience should duck under the Music bus")


func test_cues_route_to_their_bus() -> void:
	assert_eq(Sfx.bus_for("shotgun"), Sfx.BUS_SFX)
	assert_eq(Sfx.bus_for("gore_big"), Sfx.BUS_SFX)
	assert_eq(Sfx.bus_for("ui_click"), Sfx.BUS_UI)
	assert_eq(Sfx.bus_for("cash"), Sfx.BUS_UI)
	assert_eq(Sfx.bus_for("thunder"), Sfx.BUS_AMBIENCE)
	for p in Sfx._mus:
		assert_eq(p.bus, Sfx.BUS_MUSIC)
	assert_eq(Sfx.rain.bus, Sfx.BUS_AMBIENCE)
	assert_eq(Sfx.rain_heavy.bus, Sfx.BUS_AMBIENCE)


func test_ducking_cues_are_the_big_hits() -> void:
	for n in ["execution", "explosion", "slam", "boss_intro"]:
		assert_lt(Sfx.cue(n).music_duck_db, 0.0, "%s should duck the music" % n)
	for n in ["shotgun", "gore_big", "gore0", "swing0"]:
		assert_eq(Sfx.cue(n).music_duck_db, 0.0, "%s plays too often to duck the music" % n)


func test_rain_levels_stay_quiet() -> void:
	# the rain player plus its bus stays at least 12 dB under the music bus
	# (the beds are about 18 LU quieter than the music files before that)
	var db := _authored_db()
	for lvl in 3:
		assert_lt(db[&"Ambience"] + Sfx.RAIN_DB[lvl], db[&"Music"] - 12.0)
		assert_lt(db[&"Ambience"] + Sfx.RAIN_HEAVY_DB[lvl], db[&"Music"] - 12.0)
	assert_lt(Sfx.RAIN_HEAVY_DB[1], -79.0, "light rain has no heavy layer")
	assert_gt(Sfx.RAIN_HEAVY_DB[2], -79.0, "heavy rain adds the heavy layer")


func test_big_hits_duck_the_music_briefly() -> void:
	Sfx._impact = 0.0
	Sfx._impact_ready_at = 0.0
	Sfx._on_played(Sfx.cue("slam"), -8.0)
	assert_eq(Sfx._impact, 0.0, "a quiet, far slam leaves the music alone")
	Sfx._on_played(Sfx.cue("execution"), 2.0)
	assert_eq(Sfx._impact, Sfx.cue("execution").music_duck_db)
	Sfx._impact = 0.0
	Sfx._on_played(Sfx.cue("explosion"), 0.0)
	assert_eq(Sfx._impact, 0.0, "the duck can't retrigger straight away")
	Sfx._impact_ready_at = 0.0
	Sfx._on_played(Sfx.cue("shotgun"), 0.0)
	assert_eq(Sfx._impact, 0.0, "ordinary hits never duck")
