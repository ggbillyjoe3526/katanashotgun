class_name Bolt
extends Node3D
## Slow plasma bolts fired by gunners and the boss. Slashing one with the
## katana sends it straight back at whoever fired it: it homes on its shooter
## and hits it, hard (spec §3.2 Deflect). A slash in the last moment before
## it lands is a PERFECT deflect: it goes back harder, and on a boss's white
## signature volley it also hits the boss's KAMAE hard (spec §3.2).
## Also used for the player's Crimson Wave (kind = "wave", pierces enemies).
## Bolts come from the WaveDirector's pool (`fire_bolt`): a spent bolt hides
## and goes back instead of being freed.

var vel := Vector3.ZERO
var damage := 12.0
var hostile := true
var kind := "bolt"
var life := 4.0
var radius := 0.35
var _core: MeshInstance3D
var _halo: MeshInstance3D
var _halo_mat: ShaderMaterial
var _core_mat: ShaderMaterial
var _hit := {}
var _trail_t := 0.0
## The pool that takes this bolt back when it is spent (null: freed instead).
var pool: WaveDirector = null
## Built ahead of time for a pool: hidden at once.
var prewarm := false
## The enemy or boss that fired this bolt (null for the player's own shots).
var shooter: Enemy = null
## Who a deflected bolt is flying back at (null: it flies straight).
var target: Enemy = null
## The shooter's and target's `spawn_id` when taken: a pooled enemy that
## died and came back as a new spawn is not the same enemy any more.
var _shooter_spawn := 0
var _target_spawn := 0
## Deflected and on its way back (homing while it has a target).
var _returning := false
## Part of a boss's signature volley (its number; 0: an ordinary bolt).
var volley := 0
## Sent back by a PERFECT deflect.
var perfect := false
## Share of its target's KAMAE bar this bolt fills when it lands (a perfect
## deflect on a signature volley; 0 otherwise).
var kamae_bonus := 0.0
var _halo_size := 1.0

## A returned bolt hits this many times harder than it was fired.
const RETURN_DAMAGE_MULT := 8.0
const RETURN_MIN_SPEED := 36.0
const RETURN_SPEED_MULT := 2.4
## With the shooter dead, the bolt takes the enemy nearest the aim inside
## this cone (dot product with the aim).
const FALLBACK_MIN_DOT := 0.8
## PERFECT deflect: the slash lands this many seconds or less before the
## bolt would hit the player.
const PERFECT_WINDOW := 0.15
## A bolt heading this far past the player's body still counts as landing
## (the near edge of a fan).
const PERFECT_NEAR_MISS := 0.6
## A perfect return hits this many times harder than the bolt was fired
## (a normal return: RETURN_DAMAGE_MULT).
const PERFECT_DAMAGE_MULT := 12.0
## The first perfect deflect on a signature volley fills this share of the
## boss's KAMAE bar when the bolt lands (once per volley).
const SIGNATURE_KAMAE := 0.2
const SIGNATURE_COLOR := Color(1.0, 1.0, 1.0, 0.95)
const PERFECT_COLOR := Color(0.85, 1.0, 1.0)
const _NO_HIT := {}


func setup(is_hostile: bool, pos: Vector3, velocity: Vector3, dmg: float, k := "bolt", from: Enemy = null) -> void:
	hostile = is_hostile
	position = pos
	vel = velocity
	damage = dmg
	kind = k
	shooter = from
	_shooter_spawn = from.spawn_id if from else 0
	target = null
	_target_spawn = 0
	_returning = false
	volley = 0
	perfect = false
	kamae_bonus = 0.0
	if kind == "wave":
		radius = 1.4
		life = 0.55


## Back to a fresh bolt of the same kind (call `setup` and `activate` after).
func reuse() -> void:
	shooter = null
	target = null
	_returning = false
	volley = 0
	perfect = false
	kamae_bonus = 0.0
	_halo_size = 1.0
	vel = Vector3.ZERO
	damage = 12.0
	hostile = true
	life = 4.0
	radius = 0.35
	_hit.clear()
	_trail_t = 0.0
	transform = Transform3D.IDENTITY
	match kind:
		"shuriken":
			var col: Color = Game.palette.get("neon_a", Color(1, 0.2, 0.5))
			_core_mat.set_shader_parameter("color", Color(col.r, col.g, col.b, 1.0))
			_halo_mat.set_shader_parameter("color", Color(col.r, col.g, col.b, 0.7))
		"bolt":
			_core_mat.set_shader_parameter("albedo_color", Color(1.0, 0.55, 0.2))
			_halo_mat.set_shader_parameter("color", Color(1.0, 0.4, 0.1, 0.9))
	if _core:
		_core.scale = Vector3.ONE
		_core.rotation = Vector3.ZERO
	if _halo:
		_halo.scale = Vector3.ONE


## Starts flying (runs on every shot, pooled or new).
func activate() -> void:
	reset_physics_interpolation() # a pooled bolt jumps to the muzzle
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	if hostile:
		add_to_group("enemy_projectiles")
	if kind == "wave":
		look_at_from_position(position, position + vel, Vector3.UP)


## Spent: back to the pool, or freed if it has none.
func _finish() -> void:
	if pool == null:
		queue_free()
		return
	if is_in_group("enemy_projectiles"):
		remove_from_group("enemy_projectiles")
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	pool.recycle_bolt(self)


func _ready() -> void:
	if kind == "wave":
		_build_wave()
	elif kind == "shuriken":
		var col: Color = Game.palette.get("neon_a", Color(1, 0.2, 0.5))
		_core_mat = Psx.fx(Color(col.r, col.g, col.b, 1.0), TexGen.get_tex("star"), true, false, false, 2.6)
		_core = MeshInstance3D.new()
		add_child(_core)
		for k in 2:
			var q := Psx.quad(Vector2(0.7, 0.7), _core_mat)
			q.rotation.x = -PI * 0.5 if k == 0 else 0.0
			_core.add_child(q)
		_halo_mat = Psx.fx(Color(col.r, col.g, col.b, 0.7), TexGen.get_tex("glow"), true, true, false, 1.2)
		_halo = Psx.quad(Vector2(1.2, 1.2), _halo_mat)
		add_child(_halo)
	else:
		var sm := SphereMesh.new()
		sm.radius = 0.16
		sm.height = 0.32
		sm.radial_segments = 6
		sm.rings = 3
		_core = MeshInstance3D.new()
		_core.mesh = sm
		_core_mat = Psx.unlit(Color(1.0, 0.55, 0.2), 3.0, null, {"fog_amount": 0.2})
		_core.material_override = _core_mat
		_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF # it glows
		add_child(_core)
		_halo_mat = Psx.fx(Color(1.0, 0.4, 0.1, 0.9), TexGen.get_tex("glow"), true, true, false, 1.4)
		_halo = Psx.quad(Vector2(1.3, 1.3), _halo_mat)
		add_child(_halo)
	if prewarm:
		visible = false
		process_mode = Node.PROCESS_MODE_DISABLED
		return
	activate()


func _build_wave() -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = Fx.arc_mesh(1.6, 0.55, 0.32, -2.2, -0.9)
	mi.material_override = Psx.fx(Color(1.0, 0.1, 0.2, 1.0), null, true, false, false, 2.2)
	mi.material_override.set_shader_parameter("use_vertex_color", true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_core = mi


## Marks this bolt as part of a boss's signature volley: a white-hot halo
## that says "time this one" (spec §3.2 Perfect deflect).
func mark_signature(id: int) -> void:
	volley = id
	_halo_size = 1.45
	_halo_mat.set_shader_parameter("color", SIGNATURE_COLOR)


## Seconds until a bolt at `pos` flying at `velocity` reaches a body of
## radius `reach` around `center`, along its straight path. 0 if it is
## already there; INF if it is flying away or would pass farther than
## `reach + near_miss` from the centre.
static func time_to_hit(pos: Vector3, velocity: Vector3, center: Vector3, reach: float, near_miss := 0.0) -> float:
	var v2 := velocity.length_squared()
	if v2 < 0.0001:
		return INF
	var rel := center - pos
	if rel.length() <= reach:
		return 0.0
	var t_close := rel.dot(velocity) / v2
	if t_close <= 0.0:
		return INF
	var miss := (rel - velocity * t_close).length()
	if miss > reach + near_miss:
		return INF
	# time to the body's edge; a near miss counts at its closest point
	return maxf(0.0, t_close - sqrt(maxf(0.0, reach * reach - miss * miss)) / sqrt(v2))


## True when a slash now would be a PERFECT deflect: the bolt is about to
## hit the player whose chest is at `chest`.
func in_perfect_window(chest: Vector3) -> bool:
	return hostile and time_to_hit(global_position, vel, chest, radius + 0.5, PERFECT_NEAR_MISS) <= PERFECT_WINDOW


## `split` is a Yata Mirror copy: it flies at its parent's speed and makes
## no fuss of its own (no count, popup, sound or hitstop). `is_perfect`: the
## slash landed in the last moment (see `in_perfect_window`).
func deflect(dir: Vector3, split := false, is_perfect := false) -> void:
	if not hostile:
		return
	hostile = false
	remove_from_group("enemy_projectiles")
	if split:
		# a Yata Mirror copy: already at return speed and damage, no target
		life = 2.0
		vel = dir * vel.length()
	else:
		var speed := maxf(vel.length() * RETURN_SPEED_MULT, RETURN_MIN_SPEED)
		var from_enemy: Variant = shooter if _same_spawn(shooter, _shooter_spawn) else null
		_set_target(pick_return_target(from_enemy, global_position, dir, Game.enemy_list))
		_returning = target != null
		if target:
			dir = (aim_point(target) - global_position).normalized()
			# long enough to reach the shooter wherever it stands, with margin
			life = clampf(global_position.distance_to(aim_point(target)) / speed + 1.0, 2.0, 6.0)
		else:
			life = 2.0
		vel = dir * speed
		perfect = is_perfect
		damage *= PERFECT_DAMAGE_MULT if perfect else RETURN_DAMAGE_MULT
	var col := PERFECT_COLOR if perfect else Color(0.4, 1.0, 1.0)
	if kind == "shuriken":
		_core_mat.set_shader_parameter("color", Color(col.r, col.g, col.b, 1.0))
	else:
		_core_mat.set_shader_parameter("albedo_color", col)
	_halo_mat.set_shader_parameter("color", Color(0.75, 1.0, 1.0, 0.95) if perfect else Color(0.3, 0.9, 1.0, 0.9))
	if split:
		return
	Game.deflects += 1
	if perfect:
		_perfect_deflect(dir)
		return
	Sfx.play("deflect", 0.0)
	Game.hitstop(0.07)
	if Game.hud and Game.hud.post:
		Game.hud.post.flash(0.12)
	Game.popup.emit("DEFLECT!", Color(0.4, 1.0, 1.0))
	Game.gore.sparks(global_position, dir, 18, Color(0.6, 1.8, 2.0))


## The PERFECT deflect: a ringing clang, a white flash and a longer beat of
## hitstop. The first one on a boss's signature volley also earns the big
## KAMAE hit (paid when the bolt lands) and the centre stamp PERFECT.
func _perfect_deflect(dir: Vector3) -> void:
	Game.perfect_deflects += 1
	if Game.debug_autoplay:
		print("[perfect] deflect kind=%s signature=%d frame=%d" % [kind, volley, Engine.get_frames_drawn()])
	Sfx.play("deflect_perfect", 0.0, 1.0, 0.03)
	Game.hitstop(0.1)
	if Game.hud and Game.hud.post:
		Game.hud.post.flash(0.35)
	Game.popup.emit("PERFECT DEFLECT!", Color.WHITE)
	Game.gore.sparks(global_position, dir, 32, Color(2.0, 2.0, 2.0))
	if Game.player:
		Game.player.add_trauma(0.2)
	if volley != 0 and _same_spawn(shooter, _shooter_spawn) and shooter.claim_signature(volley):
		kamae_bonus = SIGNATURE_KAMAE
		if Game.debug_autoplay:
			print("[perfect] signature volley %d pays %.0f%% KAMAE on landing" % [volley, SIGNATURE_KAMAE * 100.0])
		if Game.hud:
			Game.hud.stamp("PERFECT", Color(0.4, 1.0, 1.0), 14, {"lane": "top", "hold": 0.7, "shake": 5.0, "sound": ""})
		Game.slowmo(0.35, 0.3)


## Where a returned bolt aims on an enemy's body.
static func aim_point(e: Enemy) -> Vector3:
	return e.global_position + Vector3(0, e.height * 0.6, 0)


## Untyped on purpose: a freed enemy can't be passed as an `Enemy`.
static func _alive(e: Variant) -> bool:
	return is_instance_valid(e) and not e.dead and e.is_inside_tree()


## Alive and still the same spawn it was when we took it (pooled enemies
## come back as new spawns).
static func _same_spawn(e: Variant, spawn: int) -> bool:
	return _alive(e) and e.spawn_id == spawn


func _set_target(e: Enemy) -> void:
	target = e
	_target_spawn = e.spawn_id if e else 0


## The enemy a deflected bolt flies back at: the one that fired it while it
## lives, otherwise the living enemy nearest the aim (null if none is close
## to it, and the bolt flies straight).
static func pick_return_target(from_enemy: Variant, pos: Vector3, dir: Vector3, enemies: Array) -> Enemy:
	if _alive(from_enemy):
		return from_enemy
	var best: Enemy = null
	var best_dot := FALLBACK_MIN_DOT
	for e in enemies:
		if not _alive(e):
			continue
		var d := dir.dot((aim_point(e) - pos).normalized())
		if d > best_dot:
			best_dot = d
			best = e
	return best


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		_finish()
		return
	if _returning:
		_steer()
	var from := global_position
	var to := from + vel * delta
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	# a bolt on its way back to its shooter is never stopped by cover
	var res: Dictionary = _NO_HIT if _returning else space.intersect_ray(q)
	if not res.is_empty() and kind != "wave":
		Game.gore.sparks(res.position, res.normal, 10, Color(1.8, 0.8, 0.3) if hostile else Color(0.6, 1.8, 2.0))
		Sfx.play_at("bolt_hit", res.position, -6.0)
		_finish()
		return
	global_position = to
	if kind == "wave":
		var k := life / 0.55
		_core.scale = Vector3.ONE * (1.0 + (1.0 - k) * 0.6)
		_core.material_override.set_shader_parameter("intensity", 2.2 * k)
	else:
		_halo.scale = Vector3.ONE * _halo_size * (1.0 + sin(life * 40.0) * 0.15)
		if kind == "shuriken":
			_core.rotate_y(delta * 25.0)
		_trail_t -= delta
		if _trail_t <= 0.0:
			_trail_t = 0.03
			var trail := Color(1.8, 0.7, 0.2) if hostile else (Color(1.8, 2.0, 2.0) if perfect else Color(0.5, 1.6, 2.0))
			Game.gore.spawn_drop(global_position, Vector3.ZERO, 0.15, 0.08, 1, trail)
	if hostile:
		var p := Game.player
		if p and not p.dead:
			var c := p.global_position + Vector3(0, 1.0, 0)
			if _seg_dist(from, to, c) < radius + 0.5:
				p.take_damage(damage, from)
				Game.gore.sparks(to, -vel.normalized(), 8)
				_finish()
	else:
		for e in Game.enemy_list:
			if not is_instance_valid(e) or e.dead or _hit.has(e):
				continue
			# a returned bolt passes everyone else on its way to its target
			if _returning and e != target:
				continue
			var c: Vector3 = e.global_position + Vector3(0, e.height * 0.55, 0)
			if _seg_dist(from, to, c) < radius + e.radius + e.height * 0.25:
				_hit[e] = true
				if kind == "wave":
					e.take_hit(damage, "wave", vel.normalized(), false, damage * 0.5, 4.0)
				else:
					var killed: bool = e.take_hit(damage, "deflect", vel.normalized(), false, 140.0, 12.0)
					if kamae_bonus > 0.0 and not killed and e.kamae:
						# a perfect deflect on its signature volley: the big KAMAE hit
						e.press_kamae(e.kamae.max_value * kamae_bonus)
						Game.gore.sparks(to, Vector3.UP, 24, Color(2.0, 2.0, 2.0))
					Game.gore.sparks(to, -vel.normalized(), 14, Color(0.6, 1.8, 2.0))
					# the payback lands: a cyan flash on the body and a crack;
					# a kill also gets a beat of hitstop (not every hit, so a
					# returned gatling stream doesn't stutter)
					Game.fx.impact(to, -vel.normalized(), true)
					Sfx.play_at("bolt_hit", to, 0.0)
					if killed:
						Game.hitstop(0.05)
					_finish()
					return


## Keeps a returned bolt locked on its target. If the target dies first,
## the bolt takes the next enemy along its path, or flies on straight.
func _steer() -> void:
	if not _same_spawn(target, _target_spawn):
		_set_target(pick_return_target(null, global_position, vel.normalized(), Game.enemy_list))
		if target == null:
			_returning = false
			return
	vel = (aim_point(target) - global_position).normalized() * vel.length()


static func _seg_dist(a: Vector3, b: Vector3, p: Vector3) -> float:
	var ab := b - a
	var t := 0.0
	var l2 := ab.length_squared()
	if l2 > 0.0:
		t = clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)
