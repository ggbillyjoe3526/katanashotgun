class_name SaveFile
## Crash-safe JSON files (spec §11.3). A file is one header line,
## "KSAVE <kind> <version> <sha256 of the payload>", then the JSON payload.
## Writes go to <path>.tmp first and are read back and checked before the old
## file is rotated to <path>.bak, so a crash or a full disk at any point leaves
## at least one good copy. Loading tries .tmp (a finished write that never got
## renamed), then the file, then the backup; a copy whose checksum fails is
## skipped, never trusted.

const MAGIC := "KSAVE"
const TMP := ".tmp"
const BAK := ".bak"


static func encode(kind: String, version: int, data: Dictionary) -> String:
	var payload := JSON.stringify(data, "  ")
	return "%s %s %d %s\n%s" % [MAGIC, kind, version, payload.sha256_text(), payload]


## Parses one file's text. Returns {ok, version, data} or {ok: false, error}.
static func decode(text: String, kind: String) -> Dictionary:
	var nl := text.find("\n")
	if nl < 0:
		return {"ok": false, "error": "no header"}
	var head := text.substr(0, nl).split(" ")
	var payload := text.substr(nl + 1)
	if head.size() != 4 or head[0] != MAGIC:
		return {"ok": false, "error": "not a save file"}
	if head[1] != kind:
		return {"ok": false, "error": "wrong kind %s" % head[1]}
	if not head[2].is_valid_int():
		return {"ok": false, "error": "bad version"}
	if payload.sha256_text() != head[3]:
		return {"ok": false, "error": "checksum mismatch"}
	var data = JSON.parse_string(payload)
	if not data is Dictionary:
		return {"ok": false, "error": "payload is not an object"}
	return {"ok": true, "version": int(head[2]), "data": data}


static func read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text()


## Writes atomically and keeps one backup. Returns false (and leaves the old
## file untouched) if the new copy could not be written and verified.
static func write(path: String, kind: String, version: int, data: Dictionary) -> bool:
	var text := encode(kind, version, data)
	var tmp := path + TMP
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("save: can't open %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(text)
	f.flush()
	var err := f.get_error()
	f.close()
	# read it back: a full disk can leave a short file without reporting it
	if err != OK or read_text(tmp) != text:
		push_warning("save: %s did not write cleanly" % tmp)
		DirAccess.remove_absolute(tmp)
		return false
	if FileAccess.file_exists(path):
		if decode(read_text(path), kind).ok:
			# the current file is good: it becomes the backup
			if FileAccess.file_exists(path + BAK):
				DirAccess.remove_absolute(path + BAK)
			DirAccess.rename_absolute(path, path + BAK)
		else:
			# a damaged file never replaces a good backup
			DirAccess.remove_absolute(path)
	if DirAccess.rename_absolute(tmp, path) != OK:
		# the verified .tmp stays on disk and read() still finds it
		push_warning("save: can't rename %s" % tmp)
		return false
	return true


## Loads the newest good copy. Returns {ok, version, data, source} where
## source is "tmp", "main" or "backup", or {ok: false, found} when no copy is
## good (found says whether any file existed at all).
static func read(path: String, kind: String) -> Dictionary:
	var found := false
	for c in [[path + TMP, "tmp"], [path, "main"], [path + BAK, "backup"]]:
		var text := read_text(c[0])
		if text == "":
			found = found or FileAccess.file_exists(c[0])
			continue
		found = true
		var r := decode(text, kind)
		if r.ok:
			r["source"] = c[1]
			return r
		push_warning("save: skipping %s (%s)" % [c[0], r.error])
	return {"ok": false, "found": found}


## Moves every copy aside as <path>.corrupt-<n> so a fresh file can be written
## without destroying anything a player might want recovered.
static func quarantine(path: String) -> void:
	var stamp := str(Time.get_unix_time_from_system()).replace(".", "")
	for suffix in ["", TMP, BAK]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.rename_absolute(path + suffix, "%s%s.corrupt-%s" % [path, suffix, stamp])


static func remove(path: String) -> void:
	for suffix in ["", TMP, BAK]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
