class_name VoicePool
extends RefCounted
## A fixed set of players shared by every cue (spec §10.4, §10.5), so a horde
## can't allocate players mid-fight. Picking a voice:
## 1. A cue already at its max_voices reuses its own oldest voice.
## 2. Otherwise a free voice.
## 3. Otherwise the lowest-priority, oldest voice, but only one of the same or
##    lower priority: gore never cuts off a shotgun blast or a telegraph.
## 4. Otherwise the sound is dropped.

var players: Array = [] # AudioStreamPlayer or AudioStreamPlayer3D (anything with `playing`)
var stolen := 0 # voices taken over from a lower or equal priority cue
var dropped := 0 # plays skipped because every voice was more important
var _cue: Array[StringName] = []
var _prio := PackedInt32Array()
var _started := PackedFloat64Array()


func _init(voices: Array) -> void:
	players = voices
	_cue.resize(voices.size())
	_prio.resize(voices.size())
	_started.resize(voices.size())


## Returns the index of the voice to use for this play, or -1 to drop it.
func acquire(cue: StringName, priority: int, max_voices: int, now: float) -> int:
	var own := -1 # this cue's oldest busy voice
	var own_count := 0
	var free := -1
	for i in players.size():
		if not players[i].playing:
			if free < 0:
				free = i
			continue
		if _cue[i] == cue:
			own_count += 1
			if own < 0 or _started[i] < _started[own]:
				own = i
	var pick := -1
	if own_count >= max_voices:
		pick = own
	elif free >= 0:
		pick = free
	else:
		for i in players.size():
			if _prio[i] > priority:
				continue
			if pick < 0 or _prio[i] < _prio[pick] or (_prio[i] == _prio[pick] and _started[i] < _started[pick]):
				pick = i
		if pick < 0:
			dropped += 1
			return -1
		stolen += 1
	_cue[pick] = cue
	_prio[pick] = priority
	_started[pick] = now
	return pick
