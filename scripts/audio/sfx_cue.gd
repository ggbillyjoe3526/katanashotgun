class_name SfxCue
extends Resource
## One sound effect (spec §10.4, §10.5). Each cue is a file in
## res://assets/audio/cues/ named after the cue (shotgun.tres plays for
## Sfx.play("shotgun")). A sound designer replaces a sound by dropping new
## files into `streams` in the inspector, or by overwriting the .wav it points
## at with a file of the same name. Code never needs to change.

enum Priority { AMBIENT, LOW, NORMAL, CRITICAL }

## Variants: one is picked per play, never the same one twice in a row.
@export var streams: Array[AudioStream] = []
## Bus it plays on (spec §10.1).
@export_enum("SFX", "UI", "Ambience") var bus := "SFX"
## Trim in dB, added to the level the game asks for.
@export_range(-40.0, 12.0, 0.5) var volume_db := 0.0
## Allow the small random pitch change the game asks for. Turn it off for
## sounds that must keep their exact pitch (tuned stingers, voice).
@export var vary_pitch := true
## A repeat of this cue within this many ms is skipped (hordes would
## otherwise stack the same hit on one frame).
@export_range(0, 500) var throttle_ms := 30
## How many copies may sound at once. A new one replaces the oldest.
@export_range(1, 16) var max_voices := 4
## When every voice is busy, a cue can only take over a voice of the same or
## lower priority. Player weapons, telegraphs and flow are CRITICAL so a
## horde of gore never cuts them off.
@export var priority := Priority.NORMAL
## Positional plays only: distance at full volume, and the cut-off distance.
@export var unit_size := 9.0
@export var max_distance := 70.0
## Pulls the music down by this many dB for a moment when played loud
## (0 = never). Keep it for the few biggest hits (spec §10.1).
@export_range(-12.0, 0.0, 0.5) var music_duck_db := 0.0

var _last_variant := -1


## Picks a variant with the given presentation RNG, never repeating the last.
func pick(rng: RandomNumberGenerator) -> AudioStream:
	if streams.is_empty():
		return null
	if streams.size() == 1:
		return streams[0]
	var i := rng.randi_range(0, streams.size() - 2)
	if i >= _last_variant:
		i += 1
	_last_variant = i
	return streams[i]
