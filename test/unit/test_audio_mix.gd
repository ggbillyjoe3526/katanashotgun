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


func test_music_is_the_loudest_bus() -> void:
	var music := AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Music"))
	for b in [&"SFX", &"Ambience", &"UI"]:
		assert_gt(music, AudioServer.get_bus_volume_db(AudioServer.get_bus_index(b)), "Music should sit above %s" % b)


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


func test_every_routed_cue_exists() -> void:
	for n in Sfx.UI_CUES + Sfx.AMBIENCE_CUES + Sfx.IMPACT_CUES.keys():
		assert_true(n in Sfx.NAMES, "%s is not a known cue" % n)


func test_rain_levels_stay_quiet() -> void:
	# per-player levels on top of the Ambience bus; heavy rain adds a layer
	for lvl in 3:
		assert_true(Sfx.RAIN_DB[lvl] <= 0.0 and Sfx.RAIN_HEAVY_DB[lvl] <= 0.0)
	assert_lt(Sfx.RAIN_HEAVY_DB[1], -79.0, "light rain has no heavy layer")
	assert_gt(Sfx.RAIN_HEAVY_DB[2], -79.0, "heavy rain adds the heavy layer")


func test_big_hits_duck_the_music_briefly() -> void:
	Sfx._impact = 0.0
	Sfx._on_played("execution")
	assert_lt(Sfx._impact, 0.0)
	Sfx._on_played("shotgun")
	assert_eq(Sfx._impact, Sfx.IMPACT_CUES["execution"], "ordinary hits leave the duck alone")
	Sfx._impact = 0.0
