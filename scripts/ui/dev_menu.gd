class_name DevMenu
extends SettingsMenu
## The hidden DEV menu (spec §16): F10 opens it on the title, in a run (the
## game pauses first) and on the pause screen. Not a player feature, so
## nothing on screen points to it, and it says DEV everywhere it shows.
## It is the settings screen with its own tabs, so it works the same way:
## mouse only, Esc or BACK closes, DEFAULTS turns every dev setting off.
## LOOK holds the capture helpers (the plain look is now the player's RETRO
## LOOK setting); RUN holds the settings that change how a run plays (any of
## them on makes the run a dev run, which pays no top 10 entry, XP or
## unlocks); ACTIONS does things now.
## While anything is on, a small DEV tag sits top right, under the score.

const DEV_TABS: Array[String] = ["LOOK", "RUN", "ACTIONS"]
const LAYER := 110 # above the HUD and the perf overlay
const WARN := Color(1.0, 0.78, 0.2)
const BOSS_NAMES := {"ninja": "KUROKAGE", "mech": "TETSUGUMO", "oni": "SHUTEN"}
const STATUS_ROW := MAX_ROWS - 1 # the last row line carries the dev run status
const TAG_POS := Vector2(6, 46) # from the top-right corner: under the score and combo plates
const TAG_W := 200.0 # the corner tag's lines wrap at this width

var perf: DebugPerf # the F3 overlay, shown and hidden by the PERF OVERLAY row
var tag: Label # the corner tag while dev settings are on
var _kill_all := false # SKIP WAVE waits until the game runs again
var _tag_key := "" # what the tag shows now, so it is laid out only on a change
var _give_at := 0 # GIVE CANS: the next flavour it hands out


## Builds the menu on its own layer under `main`, with its corner tag.
static func attach(main: Node) -> DevMenu:
	var layer := CanvasLayer.new()
	layer.layer = LAYER
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	main.add_child(layer)
	var m := DevMenu.new()
	for n in main.get_children():
		if n is DebugPerf:
			m.perf = n
	m.tag = Ui.label("", Ui.font_mono, Ui.PIX, WARN)
	m.tag.visible = false
	m.tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var plate := StyleBoxFlat.new() # a dark plate behind every word (spec §9.9)
	plate.bg_color = Color(0.02, 0.01, 0.05, 0.85)
	plate.set_content_margin_all(3)
	m.tag.add_theme_stylebox_override("normal", plate)
	layer.add_child(m.tag)
	layer.add_child(m)
	return m


func _init() -> void:
	tabs = DEV_TABS
	title = "DEV SETTINGS"


func _ready() -> void:
	super()
	theme = Ui.theme()


func open_key() -> Key:
	return DevSettings.KEY


## Opens on the title, the pause screen, and mid-run (pausing first); not
## over the settings screen, PLAY A SEED, a level-up offer or the results.
func can_open() -> bool:
	if visible or Game.state not in ["title", "playing", "paused"]:
		return false
	return not (Game.hud and (Game.hud.settings_menu.visible or Game.hud.seed_entry.visible))


func open() -> void:
	if Game.state == "playing" and Game.main:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		Game.main.pause_game()
	super()


func foot_label(i: int) -> String:
	return "ALL OFF" if i == 1 else super(i)


## ALL OFF goes through on one click: these are dev switches, not the player's.
func _press_defaults() -> void:
	_reset_tab()


# ---------------------------------------------------------------- rows
func _build_rows(t: String) -> Array:
	var out := []
	var on_off := [true, false]
	var on_off_names := ["ON", "OFF"]
	match t:
		"LOOK":
			if perf:
				out.append(_option("PERF OVERLAY", on_off, on_off_names,
					func(): return perf.is_shown(), func(v: Variant): perf.show_overlay(v),
					"FPS, FRAME TIME, DRAW CALLS, NODES. F3 TOO"))
			out.append(_option("HIDE HUD", on_off, on_off_names,
				func(): return DevSettings.hide_hud, func(v: Variant): DevSettings.hide_hud = v,
				"NO HUD WHILE PLAYING, FOR CLEAN CAPTURES"))
			var pal_values := [""]
			var pal_names := ["SEEDED"]
			for i in Palette.LIST.size():
				pal_values.append(str(i))
				pal_names.append(Palette.LIST[i].name)
			out.append(_option("PALETTE", pal_values, pal_names,
				func(): return Game.debug_palette, func(v: Variant): Game.debug_palette = v,
				"FROM THE NEXT RUN (ACTIONS: RESTART RUN)"))
		"RUN":
			out.append(_option("GOD MODE", on_off, on_off_names,
				func(): return Game.debug_god, func(v: Variant): Game.debug_god = v,
				"YOU TAKE NO DAMAGE"))
			out.append(_option("AUTOPLAY BOT", on_off, on_off_names,
				func(): return Game.debug_autoplay, func(v: Variant): Game.set_autoplay(v),
				"A BOT PLAYS. TURN IT OFF HERE TO TAKE OVER"))
			var speed_names := []
			for sp in DevSettings.SPEEDS:
				speed_names.append("%d%%" % roundi(sp * 100.0))
			out.append(_option("GAME SPEED", Array(DevSettings.SPEEDS), speed_names,
				func(): return DevSettings.speed, func(v: Variant): DevSettings.speed = v,
				"SLOWER OR FASTER GAME. MENUS KEEP REAL TIME"))
			out.append(_slider("START WAVE", 1.0, DevSettings.MAX_START_WAVE, 1.0,
				func(): return float(DevSettings.start_wave), func(v: float): DevSettings.start_wave = roundi(v),
				func(v: float): return "%d" % roundi(v), "WAVE THE NEXT RUN STARTS AT. BOSS EVERY 3RD"))
			var boss_values := [""]
			var boss_names := ["SEEDED"]
			for k in WaveDirector.BOSS_KINDS:
				boss_values.append(k)
				boss_names.append(BOSS_NAMES.get(k, str(k).to_upper()))
			out.append(_option("BOSS", boss_values, boss_names,
				func(): return DevSettings.boss, func(v: Variant): DevSettings.boss = v,
				"EVERY BOSS WAVE BRINGS THIS BOSS"))
			var mut_values := [""]
			var mut_names := ["SEEDED"]
			for m in Mutators.LIST:
				mut_values.append(m.id)
				mut_names.append(m.name)
			out.append(_option("MUTATOR", mut_values, mut_names,
				func(): return DevSettings.mutator, func(v: Variant): DevSettings.mutator = v,
				"EVERY REGULAR WAVE GETS THIS MUTATOR"))
			out.append(_option("SODA CANS", on_off, on_off_names,
				func(): return DevSettings.cans, _set_cans,
				"PLAY-TEST: CANS FROM WAVE 2, NOT BOSS WAVES. NO TOP 10"))
			var can_values := [""]
			var can_names := ["SEEDED"]
			for f in Soda.LIST:
				can_values.append(f.id)
				can_names.append(f.name)
			out.append(_option("CAN FLAVOUR", can_values, can_names,
				func(): return DevSettings.can_flavour, func(v: Variant): DevSettings.can_flavour = v,
				"EVERY SODA CAN IS THIS FLAVOUR"))
		"ACTIONS":
			out.append(_action("SKIP WAVE", "KILL ALL", _skip_wave,
				"KILLS EVERY ENEMY LEFT IN THE WAVE, BOSS TOO"))
			out.append(_action("LEVEL UP", "OFFER CARDS", _level_up,
				"A LEVEL-UP CARD OFFER AS YOU RESUME"))
			out.append(_action("ALL CARDS", "GIVE MAX RANK", _all_cards,
				"EVERY LEVEL-UP CARD AT ITS TOP RANK"))
			out.append(_action("REFILL", "HP AND CELLS", _refill,
				"FULL HEALTH AND SHOTGUN CELLS"))
			out.append(_action("GIVE CANS", "FILL HANDS", _give_cans,
				"THREE SODA CANS, THE NEXT FLAVOURS IN THE LIST"))
			out.append(_action("RESTART RUN", "SAME SEED", func(): _restart(true),
				"STARTS THIS SEED AGAIN WITH THE SETTINGS ABOVE"))
			out.append(_action("NEW RUN", "NEW SEED", func(): _restart(false),
				"STARTS A FRESH SEED"))
			out.append(_action("JUICE TEST", "PLAY", func(): _restart(false, "--juicetest"),
				"EVERY BIG MOMENT BACK TO BACK. CLICK AFTER TO PLAY"))
	return out


## Turns every dev setting off (the footer's ALL OFF).
func _reset_tab() -> void:
	DevSettings.reset()
	if is_instance_valid(Game.cans):
		Game.cans.on_switch(false) # the title's run follows; a run going keeps its cans
	if perf:
		perf.show_overlay(false)
	_set_tab(tab, true)
	_show_note("EVERY DEV SETTING IS OFF")
	_changed()


# ---------------------------------------------------------------- actions
## Whether a run is going (the actions that need one say so otherwise).
func _in_run() -> bool:
	if Game.state in ["playing", "paused", "levelup"] and Game.player and not Game.player.dead:
		return true
	_show_note("START A RUN FIRST")
	return false


## An action changed the run: it no longer counts.
func _mark_run() -> void:
	Game.dev_run = true


func _skip_wave() -> void:
	if not _in_run():
		return
	_mark_run()
	_kill_all = true
	_show_note("THE WAVE DIES AS YOU RESUME")


func _level_up() -> void:
	if not _in_run():
		return
	_mark_run()
	Game.pending_levelups += 1
	_show_note("CARDS COME UP AS YOU RESUME")


func _all_cards() -> void:
	if not _in_run():
		return
	_mark_run()
	Game.main._debug_augments("all")
	_show_note("EVERY CARD AT ITS TOP RANK")


func _refill() -> void:
	if not _in_run():
		return
	_mark_run()
	Game.player.heal(Game.player.max_hp)
	Game.player.add_cells(Game.player.max_cells)
	_show_note("HEALTH AND CELLS FULL")


## SODA CANS moved: the title's run takes it at once; mid-run, on brings
## cans from the next wave and off waits for the next run.
func _set_cans(v: Variant) -> void:
	DevSettings.cans = bool(v)
	if is_instance_valid(Game.cans):
		Game.cans.on_switch(DevSettings.cans)
	if Game.state != "title":
		if DevSettings.cans:
			_show_note("CANS FROM THE NEXT WAVE (NONE ON BOSS WAVES)")
		else:
			_show_note("THIS RUN KEEPS ITS CANS" if is_instance_valid(Game.cans) and Game.cans.enabled else "SODA CANS OFF")


## Fills the can slots with the next flavours in the list (each press moves
## on, so every flavour comes round).
func _give_cans() -> void:
	if not _in_run():
		return
	if not Game.cans.enabled:
		_show_note("TURN SODA CANS ON FIRST (RUN TAB)")
		return
	_mark_run()
	Game.cans.held.clear()
	for i in Soda.MAX_HELD:
		Game.cans.held.append(Soda.LIST[_give_at % Soda.LIST.size()].id)
		_give_at += 1
	Game.cans.selected = 0
	_show_note("THREE CANS IN HAND")


## Reloads for a run (or the juice test). The run on screen ends here and is
## paid into the profile like an abandoned run, unless it is a dev run.
func _restart(same_seed: bool, launch := "") -> void:
	if Game.main == null:
		return
	close()
	Game.main.leave_run()
	Game.main.restart(same_seed, launch)


func _process(delta: float) -> void:
	super(delta)
	var running := Game.state == "playing" and not get_tree().paused
	if _kill_all and running:
		_kill_all = false
		Game.main.director.queue.clear()
		for e in Game.enemy_list.duplicate():
			if is_instance_valid(e) and not e.dead:
				e.die("dev", Vector3.ZERO)
	if Game.state == "title":
		_kill_all = false
	var hud_off := DevSettings.hide_hud and Game.state == "playing"
	if Game.hud:
		Game.hud.visible = not hud_off
	_update_tag(hud_off)


## The corner tag: what is on, and whether this run counts.
func _update_tag(hidden: bool) -> void:
	if tag == null:
		return
	var dev_run := Game.dev_run and Game.state != "title"
	# the results screen has its own layout; the tag keeps out of it
	tag.visible = not visible and not hidden and Game.state != "dead" and (dev_run or DevSettings.any_on() or (Game.cans_run and Game.state != "title"))
	if not tag.visible:
		return
	var words := DevSettings.active_tags()
	var head := "DEV RUN: NOT RECORDED" if dev_run else "DEV"
	if not dev_run and Game.cans_run and Game.state != "title":
		head = "CANS RUN: NO TOP 10"
	var key := head + "|" + "|".join(words)
	if key != _tag_key:
		_tag_key = key
		_set_tag_text(head, words)
	var vs := size if size.x > 10.0 else Vector2(480, 270)
	tag.position = Vector2(vs.x - TAG_POS.x - tag.size.x, TAG_POS.y).round()


## The head line, then the settings that are on, wrapped at TAG_W.
func _set_tag_text(head: String, words: PackedStringArray) -> void:
	var lines := PackedStringArray([head])
	var line := ""
	for w in words:
		var longer := w if line == "" else "%s, %s" % [line, w]
		if line != "" and _w(longer, Ui.font_mono, Ui.PIX) > TAG_W:
			lines.append(line + ",")
			longer = w
		line = longer
	if line != "":
		lines.append(line)
	tag.text = "\n".join(lines)
	tag.reset_size()


# ---------------------------------------------------------------- drawing
func _paint() -> void:
	super()
	# the status line: whether the run on screen counts, held in one place
	var r := _row_rect(STATUS_ROW)
	var line := "RUN TAB OR ACTIONS MAKE A DEV RUN: NO TOP 10, XP, UNLOCKS"
	if Game.dev_run and Game.state != "title":
		line = "THIS RUN IS A DEV RUN: NO TOP 10, XP OR UNLOCKS"
	_content.draw_rect(r, Color(WARN, 0.14))
	_text_in(_content, line, Ui.font_bold, LABEL_PX, LABEL_X, r, WARN)
