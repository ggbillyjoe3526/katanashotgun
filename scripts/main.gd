extends Node3D
## Boots a run: picks the map from the seed, then systems, player and HUD.
## Owns the game-state flow (title -> playing <-> paused/levelup -> dead).

var player: Player
var director: WaveDirector
var hud: Hud
var post: PostFx
var boss: Enemy = null
var _capture_grace := 0.0
var _build_stamp := "" # a build completed by this level-up, stamped after it
var lock_failures := 0
var resume: Dictionary = {} # the suspended run the title offers to continue
var results: Dictionary = {} # what this run paid into the profile (XP, levels)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.main = self
	Game.set_autoplay(Game.debug_autoplay) # a dev menu launch (or its end) changes whether a free mouse pauses
	# a suspended run brings back its own seed, so the title shows its map
	var wants_resume := (not Game.autostart and not Game.debug_no_pause) or OS.get_cmdline_user_args().has("--continue")
	if wants_resume and Profile.has_suspended_run():
		resume = Profile.load_suspended_run()
		if not resume.is_empty():
			Game.next_seed = int(resume.get("seed", -1))
	Game.reset_run()
	var arena := MapRegistry.create_for_seed(Game.rng_map)
	arena.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(arena)
	arena.build()
	Game.arena = arena
	var gore := Gore.new()
	gore.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(gore)
	Game.gore = gore
	var fx := Fx.new()
	fx.process_mode = Node.PROCESS_MODE_PAUSABLE
	fx.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF # moved every frame, not per tick
	add_child(fx)
	Game.fx = fx
	director = WaveDirector.new()
	director.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(director)
	director.between_waves.connect(_on_between_waves)
	player = Player.new()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.position = arena.player_spawn
	add_child(player)
	Game.player = player
	post = PostFx.new()
	add_child(post)
	hud = Hud.new()
	add_child(hud)
	hud.post = post
	Game.hud = hud
	if OS.get_cmdline_user_args().has("--uiaudit"):
		add_child(load("res://scripts/debug_ui_audit.gd").new())
	add_child(DebugPerf.new())
	var dev := DevMenu.attach(self)
	add_child(ShaderWarmup.new())
	if Game.has_flag("--juicetest"):
		add_child(load("res://scripts/debug_juice.gd").new())
		return
	if OS.get_cmdline_user_args().has("--movetest"):
		add_child(load("res://scripts/debug_movement.gd").new())
		return
	if OS.get_cmdline_user_args().has("--cardtour"):
		add_child(load("res://scripts/debug_cards.gd").new())
		return
	if OS.get_cmdline_user_args().has("--menutour"):
		add_child(load("res://scripts/debug_menus.gd").new())
	if OS.get_cmdline_user_args().has("--runcard"):
		add_child(load("res://scripts/debug_run_card.gd").new())
		return
	if OS.get_cmdline_user_args().has("--palettetour"):
		add_child(load("res://scripts/debug_palette.gd").new())
		return
	if OS.get_cmdline_user_args().has("--citytour"):
		add_child(load("res://scripts/debug_city.gd").new())
		return
	if OS.get_cmdline_user_args().has("--showcase"):
		Game.state = "playing"
		hud.hide_title()
		var sc: Node = load("res://scripts/debug_showcase.gd").new()
		add_child(sc)
		return
	if Game.autostart or Game.debug_autoplay:
		start_run.call_deferred()
	else:
		hud.show_title()
		Sfx.play_title_music()
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--settings"):
				# debug: open the settings screen on the title, at a tab
				hud.settings_menu.tab = maxi(0, SettingsMenu.TABS.find(a.substr(11).to_upper()))
				hud.settings_menu.open()
			elif a == "--seedentry":
				hud.open_seed_entry() # debug: open PLAY A SEED on the title
			elif a.begins_with("--dev="):
				# debug: open the dev menu on the title, at a tab
				dev.tab = maxi(0, DevMenu.DEV_TABS.find(a.substr(6).to_upper()))
				dev.open()


# ---------------------------------------------------------------- flow
func start_run() -> void:
	Game.state = "playing"
	hud.hide_title()
	_capture()
	Sfx.duck_music(-6.0)
	Sfx.start_combat_music(Game.run_seed)
	Sfx.play("coin", -4.0)
	var first := DevSettings.start_wave
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--wave="):
			first = int(a.substr(7))
		elif a.begins_with("--augments="):
			_debug_augments(a.substr(11))
	if not resume.is_empty():
		first = RunSnapshot.apply(resume, director, player)
		Game.dev_run = Game.dev_run or bool(resume.get("dev", false))
		hud.on_run_resumed()
		resume = {}
	director.start(first)


## The title's other choice when a run is suspended: the saved run ends
## here. Its XP still counts (progress is never lost), then a new seed starts.
func abandon_suspended_run() -> void:
	_end_suspended_run()
	restart(false)


## PLAY A SEED on the title: a run on that seed starts at once. A suspended
## run ends first, the same way N ends it (its XP still counts).
func play_seed(s: int) -> void:
	if not resume.is_empty():
		_end_suspended_run()
	Game.next_seed = s
	restart(false)


func _end_suspended_run() -> void:
	var stats: Dictionary = resume.get("stats", {})
	# drop the snapshot first, so a crash here can't pay the run twice
	Profile.clear_suspended_run()
	if not stats.is_empty() and not bool(resume.get("dev", false)):
		_pay_run(stats, int(resume.get("seed", 0)))
	resume = {}


func _pay_run(stats: Dictionary, run_seed: int) -> void:
	Profile.finish_run(stats)
	if Profile.qualifies(int(stats.get("score", 0))):
		Profile.add_score({"name": "---", "score": int(stats.score), "wave": int(stats.get("wave", 0)), "seed": Game.seed_string(run_seed)})


## Before the dev menu reloads the scene: the suspended run on the title, or
## the run in progress, ends here and is paid into the profile like an
## abandoned run (a dev run pays nothing), so a dev restart loses no progress.
func leave_run() -> void:
	match Game.state:
		"title":
			if not resume.is_empty():
				_end_suspended_run()
		"dead":
			pass # already paid when the player died
		_:
			Profile.clear_suspended_run()
			if not Game.dev_run:
				_pay_run(Game.run_stats(), Game.run_seed)


func _on_between_waves(next_wave: int) -> void:
	var snap := RunSnapshot.capture(next_wave, director, player)
	# if this run is abandoned from the title, it counts as reaching next_wave
	var stats := Game.run_stats()
	stats["wave"] = next_wave
	snap["stats"] = stats
	if Game.dev_run:
		snap["dev"] = true # carries on as a dev run, and pays nothing if abandoned
	Profile.suspend_run(snap)


## Debug: start with augments already picked. "all" takes every card at max
## rank; otherwise a comma list of ids, each at rank 1 ("wave:2" for more).
func _debug_augments(spec: String) -> void:
	var want := {}
	if spec == "all":
		for u in Upgrades.LIST:
			want[u.id] = u.max
	else:
		for part in spec.split(",", false):
			var bits := part.split(":")
			var def := Upgrades.get_def(bits[0])
			if def.is_empty():
				push_warning("--augments: unknown card '%s'" % bits[0])
				continue
			want[def.id] = clampi(int(bits[1]) if bits.size() > 1 else 1, 1, def.max)
	for id in want:
		for r in want[id]:
			Game.upgrades[id] = Game.rank(id) + 1
			player.on_upgrade(id)


func _capture() -> void:
	if Game.debug_autoplay:
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_capture_grace = 0.6


func pause_game() -> void:
	Game.state = "paused"
	get_tree().paused = true
	hud.show_pause(true)
	Sfx.duck_music(-20.0)


func resume_game() -> void:
	Game.state = "playing"
	get_tree().paused = false
	hud.show_pause(false)
	Sfx.duck_music(-7.0)
	_capture()


func _open_levelup() -> void:
	var choices := _roll_offer()
	if choices.is_empty():
		Game.pending_levelups = 0
		return
	Game.state = "levelup"
	get_tree().paused = true
	Sfx.play("levelup", -2.0)
	Sfx.duck_music(-16.0)
	hud.show_levelup(choices, _on_upgrade)


## The next level-up's three cards.
func _roll_offer() -> Array:
	var choices := Upgrades.roll(Game.upgrades, 3)
	if Game.debug_autoplay:
		# tools/seed_check.sh compares these lines between two runs of a seed
		print("[offer] %s" % ",".join(choices.map(func(u: Dictionary) -> String: return u.id)))
	return choices


func _on_upgrade(id: String) -> void:
	Game.upgrades[id] = Game.rank(id) + 1
	player.on_upgrade(id)
	Game.pending_levelups -= 1
	var def := Upgrades.get_def(id)
	# a pick that moves a build forward says so instead of the plain name
	var news := Upgrades.build_news(id, Game.upgrades)
	if news.ends_with("COMPLETE"):
		# stamped once the cards are gone, never over them; two completed in
		# one chain of level-ups share the stamp
		_build_stamp = news if _build_stamp == "" else "%s + %s" % [_build_stamp.trim_suffix(" COMPLETE"), news]
	elif news != "":
		Game.popup.emit(news, Upgrades.LINK_COLOR)
	else:
		Game.popup.emit("%s ONLINE" % def.name, Upgrades.TAG_COLORS.get(def.tag, Color.WHITE))
	if Game.pending_levelups > 0:
		var choices := _roll_offer()
		if not choices.is_empty():
			hud.show_levelup(choices, _on_upgrade)
			Sfx.play("levelup", -6.0)
			return
		Game.pending_levelups = 0
	hud.hide_levelup()
	get_tree().paused = false
	Game.state = "playing"
	Sfx.duck_music(-7.0)
	_capture_grace = 0.6
	if _build_stamp != "":
		hud.stamp(_build_stamp, Upgrades.LINK_COLOR, 16, {"lane": "top", "hold": 1.2, "shake": 6.0, "pitch": 1.2, "burst": 30, "shadow": Color(0.3, 0.2, 0.0)})
		_build_stamp = ""


func on_player_died() -> void:
	Game.state = "dead"
	# the run is over: drop its snapshot first, so quitting now can't undo the
	# death, then pay it into the profile and keep its score
	Profile.clear_suspended_run()
	results = _dev_results() if Game.dev_run else Profile.finish_run(Game.run_stats())
	Game.record_score()
	Sfx.music_cut()
	await get_tree().create_timer(0.6, true, false, true).timeout
	hud.souls_card("FLATLINED", Color(1.0, 0.16, 0.2), "", "flatline", 3.2)
	await get_tree().create_timer(2.8, true, false, true).timeout
	hud.show_death()
	Sfx.duck_music(-14.0)
	Sfx.play_title_music()
	if not Game.debug_autoplay:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func on_boss_killed(b: Enemy) -> void:
	boss = null
	Game.bosses_killed += 1
	Game.bosses_felled.append(b.kind)
	# the reward is saved at once; its card shows after the boss tally
	director.pending_reward = {} if Game.dev_run else Profile.boss_felled(b.kind)
	Game.slowmo(0.12, 2.6)
	# loud, then quiet: the all-out FINISH splash, a hard cut to silence, then
	# the slow souls-style line fades in
	Sfx.music_cut()
	director.on_boss_killed(b)
	hud.finish_splash()
	# copy the words now: a boss finished by a glory kill is freed before the
	# card shows, and the card used to be skipped with a script error
	var line := b.defeat_text
	var sub := "%s  -  %s" % [b.display_name, b.subtitle]
	hud.juice.later(1.25, func(): hud.souls_card(line, Color(1.0, 0.86, 0.55), sub, "felled", 4.6))
	hud.juice.later(5.4, func(): Sfx.resume_combat())


## What a dev run's results screen counts up: nothing, at the Player Level
## the profile already has.
func _dev_results() -> Dictionary:
	return {"rows": [], "xp_gained": 0, "level_before": Profile.player_level, "xp_before": Profile.player_xp,
		"level_after": Profile.player_level, "xp_after": Profile.player_xp, "levels_gained": 0}


## Reloads the scene for a new run. `launch` starts a debug mode instead
## (the dev menu's juice test).
func restart(same_seed := false, launch := "") -> void:
	if same_seed:
		Game.next_seed = Game.run_seed
	Game.dev_launch = launch
	Game.autostart = true
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().reload_current_scene()


func add_entity(n: Node) -> void:
	director.add_child(n)


func hostiles_left() -> int:
	return director.hostiles_left()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		match Game.state:
			"title":
				Sfx.play("ui_click", -4.0)
				if not hud.close_title_panel():
					start_run()
				get_viewport().set_input_as_handled()
			"paused":
				resume_game()
				get_viewport().set_input_as_handled()
			"dead":
				if hud.death_ready():
					restart(false)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F11 or (event.physical_keycode == KEY_ENTER and event.alt_pressed):
			Settings.toggle_fullscreen()
		elif event.physical_keycode == KEY_BRACKETLEFT:
			Settings.nudge_sensitivity(-0.1)
		elif event.physical_keycode == KEY_BRACKETRIGHT:
			Settings.nudge_sensitivity(0.1)
		elif event.physical_keycode == KEY_ESCAPE and Game.state == "playing":
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			pause_game()
		elif Game.state == "title" and (event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_SPACE):
			start_run()
		elif Game.state == "title" and event.physical_keycode == KEY_N and not resume.is_empty():
			Sfx.play("ui_click", -4.0)
			abandon_suspended_run()
		elif Game.state == "title" and event.physical_keycode == KEY_Q:
			# title only: in a run Q is a dash key, and a lost mouse lock pauses
			# mid-dash, so the pause screen quits by its button alone
			hud.press_title_quit()
		elif Game.state == "title" and event.physical_keycode == KEY_S:
			hud.open_seed_entry()
		elif event.physical_keycode == KEY_C and (Game.state == "paused" or (Game.state == "dead" and hud.death_ready())):
			hud.copy_seed()
		elif Game.state in ["title", "paused"] and event.physical_keycode in [KEY_1, KEY_2]:
			Profile.cycle_equipped("katana" if event.physical_keycode == KEY_1 else "shotgun")
			Sfx.play("ui_click", -4.0)
		elif Game.state == "dead" and hud.death_ready() and event.physical_keycode == KEY_R:
			restart(true)
		elif Game.state == "dead" and hud.death_ready() and event.physical_keycode in [KEY_ENTER, KEY_SPACE]:
			restart(false)


func _process(delta: float) -> void:
	_capture_grace -= delta
	if Game.state == "playing":
		if not Game.debug_no_pause and _capture_grace <= 0.0 and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			pause_game()
			lock_failures += 1
		elif Game.pending_levelups > 0 and not Game.player.dead and not hud.juice.centre_busy():
			_open_levelup()
	if Game.state == "playing" and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and _capture_grace < -3.0:
		lock_failures = 0
	if Game.debug_autoplay and Game.state == "dead" and hud.death_ready() and OS.get_cmdline_user_args().has("--restart"):
		restart(false)
	if Game.debug_autoplay and Game.state == "levelup":
		# testing: auto-pick the first augment
		hud._pick(0)
	if Game.debug_autoplay:
		_log_t -= delta
		if _log_t <= 0.0:
			_log_t = 2.0
			print("[t=%.0f] seed=%s pal=%s state=%s wave=%d boss=%s mut=%s alive=%d queue=%d kills=%d exec=%d defl=%d bosses=%d lvl=%d hp=%.0f score=%d fps=%d" % [
				Game.run_time, Game.seed_string(Game.run_seed), Game.palette.name, Game.state, Game.wave, director.boss_kind if director.is_boss_wave(Game.wave) else "-",
				Game.mutator.get("id", "-"), Game.enemy_list.size(), director.queue.size(), Game.kills,
				Game.executions, Game.deflects, Game.bosses_killed, Game.level, player.hp, Game.score,
				Engine.get_frames_per_second()])
			if OS.get_cmdline_user_args().has("--verbose-ai"):
				print("   player ", player.global_position.snapped(Vector3.ONE * 0.1), " vel ", player.velocity.snapped(Vector3.ONE * 0.1))
				for e in Game.enemy_list:
					print("   ", e.kind, " st=", e.state, " pos=", e.global_position.snapped(Vector3.ONE * 0.1), " hp=", int(e.hp), " floor=", e.is_on_floor())


var _log_t := 0.0
