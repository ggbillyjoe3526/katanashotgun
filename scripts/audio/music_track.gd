class_name MusicTrack
extends Resource
## One piece of music (spec §10.2, §10.5): a file in res://assets/music/tracks/.
## The music director builds the combat playlist, boss themes and title theme
## from these files, so adding or replacing a track needs no code.
##
## Stems: stem 0 always plays. Each further stem is an intensity layer that
## fades in as the fight heats up (combo heat, boss enrage) and drops out in
## calm moments. All stems must be the same length and start together.

## Which slot the track fills.
@export_enum("combat", "boss", "title") var role := "combat"
## Boss themes only: the boss kind this theme belongs to (ninja, mech, oni).
@export var boss_kind := ""
## Stem 0 is the base mix; the rest are intensity layers.
@export var stems: Array[AudioStream] = []
## Per stem: the intensity (0 to 1) at which that layer is fully in. Stem 0
## ignores this. Missing entries count as 1.
@export var stem_intensity := PackedFloat32Array()
## Boss and title tracks loop. Combat tracks don't: the playlist moves on.
@export var loop := false
## Seconds into the track where the loop restarts (skips the intro).
@export var loop_offset := 0.0
## Informational, for beat-synced work later.
@export var bpm := 0.0
## Trim in dB so tracks from different sources sit at the same level.
@export_range(-24.0, 12.0, 0.5) var volume_db := 0.0

## How far below its "fully in" intensity a layer starts fading in.
const LAYER_FADE := 0.25

var _built: AudioStream


## The stream to play: the single stem, or every stem in sync.
func build() -> AudioStream:
	if _built:
		return _built
	for s in stems:
		_set_loop(s)
	if stems.size() == 1:
		_built = stems[0]
	elif stems.size() > 1:
		var sync := AudioStreamSynchronized.new()
		sync.stream_count = stems.size()
		for i in stems.size():
			sync.set_sync_stream(i, stems[i])
			sync.set_sync_stream_volume(i, 0.0 if i == 0 else -80.0)
		_built = sync
	return _built


func length() -> float:
	return stems[0].get_length() if not stems.is_empty() and stems[0] else 0.0


## Sets each layer's level for an intensity between 0 and 1.
func set_intensity(intensity: float) -> void:
	var sync := _built as AudioStreamSynchronized
	if sync == null:
		return
	for i in range(1, stems.size()):
		sync.set_sync_stream_volume(i, layer_db(i, intensity))


func layer_db(i: int, intensity: float) -> float:
	if i == 0:
		return 0.0
	var full: float = stem_intensity[i] if i < stem_intensity.size() else 1.0
	var k := clampf((intensity - (full - LAYER_FADE)) / LAYER_FADE, 0.0, 1.0)
	return linear_to_db(k) if k > 0.001 else -80.0


func _set_loop(s: AudioStream) -> void:
	if s is AudioStreamOggVorbis or s is AudioStreamMP3:
		s.set("loop", loop)
		s.set("loop_offset", loop_offset)
	elif s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
		w.loop_begin = int(loop_offset * w.mix_rate)
		w.loop_end = int(w.get_length() * w.mix_rate)
