extends Node
## Debug-only check of the run card (spec §19.1 #10). Plays out the end of a
## sample run (wave 14, four bosses, two builds), types initials on the
## results screen, presses SAVE RUN CARD, and quits with exit code 1 if no
## card was saved. Needs a renderer, so in the cloud run it under xvfb:
##   xvfb-run -a godot --path . --rendering-driver opengl3 -- --runcard --runcard-out=DIR
## With --runcard-out, the card and two screenshots of the results screen
## (before and after saving) are copied to DIR. Uses the debug profile.

const TIMEOUT := 30.0

var out_dir := ""
var t := 0.0
var step := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--runcard-out="):
			out_dir = a.substr(14)
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir)
	Game.state = "playing"
	Game.hud.hide_title()
	Game.score = 1284650
	Game.wave = 14
	Game.kills = 412
	Game.executions = 58
	Game.headshots = 97
	Game.deflects = 33
	Game.best_combo = 64
	Game.level = 19
	Game.run_time = 1122.0
	Game.bosses_felled = ["ninja", "mech", "oni", "ninja"]
	Game.bosses_killed = 4
	Game.note_tally(12, 148200)
	Game.upgrades = {"fork": 1, "ikazuchi": 2, "inazuma": 1, "edge": 1, "wave": 1, "hachiman": 1}
	Game.main.on_player_died()


func _process(_delta: float) -> void:
	t += Game.real_dt
	var hud: Hud = Game.hud
	if t > TIMEOUT:
		push_error("run card check: timed out at step %d" % step)
		get_tree().quit(1)
		return
	match step:
		0: # type initials once the results ask for them
			if hud.initials_root.visible:
				hud.initials = "ACE"
				hud._finish_initials()
			if hud.death_ready():
				step = 1
		1: # the save button is up: capture it, then press it
			if hud.run_card.is_visible_in_tree():
				step = 2
				await _capture("results.png")
				hud.run_card.make()
		2:
			match hud.run_card.state:
				RunCardPanel.State.SAVED:
					step = 3
					await _capture("results-saved.png")
					var path := hud.run_card.path
					if out_dir != "":
						DirAccess.copy_absolute(path, out_dir.path_join("run-card.png"))
					print("RUN CARD saved: %s" % path)
					get_tree().quit(0)
				RunCardPanel.State.FAILED:
					step = 3
					push_error("run card check: the card was not saved")
					get_tree().quit(1)


func _capture(file: String) -> void:
	if out_dir == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png(out_dir.path_join(file))
