extends Node
## Debug: a scripted movement course that checks the jump, double jump,
## ledge climb and plunge rules on real physics, then quits with exit code 0
## (all passed) or 1. Run with:
##   godot --headless --path . --fixed-fps 60 -- --movetest
## Each check builds its blocks on a test floor far outside the arena, puts
## the player in place and holds keys for it, the way a player would.

const ORIGIN := Vector3(300, 0, 0) # well away from the arena and its spawns
const TIMEOUT := 240 # physics frames per check

var _checks: Array[Dictionary] = []
var _i := -1
var _f := 0
var _course: Node3D
var _climbed := false
var _plunge_seen := false
var _max_y := -INF
var _max_h := 0.0 # top horizontal speed seen in the check
var _enemy: Enemy
var _fails := 0
var _executions0 := 0
var _taps := {} # action -> physics frame to let go of it
var _double_sent := false
var _finisher_sent := false
var _pad: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = -100 # presses land before the player reads them
	Game.state = "playing"
	Game.debug_god = true
	Game.hud.hide_title()
	_add_floor()
	var d := Player.JUMP_VEL * Player.JUMP_VEL / (2.0 * Player.GRAVITY)
	var dd := Player.DOUBLE_JUMP_VEL * Player.DOUBLE_JUMP_VEL / (2.0 * Player.GRAVITY)
	print("[movetest] on paper: jump apex %.2f m, double jump adds %.2f m (up to %.2f m), grab reach %.2f m" % [d, dd, d + dd, LedgeClimb.REACH])
	_checks = [
		{"name": "clean jump onto a 1.2 m crate, no climb", "blocks": [[1.2, 3.0]], "keys": ["jump"], "want_climb": false, "want_top": 1.2},
		{"name": "single jump falls short of 2.6 m, climbs it", "blocks": [[2.6, 2.0]], "keys": ["jump"], "want_climb": true, "want_top": 2.6},
		{"name": "single jump up to a 3.6 m ledge, climbs it", "blocks": [[3.6, 1.2]], "keys": ["jump"], "want_climb": true, "want_top": 3.6},
		{"name": "double jump onto a 3.6 m deck, no climb", "blocks": [[3.6, 1.2]], "keys": ["jump", "double"], "forward": false, "forward_at_double": true, "want_climb": false, "want_top": 3.6},
		{"name": "double jump plus climb onto a 5.6 m tower", "blocks": [[5.6, 1.2]], "keys": ["jump", "double"], "want_climb": true, "want_top": 5.6},
		{"name": "a 7 m wall can never be climbed", "blocks": [[7.0, 1.2]], "keys": ["jump", "double"], "want_climb": false, "want_top": 0.0},
		{"name": "double jump height on open floor", "blocks": [], "keys": ["jump", "double"], "want_climb": false, "want_top": 0.0, "measure": true, "forward": false},
		{"name": "double jump pushes a little toward the keys held", "blocks": [], "keys": ["jump", "double"], "push": true},
		{"name": "no plunge from a jump on the same level", "blocks": [], "keys": ["jump", "double"], "enemy": Vector3(0, 0, -2.0), "want_plunge": false, "forward": false, "pitch": -0.9},
		{"name": "no plunge onto a brute that isn't staggered", "blocks": [[4.0, 0.0, 6.0]], "start_y": 4.0, "keys": [], "enemy": Vector3(0, 0, -3.5), "kind": "brute", "want_plunge": false, "pitch": -0.9},
		{"name": "plunge onto a grunt at the foot of the wall lands clear of it", "blocks": [[4.0, 0.0, 6.0]], "start_y": 4.0, "keys": [], "enemy": Vector3(0, 0, -1.5), "want_plunge": true, "want_top": 0.0, "max_z": -1.4, "pitch": -1.3},
		{"name": "plunge from a 4 m ledge onto a grunt", "blocks": [[4.0, 0.0, 6.0]], "start_y": 4.0, "keys": [], "enemy": Vector3(0, 0, -3.2), "want_plunge": true, "pitch": -0.9},
		{"name": "plunge from a jump pad launch onto a grunt on the same floor", "blocks": [], "keys": [], "pad": Vector3(0, 17.0, -5.0), "enemy": Vector3(0, 0, -6.0), "want_plunge": true, "forward": false, "pitch": -1.1},
	]
	_next()


func _add_floor() -> void:
	_course = Node3D.new()
	add_child(_course)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	cs.shape = box
	body.add_child(cs)
	body.position = ORIGIN + Vector3(0, -0.5, 0)
	_course.add_child(body)


## A block in front of the player: [top height, gap from the player to its
## face, optional depth]. With gap 0 the player starts on top of it, 1 m back
## from the edge in front.
func _add_block(spec: Array) -> void:
	var h: float = spec[0]
	var gap: float = spec[1]
	var depth: float = spec[2] if spec.size() > 2 else 4.0
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6, h, depth)
	cs.shape = box
	body.add_child(cs)
	var face_z := -1.0 if gap <= 0.0 else -(gap + Player.CAPSULE_RADIUS)
	var center_z := face_z + depth * 0.5 if gap <= 0.0 else face_z - depth * 0.5
	body.position = ORIGIN + Vector3(0, h * 0.5, center_z)
	_course.add_child(body)


func _next() -> void:
	_i += 1
	_f = 0
	_climbed = false
	_plunge_seen = false
	_double_sent = false
	_finisher_sent = false
	_max_y = -INF
	_max_h = 0.0
	for n in _course.get_children().slice(1):
		_course.remove_child(n) # out of the world now, so the next start is clear
		n.queue_free()
	if is_instance_valid(_enemy):
		_enemy.queue_free()
	_enemy = null
	Game.arena.jump_pads.erase(_pad)
	_pad = {}
	_release()
	if _i >= _checks.size():
		print("[movetest] %s: %d of %d checks failed" % ["FAIL" if _fails > 0 else "PASS", _fails, _checks.size()])
		get_tree().quit(1 if _fails > 0 else 0)
		return
	var c := _checks[_i]
	for b in c.blocks:
		_add_block(b)
	if c.has("pad"):
		_pad = {"pos": ORIGIN, "r": 1.35, "launch": c.pad}
		Game.arena.jump_pads.append(_pad)
	if c.has("enemy"):
		_enemy = Enemy.new()
		_enemy.setup(c.get("kind", "grunt"))
		_enemy.frozen = true
		_enemy.position = ORIGIN + c.enemy
		Game.main.director.add_child(_enemy)
	var p := Game.player
	p.global_position = ORIGIN + Vector3(0, c.get("start_y", 0.0) + 0.02, 0)
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
	p.yaw = 0.0
	p.pitch = c.get("pitch", 0.0)
	p.jumps_left = 1
	_executions0 = Game.executions


func _release() -> void:
	_taps.clear()
	for a in ["move_forward", "jump", "finisher"]:
		Input.action_release(a)


## A key press held for two physics frames, so the player sees exactly one
## "just pressed" whichever of us runs first in a frame.
func _tap(action: String) -> void:
	Input.action_press(action)
	_taps[action] = _f + 2


func _physics_process(_delta: float) -> void:
	if _i < 0 or _i >= _checks.size():
		return
	var c := _checks[_i]
	var p := Game.player
	_f += 1
	Game.player.hp = Game.player.max_hp
	# keys: settle 10 frames, then walk forward; jump at once, double jump
	# at the top of the first jump
	for a in _taps.keys():
		if _f >= _taps[a]:
			Input.action_release(a)
			_taps.erase(a)
	if _f == 10 and c.get("forward", true):
		Input.action_press("move_forward")
	if _f == 12 and c.keys.has("jump"):
		_tap("jump")
	if c.keys.has("double") and not _double_sent and _f > 16 and not p.is_on_floor() and p.velocity.y <= 0.3 and p.climb_t < 0.0:
		_double_sent = true
		_tap("jump")
		if c.get("forward_at_double", false):
			Input.action_press("move_forward")
	if p.climb_t >= 0.0:
		_climbed = true
	_max_y = maxf(_max_y, p.global_position.y)
	_max_h = maxf(_max_h, Vector2(p.velocity.x, p.velocity.z).length())
	if OS.get_cmdline_user_args().has("--movetrace"):
		print("[trace] %d f=%d y=%.2f vy=%.2f floor=%s jl=%d climb=%.2f ready=%s plunge=%s gk=%s" % [_i, _f, p.global_position.y, p.velocity.y, p.is_on_floor(), p.jumps_left, p.climb_t, p.gk_ready != null, p.gk_ready_plunge, p.gk_target != null])
	if p.gk_ready_plunge:
		_plunge_seen = true
		if c.get("want_plunge", false) and not _finisher_sent:
			_finisher_sent = true
			_tap("finisher")
	var settled := _f > 30 and p.is_on_floor() and p.climb_t < 0.0 and p.gk_target == null
	if c.has("enemy"):
		settled = settled and (_f > 150 or (_enemy_gone() and p.gk_target == null))
	if not settled and _f < TIMEOUT:
		return
	_finish(c, p)
	_next()


func _enemy_gone() -> bool:
	return not is_instance_valid(_enemy) or _enemy.dead


func _finish(c: Dictionary, p: Player) -> void:
	var y := p.global_position.y
	var errs: Array[String] = []
	if c.has("want_climb") and _climbed != c.want_climb:
		errs.append("climbed=%s" % _climbed)
	if c.has("want_top") and not c.get("measure", false) and absf(y - float(c.want_top)) > 0.15:
		errs.append("ended at y=%.2f, wanted %.2f" % [y, c.want_top])
	if c.has("max_z") and p.global_position.z - ORIGIN.z > float(c.max_z):
		errs.append("ended inside the ledge (z=%.2f)" % (p.global_position.z - ORIGIN.z))
	if c.get("measure", false) and _max_h > 0.5:
		errs.append("drifted %.2f m/s with no keys held" % _max_h)
	if c.get("push", false):
		var lo := Player.WALK_SPEED + 1.0
		var hi := Player.WALK_SPEED * Player.DOUBLE_JUMP_PUSH_CAP + 0.05
		if _max_h < lo or _max_h > hi:
			errs.append("top speed %.2f m/s, wanted %.1f to %.1f" % [_max_h, lo, hi])
	if c.get("measure", false):
		var want := (Player.JUMP_VEL * Player.JUMP_VEL + Player.DOUBLE_JUMP_VEL * Player.DOUBLE_JUMP_VEL) / (2.0 * Player.GRAVITY)
		if absf(_max_y - want) > 0.25:
			errs.append("peak %.2f m, wanted about %.2f" % [_max_y, want])
	if c.has("want_plunge"):
		if _plunge_seen != c.want_plunge:
			errs.append("plunge prompt=%s" % _plunge_seen)
		if c.want_plunge and not (_enemy_gone() and Game.executions == _executions0 + 1):
			errs.append("plunge did not kill (executions +%d)" % (Game.executions - _executions0))
	if errs.is_empty():
		print("[movetest] ok    %s (y=%.2f, peak %.2f, top speed %.1f)" % [c.name, y, _max_y, _max_h])
	else:
		_fails += 1
		print("[movetest] FAIL  %s: %s" % [c.name, ", ".join(errs)])
