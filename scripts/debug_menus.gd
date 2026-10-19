extends Node
## Debug: shows every Focus menu in turn (spec §9.7), for screenshots and for
## the overlap audit. Run with:  godot --path . -- --menutour [--uiaudit]
## Title (plain, then each side panel and a suspended run), pause with the
## armory open, a level-up hand with a card chosen, then the results with a
## new best and initials typed. Uses the debug profile, never the player's.

var _t := 0.0
var _step := 0
var _hud: Hud


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hud = Game.hud
	# a made-up table so the hi-scores have rows to show
	Profile.high_scores = [
		{"name": "WIL", "score": 55000, "wave": 9, "seed": ""},
		{"name": "AKI", "score": 31270, "wave": 7, "seed": ""},
	]


func _process(_delta: float) -> void:
	_t += Game.real_dt
	var steps := [
		[2.0, func(): _hud.title_menu.press(Hud.T_HOWTO)],
		[4.0, func(): _hud.title_menu.press(Hud.T_ARMORY)],
		[6.0, func(): _click(_hud.title_menu, Hud.T_SCORES, "title HI-SCORES")],
		[6.5, func(): print("[menutour] title panel: %s" % _hud._title_panel_kind)],
		[8.0, func():
			Game.main.resume = {"next_wave": 7}
			_hud.show_title()],
		[10.0, func():
			_hud.title_menu.press(Hud.T_QUIT)],
		[11.0, func():
			Game.main.resume = {}
			Game.main.start_run()],
		[14.0, func():
			Game.upgrades = {"idaten": 1, "edge": 1, "fork": 1}
			Game.main.pause_game()
			Game.main.lock_failures = 2], # shows the mouse-lock hint
		[15.5, func(): _click(_hud.pause_menu, Hud.P_ARMORY, "pause ARMORY")],
		[16.0, func(): print("[menutour] pause armory open: %s" % _hud.pause_armory_plate.visible)],
		[17.5, func(): Game.main.resume_game()],
		[18.0, func(): Game.pending_levelups = 1],
		[20.0, func(): _hud._select(1)],
		[22.0, func(): _hud._pick(1)],
		[23.0, func():
			Game.kills = 212
			Game.executions = 61
			Game.headshots = 40
			Game.deflects = 141
			Game.bosses_killed = 2
			Game.best_combo = 64
			Game.level = 14
			Game.run_time = 342.0
			Game.wave = 14
			Game.score = 386418
			Game.player.dead = true
			Game.main.on_player_died()],
		[29.5, func(): _hud.initials = "JC"],
		[31.0, func():
			_hud.initials = "JCE"
			_hud._finish_initials()],
		[38.0, func(): get_tree().quit()],
	]
	while _step < steps.size() and _t >= steps[_step][0]:
		steps[_step][1].call()
		_step += 1


## A real mouse click on a menu item's words, through the viewport like the
## player's, so the tour also checks that clicks reach the items.
func _click(list: MenuList, i: int, what: String) -> void:
	var row: Control = list.get_child(i + 1) # child 0 is the marker bar
	var at := get_viewport().get_final_transform() * row.get_global_rect().get_center()
	print("[menutour] click %s at %s" % [what, at])
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	get_viewport().push_input(move)
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = at
		e.global_position = at
		get_viewport().push_input(e)
