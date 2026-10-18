class_name Settings
## The player's settings (spec §15.4): audio bus volumes, window and frame
## pacing, render scale, quality preset, field of view, mouse sensitivity, key
## bindings, and the comfort sliders for screen shake and flashes.
## All static, so any script reads them directly (Settings.fov). Game calls
## boot() once at start-up; the settings menu edits the values, then calls
## the matching apply_*() and save().
## Saved as plain data (to_dict / from_dict) so the profile can store it; until
## the profile system lands, save() writes its own file with an atomic rename
## and one backup (spec §11.3).

const VERSION := 1
const BUSES: Array[String] = ["Master", "Music", "SFX", "Ambience", "UI"]
const SENS_BASE := 0.0024 # radians per mouse pixel at sensitivity 1.0
const SENS_MIN := 0.1
const SENS_MAX := 5.0
const FOV_MIN := 70.0
const FOV_MAX := 110.0
const RENDER_SCALE_MIN := 0.5
const WINDOW_MODES: Array[String] = ["windowed", "fullscreen", "exclusive"]
const FPS_CAPS: Array[int] = [0, 60, 75, 120, 144, 165, 240, 360] # 0 = uncapped
const QUALITY_IDS: Array[String] = ["low", "medium", "high"]
## Picking a preset sets render scale to this as a starting point.
const QUALITY_RENDER_SCALE := {"low": 0.75, "medium": 1.0, "high": 1.0}
## Actions the player can rebind, in menu order. Actions missing from the
## InputMap are skipped, so new ones can be listed before they land.
const REBINDABLE := [
	["katana", "KATANA"],
	["shotgun", "SHOTGUN"],
	["finisher", "GLORY KILL"],
	["jump", "JUMP"],
	["dash", "DASH"],
	["move_forward", "MOVE FORWARD"],
	["move_back", "MOVE BACK"],
	["move_left", "MOVE LEFT"],
	["move_right", "MOVE RIGHT"],
]
const SLOTS := 2 # bindings shown per action
## Keys the menu keeps for itself: Esc pauses and backs out, F11 is fullscreen.
const RESERVED_KEYS: Array[int] = [KEY_ESCAPE, KEY_F11]
const DEFAULT_FOV := 88.0

static var path := "user://settings.json"

static var volume := {} # bus name -> 0..1
static var window_mode := "windowed"
static var vsync := true
static var fps_cap := 0
static var render_scale := 1.0
static var quality := "high"
static var fov := DEFAULT_FOV
static var sensitivity := 1.0
static var shake := 1.0 # comfort: 0 = no screen shake, 1 = full
static var flash := 1.0 # comfort: 0 = no white flashes or impact frames, 1 = full
## action -> Array of event dicts ({"k": physical keycode} or {"m": mouse button})
static var bindings := {}

static var _bus_base_db := {}
static var _default_events := {} # action -> its events from project.godot


## Loads the saved settings (or defaults) and applies all of them.
static func boot() -> void:
	for r in REBINDABLE:
		_remember_defaults(r[0])
	reset_all()
	load_file()
	apply_all()


static func reset_all() -> void:
	reset_audio()
	reset_video()
	reset_controls()
	reset_comfort()


static func reset_audio() -> void:
	volume = {}
	for b in BUSES:
		volume[b] = 1.0


static func reset_video() -> void:
	window_mode = "windowed"
	vsync = true
	fps_cap = 0
	quality = "high"
	render_scale = 1.0
	fov = DEFAULT_FOV


static func reset_controls() -> void:
	sensitivity = 1.0
	bindings = {}
	for action in _default_events:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
			for ev in _default_events[action]:
				InputMap.action_add_event(action, ev)


## Keeps a copy of an action's default events before any rebinding, so
## "defaults" can put them back.
static func _remember_defaults(action: String) -> void:
	if InputMap.has_action(action) and not _default_events.has(action):
		_default_events[action] = InputMap.action_get_events(action).duplicate()


static func reset_comfort() -> void:
	shake = 1.0
	flash = 1.0


# ---------------------------------------------------------------- apply
static func apply_all() -> void:
	apply_audio()
	apply_video()
	apply_controls()


## Sets each bus to its authored level plus the player's slider, so the mix
## stays in the bus layout. Buses that don't exist yet are skipped.
static func apply_audio() -> void:
	for b in BUSES:
		var idx := AudioServer.get_bus_index(b)
		if idx < 0:
			continue
		if not _bus_base_db.has(b):
			_bus_base_db[b] = AudioServer.get_bus_volume_db(idx)
		var v: float = volume.get(b, 1.0)
		AudioServer.set_bus_mute(idx, v <= 0.001)
		AudioServer.set_bus_volume_db(idx, float(_bus_base_db[b]) + linear_to_db(maxf(v, 0.001)))


static func apply_video() -> void:
	apply_window()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = fps_cap
	apply_quality()
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		tree.root.scaling_3d_scale = render_scale


static func apply_window() -> void:
	var want := DisplayServer.WINDOW_MODE_WINDOWED
	match window_mode:
		"fullscreen":
			want = DisplayServer.WINDOW_MODE_FULLSCREEN
		"exclusive":
			want = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)


## Hands the preset to the quality system (scripts/quality.gd, class Quality)
## when it exists; until then the preset is only stored.
static func apply_quality() -> void:
	for c in ProjectSettings.get_global_class_list():
		if c.get("class", &"") == &"Quality":
			var q: Script = load(c.get("path", ""))
			if q:
				q.call("apply", quality)
			return


static func apply_controls() -> void:
	Game.mouse_sensitivity = SENS_BASE * sensitivity
	for action in bindings:
		if not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		for d in bindings[action]:
			var ev := event_from_dict(d)
			if ev:
				InputMap.action_add_event(action, ev)


# ---------------------------------------------------------------- shortcuts
## F11 / Alt+Enter: windowed <-> fullscreen, remembered.
static func toggle_fullscreen() -> void:
	window_mode = "windowed" if window_mode != "windowed" else "fullscreen"
	apply_window()
	save()


## The [ and ] keys nudge sensitivity by 0.1.
static func nudge_sensitivity(step: float) -> void:
	sensitivity = clampf(snappedf(sensitivity + step, 0.1), SENS_MIN, SENS_MAX)
	apply_controls()
	save()


static func set_quality(id: String) -> void:
	if not QUALITY_IDS.has(id):
		return
	quality = id
	render_scale = QUALITY_RENDER_SCALE[id]


# ---------------------------------------------------------------- bindings
## The rebindable actions that exist right now, as [action, label] pairs.
static func rebindable_actions() -> Array:
	var out := []
	for r in REBINDABLE:
		if InputMap.has_action(r[0]):
			_remember_defaults(r[0])
			out.append(r)
	return out


## The action's key and mouse events (the ones a slot can show).
static func action_events(action: String) -> Array[InputEvent]:
	var out: Array[InputEvent] = []
	if not InputMap.has_action(action):
		return out
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey or ev is InputEventMouseButton:
			out.append(ev)
	return out


## Puts `ev` in the action's slot. If another rebindable action (or the other
## slot) already uses it, the two swap, so nothing is left bound twice.
## Returns the label of the action it swapped with, or "".
static func bind(action: String, slot: int, ev: InputEvent) -> String:
	var mine := action_events(action)
	var old: InputEvent = mine[slot] if slot < mine.size() else null
	var swapped := ""
	for r in rebindable_actions():
		var other: String = r[0]
		var evs := action_events(other)
		for i in evs.size():
			if not same_input(evs[i], ev) or (other == action and i == slot):
				continue
			if other == action:
				# moving to the other slot of the same action: just swap the two
				evs[i] = old
			elif old:
				evs[i] = old
				swapped = r[1]
			else:
				evs.remove_at(i)
				swapped = r[1]
			_set_events(other, evs)
			if other == action:
				mine = evs
			break
	while mine.size() <= slot:
		mine.append(null)
	mine[slot] = ev
	_set_events(action, mine)
	return swapped


static func clear_binding(action: String, slot: int) -> void:
	var mine := action_events(action)
	if slot < mine.size():
		mine.remove_at(slot)
		_set_events(action, mine)


static func _set_events(action: String, evs: Array) -> void:
	InputMap.action_erase_events(action)
	var saved := []
	for ev in evs:
		if ev == null:
			continue
		InputMap.action_add_event(action, ev)
		saved.append(event_to_dict(ev))
	bindings[action] = saved


static func same_input(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		return _keycode(a) == _keycode(b)
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return a.button_index == b.button_index
	return false


static func _keycode(k: InputEventKey) -> int:
	return k.physical_keycode if k.physical_keycode != 0 else k.keycode


static func event_to_dict(ev: InputEvent) -> Dictionary:
	if ev is InputEventKey:
		return {"k": _keycode(ev)}
	if ev is InputEventMouseButton:
		return {"m": ev.button_index}
	return {}


static func event_from_dict(d: Variant) -> InputEvent:
	if not d is Dictionary:
		return null
	if d.has("k"):
		var code := int(d.k)
		if code <= 0:
			return null
		var k := InputEventKey.new()
		k.physical_keycode = code as Key
		return k
	if d.has("m"):
		var b := int(d.m)
		if b <= 0 or b > MOUSE_BUTTON_XBUTTON2:
			return null
		var m := InputEventMouseButton.new()
		m.button_index = b as MouseButton
		return m
	return null


## A short name for a binding slot: "W", "SPACE", "LMB".
static func event_name(ev: InputEvent) -> String:
	if ev == null:
		return "-"
	if ev is InputEventMouseButton:
		match ev.button_index:
			MOUSE_BUTTON_LEFT:
				return "LMB"
			MOUSE_BUTTON_RIGHT:
				return "RMB"
			MOUSE_BUTTON_MIDDLE:
				return "MMB"
			MOUSE_BUTTON_WHEEL_UP:
				return "WHEEL UP"
			MOUSE_BUTTON_WHEEL_DOWN:
				return "WHEEL DOWN"
			MOUSE_BUTTON_XBUTTON1:
				return "MOUSE 4"
			MOUSE_BUTTON_XBUTTON2:
				return "MOUSE 5"
		return "MOUSE %d" % ev.button_index
	if ev is InputEventKey:
		var code := _keycode(ev)
		# show the key printed on the player's keyboard layout (AZERTY shows Z)
		var shown := code as Key
		if DisplayServer.get_name() != "headless":
			var local := DisplayServer.keyboard_get_keycode_from_physical(code as Key)
			if local != KEY_NONE:
				shown = local
		return OS.get_keycode_string(shown).to_upper()
	return "?"


# ---------------------------------------------------------------- save data
static func to_dict() -> Dictionary:
	return {
		"v": VERSION,
		"volume": volume.duplicate(),
		"window_mode": window_mode,
		"vsync": vsync,
		"fps_cap": fps_cap,
		"render_scale": render_scale,
		"quality": quality,
		"fov": fov,
		"sensitivity": sensitivity,
		"shake": shake,
		"flash": flash,
		"bindings": bindings.duplicate(true),
	}


## Reads saved data over the current values. Anything missing, of the wrong
## type or out of range keeps its current value, so an old or damaged file
## never breaks the game. JSON gives numbers back as floats, so ints are cast.
static func from_dict(d: Dictionary) -> void:
	var vol: Variant = d.get("volume")
	if vol is Dictionary:
		for b in BUSES:
			if _is_num(vol.get(b)):
				volume[b] = clampf(float(vol[b]), 0.0, 1.0)
	var wm: Variant = d.get("window_mode")
	if wm is String and WINDOW_MODES.has(wm):
		window_mode = wm
	if d.get("vsync") is bool:
		vsync = d.vsync
	if _is_num(d.get("fps_cap")) and FPS_CAPS.has(int(d.fps_cap)):
		fps_cap = int(d.fps_cap)
	var q: Variant = d.get("quality")
	if q is String and QUALITY_IDS.has(q):
		quality = q
	if _is_num(d.get("render_scale")):
		render_scale = clampf(snappedf(float(d.render_scale), 0.05), RENDER_SCALE_MIN, 1.0)
	if _is_num(d.get("fov")):
		fov = clampf(roundf(float(d.fov)), FOV_MIN, FOV_MAX)
	if _is_num(d.get("sensitivity")):
		sensitivity = clampf(snappedf(float(d.sensitivity), 0.1), SENS_MIN, SENS_MAX)
	if _is_num(d.get("shake")):
		shake = clampf(float(d.shake), 0.0, 1.0)
	if _is_num(d.get("flash")):
		flash = clampf(float(d.flash), 0.0, 1.0)
	var bd: Variant = d.get("bindings")
	if bd is Dictionary:
		for action in bd:
			if not action is String or not bd[action] is Array:
				continue
			var evs := []
			for e in bd[action]:
				if event_from_dict(e):
					evs.append(event_to_dict(event_from_dict(e)))
			bindings[action] = evs


static func _is_num(v: Variant) -> bool:
	return v is float or v is int


# ---------------------------------------------------------------- file
## Writes the settings: a temp file first, then the old file becomes the
## backup and the temp file takes its place, so a crash mid-write never
## leaves a half-written file as the only copy.
static func save() -> bool:
	var tmp := path + ".tmp"
	var bak := path + ".bak"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Settings: can't write %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(JSON.stringify(to_dict(), "\t"))
	f.close()
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(bak):
			DirAccess.remove_absolute(bak)
		DirAccess.rename_absolute(path, bak)
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK:
		push_warning("Settings: can't replace %s (%s)" % [path, error_string(err)])
		return false
	return true


## Loads the file, or its backup if the file is missing or damaged. Returns
## false when neither could be read (the defaults stay).
static func load_file() -> bool:
	for p in [path, path + ".bak"]:
		var d := _read(p)
		if not d.is_empty():
			from_dict(d)
			return true
	return false


static func _read(p: String) -> Dictionary:
	if not FileAccess.file_exists(p):
		return {}
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return {}
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		return {}
	var data: Variant = json.data
	if data is Dictionary and _is_num(data.get("v")):
		return data
	return {}
