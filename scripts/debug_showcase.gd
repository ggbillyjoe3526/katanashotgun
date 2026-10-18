extends Node
## Debug-only scripted scene for checking models, viewmodel animation and gore.
## Run with:  godot --path . -- --showcase
## Enemies are lined up and frozen; then killed in each gore style.

var t := 0.0
var enemies := {}
var step := 0


func _ready() -> void:
	var dir: Node = Game.main.director
	var defs := {"grunt": Vector3(-3.6, 0, 15.5), "gunner": Vector3(-1.2, 0, 15.5), "brute": Vector3(1.6, 0, 15.0), "oni": Vector3(5.5, 0, 13.0)}
	if OS.get_cmdline_user_args().has("--bosses"):
		defs = {"ninja": Vector3(-5.0, 0, 15.0), "mech": Vector3(0.5, 0, 11.0), "oni": Vector3(6.0, 0, 13.0)}
		step = 99
	for k in defs:
		var e: Enemy = Boss.new() if k in WaveDirector.BOSS_KINDS else Enemy.new()
		e.setup(k)
		e.position = defs[k]
		e.frozen = true
		dir.add_child(e)
		enemies[k] = e
	Game.player.yaw = 0.0
	Game.player.pitch = -0.02


func _process(delta: float) -> void:
	t += delta
	var p: Player = Game.player
	match step:
		0:
			if t > 1.6:
				step = 1
				p._slash()
		1:
			if t > 2.2:
				step = 2
				p._slash()
		2:
			if t > 2.7:
				step = 3
				# shotgun the grunt
				p.yaw = atan2(-(enemies.grunt.global_position.x - p.global_position.x), -(enemies.grunt.global_position.z - p.global_position.z))
				p.pitch = -0.05
		3:
			if t > 2.8:
				step = 4
				p._fire()
				if is_instance_valid(enemies.grunt) and not enemies.grunt.dead:
					enemies.grunt.take_hit(999, "shotgun", -p.global_basis.z, true, 0, 10)
		4:
			if t > 4.2:
				step = 5
				enemies.gunner.frozen = false
				enemies.gunner.stagger_now()
				enemies.gunner.frozen = true
				p.global_position = enemies.gunner.global_position + Vector3(0, 0, 2.6)
				p.yaw = 0.0
		5:
			if t > 5.0:
				step = 6
				p._slash()
		6:
			if t > 7.0:
				step = 7
				p.global_position = enemies.brute.global_position + Vector3(0.0, 0, 3.4)
				p.yaw = 0.0
				p._slash()
		7:
			if t > 7.6:
				step = 8
				if is_instance_valid(enemies.brute) and not enemies.brute.dead:
					enemies.brute.die("katana", Vector3(1, 0, -0.3))
		8:
			if t > 9.5:
				step = 9
				p.global_position = Vector3(2.0, 0, 21.0)
				p.yaw = atan2(-(enemies.oni.global_position.x - p.global_position.x), -(enemies.oni.global_position.z - p.global_position.z))
				p.pitch = 0.12
