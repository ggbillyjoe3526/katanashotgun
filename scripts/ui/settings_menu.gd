class_name SettingsMenu
extends Control
## The settings screen, opened from the title and the pause screen (click
## SETTINGS or press Tab). Four tabs: AUDIO, VIDEO, CONTROLS and COMFORT.
## Works with the mouse (click, drag, wheel) and the keyboard (arrows or WASD
## to move and change, Enter to rebind, Q / E or Tab for tabs, Esc to go back).
## Everything sits on one dark tech panel and is drawn still and flat, so every
## word reads at a glance (spec §9.9). Changes apply at once and are saved half
## a second after the last one, and again when the menu closes.

signal closed

const PANEL := Vector2(440, 256)
const ROW_Y := 56.0
const ROW_H := 16.0
const MAX_ROWS := 10
const LABEL_X := 16.0
const VALUE_X := 196.0
const VALUE_W := 228.0
const SLIDER_W := 132.0
const SLOT_W := 104.0
const TABS: Array[String] = ["AUDIO", "VIDEO", "CONTROLS", "COMFORT"]
const LABEL_PX := 13 # Chakra Petch
const VALUE_PX := 14 # Share Tech Mono
const TITLE_PX := 16 # Orbitron
const NOTE_LEN := 3.0
const SAVE_DELAY := 0.5
const TEXT := Color(0.86, 0.83, 0.96)
const DIM := Color(0.62, 0.58, 0.78)
const DARK := Color(0.03, 0.015, 0.07)
const AUDIO_NAMES := {"Master": "MASTER", "Music": "MUSIC", "SFX": "SOUND EFFECTS", "Ambience": "AMBIENCE", "UI": "MENUS AND HUD"}

var tab := 0
var sel := 0 # selected row
var slot := 0 # selected binding slot on a key row
var capturing := false
var rows: Array = [] # this tab's rows (see _build_rows)

var _panel: Shard
var _content: Control
var _origin := Vector2.ZERO
var _hover_tab := -1
var _hover_foot := -1
var _dragging := -1
var _note := ""
var _note_t := 99.0
var _save_t := -1.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_panel = Shard.make(DARK, 12.0, Color(Game.palette.get("neon_b", Hud.CYAN)), Color(Game.palette.get("neon_a", Hud.MAGENTA)))
	_panel.brackets = Color.WHITE
	_panel.bracket_len = 10.0
	_panel.size = PANEL
	add_child(_panel)
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.size = PANEL
	_content.draw.connect(_paint)
	add_child(_content)


func open() -> void:
	visible = true
	capturing = false
	_dragging = -1
	_note_t = 99.0
	_set_tab(tab)
	Sfx.play("ui_click", -4.0)


func _notification(what: int) -> void:
	# a change still waiting for its save is written before the window closes
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_flush_save()


func close() -> void:
	if not visible:
		return
	visible = false
	capturing = false
	_dragging = -1
	_flush_save()
	Sfx.play("ui_click", -6.0, 0.85)
	closed.emit()


## Settings can be opened only from the title and the pause screen.
func can_open() -> bool:
	return not visible and Game.state in ["title", "paused"]


# ---------------------------------------------------------------- rows
func _set_tab(i: int, keep_row := false) -> void:
	tab = wrapi(i, 0, TABS.size())
	rows = _build_rows(TABS[tab])
	sel = clampi(sel, 0, maxi(rows.size() - 1, 0)) if keep_row else 0
	slot = 0
	capturing = false


## One dictionary per row. Sliders: get/set a float in [lo, hi] by step.
## Options: a list of values and their names. Keys: an action's two slots.
func _build_rows(t: String) -> Array:
	var out := []
	match t:
		"AUDIO":
			for b in Settings.BUSES:
				var bus: String = b
				if not Settings.has_bus(bus):
					continue # a slider that does nothing yet stays hidden
				out.append(_slider(AUDIO_NAMES.get(bus, bus.to_upper()), 0.0, 1.0, 0.05,
					func(): return float(Settings.volume.get(bus, 1.0)),
					func(v: float): _set_volume(bus, v),
					_pct, "VOLUME OF THIS PART OF THE MIX"))
		"VIDEO":
			out.append(_option("WINDOW MODE", Settings.WINDOW_MODES, ["WINDOWED", "FULLSCREEN", "EXCLUSIVE FULLSCREEN"],
				func(): return Settings.window_mode, _set_window,
				"F11 SWITCHES IT ANY TIME. EXCLUSIVE CAN CUT LAG"))
			out.append(_option("VSYNC", [true, false], ["ON", "OFF"],
				func(): return Settings.vsync, _set_vsync,
				"ON STOPS TEARING. OFF CUTS INPUT LAG"))
			var cap_names := []
			for cap in Settings.FPS_CAPS:
				cap_names.append("UNCAPPED" if cap == 0 else "%d FPS" % cap)
			out.append(_option("FRAME CAP", Settings.FPS_CAPS, cap_names,
				func(): return Settings.fps_cap, _set_fps_cap,
				"HIGHEST FRAME RATE THE GAME WILL RUN AT"))
			if Settings.quality_system():
				out.append(_option("QUALITY", Settings.QUALITY_IDS, ["LOW", "MEDIUM", "HIGH"],
					func(): return Settings.quality, _set_quality,
					"FEWER EFFECTS ON LOW. THE LOOK STAYS THE SAME"))
			out.append(_slider("RENDER SCALE", Settings.RENDER_SCALE_MIN, 1.0, 0.05,
				func(): return Settings.render_scale, _set_render_scale,
				_pct, "SHARPNESS OF THE 3D VIEW. LOWER RUNS FASTER"))
			out.append(_slider("FIELD OF VIEW", Settings.FOV_MIN, Settings.FOV_MAX, 1.0,
				func(): return Settings.fov, _set_fov,
				func(v: float): return "%d" % roundi(v), "HOW WIDE YOU SEE. DEFAULT 88"))
		"CONTROLS":
			out.append(_slider("MOUSE SENSITIVITY", Settings.SENS_MIN, Settings.SENS_MAX, 0.1,
				func(): return Settings.sensitivity, _set_sensitivity,
				func(v: float): return "%.1f" % v, "[ AND ] ALSO CHANGE IT IN GAME"))
			for r in Settings.rebindable_actions():
				out.append({"type": "key", "label": r[1], "action": r[0], "help": "CLICK OR ENTER TO CHANGE. DELETE CLEARS"})
		"COMFORT":
			out.append(_slider("SCREEN SHAKE", 0.0, 1.0, 0.05,
				func(): return Settings.shake, _set_shake,
				_pct, "CAMERA AND HUD SHAKE"))
			out.append(_slider("FLASHES", 0.0, 1.0, 0.05,
				func(): return Settings.flash, _set_flash,
				_pct, "WHITE FLASHES. BELOW 100% NOTHING STROBES"))
	return out


func _set_volume(bus: String, v: float) -> void:
	Settings.volume[bus] = v
	Settings.apply_audio()


func _set_window(v: Variant) -> void:
	Settings.window_mode = v
	Settings.apply_window()


func _set_vsync(v: Variant) -> void:
	Settings.vsync = v
	Settings.apply_video()


func _set_fps_cap(v: Variant) -> void:
	Settings.fps_cap = v
	Settings.apply_video()


func _set_quality(v: Variant) -> void:
	Settings.set_quality(v)
	Settings.apply_video()


func _set_render_scale(v: float) -> void:
	Settings.render_scale = v
	Settings.apply_video()


func _set_fov(v: float) -> void:
	Settings.fov = v


func _set_sensitivity(v: float) -> void:
	Settings.sensitivity = v
	Settings.apply_controls()


func _set_shake(v: float) -> void:
	Settings.shake = v


func _set_flash(v: float) -> void:
	Settings.flash = v


func _slider(label: String, lo: float, hi: float, step: float, getter: Callable, setter: Callable, fmt: Callable, help: String) -> Dictionary:
	return {"type": "slider", "label": label, "lo": lo, "hi": hi, "step": step, "get": getter, "set": setter, "fmt": fmt, "help": help}


func _option(label: String, values: Array, names: Array, getter: Callable, setter: Callable, help: String) -> Dictionary:
	return {"type": "option", "label": label, "values": values, "names": names, "get": getter, "set": setter, "help": help}


func _pct(v: float) -> String:
	return "%d%%" % roundi(v * 100.0)


## Moves a slider by `steps` or an option by `steps` entries.
func _adjust(i: int, steps: int) -> void:
	if i < 0 or i >= rows.size():
		return
	var r: Dictionary = rows[i]
	match r.type:
		"slider":
			_set_slider(r, float(r.get.call()) + steps * float(r.step))
		"option":
			var vals: Array = r.values
			var cur := vals.find(r.get.call())
			r.set.call(vals[wrapi(cur + steps, 0, vals.size())])
			_changed()
		"key":
			slot = clampi(slot + steps, 0, Settings.SLOTS - 1)
			Sfx.play("ui_hover", -10.0)


func _set_slider(r: Dictionary, v: float) -> void:
	var lo: float = r.lo
	var hi: float = r.hi
	v = clampf(lo + snappedf(v - lo, r.step), lo, hi)
	if is_equal_approx(v, float(r.get.call())):
		return
	r.set.call(v)
	_changed()


func _changed() -> void:
	Sfx.play("ui_click", -9.0, 1.15, 0.0)
	_save_t = SAVE_DELAY


func _flush_save() -> void:
	if _save_t >= 0.0:
		_save_t = -1.0
		Settings.save()


func _reset_tab() -> void:
	match TABS[tab]:
		"AUDIO":
			Settings.reset_audio()
		"VIDEO":
			Settings.reset_video()
		"CONTROLS":
			Settings.reset_controls()
		"COMFORT":
			Settings.reset_comfort()
	Settings.apply_all()
	_set_tab(tab, true)
	_show_note("%s RESET TO DEFAULTS" % TABS[tab])
	_changed()


func _show_note(text: String) -> void:
	_note = text
	_note_t = 0.0


# ---------------------------------------------------------------- rebinding
func _start_capture(i: int, s: int) -> void:
	sel = i
	slot = s
	capturing = true
	Sfx.play("ui_click", -6.0)


func _finish_capture(ev: InputEvent) -> void:
	capturing = false
	var r: Dictionary = rows[sel]
	var swapped := Settings.bind(r.action, slot, ev)
	if swapped != "":
		_show_note("%s MOVED FROM %s" % [Settings.event_name(ev), swapped])
	_changed()


# ---------------------------------------------------------------- input
func _input(event: InputEvent) -> void:
	if not visible:
		# Tab opens the menu from the title and the pause screen
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_TAB and can_open():
			open()
			get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey:
		return
	var k := event as InputEventKey
	var code := k.physical_keycode
	if code == KEY_F11 or (code == KEY_ENTER and k.alt_pressed):
		return # main toggles fullscreen
	get_viewport().set_input_as_handled()
	if not k.pressed:
		return
	if capturing:
		if k.echo:
			return
		if code == KEY_ESCAPE:
			capturing = false
		elif not Settings.RESERVED_KEYS.has(code):
			var ev := InputEventKey.new()
			ev.physical_keycode = code
			_finish_capture(ev)
		return
	match code:
		KEY_ESCAPE:
			close()
		KEY_UP, KEY_W:
			_select(sel - 1)
		KEY_DOWN, KEY_S:
			_select(sel + 1)
		KEY_LEFT, KEY_A:
			_adjust(sel, -1)
		KEY_RIGHT, KEY_D:
			_adjust(sel, 1)
		KEY_TAB:
			if not k.echo:
				_switch_tab(tab - 1 if k.shift_pressed else tab + 1)
		KEY_Q:
			if not k.echo:
				_switch_tab(tab - 1)
		KEY_E:
			if not k.echo:
				_switch_tab(tab + 1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if not k.echo:
				_activate(sel)
		KEY_DELETE, KEY_BACKSPACE:
			if sel < rows.size() and rows[sel].type == "key":
				Settings.clear_binding(rows[sel].action, slot)
				_changed()
		KEY_R:
			if not k.echo:
				_reset_tab()


func _gui_input(event: InputEvent) -> void:
	accept_event()
	var mp := _content.get_local_mouse_position()
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			if mb.button_index == MOUSE_BUTTON_LEFT and _dragging >= 0:
				_dragging = -1
			return
		if capturing:
			var ev := InputEventMouseButton.new()
			ev.button_index = mb.button_index
			_finish_capture(ev)
			return
		var row := _row_at(mp)
		if mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			if row >= 0 and rows[row].type != "key":
				_adjust(row, 1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		var t := _tab_at(mp)
		if t >= 0:
			_switch_tab(t)
			return
		match _foot_at(mp):
			0:
				close()
				return
			1:
				_reset_tab()
				return
		if row < 0:
			return
		sel = row
		var r: Dictionary = rows[row]
		match r.type:
			"slider":
				if _slider_rect(row).grow(4).has_point(mp):
					_dragging = row
					_drag_to(mp.x)
			"option":
				var vr := _value_rect(row)
				if vr.has_point(mp):
					_adjust(row, -1 if mp.x < vr.get_center().x else 1)
			"key":
				for s in Settings.SLOTS:
					if _slot_rect(row, s).has_point(mp):
						_start_capture(row, s)
	elif event is InputEventMouseMotion:
		if _dragging >= 0:
			_drag_to(mp.x)
			return
		_hover_tab = _tab_at(mp)
		_hover_foot = _foot_at(mp)
		var row := _row_at(mp)
		if row >= 0 and row != sel and not capturing:
			_select(row)
		if row >= 0 and rows[row].type == "key" and not capturing:
			for s in Settings.SLOTS:
				if _slot_rect(row, s).has_point(mp):
					slot = s


func _select(i: int) -> void:
	if rows.is_empty():
		return
	var n := clampi(i, 0, rows.size() - 1)
	if n != sel:
		sel = n
		slot = 0
		Sfx.play("ui_hover", -10.0)


func _switch_tab(i: int) -> void:
	_set_tab(i)
	Sfx.play("ui_hover", -6.0)


func _activate(i: int) -> void:
	if i < 0 or i >= rows.size():
		return
	match rows[i].type:
		"key":
			_start_capture(i, slot)
		"option":
			_adjust(i, 1)


func _drag_to(x: float) -> void:
	var r: Dictionary = rows[_dragging]
	var sr := _slider_rect(_dragging)
	var k := clampf((x - sr.position.x) / sr.size.x, 0.0, 1.0)
	_set_slider(r, lerpf(r.lo, r.hi, k))


# ---------------------------------------------------------------- layout
func _row_rect(i: int) -> Rect2:
	return Rect2(Vector2(10, ROW_Y + i * ROW_H), Vector2(PANEL.x - 20, ROW_H - 1))


func _value_rect(i: int) -> Rect2:
	return Rect2(Vector2(VALUE_X, ROW_Y + i * ROW_H + 1), Vector2(VALUE_W - 14, ROW_H - 3))


func _slider_rect(i: int) -> Rect2:
	return Rect2(Vector2(VALUE_X, ROW_Y + i * ROW_H + 6), Vector2(SLIDER_W, 4))


func _slot_rect(i: int, s: int) -> Rect2:
	return Rect2(Vector2(VALUE_X + s * (SLOT_W + 6), ROW_Y + i * ROW_H + 1), Vector2(SLOT_W, ROW_H - 3))


func _tab_rect(i: int) -> Rect2:
	return Rect2(Vector2(12 + i * 86, 32), Vector2(82, 16))


func _foot_rect(i: int) -> Rect2:
	# 0 = BACK, 1 = DEFAULTS, bottom right
	var w := 84.0
	return Rect2(Vector2(PANEL.x - 20 - (2 - i) * (w + 6) + 6, PANEL.y - 21), Vector2(w, 14))


func _row_at(p: Vector2) -> int:
	for i in rows.size():
		if _row_rect(i).has_point(p):
			return i
	return -1


func _tab_at(p: Vector2) -> int:
	for i in TABS.size():
		if _tab_rect(i).has_point(p):
			return i
	return -1


func _foot_at(p: Vector2) -> int:
	for i in 2:
		if _foot_rect(i).has_point(p):
			return i
	return -1


func _process(_delta: float) -> void:
	if not visible:
		return
	var rd := Game.real_dt
	_note_t += rd
	if _save_t >= 0.0:
		_save_t -= rd
		if _save_t < 0.0:
			_save_t = 0.0
			_flush_save()
	var vs := size if size.x > 10.0 else Vector2(480, 270)
	_origin = ((vs - PANEL) * 0.5).round()
	_panel.position = _origin
	_content.position = _origin
	queue_redraw()
	_content.queue_redraw()


# ---------------------------------------------------------------- drawing
func _draw() -> void:
	# a near-opaque shade so nothing busy shows behind the words
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.0, 0.03, 0.86))


func _paint() -> void:
	var c := _content
	var a: Color = Game.palette.get("neon_a", Hud.MAGENTA)
	var b: Color = Game.palette.get("neon_b", Hud.CYAN)
	var gold: Color = Game.palette.get("neon_c", Hud.YELLOW)
	_text(c, "SETTINGS", Ui.font_big, TITLE_PX, Vector2(14, 9), Color.WHITE)
	var hint := "Q / E  CHANGE TAB"
	_text(c, hint, Ui.font_bold, LABEL_PX, Vector2(PANEL.x - 14 - _w(hint, Ui.font_bold, LABEL_PX), 12), DIM)
	# tabs
	for i in TABS.size():
		var tr := _tab_rect(i)
		var on := i == tab
		c.draw_rect(tr, a if on else Color(0.1, 0.07, 0.18))
		if i == _hover_tab and not on:
			c.draw_rect(tr, a, false, 1.0)
		var tw := _w(TABS[i], Ui.font_bold, LABEL_PX)
		_text(c, TABS[i], Ui.font_bold, LABEL_PX, Vector2(tr.position.x + (tr.size.x - tw) * 0.5, tr.position.y + 2), DARK if on else TEXT)
	c.draw_rect(Rect2(Vector2(10, 50), Vector2(PANEL.x - 20, 1)), Color(a, 0.6))
	# rows
	for i in rows.size():
		var r: Dictionary = rows[i]
		var rr := _row_rect(i)
		var picked := i == sel
		if picked:
			c.draw_rect(rr, Color(a, 0.16))
			c.draw_rect(Rect2(rr.position, Vector2(2, rr.size.y)), a)
		_text(c, r.label, Ui.font_bold, LABEL_PX, Vector2(LABEL_X, rr.position.y + 2), Color.WHITE if picked else TEXT)
		match r.type:
			"slider":
				_paint_slider(c, i, r, b, picked)
			"option":
				_paint_option(c, i, r, a, picked)
			"key":
				_paint_key(c, i, r, a, gold, picked)
	# help line (or a note, such as a key that moved) and the footer buttons
	var help_y := ROW_Y + MAX_ROWS * ROW_H + 3
	var line := ""
	var col := DIM
	if capturing:
		line = "PRESS A KEY OR MOUSE BUTTON.  ESC CANCELS"
		col = gold
	elif _note_t < NOTE_LEN:
		line = _note
		col = gold
	elif sel < rows.size():
		line = rows[sel].help
	_text(c, line, Ui.font_bold, LABEL_PX, Vector2(14, help_y), col)
	for i in 2:
		var fr := _foot_rect(i)
		var hov := i == _hover_foot
		c.draw_rect(fr, Color(a, 0.9) if hov else Color(0.1, 0.07, 0.18))
		c.draw_rect(fr, a, false, 1.0)
		var lbl: String = ["ESC  BACK", "R  DEFAULTS"][i]
		var lw := _w(lbl, Ui.font_bold, LABEL_PX)
		_text(c, lbl, Ui.font_bold, LABEL_PX, Vector2(fr.position.x + (fr.size.x - lw) * 0.5, fr.position.y + 1), DARK if hov else TEXT)


func _paint_slider(c: Control, i: int, r: Dictionary, col: Color, picked: bool) -> void:
	var sr := _slider_rect(i)
	var v: float = r.get.call()
	var k := clampf((v - float(r.lo)) / (float(r.hi) - float(r.lo)), 0.0, 1.0)
	c.draw_rect(sr, Color(0.16, 0.12, 0.28))
	c.draw_rect(Rect2(sr.position, Vector2(roundf(sr.size.x * k), sr.size.y)), col)
	var kx := roundf(sr.position.x + sr.size.x * k) - 1.0
	c.draw_rect(Rect2(Vector2(kx, sr.position.y - 3), Vector2(3, sr.size.y + 6)), Color.WHITE if picked else TEXT)
	_text(c, r.fmt.call(v), Ui.font_mono, VALUE_PX, Vector2(sr.end.x + 12, ROW_Y + i * ROW_H), Color.WHITE)


func _paint_option(c: Control, i: int, r: Dictionary, col: Color, picked: bool) -> void:
	var vr := _value_rect(i)
	var idx: int = r.values.find(r.get.call())
	var name: String = r.names[idx] if idx >= 0 else "?"
	var arrow := col if picked else DIM
	_text(c, "<", Ui.font_mono, VALUE_PX, Vector2(vr.position.x, vr.position.y - 1), arrow)
	_text(c, ">", Ui.font_mono, VALUE_PX, Vector2(vr.end.x - _w(">", Ui.font_mono, VALUE_PX), vr.position.y - 1), arrow)
	var nw := _w(name, Ui.font_mono, VALUE_PX)
	_text(c, name, Ui.font_mono, VALUE_PX, Vector2(vr.position.x + (vr.size.x - nw) * 0.5, vr.position.y - 1), Color.WHITE)


func _paint_key(c: Control, i: int, r: Dictionary, col: Color, gold: Color, picked: bool) -> void:
	var evs := Settings.action_events(r.action)
	for s in Settings.SLOTS:
		var sr := _slot_rect(i, s)
		var live := picked and s == slot
		if capturing and live:
			c.draw_rect(sr, gold)
			var t := "PRESS KEY"
			_text(c, t, Ui.font_mono, VALUE_PX, Vector2(sr.position.x + (sr.size.x - _w(t, Ui.font_mono, VALUE_PX)) * 0.5, sr.position.y - 1), DARK)
			continue
		c.draw_rect(sr, Color(0.1, 0.07, 0.18))
		c.draw_rect(sr, col if live else Color(0.3, 0.26, 0.45), false, 1.0)
		var t := Settings.event_name(evs[s]) if s < evs.size() else "-"
		_text(c, t, Ui.font_mono, VALUE_PX, Vector2(sr.position.x + (sr.size.x - _w(t, Ui.font_mono, VALUE_PX)) * 0.5, sr.position.y - 1), Color.WHITE if s < evs.size() else DIM)


func _text(c: Control, t: String, f: Font, px: int, top_left: Vector2, col: Color) -> void:
	c.draw_string(f, (top_left + Vector2(0, f.get_ascent(px))).round(), t, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func _w(t: String, f: Font, px: int) -> float:
	return f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
