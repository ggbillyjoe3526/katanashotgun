class_name Quality
## Graphics presets (spec §14): WEAK, MEDIOCRE and INSANE in game, stored as
## the ids low, medium and high. This file owns the effect caps; Graphics
## (scripts/graphics.gd) owns what each preset does to the lighting and which
## renderer it runs on. Presets change counts and light, never the art style.
## Every pool and cap reads its size from here (the table is in spec §14).
## WEAK trims the piles (blood drops, decals, gibs, numbers, arcs) so a 2015
## laptop holds 60 fps; MEDIOCRE keeps the full show (its caps sit above
## anything a fight produces); INSANE throws more blood and chunks per kill.
## Pools are built at the largest size, so a preset can change mid-run
## without allocating.
## The settings menu calls `Quality.apply(id)` on load and when the option
## changes; `--quality=low|medium|high` on the command line does the same.

const PRESETS := ["low", "medium", "high"]
## The names the player sees.
const NAMES := {"low": "WEAK", "medium": "MEDIOCRE", "high": "INSANE"}
const DEFAULT := "medium"
## Per-preset caps. Keys are read with `Quality.cap(key)`.
const CAPS := {
	"high": {
		"drops": 2700, "decals": 780, "gibs": 160, "chunks_k": 1.3, "drops_k": 1.5,
		"numbers": 40, "arcs": 128, "mists": 56, "smoke": 80, "flashes": 64, "traffic": 40,
		"drones": 12,
	},
	"medium": {
		"drops": 1800, "decals": 520, "gibs": 110, "chunks_k": 1.0, "drops_k": 1.0,
		"numbers": 40, "arcs": 96, "mists": 40, "smoke": 60, "flashes": 48, "traffic": 40,
		"drones": 8,
	},
	"low": {
		"drops": 700, "decals": 220, "gibs": 50, "chunks_k": 0.5, "drops_k": 0.5,
		"numbers": 18, "arcs": 36, "mists": 16, "smoke": 20, "flashes": 16, "traffic": 16,
		"drones": 4,
	},
}

static var preset := DEFAULT
static var _emitter: _QualitySignal


## The cap `key` for the current preset.
static func cap(key: String) -> int:
	return int(CAPS[preset][key])


## A scale for counts that aren't hard caps (blood per burst, chunks).
static func scale(key: String) -> float:
	return float(CAPS[preset][key])


## The largest cap any preset uses: pools are allocated at this size.
static func max_cap(key: String) -> int:
	var m := 0
	for id in PRESETS:
		m = maxi(m, int(CAPS[id][key]))
	return m


static func apply(id: String) -> void:
	if not CAPS.has(id):
		push_warning("Quality: unknown preset '%s', keeping %s" % [id, preset])
		return
	preset = id
	_signal().emit(id)


## Reads `--quality=` from the command line. Called once by Game at boot.
static func from_cmdline() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--quality="):
			apply(a.substr(10).to_lower())


## Emitted (with the new id) after `apply` changes the preset.
static func _signal() -> Signal:
	if _emitter == null:
		_emitter = _QualitySignal.new()
	return _emitter.preset_changed


## Connects `cb(id: String)` to preset changes.
static func on_changed(cb: Callable) -> void:
	var s := _signal()
	if not s.is_connected(cb):
		s.connect(cb)


## Disconnects a callable connected with `on_changed`.
static func off_changed(cb: Callable) -> void:
	var s := _signal()
	if s.is_connected(cb):
		s.disconnect(cb)


class _QualitySignal:
	extends RefCounted
	signal preset_changed(id: String)
