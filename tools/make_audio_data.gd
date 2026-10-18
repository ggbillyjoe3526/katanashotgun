extends SceneTree
## Creates the audio data files the game reads (spec §10.5):
## - a cue file in res://assets/audio/cues/ for every sound in res://assets/audio/
##   that doesn't have one yet (the rain beds excepted),
## - a track file in res://assets/music/tracks/ for every piece of music in
##   res://assets/music/ that doesn't have one yet.
## It never touches a file that already exists, so tuning done in the
## inspector is safe. Run after adding new sounds:
##   godot --headless --path . --import
##   godot --headless --path . -s res://tools/make_audio_data.gd

const SOUND_DIR := "res://assets/audio/"
const CUE_DIR := "res://assets/audio/cues/"
const MUSIC_DIR := "res://assets/music/"
const TRACK_DIR := "res://assets/music/tracks/"
const BEDS := ["rain", "rain_heavy"] # looping ambience, played by Sfx directly

## Starting values for new cues; after that the cue files are the truth.
const UI_CUES := [
	"ui_click", "ui_hover", "type", "tick", "stamp", "chime", "cash", "count", "go", "mult", "deal", "fanfare",
]
const AMBIENCE_CUES := ["thunder"]
const CRITICAL := [
	"shotgun", "recharge", "empty", "swing0", "swing1", "swing2", "slice", "execution", "deflect", "headshot",
	"hurt", "windup", "alarm", "player_death", "felled", "flatline", "finish", "cutin", "boss_intro",
	"levelup", "wave_clear", "highscore",
]
const LOW := ["gore0", "gore1", "gore2", "gore_big", "spawn", "ignite"]
const MAX_VOICES := {
	"gore0": 2, "gore1": 2, "gore2": 2, "gore_big": 3, "shotgun": 3, "swing0": 2, "swing1": 2, "swing2": 2,
	"gatling": 3, "type": 2, "ui_hover": 1, "ui_click": 2, "tick": 3, "thunder": 2,
}
const MUSIC_DUCK := {"execution": -3.0, "explosion": -2.5, "slam": -2.0, "boss_intro": -3.0}
const NO_PITCH := ["levelup", "wave_clear", "highscore", "fanfare", "felled", "flatline", "boss_intro"]
const BOSS_KINDS := {"boss_0": "ninja", "boss_1": "mech", "boss_2": "oni"}
const BPM := {
	"combat_0": 108, "combat_1": 104, "combat_2": 110, "combat_3": 100, "combat_4": 112, "combat_5": 106,
	"boss_0": 128, "boss_1": 122, "boss_2": 132, "title": 88,
}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(CUE_DIR)
	DirAccess.make_dir_recursive_absolute(TRACK_DIR)
	var made := 0
	for f in ResourceLoader.list_directory(SOUND_DIR):
		var id := f.get_basename()
		if f.ends_with("/") or id in BEDS or not _is_audio(f):
			continue
		var path := CUE_DIR + id + ".tres"
		if ResourceLoader.exists(path):
			continue
		ResourceSaver.save(new_cue(id, load(SOUND_DIR + f)), path)
		made += 1
	for f in ResourceLoader.list_directory(MUSIC_DIR):
		var id := f.get_basename()
		if f.ends_with("/") or not _is_audio(f):
			continue
		var path := TRACK_DIR + id + ".tres"
		if ResourceLoader.exists(path):
			continue
		ResourceSaver.save(new_track(id, load(MUSIC_DIR + f)), path)
		made += 1
	print("[audio data] created %d file(s)" % made)
	quit()


static func _is_audio(f: String) -> bool:
	return f.get_extension() in ["wav", "ogg", "mp3"]


## The starting cue for a sound. (A sound with no cue file still plays, with
## SfxCue's defaults, until this tool is run.)
static func new_cue(id: String, stream: AudioStream) -> SfxCue:
	var c := SfxCue.new()
	c.streams = [stream]
	c.bus = "UI" if id in UI_CUES else ("Ambience" if id in AMBIENCE_CUES else "SFX")
	c.max_voices = MAX_VOICES.get(id, 4)
	c.music_duck_db = MUSIC_DUCK.get(id, 0.0)
	c.vary_pitch = not id in NO_PITCH
	if id in CRITICAL:
		c.priority = SfxCue.Priority.CRITICAL
	elif id in LOW:
		c.priority = SfxCue.Priority.LOW
	elif id in AMBIENCE_CUES:
		c.priority = SfxCue.Priority.AMBIENT
	return c


static func new_track(id: String, stream: AudioStream) -> MusicTrack:
	var t := MusicTrack.new()
	t.stems = [stream]
	t.bpm = BPM.get(id, 0)
	if id.begins_with("boss"):
		t.role = "boss"
		t.boss_kind = BOSS_KINDS.get(id, "")
		t.loop = true
	elif id.begins_with("title"):
		t.role = "title"
		t.loop = true
	return t
