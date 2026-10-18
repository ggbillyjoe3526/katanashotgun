extends Node
## Debug: `--record-mix=DIR` records every bus (Master, Music, SFX, Ambience,
## UI) to DIR/<bus>.wav when the game quits, so the mix can be measured stem
## by stem (for example with ffmpeg's ebur128 filter). Use it with Movie Maker
## (`--write-movie`) so the audio follows game time, or on a real audio device.

var _dir := ""
var _recorders := {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--record-mix="):
			_dir = a.substr(13)
	if _dir == "":
		push_warning("--record-mix needs a folder: --record-mix=/path/to/dir")
		return
	DirAccess.make_dir_recursive_absolute(_dir)
	for i in AudioServer.bus_count:
		var rec := AudioEffectRecord.new()
		rec.format = AudioStreamWAV.FORMAT_16_BITS
		AudioServer.add_bus_effect(i, rec)
		_recorders[AudioServer.get_bus_name(i)] = rec
		rec.set_recording_active(true)
	print("[mix] recording %d buses to %s" % [_recorders.size(), _dir])


func _exit_tree() -> void:
	for bus: String in _recorders:
		var rec: AudioEffectRecord = _recorders[bus]
		var wav := rec.get_recording()
		rec.set_recording_active(false)
		if wav:
			wav.save_to_wav(_dir.path_join(bus.to_lower() + ".wav"))
	if not _recorders.is_empty():
		print("[mix] wrote %d stems to %s" % [_recorders.size(), _dir])
