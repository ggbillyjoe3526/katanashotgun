class_name Player
extends CharacterBody3D
## Fast Doom-style movement + the katana/shotgun dual wield.
##   LMB  katana  — 3-hit combo, cleaves, deflects bolts, katana kills
##                  charge cells.
##   RMB  arc shotgun — hitscan "pellets" drawn as lightning, headshots x2,
##                  staggers.
## Glory kills (Doom 2016 style): pressing F (the `finisher` action) near a
## staggered enemy locks the camera on, lunges you in and plays a short
## contextual finisher while you are invulnerable. The world runs in slow
## motion; the finisher runs in real time.
##   Shift dash (i-frames), Space jump / double jump.

const WALK_SPEED := 8.8
const GROUND_ACCEL := 70.0
const AIR_ACCEL := 28.0
const GRAVITY := 26.0
const JUMP_VEL := 9.4
const DOUBLE_JUMP_VEL := 8.6
const DASH_SPEED := 21.0
const DASH_TIME := 0.2
const DASH_RECHARGE := 1.4 # seconds per charge
const BASE_FOV := 88.0 # the default; the live value is Settings.fov
const KATANA_CD := 0.32
const KATANA_FINISHER_CD := 0.45
const SHOTGUN_CD := 0.72
const OVERHEAL_PER_CELL := 6.0 # Chimatsuri Steel: HP of overheal per cell
const UTSUSEMI_CD := 3.0 # Utsusemi Shell: seconds between saves
# glory kill reach: a staggered enemy can be finished from this far (metres
# past its body) and this close to the crosshair. The current target is kept
# a little further out so the prompt doesn't flicker at the edge.
const FINISHER_REACH := 4.5
const FINISHER_KEEP_REACH := 5.5
const KURAMA_REACH := 9.0 # Kurama Leap augment
const KURAMA_KEEP_REACH := 10.0
const GLORY_LUNGE := 0.13 # seconds to close FINISHER_REACH; longer leaps take longer
const GLORY_LUNGE_MAX := 0.26
const FINISHER_CONE := PI / 3.0 # 60 degrees
const FINISHER_KEEP_CONE := PI * 4.0 / 9.0 # 80 degrees
const FINISHER_BUFFER := 0.18
const FINISHER_HEIGHT_REACH := 1.7 # above/below the enemy's middle, as the katana
const FINISHER_DIST_WEIGHT := 0.05 # radians of aim one metre of distance is worth
const FINISHER_SIGHT_HEIGHT := 0.8 # the wall check aims this high up the body

var head: Node3D
var cam: Camera3D
var vm: Viewmodel
var muzzle_light: OmniLight3D

var yaw := 0.0
var pitch := 0.0
var recoil := 0.0
var max_hp := 100.0
var hp := 100.0
var max_cells := 4
var cells := 4
var cell_regen := 0.0
var max_dash := 2
var dash_charges := 2.0
var dash_t := 0.0
var dash_dir := Vector3.ZERO
var _dash_hit := {}
var jumps_left := 1
var katana_cd := 0.0
var shotgun_cd := 0.0
var katana_buffer := 0.0
var combo_step := 0
var combo_reset := 0.0
var slash_count := 0
var invuln := 0.0
var dead := false
var trauma := 0.0
var _shake_t := 0.0
var fov_kick := 0.0
var exec_zoom := 0.0
var tilt := 0.0
var bob_t := 0.0
var land_dip := 0.0
var _was_on_floor := true
var _prev_vy := 0.0
var _knock := Vector3.ZERO
var _hurt_t := 0.0
var _input_dir := Vector2.ZERO
var _attract_t := 0.0
var _auto_t := 0.0
var _auto_strafe := 1.0
var utsusemi_cd := 0.0
var _overheal := 0.0 # Chimatsuri Steel: healing past full HP, banked toward cells
var _sanzu_wave := -1 # the wave Sanzu Reprieve was last spent in

# glory kill
var gk_ready: Enemy = null # the staggered enemy F would finish right now
var finisher_buffer := 0.0
var _sight_query := PhysicsRayQueryParameters3D.new() # reused: no per-frame allocation
var gk_target: Enemy = null
var gk_kind := ""
var gk_t := 0.0
var gk_len := 0.8
var gk_from := Vector3.ZERO
var gk_to := Vector3.ZERO
var gk_cam_y := 0.0
var gk_events: Array = []
var gk_lunge := GLORY_LUNGE
var _gk_yaw0 := 0.0
var _gk_pitch0 := 0.0
var _gk_dir := Vector3.FORWARD


func _ready() -> void:
	_sight_query.collision_mask = 1 # world only
	collision_layer = 2
	collision_mask = 1
	floor_max_angle = deg_to_rad(50)
	floor_snap_length = 0.35
	add_to_group("player")
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	head = Node3D.new()
	head.position.y = 1.55
	add_child(head)
	cam = Camera3D.new()
	cam.fov = Settings.fov
	cam.near = 0.02
	cam.far = 500.0
	head.add_child(cam)
	cam.current = true
	vm = Viewmodel.new()
	cam.add_child(vm)
	muzzle_light = OmniLight3D.new()
	muzzle_light.light_color = Color(0.45, 0.75, 1.0)
	muzzle_light.omni_range = 10.0
	muzzle_light.light_energy = 0.0
	muzzle_light.position = Vector3(0.2, -0.1, -0.8)
	cam.add_child(muzzle_light)
	vm.set_cells(cells, max_cells)
	yaw = rotation.y


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Game.state == "playing" and not dead and gk_target == null:
		var rel: Vector2 = event.screen_relative
		yaw -= rel.x * Game.mouse_sensitivity
		pitch = clampf(pitch - rel.y * Game.mouse_sensitivity, -1.52, 1.52)
		vm.add_sway(rel)


# ---------------------------------------------------------------- frame
func _process(delta: float) -> void:
	if gk_target != null:
		_update_glory(Game.real_dt)
	if Game.state == "title":
		_attract_t += delta
		yaw = sin(_attract_t * 0.15) * 0.5
		pitch = 0.08 + sin(_attract_t * 0.23) * 0.05
	rotation.y = yaw
	recoil = move_toward(recoil, 0.0, delta * 0.5)
	head.rotation.x = pitch + recoil
	# shake
	trauma = maxf(0.0, trauma - delta * 1.6)
	_shake_t += delta * 30.0
	var sh := trauma * trauma * Settings.shake
	cam.rotation.x = sin(_shake_t * 1.3) * 0.04 * sh
	cam.rotation.y = sin(_shake_t * 1.7 + 2.0) * 0.04 * sh
	tilt = lerpf(tilt, -_input_dir.x * 0.035, 1.0 - exp(-8.0 * delta))
	cam.rotation.z = tilt + sin(_shake_t * 1.1 + 4.0) * 0.06 * sh
	cam.h_offset = sin(_shake_t * 2.1) * 0.08 * sh
	cam.v_offset = sin(_shake_t * 2.6 + 1.0) * 0.08 * sh
	fov_kick = move_toward(fov_kick, 0.0, delta * 60.0)
	exec_zoom = move_toward(exec_zoom, 0.0, delta * 25.0)
	cam.fov = Settings.fov + fov_kick - exec_zoom
	land_dip = move_toward(land_dip, 0.0, delta * 1.2)
	var hspeed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and hspeed > 1.0 and dash_t <= 0.0:
		bob_t += delta * hspeed * 0.9
	var bob_amt := clampf(hspeed / WALK_SPEED, 0.0, 1.0) if is_on_floor() else 0.0
	head.position.y = (1.55 if not dead else 0.35) + sin(bob_t * 2.0) * 0.035 * bob_amt - land_dip + gk_cam_y
	vm.set_bob(bob_amt, bob_t)
	vm.visible = Game.state != "title"
	muzzle_light.light_energy = move_toward(muzzle_light.light_energy, 0.0, delta * 80.0)
	if dead:
		cam.rotation.z = lerpf(cam.rotation.z, 0.6, 1.0 - exp(-3.0 * delta))


func _physics_process(delta: float) -> void:
	if Game.state == "title":
		return
	katana_cd -= delta
	shotgun_cd -= delta
	katana_buffer -= delta
	finisher_buffer -= delta
	combo_reset -= delta
	invuln -= delta
	_hurt_t -= delta
	utsusemi_cd -= delta
	if dead:
		_set_finisher_target(null)
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
		velocity.y -= GRAVITY * delta
		move_and_slide()
		return
	if gk_target != null:
		# the finisher drives the body; nothing else happens meanwhile
		velocity = Vector3.ZERO
		return

	# glory kill on F: the press is buffered like the katana's, so pressing
	# just before an enemy staggers or comes into reach still counts
	_set_finisher_target(_find_finisher_target())
	if Input.is_action_just_pressed("finisher") or (Game.debug_autoplay and gk_ready != null):
		finisher_buffer = FINISHER_BUFFER
	if finisher_buffer > 0.0 and gk_ready != null:
		finisher_buffer = 0.0
		_start_glory(gk_ready)
		return

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if Game.debug_autoplay:
		input = _autoplay(delta)
	_input_dir = input
	var wish := Basis(Vector3.UP, yaw) * Vector3(input.x, 0, input.y)
	if wish.length() > 1.0:
		wish = wish.normalized()

	# dash
	if Input.is_action_just_pressed("dash") and dash_charges >= 1.0 and dash_t <= 0.0:
		_start_dash(wish)
	dash_charges = minf(float(max_dash), dash_charges + delta / DASH_RECHARGE)

	if dash_t > 0.0:
		dash_t -= delta
		velocity = dash_dir * DASH_SPEED
		if Game.rank("dashcut") > 0:
			_dash_cut()
		if dash_t <= 0.0:
			velocity = dash_dir * WALK_SPEED * 1.15
	else:
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		var hv := Vector3(velocity.x, 0, velocity.z)
		var target := wish * WALK_SPEED
		var accel := GROUND_ACCEL if is_on_floor() else AIR_ACCEL
		if hv.length() > WALK_SPEED * 1.05 and not is_on_floor():
			accel *= 0.3 # keep jump-pad / dash momentum in the air
		hv = hv.move_toward(target, accel * delta)
		velocity.x = hv.x
		velocity.z = hv.z

	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = JUMP_VEL
			Sfx.play("jump", -8.0)
		elif jumps_left > 0:
			jumps_left -= 1
			velocity.y = DOUBLE_JUMP_VEL
			Sfx.play("jump", -6.0, 1.3)
			Game.gore.sparks(global_position, Vector3.DOWN, 6, Color(0.5, 1.6, 2.0))

	velocity += _knock
	_knock = Vector3.ZERO
	_prev_vy = velocity.y
	move_and_slide()

	if is_on_floor():
		if not _was_on_floor and _prev_vy < -6.0:
			land_dip = clampf(-_prev_vy * 0.012, 0.0, 0.22)
			Sfx.play("land", -10.0)
		jumps_left = 1
	_was_on_floor = is_on_floor()

	for pad in Game.arena.jump_pads:
		var d := Vector2(global_position.x - pad.pos.x, global_position.z - pad.pos.z).length()
		if d < pad.r and global_position.y < pad.pos.y + 0.6 and velocity.y <= 0.5:
			velocity = pad.launch
			jumps_left = 1
			Sfx.play("jumppad", -4.0)
			fov_kick = 10.0
			Game.gore.sparks(global_position, Vector3.UP, 16, Color(0.4, 2.0, 1.4))

	# cells trickle back slowly (max 2) so you're never fully stranded
	if cells < 2 and Game.mut("regen", true):
		cell_regen += delta
		if cell_regen >= 2.5:
			cell_regen = 0.0
			add_cells(1)
	else:
		cell_regen = 0.0

	# weapons
	var katana_pressed := Input.is_action_just_pressed("katana")
	var katana_held := Input.is_action_pressed("katana")
	var shotgun_held := Input.is_action_pressed("shotgun")
	if Game.debug_autoplay:
		var auto := _autoplay_weapons()
		katana_pressed = auto.x > 0.5
		katana_held = katana_pressed
		shotgun_held = auto.y > 0.5
	if katana_pressed:
		katana_buffer = 0.18
	if (katana_buffer > 0.0 or katana_held) and katana_cd <= 0.0:
		_slash()
	if shotgun_held and shotgun_cd <= 0.0:
		_fire()

	if global_position.y < -10.0:
		global_position = Game.arena.player_spawn
		velocity = Vector3.ZERO


# ---------------------------------------------------------------- movement
func _start_dash(wish: Vector3) -> void:
	dash_charges -= 1.0
	var d := wish
	if d.length() < 0.1:
		d = -global_basis.z
	d.y = 0.0
	dash_dir = d.normalized()
	dash_t = DASH_TIME
	invuln = DASH_TIME + 0.1
	fov_kick = 14.0
	_dash_hit.clear()
	Game.hud.speed_lines(0.55)
	Sfx.play("dash", -4.0)
	if Game.rank("idaten") > 0:
		add_cells(1)


func _dash_cut() -> void:
	for e in Game.enemy_list:
		if not is_instance_valid(e) or e.dead or _dash_hit.has(e):
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		if to.length() < e.radius + 1.3:
			_dash_hit[e] = true
			var dmg := 40.0 * Game.rank("dashcut")
			var killed: bool = e.take_hit(dmg, "dashcut", dash_dir, false, 30.0, 5.0)
			Sfx.play("slice", -4.0, 1.2)
			Game.hitstop(0.03)
			if killed:
				add_cells(1)


func knockback(v: Vector3) -> void:
	_knock += v
	if v.y > 0.0:
		velocity.y = maxf(velocity.y, 0.0)


func add_trauma(t: float) -> void:
	trauma = clampf(trauma + t, 0.0, 1.0)


# ---------------------------------------------------------------- katana
func _slash() -> void:
	katana_buffer = 0.0
	combo_step = (combo_step + 1) % 3 if combo_reset > 0.0 else 0
	combo_reset = 0.65
	katana_cd = KATANA_CD if combo_step < 2 else KATANA_FINISHER_CD
	slash_count += 1
	vm.slash(combo_step)
	Game.fx.slash_trail(cam, combo_step)
	Sfx.play("swing%d" % combo_step, -3.0)

	var origin := cam.global_position
	var fwd := -cam.global_basis.z
	var right := cam.global_basis.x
	var fwd_flat := Vector3(fwd.x, 0, fwd.z).normalized()
	var reach := 3.4
	var half := deg_to_rad(68.0)
	var dmg := 50.0 * float(Game.mut("dmg_out", 1.0))
	# Masamune Edge: the third cut is a heavy one that ignores armour
	var heavy := combo_step == 2 and Game.rank("edge") > 0
	var source := "heavy" if heavy else "katana"
	var poise := 100.0 if heavy else 18.0
	if heavy:
		dmg *= 2.0
	var sweep := right if combo_step == 0 else (-right if combo_step == 1 else Vector3.DOWN)
	var hit_dir := (fwd_flat * 0.6 + sweep * 0.8).normalized()

	var hits: Array = []
	for e in Game.enemy_list:
		if not is_instance_valid(e) or e.dead:
			continue
		var center: Vector3 = e.global_position + Vector3(0, e.height * 0.5, 0)
		var to := center - origin
		var flat := Vector3(to.x, 0, to.z)
		var d: float = flat.length() - e.radius
		if d > reach:
			continue
		if absf(to.y) > e.height * 0.5 + 1.7:
			continue
		if flat.length() > 0.4 and fwd_flat.angle_to(flat.normalized()) > half:
			continue
		hits.append(e)
	hits.sort_custom(func(a, b): return a.global_position.distance_squared_to(global_position) < b.global_position.distance_squared_to(global_position))

	var killed := 0
	var homura := Game.rank("homura") > 0
	for e in hits:
		var d := dmg
		if homura:
			# burning enemies are cut deeper; the cut then sets (or keeps) them alight
			if e.burn_t > 0.0:
				d *= 1.5
			e.ignite(1)
		if e.take_hit(d, source, hit_dir, false, poise, 4.0):
			killed += 1
	if hits.size() > 0:
		Sfx.play("slice", -1.0)
		if heavy:
			Sfx.play("slam", -6.0, 1.4)
		Game.hitstop(0.045 + 0.012 * mini(hits.size(), 4) + (0.02 if heavy else 0.0))
		add_trauma(0.32 if heavy else 0.22)
		if Game.rank("chimatsuri") > 0:
			_blood_heal(float(Game.rank("chimatsuri") * hits.size()))
	if killed > 0:
		add_cells(killed * (1 + Game.rank("battery")))

	# deflect bolts
	for b in get_tree().get_nodes_in_group("enemy_projectiles"):
		var to: Vector3 = b.global_position - origin
		if to.length() > reach + 2.2:
			continue
		if to.length() > 0.5 and fwd.angle_to(to.normalized()) > half + 0.35:
			continue
		b.deflect(fwd)
		add_cells(1)
		if Game.rank("yata") > 0:
			_mirror_split(b)

	if Game.rank("wave") > 0:
		var every := 4 - Game.rank("wave")
		if slash_count % maxi(1, every) == 0 or heavy:
			var w := Bolt.new()
			w.setup(false, origin + fwd * 0.8, fwd * 26.0, 40.0 + 15.0 * Game.rank("wave"), "wave")
			Game.main.add_entity(w)
			Sfx.play("wave_blade", -4.0)


## Chimatsuri Steel: katana healing; past full HP it banks toward cells.
func _blood_heal(amount: float) -> void:
	var room := maxf(0.0, max_hp - hp)
	heal(amount)
	if amount <= room:
		return
	_overheal += amount - room
	while _overheal >= OVERHEAL_PER_CELL:
		_overheal -= OVERHEAL_PER_CELL
		add_cells(1)


## Yata Mirror: a deflected bolt sends two more copies out either side.
func _mirror_split(b: Bolt) -> void:
	for side in [-1.0, 1.0]:
		var nb := Bolt.new()
		nb.setup(true, b.global_position, b.vel, b.damage, b.kind)
		Game.main.add_entity(nb)
		# 0.35 rad stays outside the deflect auto-aim cone, so the copies fan out
		nb.deflect(b.vel.normalized().rotated(Vector3.UP, side * 0.35), true)


# ---------------------------------------------------------------- glory kills
## The staggered enemy a glory kill would take: in reach, near the crosshair
## and in plain sight. Closest to the crosshair wins.
func _find_finisher_target() -> Enemy:
	var origin := cam.global_position
	var fwd := -cam.global_basis.z
	var fwd_flat := Vector3(fwd.x, 0, fwd.z).normalized()
	var best: Enemy = null
	var best_score := INF
	var leap := Game.rank("kurama") > 0
	var reach := KURAMA_REACH if leap else FINISHER_REACH
	var keep_reach := KURAMA_KEEP_REACH if leap else FINISHER_KEEP_REACH
	for e in Game.enemy_list:
		if not is_instance_valid(e) or not e.is_staggered():
			continue
		var keep: bool = e == gk_ready
		var center: Vector3 = e.global_position + Vector3(0, e.height * 0.5, 0)
		var to := center - origin
		var flat := Vector3(to.x, 0, to.z)
		var d: float = flat.length() - e.radius
		if d > (keep_reach if keep else reach):
			continue
		if absf(to.y) > e.height * 0.5 + FINISHER_HEIGHT_REACH:
			continue
		var ang := 0.0
		if flat.length() > e.radius:
			ang = fwd_flat.angle_to(flat.normalized())
		if ang > (FINISHER_KEEP_CONE if keep else FINISHER_CONE):
			continue
		var score := ang + maxf(d, 0.0) * FINISHER_DIST_WEIGHT
		if score >= best_score:
			continue
		# never lunge through a wall (aimed high, so low cover doesn't block)
		_sight_query.from = origin
		_sight_query.to = e.global_position + Vector3(0, e.height * FINISHER_SIGHT_HEIGHT, 0)
		if not get_world_3d().direct_space_state.intersect_ray(_sight_query).is_empty():
			continue
		best = e
		best_score = score
	return best


func _set_finisher_target(e: Enemy) -> void:
	if e == gk_ready:
		return
	if is_instance_valid(gk_ready):
		gk_ready.set_finisher_lit(false)
	gk_ready = e
	if e != null:
		e.set_finisher_lit(true)


## Picks a finisher from the situation and starts it.
func _start_glory(e: Enemy) -> void:
	_set_finisher_target(null)
	dash_t = 0.0 # a dash cut short by the finisher doesn't resume after it
	Game.executions += 1
	add_cells(3)
	heal(20.0 * float(Game.mut("exec_heal", 1.0)))
	var to_me := global_position - e.global_position
	to_me.y = 0.0
	if to_me.length() < 0.1:
		to_me = global_basis.z
	to_me = to_me.normalized()
	var facing := Vector3(sin(e.face_yaw), 0, cos(e.face_yaw))
	if e.is_boss:
		gk_kind = "boss"
	elif e.kind == "brute":
		gk_kind = "brute"
	elif not is_on_floor() and global_position.y > e.global_position.y + 0.9:
		gk_kind = "air"
	elif facing.dot(to_me) < -0.35:
		gk_kind = "back"
	else:
		gk_kind = "front_a" if randf() < 0.5 else "front_b"
	gk_target = e
	gk_t = 0.0
	gk_from = global_position
	var stand := e.radius + (1.25 if gk_kind in ["brute", "boss"] else 0.85)
	gk_to = e.global_position + to_me * stand
	gk_to.y = e.global_position.y
	# a Kurama Leap from further away takes a little longer to land
	gk_lunge = clampf(GLORY_LUNGE * gk_from.distance_to(gk_to) / FINISHER_REACH, GLORY_LUNGE, GLORY_LUNGE_MAX)
	_gk_yaw0 = yaw
	_gk_pitch0 = pitch
	_gk_dir = -to_me
	e.glory_hold(self)
	invuln = 99.0
	velocity = Vector3.ZERO
	# the world crawls while the finisher plays in real time
	Game.slowmo(0.25, 1.0)
	Game.hud.glory_start(gk_kind)
	if Game.debug_autoplay:
		print("[glory] %s %s frame=%d" % [gk_kind, e.kind, Engine.get_frames_drawn()])
	Sfx.play("dash", -2.0, 0.8)
	fov_kick = -10.0
	_build_glory_events()


## Each finisher is a list of [time, beat]. Beats: slash/thrust/blast/kill.
func _build_glory_events() -> void:
	match gk_kind:
		"front_a": # run it through, then the shotgun under the chin
			gk_len = 0.82
			gk_events = [[0.12, "thrust"], [0.36, "pose_chin"], [0.48, "blast_kill_headpop"]]
		"front_b": # take the head off, then blast the chest
			gk_len = 0.8
			gk_events = [[0.12, "slash_neck"], [0.38, "pose_point"], [0.46, "blast_kill_execution"]]
		"back": # through the back, then rip the blade up
			gk_len = 0.82
			gk_events = [[0.12, "thrust"], [0.38, "rip_up"], [0.5, "kill_split"]]
		"air": # falling overhead cut, split in two
			gk_len = 0.72
			gk_events = [[0.02, "pose_overhead"], [0.16, "chop"], [0.2, "kill_split"]]
		"brute": # climb up, chop the skull, blast down into the neck
			gk_len = 0.95
			gk_events = [[0.02, "pose_overhead"], [0.2, "chop"], [0.42, "pose_down"], [0.52, "blast_kill_headpop"]]
		"boss": # X-cut, then point-blank blast
			gk_len = 0.95
			gk_events = [[0.12, "slash_x1"], [0.26, "slash_x2"], [0.46, "pose_point"], [0.56, "blast_kill_execution"]]
	# a longer leap pushes every beat back so the first one lands on arrival
	var late := gk_lunge - GLORY_LUNGE
	if late > 0.0:
		gk_len += late
		for ev in gk_events:
			ev[0] += late
	vm.glory_begin()


func _update_glory(rd: float) -> void:
	var e := gk_target
	gk_t += rd
	var t := gk_t
	# lunge + camera lock
	var lunge := clampf(t / gk_lunge, 0.0, 1.0)
	lunge = 1.0 - pow(1.0 - lunge, 3.0)
	var pos := gk_from.lerp(gk_to, lunge)
	if gk_kind == "air":
		pos.y = lerpf(gk_from.y, gk_to.y, lunge * lunge)
	global_position = pos
	var look_h := 0.62
	if gk_kind == "brute":
		gk_cam_y = 0.9 * sin(clampf(t / 0.2, 0.0, 1.0) * PI * 0.5) * (1.0 - smoothstep(0.6, 0.9, t))
		look_h = 0.82
	elif gk_kind == "back":
		look_h = 0.55 + 0.35 * smoothstep(0.38, 0.55, t)
	elif gk_kind == "front_a":
		look_h = 0.62 + 0.25 * smoothstep(0.34, 0.46, t)
	if is_instance_valid(e):
		var aim := e.global_position + Vector3(0, e.height * look_h, 0) - (global_position + Vector3(0, head.position.y, 0))
		var want_yaw := atan2(-aim.x, -aim.z)
		var want_pitch := clampf(atan2(aim.y, Vector2(aim.x, aim.z).length()), -1.2, 1.2)
		var k := clampf(t / 0.1, 0.0, 1.0)
		yaw = lerp_angle(_gk_yaw0, want_yaw, k)
		pitch = lerpf(_gk_pitch0, want_pitch, k)
	# beats
	while not gk_events.is_empty() and t >= gk_events[0][0]:
		var beat: String = gk_events.pop_front()[1]
		_glory_beat(beat)
	if t >= gk_len:
		_end_glory()


func _glory_beat(beat: String) -> void:
	var e := gk_target
	var alive := is_instance_valid(e) and not e.dead
	var chest := (e.global_position + Vector3(0, e.height * 0.6, 0)) if is_instance_valid(e) else global_position
	var headp := (e.global_position + Vector3(0, e.head_y + 0.1, 0)) if is_instance_valid(e) else global_position
	match beat:
		"thrust":
			vm.glory_pose("thrust")
			Sfx.play("slice", 0.0, 0.8)
			Sfx.play("gore_big", -2.0)
			Game.gore.burst(chest, -_gk_dir + Vector3.UP * 0.3, 60, 7.0, 0.4, 2.0, 0.08)
			Game.hitstop(0.05)
			add_trauma(0.35)
			if alive:
				e.glory_hit(_gk_dir, 1.0)
			Game.hud.impact_frame(0.05)
		"slash_neck":
			vm.slash(0)
			Game.fx.slash_trail(cam, 0)
			Sfx.play("swing0", -2.0)
			Sfx.play("slice", 0.0)
			Game.gore.burst(headp, Vector3.UP, 70, 8.0, 0.4, 3.0, 0.08)
			add_trauma(0.3)
			Game.hitstop(0.05)
			if alive:
				e.glory_hit(_gk_dir, 0.7)
		"slash_x1", "slash_x2":
			var v := 0 if beat == "slash_x1" else 1
			vm.slash(v)
			Game.fx.slash_trail(cam, v)
			Sfx.play("swing%d" % v, -1.0)
			Sfx.play("slice", 0.0, 0.9)
			Game.gore.burst(chest, Vector3.UP - _gk_dir, 90, 9.0, 0.5, 3.0, 0.09)
			Game.hitstop(0.06)
			add_trauma(0.4)
			Game.hud.impact_frame(0.05)
			if alive:
				e.glory_hit(_gk_dir, 0.8)
		"rip_up":
			vm.glory_pose("rip_up")
			Sfx.play("swing2", 0.0, 0.8)
			Game.gore.burst(chest, Vector3.UP, 120, 11.0, 0.3, 4.0, 0.09)
			add_trauma(0.4)
		"pose_chin":
			vm.glory_pose("chin")
		"pose_point":
			vm.glory_pose("point")
		"pose_overhead":
			vm.glory_pose("overhead")
		"pose_down":
			vm.glory_pose("down")
		"chop":
			vm.glory_pose("chop")
			Game.fx.slash_trail(cam, 2)
			Sfx.play("swing2", 0.0)
			Sfx.play("slam", -2.0, 1.2)
			Game.gore.burst(headp, Vector3.UP, 80, 8.0, 0.4, 3.0, 0.08)
			add_trauma(0.5)
			land_dip = 0.18
			Game.hitstop(0.06)
			if alive:
				e.glory_hit(_gk_dir, 1.0)
		_:
			if beat.begins_with("blast"):
				vm.fire()
				Sfx.play("shotgun", 1.0)
				Sfx.play("zap", -2.0)
				muzzle_light.light_energy = 9.0
				var muzzle := vm.muzzle_position()
				var target := headp if beat.ends_with("headpop") else chest
				for i in 5:
					Game.fx.arc(muzzle, target + Vector3(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3), randf_range(-0.3, 0.3)), 0.14, 0.04, 1.0, 1)
			if beat.contains("kill_"):
				_glory_kill(beat.get_slice("kill_", 1))


## The killing beat.
func _glory_kill(gore_mode: String) -> void:
	var e := gk_target
	if not is_instance_valid(e) or e.dead:
		return
	var died := e.execute(_gk_dir, gore_mode)
	Sfx.play("execution", 2.0)
	Game.hitstop(0.09)
	exec_zoom = 16.0
	add_trauma(0.75)
	Game.hud.execution_flash()
	Game.hud.impact_frame(0.09)
	if not died:
		return
	if Game.rank("kamaitachi") > 0:
		# eight blood blades fan out flat from the kill
		var c := e.global_position + Vector3(0, 1.0, 0)
		for i in 8:
			var dir := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 8.0)
			var w := Bolt.new()
			w.setup(false, c + dir * 0.6, dir * 26.0, 60.0, "wave")
			Game.main.add_entity(w)
		Sfx.play("wave_blade", -1.0, 0.8)
	if Game.rank("chain") > 0:
		for o in Game.enemy_list:
			if is_instance_valid(o) and not o.dead and o.global_position.distance_to(e.global_position) < 9.0:
				o.stagger_now()
	if Game.rank("taiko") > 0:
		Game.combo += 5
		Game.best_combo = maxi(Game.best_combo, Game.combo)
		Game.combo_hold = 3.0
		Game.popup.emit("TAIKO +5 COMBO", Upgrades.TAG_COLORS.GLORY)


func _end_glory() -> void:
	if is_instance_valid(gk_target):
		gk_target.glory_release()
	gk_target = null
	gk_events = []
	gk_cam_y = 0.0
	invuln = 0.35
	vm.glory_end()
	# a little hop back out of the gore
	velocity = -_gk_dir * 3.0 + Vector3.UP * 2.0
	katana_cd = 0.12


# ---------------------------------------------------------------- shotgun
func _fire() -> void:
	if cells <= 0:
		shotgun_cd = 0.3
		Sfx.play("empty", -2.0)
		Game.hud.no_ammo()
		return
	cells -= 1
	# Inazuma Overload: the blast that spends the last cell is a big one
	var overload := cells == 0 and Game.rank("inazuma") > 0
	shotgun_cd = SHOTGUN_CD
	vm.fire()
	vm.set_cells(cells, max_cells)
	Sfx.play("shotgun", 0.0)
	muzzle_light.light_energy = 7.0
	add_trauma(0.32)
	recoil += 0.05
	fov_kick = maxf(fov_kick, 4.0)
	if overload:
		Sfx.play("zap", 0.0, 0.7)
		muzzle_light.light_energy = 12.0
		add_trauma(0.25)
		fov_kick = maxf(fov_kick, 9.0)
		Game.popup.emit("OVERLOAD!", Upgrades.TAG_COLORS.SHOTGUN)
	var space := get_world_3d().direct_space_state
	var origin := cam.global_position
	var basis := cam.global_basis
	var pellets := 10 * (2 if overload else 1)
	# Hachiman Focus: a tight choke that keeps full strength further out
	var focus := Game.rank("hachiman") > 0
	var spread := 0.04 if focus else 0.085
	var falloff_start := 18.0 if focus else 7.0
	var per := {}
	var muzzle := vm.muzzle_position()
	for i in pellets:
		var a := randf() * TAU
		var r := sqrt(randf()) * spread
		var dir := (basis * Vector3(cos(a) * r, sin(a) * r, -1.0)).normalized()
		var to := origin + dir * 48.0
		var q := PhysicsRayQueryParameters3D.create(origin, to, 1 | 4)
		var res := space.intersect_ray(q)
		var end := to
		if not res.is_empty():
			end = res.position
			var col = res.collider
			if col is Enemy and not col.dead:
				var dist := origin.distance_to(end)
				var falloff := clampf(1.0 - (dist - falloff_start) / 22.0, 0.3, 1.0)
				var dmg := 13.0 * falloff * float(Game.mut("dmg_out", 1.0))
				var headshot: bool = (end.y - col.global_position.y) > col.head_y
				if headshot:
					dmg *= 2.0
				if not per.has(col):
					per[col] = {"dmg": 0.0, "head": false, "n": 0}
				per[col].dmg += dmg
				per[col].head = per[col].head or headshot
				per[col].n += 1
			else:
				Game.fx.impact(end, res.normal, true)
		# every other "pellet" is drawn as a lightning arc
		if i % 2 == 0:
			Game.fx.arc(muzzle, end, 0.1, 0.035, 1.0, 1 if i % 4 == 0 else 0)
	# a few short arcs spray off the electrodes
	for k in 3:
		var sd := (basis * Vector3(randf_range(-0.5, 0.5), randf_range(-0.4, 0.4), -1.0)).normalized()
		Game.fx.arc(muzzle, muzzle + sd * randf_range(0.5, 1.3), 0.06, 0.02, 1.3, 0)
	var stagger_mult := 1.0 + 0.6 * Game.rank("ikazuchi")
	var kb := 6.0 + 8.0 * Game.rank("ikazuchi")
	# Raijin's Fork: pick the leap targets before anyone dies, so the arcs
	# start from where the blast landed
	var forks := _fork_targets(per) if Game.rank("fork") > 0 else []
	var any_head := false
	var head_blast := false
	var kills := 0
	var fwd := -basis.z
	for e in per:
		var d: Dictionary = per[e]
		if d.head:
			any_head = true
		var headshot: bool = d.head and d.n >= 3
		head_blast = head_blast or headshot
		var poise: float = d.dmg * stagger_mult
		if overload and e.is_boss:
			poise *= 3.0
		if Game.rank("dragon") > 0:
			e.ignite(Game.rank("dragon"))
		var at: Vector3 = e.global_position
		if e.take_hit(d.dmg, "shotgun", fwd, headshot, poise, kb):
			kills += 1
			if headshot and Game.rank("gasha") > 0:
				_skull_burst(at)
		elif overload and not e.is_boss:
			e.stagger_now()
	for f in forks:
		var t: Enemy = f.to
		if not is_instance_valid(t) or t.dead:
			continue
		Game.fx.arc(f.from, t.global_position + Vector3(0, t.height * 0.55, 0), 0.14, 0.04, 1.2, 1)
		if Game.rank("dragon") > 0:
			t.ignite(Game.rank("dragon"))
		if t.take_hit(f.dmg, "shotgun", (t.global_position - f.from).normalized(), false, f.dmg * stagger_mult, kb * 0.5):
			kills += 1
	if per.size() > 0:
		Game.hitstop(0.035)
	if per.size() > 0:
		var first: Enemy = per.keys()[0]
		Sfx.play_at("zap", first.global_position + Vector3(0, first.height * 0.6, 0), -2.0)
	if any_head:
		Sfx.play("headshot", -4.0)
	if head_blast and Game.rank("yoichi") > 0:
		add_cells(1)
	if kills > 0 and Game.rank("fujin") > 0:
		dash_charges = minf(float(max_dash), dash_charges + 1.0)


## Raijin's Fork: from each enemy the blast hit (the first four), an arc leaps
## to the two nearest enemies within 7 m that the blast missed. Each leap
## carries 40% of that enemy's blast damage (at least 15). Nearest first, so
## the same fight always forks the same way.
func _fork_targets(per: Dictionary) -> Array:
	var out := []
	var taken := {}
	var sources := 0
	for e in per:
		if sources >= 4:
			break
		sources += 1
		var from: Vector3 = e.global_position + Vector3(0, e.height * 0.55, 0)
		var near: Array = []
		for o in Game.enemy_list:
			if not is_instance_valid(o) or o.dead or per.has(o) or taken.has(o):
				continue
			var dd: float = o.global_position.distance_to(e.global_position)
			if dd < 7.0:
				near.append([dd, o])
		near.sort_custom(func(a, b): return a[0] < b[0])
		for k in mini(2, near.size()):
			var o: Enemy = near[k][1]
			taken[o] = true
			out.append({"from": from, "to": o, "dmg": maxf(15.0, per[e].dmg * 0.4)})
	return out


## Gashadokuro Burst: a headshot kill blows up, hurting and staggering the
## enemies around it (bosses take the damage but keep their footing).
func _skull_burst(at: Vector3) -> void:
	Game.fx.explosion(at, 0.0, false, 2.0)
	for o in Game.enemy_list.duplicate():
		if not is_instance_valid(o) or o.dead:
			continue
		var to: Vector3 = o.global_position - at
		if to.length() > 5.0:
			continue
		to.y = 0.0
		var dir := to.normalized() if to.length() > 0.01 else Vector3.ZERO
		if not o.take_hit(30.0, "explode", dir, false, 0.0, 6.0) and not o.is_boss:
			o.stagger_now()


func add_cells(n: int) -> void:
	cells = mini(max_cells, cells + n)
	vm.set_cells(cells, max_cells)


# ---------------------------------------------------------------- health
func heal(amount: float) -> void:
	if dead:
		return
	hp = minf(max_hp, hp + amount)


func take_damage(amount: float, from_pos: Vector3) -> void:
	if dead or invuln > 0.0 or Game.state != "playing":
		return
	amount *= float(Game.mut("dmg_in", 1.0))
	if Game.debug_god:
		amount = 0.0
	# Utsusemi Shell: a ready dash takes the hit instead
	if Game.rank("utsusemi") > 0 and utsusemi_cd <= 0.0 and dash_charges >= 1.0 and amount > 0.0:
		dash_charges -= 1.0
		utsusemi_cd = UTSUSEMI_CD
		invuln = 0.4
		Sfx.play("dash", -2.0, 1.4)
		Game.gore.sparks(global_position + Vector3(0, 1.0, 0), Vector3.UP, 14, Color(0.6, 2.0, 0.9))
		Game.popup.emit("UTSUSEMI", Upgrades.TAG_COLORS.DASH)
		return
	# Sanzu Reprieve: once per wave, a killing blow leaves you on 1 HP
	if hp - amount <= 0.0 and Game.rank("sanzu") > 0 and _sanzu_wave != Game.wave:
		_sanzu_wave = Game.wave
		amount = hp - 1.0
		hp = 1.0
		Game.wave_damage += amount
		invuln = 1.5
		add_trauma(0.6)
		Sfx.play("hurt", -2.0)
		Sfx.play("chime", -4.0, 0.8)
		Game.hud.damage_flash(amount, from_pos)
		Game.popup.emit("SANZU REPRIEVE", Upgrades.TAG_COLORS.BODY)
		return
	hp -= amount
	Game.wave_damage += amount
	invuln = 0.12
	add_trauma(0.45)
	Sfx.play("hurt", -2.0)
	Game.hud.damage_flash(amount, from_pos)
	if hp <= 0.0:
		_die()


func _die() -> void:
	hp = 0.0
	dead = true
	Sfx.play("player_death", 0.0)
	Game.main.on_player_died()


func on_upgrade(id: String) -> void:
	match id:
		"chrome":
			max_hp += 25.0
			hp = max_hp
		"inazuma":
			max_cells += 2
			add_cells(2)
		"idaten":
			max_dash += 1
			dash_charges = float(max_dash)
	vm.set_cells(cells, max_cells)


# ---------------------------------------------------------------- autoplay (testing)
var _auto_target: Enemy = null
var _auto_weapons := Vector2.ZERO


func _autoplay(delta: float) -> Vector2:
	_auto_t -= delta
	var best: Enemy = null
	var best_d := 1e9
	for e in Game.enemy_list:
		if is_instance_valid(e) and not e.dead:
			var d := global_position.distance_to(e.global_position)
			if e.is_staggered():
				d *= 0.3
			if d < best_d:
				best_d = d
				best = e
	_auto_target = best
	_auto_weapons = Vector2.ZERO
	if best == null:
		return Vector2(sin(Time.get_ticks_msec() * 0.001), -0.3)
	var aim := best.global_position + Vector3(0, best.height * 0.6, 0) - cam.global_position
	var want_yaw := atan2(-aim.x, -aim.z)
	yaw = lerp_angle(yaw, want_yaw, 1.0 - exp(-10.0 * delta))
	pitch = lerpf(pitch, atan2(aim.y, Vector2(aim.x, aim.z).length()), 1.0 - exp(-10.0 * delta))
	if _auto_t <= 0.0:
		_auto_t = randf_range(0.8, 2.0)
		_auto_strafe = -_auto_strafe
	var close := best_d < 3.0 + best.radius
	# a staggered enemy gets a glory kill (pressed for the bot above), not a slash
	_auto_weapons.x = 1.0 if (close and not best.is_staggered()) else 0.0
	_auto_weapons.y = 1.0 if (best_d < 10.0 and cells > 0 and not best.is_staggered()) else 0.0
	if best.is_staggered():
		return Vector2(0, -1)
	if best_d > 6.0:
		return Vector2(_auto_strafe * 0.4, -1)
	return Vector2(_auto_strafe, -0.2 if best_d > 2.5 else 0.3)


func _autoplay_weapons() -> Vector2:
	return _auto_weapons
