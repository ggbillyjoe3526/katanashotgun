class_name DebugPerf
extends CanvasLayer
## Perf overlay and probe (spec §14, §16). F3 toggles the overlay in any
## build: fps, frame time, draw calls, live nodes and node churn.
## `--perf` also logs a line every 2 s and a summary at exit, so a fixed-seed
## autoplay run can be compared before and after a change:
##   godot --path . -- --autoplay --god --seed=1234-5678 --perf
## Frame times only mean something on real hardware; the node, object and
## draw-call counts are the same on any machine.

const LOG_EVERY := 2.0

var _label: Label
var _plate: ColorRect
var _log := false
var _log_t := 0.0
var _added := 0 # nodes that entered the tree since the last sample
var _added_total := 0
var _added_combat := 0
var _frames := 0
var _combat_frames := 0
var _combat_time := 0.0
var _draw_sum := 0.0
var _draw_max := 0
var _prim_max := 0
var _nodes_max := 0
var _objs_max := 0
var _script_ms: PackedFloat32Array = PackedFloat32Array()
var _spike_frames := 0 # frames where 40+ nodes entered the tree at once
var _frame_added := 0
var _fps_t := 0.0
var _fps_frames := 0
var _fps := 0.0
var _ms_max := 0.0
var _first: _Clock
var _last: _Clock


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_log = OS.get_cmdline_user_args().has("--perf")
	Ui.init()
	_plate = ColorRect.new()
	_plate.color = Color(0, 0, 0, 0.72)
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.position = Vector2(4, 4)
	add_child(_plate)
	_label = Ui.label("", Ui.font_mono, 7, Color(0.7, 1.0, 0.8))
	_label.position = Vector2(8, 5)
	add_child(_label)
	get_tree().node_added.connect(_on_node_added)
	# script time: a clock that runs first and one that runs last, every
	# process and physics step (process priority is global)
	_first = _Clock.new()
	_first.process_priority = -100000
	_first.process_physics_priority = -100000
	_last = _Clock.new()
	_last.process_priority = 100000
	_last.process_physics_priority = 100000
	_last.start = _first
	add_child(_first)
	add_child(_last)
	_set_shown(_log)


## Samples only while the overlay is up or --perf is logging, so a release
## build pays nothing for it.
func _active() -> bool:
	return _log or _label.visible


func _on_node_added(_n: Node) -> void:
	if not _label.visible and not _log:
		return
	_added += 1
	_frame_added += 1


func _set_shown(on: bool) -> void:
	_plate.visible = on
	_label.visible = on
	if _first:
		var mode := Node.PROCESS_MODE_ALWAYS if (on or _log) else Node.PROCESS_MODE_DISABLED
		_first.process_mode = mode
		_last.process_mode = mode
		_last.acc = 0


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.physical_keycode == KEY_F3:
		_set_shown(not _label.visible)
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not _active():
		return
	var rd := Game.real_dt
	var draw := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var prims := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var objs := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	# last frame's script time (every _process and _physics_process)
	var script_ms := _last.take_ms()
	var combat := Game.state == "playing" and not Game.enemy_list.is_empty()
	_frames += 1
	if combat:
		_combat_frames += 1
		_combat_time += rd
		_added_combat += _frame_added
		_draw_sum += draw
		_draw_max = maxi(_draw_max, draw)
		_prim_max = maxi(_prim_max, prims)
		if _log:
			_script_ms.append(script_ms) # --perf runs are bounded by --quit-after
		if _frame_added >= 40:
			_spike_frames += 1
	_nodes_max = maxi(_nodes_max, nodes)
	_objs_max = maxi(_objs_max, objs)
	_added_total += _frame_added
	_frame_added = 0
	# overlay
	_fps_t += rd
	_fps_frames += 1
	_ms_max = maxf(_ms_max, rd * 1000.0)
	if _fps_t >= 0.5:
		_fps = _fps_frames / _fps_t
		if _label.visible:
			_label.text = "FPS %d  //  %.1f MS (MAX %.1f)\nDRAW %d  //  PRIMS %dK\nNODES %d  //  OBJECTS %d\nNEW NODES %d/S  //  ENEMIES %d\nQUALITY %s" % [
				roundi(_fps), 1000.0 / maxf(_fps, 0.001), _ms_max, draw, prims / 1000, nodes, objs,
				roundi(_added / _fps_t), Game.enemy_list.size(), Quality.preset.to_upper()]
			_label.size = Vector2.ZERO
			_plate.size = _label.size + Vector2(8, 3)
		_fps_t = 0.0
		_fps_frames = 0
		_ms_max = 0.0
		if not _log:
			_added = 0
	if not _log:
		return
	_log_t += rd
	if _log_t >= LOG_EVERY:
		print("[perf] wave=%d enemies=%d draw=%d prims=%d nodes=%d objects=%d new_nodes/s=%.0f" % [
			Game.wave, Game.enemy_list.size(), draw, prims, nodes, objs, _added / _log_t])
		_log_t = 0.0
		_added = 0


func _exit_tree() -> void:
	if not _log or _combat_frames == 0:
		return
	var ms := _script_ms.duplicate()
	ms.sort()
	var p99: float = ms[mini(ms.size() - 1, int(ms.size() * 0.99))]
	var avg := 0.0
	for v in ms:
		avg += v
	avg /= ms.size()
	print("[perf-summary] quality=%s frames=%d combat_frames=%d" % [Quality.preset, _frames, _combat_frames])
	print("[perf-summary] combat: new_nodes/s=%.1f spike_frames(40+ new nodes)=%d draw_avg=%.0f draw_max=%d prims_max=%d" % [
		_added_combat / maxf(_combat_time, 0.001), _spike_frames, _draw_sum / _combat_frames, _draw_max, _prim_max])
	print("[perf-summary] peaks: nodes=%d objects=%d  total_new_nodes=%d" % [_nodes_max, _objs_max, _added_total])
	print("[perf-summary] script ms per frame (this machine only, compare runs on one machine): avg=%.2f p99=%.2f max=%.2f" % [avg, p99, ms[ms.size() - 1]])


## Marks the start (on the first clock) and end (on the last) of each
## process and physics step, adding up the time in between.
class _Clock:
	extends Node
	var start: _Clock
	var t0 := 0
	var acc := 0

	func _process(_d: float) -> void:
		_mark()

	func _physics_process(_d: float) -> void:
		_mark()

	func _mark() -> void:
		if start == null:
			t0 = Time.get_ticks_usec()
		else:
			acc += Time.get_ticks_usec() - start.t0

	func take_ms() -> float:
		var ms := acc / 1000.0
		acc = 0
		return ms
