extends GutTest
## Audio pipeline (spec §10.5): cue and track data, voice pools that protect
## important sounds, variants and stem layers.


class FakeVoice:
	var playing := false


func _pool(n: int) -> VoicePool:
	var voices: Array = []
	for i in n:
		voices.append(FakeVoice.new())
	return VoicePool.new(voices)


func _fill(pool: VoicePool, cue: StringName, prio: int, count: int, t0 := 0.0) -> void:
	for k in count:
		var i := pool.acquire(cue, prio, 99, t0 + k)
		pool.players[i].playing = true


func test_every_sound_has_a_cue_file() -> void:
	for f in ResourceLoader.list_directory(Sfx.SOUND_DIR):
		var id := f.get_basename()
		if f.get_extension() == "wav":
			assert_true(ResourceLoader.exists(Sfx.CUE_DIR + id + ".tres"), "no cue file for %s" % f)


func test_every_cue_loads_with_a_sound() -> void:
	assert_gt(Sfx.cues.size(), 50)
	for id: StringName in Sfx.cues:
		var c: SfxCue = Sfx.cues[id]
		assert_false(c.streams.is_empty(), "%s has no sound" % id)
		assert_true(c.bus in ["SFX", "UI", "Ambience"], "%s has a bad bus" % id)


func test_music_roles_are_filled() -> void:
	assert_eq(Sfx.combat_tracks.size(), 6)
	assert_eq(Sfx.title_track, "title")
	for kind in ["ninja", "mech", "oni"]:
		assert_true(Sfx.boss_tracks.has(kind), "no theme for boss %s" % kind)
	var sorted := Sfx.combat_tracks.duplicate()
	sorted.sort()
	assert_eq(Sfx.combat_tracks, sorted, "the playlist order must not depend on the file system")


func test_same_seed_gives_same_playlist() -> void:
	Sfx.start_combat_music(1234)
	var a: Array = Sfx._playlist.duplicate()
	Sfx.start_combat_music(1234)
	assert_eq(Sfx._playlist, a)
	Sfx.music_cut()
	for m in Sfx._mus:
		m.stop()
	Sfx._playlist = []


func test_critical_cues_outrank_gore() -> void:
	assert_eq(Sfx.cue("shotgun").priority, SfxCue.Priority.CRITICAL)
	for n in ["windup", "roar", "slam"]:
		assert_eq(Sfx.cue(n).priority, SfxCue.Priority.CRITICAL, "telegraph %s must always be heard" % n)
	assert_eq(Sfx.cue("zap").priority, SfxCue.Priority.CRITICAL)
	assert_lt(Sfx.cue("gore0").priority, Sfx.cue("shotgun").priority)


func test_unknown_sound_is_ignored() -> void:
	assert_null(Sfx.cue(&"no_such_sound"))
	Sfx.play("no_such_sound") # must not error


func test_pool_uses_a_free_voice_first() -> void:
	var pool := _pool(3)
	_fill(pool, &"gore0", 1, 2)
	assert_eq(pool.acquire(&"shotgun", 3, 4, 10.0), 2)
	assert_eq(pool.stolen, 0)


func test_pool_low_priority_never_steals_from_high() -> void:
	var pool := _pool(2)
	_fill(pool, &"shotgun", 3, 2)
	assert_eq(pool.acquire(&"gore0", 1, 4, 10.0), -1)
	assert_eq(pool.dropped, 1)


func test_pool_high_priority_steals_oldest_lowest() -> void:
	var pool := _pool(3)
	_fill(pool, &"spawn", 1, 1, 0.0) # voice 0, low, oldest
	_fill(pool, &"enemy_shot", 2, 1, 1.0) # voice 1
	_fill(pool, &"gore0", 1, 1, 2.0) # voice 2, low, newer
	assert_eq(pool.acquire(&"shotgun", 3, 4, 10.0), 0)
	assert_eq(pool.stolen, 1)


func test_pool_cue_at_its_limit_reuses_its_own_oldest() -> void:
	var pool := _pool(6)
	_fill(pool, &"gore0", 1, 1, 0.0) # voice 0
	_fill(pool, &"tick", 2, 1, 1.0) # voice 1
	_fill(pool, &"gore0", 1, 1, 2.0) # voice 2
	assert_eq(pool.acquire(&"gore0", 1, 2, 10.0), 0, "the third gore replaces the oldest gore")


func test_variants_never_repeat_back_to_back() -> void:
	var c := SfxCue.new()
	c.streams = [AudioStreamWAV.new(), AudioStreamWAV.new(), AudioStreamWAV.new()]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var last: AudioStream = null
	for k in 50:
		var s := c.pick(rng)
		assert_ne(s, last)
		last = s


func _wav(seconds: float) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = 22050
	var data := PackedByteArray()
	data.resize(int(seconds * 22050) * 2)
	w.data = data
	return w


func test_stems_build_a_synchronized_stream() -> void:
	var t := MusicTrack.new()
	t.stems = [_wav(1.0), _wav(1.0), _wav(1.0)]
	t.stem_intensity = PackedFloat32Array([0.0, 0.5, 1.0])
	var s := t.build() as AudioStreamSynchronized
	assert_not_null(s)
	assert_eq(s.stream_count, 3)
	t.set_intensity(0.0)
	assert_lt(s.get_sync_stream_volume(1), -79.0, "layers start out")
	t.set_intensity(0.5)
	assert_almost_eq(s.get_sync_stream_volume(1), 0.0, 0.01, "layer 1 is fully in at 0.5")
	assert_lt(s.get_sync_stream_volume(2), -79.0, "layer 2 waits for 1.0")
	t.set_intensity(1.0)
	assert_almost_eq(s.get_sync_stream_volume(2), 0.0, 0.01)
	assert_almost_eq(s.get_sync_stream_volume(0), 0.0, 0.01, "stem 0 always plays")


func test_single_stem_loops_from_its_loop_point() -> void:
	var t := MusicTrack.new()
	t.stems = [_wav(2.0)]
	t.loop = true
	t.loop_offset = 0.5
	var w := t.build() as AudioStreamWAV
	assert_eq(w.loop_mode, AudioStreamWAV.LOOP_FORWARD)
	assert_eq(w.loop_begin, 11025)
