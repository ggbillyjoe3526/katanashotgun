extends Node
## Debug: plays every "juice" moment back to back without any gameplay, for
## tuning and for recording. Run with:  godot --path . -- --juicetest

var _t := 0.0
var _step := 0
var _hud: Hud


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hud = Game.hud
	Game.state = "playing"
	_hud.hide_title()
	Sfx.start_combat_music(Game.run_seed)
	Game.wave = 4
	Game.score = 48210
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--juicestart="):
			_t = float(a.substr(13))


func _process(_delta: float) -> void:
	_t += Game.real_dt
	var steps := [
		[0.2, func(): _hud.wave_intro(4, "HYAKKI YAKO  //  SCORE x1.2\n60% MORE GRUNTS, BUT WEAKER", Color.WHITE, false)],
		[4.0, func(): _fake_kills(10)],
		[5.2, func(): _fake_kills(10)],
		[6.4, func():
			Game.combo = 0
			_hud.show_tally({"title": "WAVE 4 CLEAR", "rows": [["WAVE CLEAR", "", 1000], ["KILLS", "31 X 25", 775], ["GLORY KILLS", "4 X 200", 800], ["HEADSHOTS", "6 X 75", 450], ["DEFLECTS", "9 X 100", 900]], "chips": 3925, "mults": [["WAVE 4", 1.4], ["FLAWLESS", 1.5], ["HYAKKI YAKO", 1.2]], "total": 9891, "flawless": true})
			Game.add_score(9891)],
		[12.0, func():
			Sfx.music_cut()
			_hud.finish_splash()],
		[13.25, func(): _hud.souls_card("SHADOW DELETED", Color(1.0, 0.86, 0.55), "KUROKAGE  -  BLADE OF THE NULL SIGNAL", "felled", 4.6)],
		[18.4, func():
			Sfx.resume_combat()
			# own two build cards so the offer shows a RECOMMENDED card
			Game.upgrades = {"idaten": 1, "edge": 1}
			Game.pending_levelups = 1],
		[19.6, func(): _hud._select(1)],
		[20.6, func(): _hud._pick(1)],
		[21.4, func():
			_hud.show_boss_intro("KUROKAGE", "BLADE OF THE NULL SIGNAL")
			Game.popup.emit("HEADSHOT +120", Color(1.0, 0.9, 0.3))
			Game.popup.emit("GLORY KILL +400", Color(1.0, 0.3, 0.5))
			Game.popup.emit("DEFLECT +100", Color(0.4, 0.95, 1.0))
			_hud.no_ammo()
			_hud.finisher_demo = true
			_hud.show_hint("KATANA KILLS CHARGE THE SHOTGUN  -  KEEP BOTH HANDS BUSY")],
		[23.0, func(): Game.hud_message.emit("KUROKAGE IS ENRAGED", Color(1, 0.2, 0.3), false)],
		[25.0, func():
			_hud.finisher_demo = false
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
	]
	while _step < steps.size() and _t >= steps[_step][0] + 0.5 and steps[_step][0] < _t - 0.6:
		_step += 1 # skipped by --juicestart
	while _step < steps.size() and _t >= steps[_step][0]:
		steps[_step][1].call()
		_step += 1


func _fake_kills(n: int) -> void:
	for i in n:
		Game.register_kill(40, 0.0, "", Color.WHITE)
	Game.popup.emit("HEADSHOT +120", Color(1.0, 0.9, 0.3))
