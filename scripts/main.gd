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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.main = self
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
	add_child(fx)
	Game.fx = fx
	director = WaveDirector.new()
	director.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(director)
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
	if OS.get_cmdline_user_args().has("--juicetest"):
		add_child(load("res://scripts/debug_juice.gd").new())
		return
	if OS.get_cmdline_user_args().has("--cardtour"):
		add_child(load("res://scripts/debug_cards.gd").new())
		return
	if OS.get_cmdline_user_args().has("--palettetour"):
		add_child(load("res://scripts/debug_palette.gd").new())
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


# ---------------------------------------------------------------- flow
func start_run() -> void:
	Game.state = "playing"
	hud.hide_title()
	_capture()
	Sfx.duck_music(-6.0)
	Sfx.start_combat_music(Game.run_seed)
	Sfx.play("coin", -4.0)
	var first := 1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--wave="):
			first = int(a.substr(7))
		elif a.begins_with("--augments="):
			_debug_augments(a.substr(11))
	director.start(first)


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
	var choices := Upgrades.roll(Game.upgrades, 3)
	if choices.is_empty():
		Game.pending_levelups = 0
		return
	Game.state = "levelup"
	get_tree().paused = true
	Sfx.play("levelup", -2.0)
	Sfx.duck_music(-16.0)
	hud.show_levelup(choices, _on_upgrade)


func _on_upgrade(id: String) -> void:
	Game.upgrades[id] = Game.rank(id) + 1
	player.on_upgrade(id)
	Game.pending_levelups -= 1
	var def := Upgrades.get_def(id)
	# a pick that moves a build forward says so instead of the plain name
	var news := Upgrades.build_news(id, Game.upgrades)
	if news.ends_with("COMPLETE"):
		_build_stamp = news # stamped once the cards are gone, never over them
	elif news != "":
		Game.popup.emit(news, Upgrades.LINK_COLOR)
	else:
		Game.popup.emit("%s ONLINE" % def.name, Upgrades.TAG_COLORS.get(def.tag, Color.WHITE))
	if Game.pending_levelups > 0:
		var choices := Upgrades.roll(Game.upgrades, 3)
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
		hud.stamp(_build_stamp, Upgrades.LINK_COLOR, 16, {"anchor": Vector2(0.5, 0.5), "off": Vector2(0, -44), "hold": 1.2, "shake": 6.0, "pitch": 1.2, "burst": 30, "shadow": Color(0.3, 0.2, 0.0)})
		_build_stamp = ""


func on_player_died() -> void:
	Game.state = "dead"
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


func restart(same_seed := false) -> void:
	if same_seed:
		Game.next_seed = Game.run_seed
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
		elif Game.pending_levelups > 0 and not Game.player.dead:
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
