class_name Enemy
extends CharacterBody3D
## One script for all enemy types (grunt, gunner, brute, oni boss).
## Bodies are blocky humanoids built from boxes so they can be torn apart into
## gibs. Every attack is telegraphed (wind-up pose, glowing eyes, sound).
## Grunts, gunners and brutes are pooled by the WaveDirector (spec §14): a
## dead one is parked, hidden, and later reset with `reuse()` instead of
## being freed and rebuilt.

# stagger marker: red while staggered, gold on the one a glory kill would take
const MARKER_RED := Color(1.0, 0.05, 0.1)
const FINISHER_GOLD := Color(1.0, 0.8, 0.15)

enum S { SPAWN, CHASE, WINDUP, RECOVER, STAGGER, CHARGE_WINDUP, CHARGE, SLAM, VOLLEY_WINDUP, DASH_WINDUP, DASH, BLINK, GATLING, MISSILE_WINDUP, STOMP_WINDUP, SIDESTEP, RED_WINDUP, RED_ACT, AREA_WINDUP, LEAP_WINDUP, LEAP }

## A boss's armour drops for this long after its big moves (spec §5.6), and
## KAMAE fills this much faster meanwhile: the punish window.
const EXPOSED_KAMAE := 1.5
## A boss saves its leaps, dashes and charges for when it stands within this
## many metres of the player's height (the brute's charge rule too).
const SAME_LEVEL := 1.5
const SLAM_REACH := 14.0 # Shuten's leap slam carries this far (metres)

# Onryo's Grudge mutator: a dead enemy bursts this long after, this big
const GRUDGE_DELAY := 1.1
const GRUDGE_RADIUS := 2.2
const GRUDGE_DAMAGE := 14.0
# Hannya's Wrath mutator: below this share of HP an enemy enrages once
const WRATH_AT := 0.5
const WRATH_SPEED := 1.4
const WRATH_DAMAGE := 1.3

## Enemy attacks (spec §4): the weapon edge heats from its idle colour to
## WINDUP_HOT through the windup and is white-hot when the blow lands; the
## swing leaves a red arc where it cut.
const WINDUP_HOT := Color(1.0, 0.18, 0.08)
const SWING_COLOR := Color(1.0, 0.28, 0.12)
const WEAPON_NEONS: Array[Color] = [Color(0.2, 1.0, 1.0), Color(1.0, 0.25, 0.8), Color(0.6, 1.0, 0.25), Color(1.0, 0.55, 0.1)]
const STRIKE_HOLD := 0.22 # seconds the strike pose is held before the recovery
const GRUNT_REACH := 2.7 # a blow hits this far past the body's centre... (+ radius)
const BRUTE_REACH := 3.6
const GRUNT_STRIKE := [Vector3(0.3, 0, 0.1), Vector3(-0.45, 0, 0.3), 0.5] # see _strike_pose
const BRUTE_STRIKE := [Vector3(-0.35, 0, -0.25), Vector3(-0.35, 0, 0.1), 0.6]

var kind := "grunt"
var hp := 45.0
var max_hp := 45.0
var speed := 7.6
var radius := 0.45
var height := 1.8
var head_y := 1.52
var poise := 22.0
var max_poise := 22.0
var stagger_time := 1.6
var armor := 1.0
var mass := 1.0
var damage_mult := 1.0
var xp := 10.0
var points := 100
var is_boss := false
var display_name := ""
var subtitle := ""
var defeat_text := "TARGET TERMINATED" # the big card when a boss dies
var kamae_max := 0.0 # bosses: size of the KAMAE bar before cycle scaling
var kamae: BossKamae = null # bosses only: the posture bar that replaces poise
var exposed_t := 0.0 # bosses: armour down after a big move (the punish window)
var _signature_seq := 0 # bosses: signature volleys fired (spec §3.2 Perfect deflect)
var _signature_paid := 0 # the last signature volley that paid its KAMAE hit
var dice_seed := -1 # set before spawning to roll this enemy's dice from the run's seed

var state: S = S.SPAWN
var state_t := 0.0
var recover_time := 0.5
var attack_cd := 1.0
var special_cd := 4.0
var dead := false
var poise_t := 0.0
var flash_t := 0.0
var _flash_on := false
var walk_phase := 0.0
var knock := Vector3.ZERO
var strafe := 1.0
var strafe_t := 0.0
var burn_t := 0.0
var burn_dps := 0.0
var burn_tick := 0.0
var charge_dir := Vector3.ZERO
var charge_hit := false
var leap_vel := Vector3.ZERO
var combo_left := 0
var special_seq := 0
var enraged := false
var _wrath := false # Hannya's Wrath mutator: enraged once wounded
var face_yaw := 0.0
var landed := false
var frozen := false # no AI (debug showcase, or shorted out when the boss dies)
var shorted := false # frozen in place by the boss's death, keeps its facing
var glory_gore := "" # gore style picked by a glory kill finisher
var shock_t := 0.0 # electrified by the arc shotgun: blue flicker + crawling arcs
var _shock_arc_t := 0.0
var _stuck_t := 0.0
var _detour := Vector3.ZERO
var _detour_t := 0.0
var _to_player := Vector3.ZERO # flat direction straight at the player (chase moves may follow a path instead)
var _path := PackedVector3Array() # navmesh corners to the player (maps with use_navigation)
var _path_types := PackedInt32Array() # region or link, per corner
var _path_i := 0
var _query: NavigationPathQueryParameters3D
var _floor_q: PhysicsRayQueryParameters3D # _floor_below's ray, reused
var _query_result: NavigationPathQueryResult3D
var _repath_t := 0.0

var visual: Node3D
var hips: Node3D
var torso_pivot: Node3D
var leg_l: Node3D
var leg_r: Node3D
var arm_l: Node3D
var arm_r: Node3D
var head_mesh: MeshInstance3D
var muzzle: Node3D
var _leg_len := 0.82
var _parts: Array[Node3D] = []
var _mats: Array[ShaderMaterial] = []
var _eye_mat: ShaderMaterial
var _eye_color := Color(0.2, 1.0, 1.0)
var _glow_mat: ShaderMaterial
var marker: MeshInstance3D
var finisher_lit := false # the player's glory kill would take this one
var _exec_tag := "GLORY KILL" # the kill tag a finisher's kill shows
var _rng := RandomNumberGenerator.new()
var _jacket_mat: ShaderMaterial
var _mohawk: Node3D
## The weapon in the right hand (spec §4): the grunt's NATA blade, the
## brute's KANABO club, the gunner's arm cannon. Its glowing edge is the
## telegraph: it heats up through the windup and flares on the strike.
var _weapon: Node3D
var _weapon_glow: ShaderMaterial
var _weapon_tip: Node3D
var _weapon_color := Color(1.0, 0.35, 0.1) # its idle glow; every windup runs to WINDUP_HOT
var _flinch := 0.0 # a hit's recoil through the body: 1 just hit, eases back to 0
var _flinch_twist := 0.0 # which way the torso turns from the hit (-1..1)
## The pool that takes this enemy back when it dies (null: freed instead).
var pool: WaveDirector = null
## Built ahead of time for a pool: no spawn beam or sound, parked at once.
var prewarm := false

## Counts spawns, so a pooled enemy reads as a new one each time it is
## handed out (`spawn_id`). A deflected bolt checks it before homing.
static var _spawn_count := 0
var spawn_id := 0

## Set when an enemy joins or leaves the "enemies" group, so the
## WaveDirector rebuilds Game.enemy_list only when it changed.
static var list_dirty := true
## Every member's starting value, taken from the first plain Enemy, so
## `reuse()` resets all run state, including members added later.
static var _defaults := {}
## Members `reuse()` keeps: the body built once in `_ready`, its kind (pools
## are per kind) and the pool.
const _KEEP := [
	"kind", "visual", "hips", "torso_pivot", "leg_l", "leg_r", "arm_l", "arm_r", "head_mesh", "muzzle",
	"_leg_len", "_parts", "_mats", "_eye_mat", "_eye_color", "_glow_mat", "marker", "_rng",
	"_jacket_mat", "_mohawk", "_weapon", "_weapon_glow", "_weapon_tip", "_weapon_color", "pool", "prewarm", "_defaults",
]


func _init() -> void:
	if _defaults.is_empty() and get_script() == Enemy:
		for prop in get_property_list():
			if not (prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) or prop.name in _KEEP:
				continue
			var v: Variant = get(prop.name)
			if typeof(v) != TYPE_OBJECT:
				_defaults[prop.name] = v


func setup(k: String, scale_mult := 1.0) -> void:
	kind = k
	match k:
		"grunt":
			hp = 45.0; speed = 5.8; poise = 22.0; stagger_time = 1.8; xp = 10.0; points = 100
			hp *= float(Game.mut("grunt_hp", 1.0))
		"gunner":
			hp = 80.0; speed = 4.8; poise = 45.0; stagger_time = 2.2; xp = 18.0; points = 150; mass = 1.3
		"brute":
			hp = 520.0; speed = 3.8; radius = 0.75; height = 2.6; head_y = 2.12; poise = 160.0
			stagger_time = 2.8; armor = 0.35; xp = 60.0; points = 600; mass = 3.5
		"oni":
			hp = 5200.0; speed = 4.4; radius = 1.05; height = 3.4; head_y = 2.8
			stagger_time = 3.0; armor = 0.5; xp = 500.0; points = 8000; mass = 9.0; kamae_max = 1600.0
			is_boss = true; display_name = "SHUTEN"; subtitle = "THE OVERCLOCKED DAEMON"; defeat_text = "DAEMON PURGED"
	if not is_boss:
		hp *= float(Game.mut("enemy_hp", 1.0))
		speed *= float(Game.mut("enemy_speed", 1.0))
	if k in ["grunt", "gunner"]:
		armor = float(Game.mut("light_armor", armor)) # Kabuto Plate
	_finish_setup(scale_mult)


func _finish_setup(scale_mult: float) -> void:
	hp *= scale_mult
	max_hp = hp
	max_poise = poise
	damage_mult = 1.0 + (scale_mult - 1.0) * 0.5
	if is_boss:
		# later cycles take more pressure to break, at the same pace as damage
		kamae = BossKamae.new(kamae_max * damage_mult)


func _ready() -> void:
	if dice_seed >= 0:
		_rng.seed = dice_seed
	else:
		_rng.randomize()
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(50)
	max_slides = 3
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = radius
	cap.height = height
	cs.shape = cap
	cs.position.y = height * 0.5
	add_child(cs)
	_build_body()
	if prewarm:
		_park()
		return
	activate()


## Enters the fight: joins the enemy list, rolls its timers and drops in
## on a spawn beam. Runs on every spawn, pooled or new.
func activate() -> void:
	reset_physics_interpolation() # a pooled enemy jumps to its spawn point
	if dice_seed >= 0:
		# a fresh roll of this spawn's dice, pooled or new (spec §7.5)
		_rng.seed = dice_seed
	Enemy._spawn_count += 1
	spawn_id = Enemy._spawn_count
	add_to_group("enemies")
	Enemy.list_dirty = true
	attack_cd = _rng.randf_range(0.5, 1.4)
	special_cd = _rng.randf_range(3.0, 6.0)
	strafe = 1.0 if _rng.randf() < 0.5 else -1.0
	var fh := Game.arena.floor_height_at(global_position.x, global_position.z, global_position.y)
	Game.fx.spawn_beam(Vector3(global_position.x, fh, global_position.z), _eye_color.lerp(Color.RED, 0.5), height)
	Sfx.play_at("spawn", global_position, -6.0)
	if kind == "oni":
		Sfx.play("roar", 2.0, 0.7)


## Back to a fresh enemy of the same kind (call `setup` and `activate`
## after). Run state returns to its starting values; the body is kept.
func reuse() -> void:
	for k in _defaults:
		var v: Variant = _defaults[k]
		if v is Array or v is Dictionary:
			v = v.duplicate()
		set(k, v)
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	collision_layer = 4
	velocity = Vector3.ZERO
	visual.scale = Vector3.ONE
	visual.rotation = Vector3.ZERO
	hips.position.y = _leg_len
	torso_pivot.rotation = Vector3.ZERO
	for limb: Node3D in [leg_l, leg_r, arm_l, arm_r]:
		limb.rotation = Vector3.ZERO
	marker.visible = false
	marker.scale = Vector3.ONE
	for m in _mats:
		m.set_shader_parameter("flash", 0.0)
		m.set_shader_parameter("flash_color", Color(1, 1, 1))
	_eye_mat.set_shader_parameter("energy", 3.0)
	_eye_mat.set_shader_parameter("albedo_color", _eye_color)
	if _glow_mat:
		_glow_mat.set_shader_parameter("energy", 1.0)
	_roll_look()


## Hidden and still until the pool hands it out again.
func _park() -> void:
	visible = false
	marker.visible = false
	collision_layer = 0
	velocity = Vector3.ZERO
	knock = Vector3.ZERO
	process_mode = Node.PROCESS_MODE_DISABLED


## Grunts vary: jacket colour, mohawk, and a pipe in the hand.
func _roll_look() -> void:
	if kind != "grunt" or _jacket_mat == null:
		_set_weapon_heat(0.0)
		return
	var jackets := [Color(0.45, 0.08, 0.12), Color(0.3, 0.1, 0.4), Color(0.08, 0.3, 0.32), Color(0.4, 0.25, 0.08)]
	var r := Game.rng_fx # looks only: the gameplay dice stay untouched
	var jacket: Color = jackets[r.randi() % jackets.size()]
	_jacket_mat.set_shader_parameter("albedo_color", jacket)
	_jacket_mat.set_shader_parameter("emission_color", jacket)
	_mohawk.visible = r.randf() < 0.7
	# every grunt is armed; only the edge's neon varies
	_weapon_color = WEAPON_NEONS[r.randi() % WEAPON_NEONS.size()]
	_set_weapon_heat(0.0)


# ---------------------------------------------------------------- body
func _mat(c: Color, tex := "cloth") -> ShaderMaterial:
	var m := Psx.lit(c, TexGen.get_tex(tex), false, 1.0, {"uv_tiling": Vector2(2, 2), "emission_color": c, "emission_strength": 0.22})
	_mats.append(m)
	return m


func _part(parent: Node3D, part_name: String, size: Vector3, mat: Material, pos: Vector3, gib := true) -> MeshInstance3D:
	var mi := Psx.box(size, mat, pos)
	mi.name = part_name
	parent.add_child(mi)
	if gib:
		_parts.append(mi)
	return mi


func _build_body() -> void:
	visual = Node3D.new()
	add_child(visual)
	var s := height / 1.8
	var bw := 1.0
	var jacket := Color(0.45, 0.08, 0.12)
	var pants := Color(0.12, 0.11, 0.16)
	var skin := Color(0.78, 0.62, 0.55)
	match kind:
		"grunt":
			_eye_color = Color(0.2, 1.0, 1.0) # jacket colour: _roll_look()
		"gunner":
			jacket = Color(0.3, 0.34, 0.45)
			_eye_color = Color(1.0, 0.5, 0.1)
		"brute":
			jacket = Color(0.82, 0.62, 0.12)
			pants = Color(0.1, 0.1, 0.12)
			_eye_color = Color(1.0, 0.15, 0.1)
			bw = 1.35
		"oni":
			jacket = Color(0.12, 0.1, 0.12)
			pants = Color(0.08, 0.07, 0.09)
			skin = Color(0.72, 0.1, 0.08)
			_eye_color = Color(1.0, 0.85, 0.2)
			bw = 1.3
		"ninja":
			jacket = Color(0.16, 0.12, 0.26)
			pants = Color(0.1, 0.08, 0.16)
			skin = Color(0.2, 0.18, 0.26)
			_eye_color = Game.palette.get("neon_a", Color(1, 0.2, 0.5))
			bw = 0.95
	var m_jacket := _mat(jacket, "cloth" if kind != "brute" else "panel")
	_jacket_mat = m_jacket
	var m_pants := _mat(pants, "cloth")
	var m_skin := _mat(skin, "skin")
	var m_dark := _mat(Color(0.1, 0.1, 0.13), "noise")
	_eye_mat = Psx.unlit(_eye_color, 3.0, null, {"fog_amount": 0.3})
	_leg_len = 0.82 * s
	var torso_h := 0.62 * s

	hips = Node3D.new()
	hips.position.y = _leg_len
	visual.add_child(hips)
	_part(hips, "Pelvis", Vector3(0.38 * bw, 0.18, 0.24) * s, m_pants, Vector3.ZERO)
	torso_pivot = Node3D.new()
	torso_pivot.position.y = 0.06 * s
	hips.add_child(torso_pivot)
	var torso := _part(torso_pivot, "Torso", Vector3(0.48 * bw, torso_h / s, 0.3) * s, m_jacket if kind != "oni" else m_skin, Vector3(0, torso_h * 0.5, 0))
	# torso decorations ride along with the torso gib
	match kind:
		"grunt":
			torso.add_child(Psx.box(Vector3(0.06, 0.4, 0.02) * s, Psx.unlit(_eye_color, 2.0), Vector3(0.12 * s, 0.0, 0.155 * s)))
		"gunner":
			torso.add_child(Psx.box(Vector3(0.5, 0.34, 0.34) * s, _mat(Color(0.22, 0.24, 0.3), "panel"), Vector3(0, 0.1 * s, 0)))
			torso.add_child(Psx.box(Vector3(0.3, 0.04, 0.02) * s, Psx.unlit(_eye_color, 2.5), Vector3(0, 0.15 * s, 0.18 * s)))
		"brute":
			for sx in [-1.0, 1.0]:
				torso.add_child(Psx.box(Vector3(0.36, 0.2, 0.42) * s, _mat(Color(0.82, 0.62, 0.12), "hazard"), Vector3(sx * 0.42 * s, torso_h * 0.42, 0)))
			torso.add_child(Psx.box(Vector3(0.1, 0.1, 0.03) * s, Psx.unlit(Color(1, 0.2, 0.1), 3.0), Vector3(0, 0.1 * s, 0.165 * s)))
		"oni":
			torso.add_child(Psx.box(Vector3(0.5 * bw, 0.18, 0.32) * s, m_dark, Vector3(0, -torso_h * 0.38, 0)))
			for sx in [-1.0, 1.0]:
				torso.add_child(Psx.box(Vector3(0.3, 0.16, 0.36) * s, _mat(Color(0.25, 0.22, 0.2), "panel"), Vector3(sx * 0.4 * s, torso_h * 0.45, 0)))
	head_mesh = _part(torso_pivot, "Head", Vector3(0.26, 0.28, 0.27) * s, m_skin if kind != "gunner" else _mat(Color(0.25, 0.27, 0.33), "panel"), Vector3(0, torso_h + 0.17 * s, 0))
	head_mesh.add_child(Psx.box(Vector3(0.23, 0.06, 0.02) * s, _eye_mat, Vector3(0, 0.03 * s, 0.14 * s)))
	match kind:
		"grunt":
			_mohawk = Psx.box(Vector3(0.05, 0.14, 0.24) * s, Psx.unlit(Color(1.0, 0.2, 0.7), 1.8), Vector3(0, 0.2 * s, -0.01 * s))
			head_mesh.add_child(_mohawk)
		"brute":
			head_mesh.add_child(Psx.box(Vector3(0.3, 0.12, 0.3) * s, _mat(Color(0.82, 0.62, 0.12), "panel"), Vector3(0, 0.14 * s, 0)))
		"oni":
			var horn := _mat(Color(0.92, 0.86, 0.7), "noise")
			for sx in [-1.0, 1.0]:
				var h := MeshInstance3D.new()
				var pm := PrismMesh.new()
				pm.size = Vector3(0.08, 0.26, 0.08) * s
				h.mesh = pm
				h.material_override = horn
				h.position = Vector3(sx * 0.1 * s, 0.24 * s, 0)
				h.rotation.z = -sx * 0.35
				head_mesh.add_child(h)
			head_mesh.add_child(Psx.box(Vector3(0.18, 0.05, 0.02) * s, Psx.unlit(Color(1, 1, 1), 1.0), Vector3(0, -0.08 * s, 0.14 * s)))

	arm_l = Node3D.new()
	arm_l.position = Vector3(-0.3 * bw * s, torso_h - 0.06 * s, 0)
	torso_pivot.add_child(arm_l)
	arm_r = Node3D.new()
	arm_r.position = Vector3(0.3 * bw * s, torso_h - 0.06 * s, 0)
	torso_pivot.add_child(arm_r)
	var arm_size := Vector3(0.13 * bw, 0.62, 0.13) * s
	var arm_mat := m_jacket if kind != "oni" else m_skin
	_part(arm_l, "ArmL", arm_size, arm_mat, Vector3(0, -0.31 * s, 0))
	if kind == "gunner":
		var cannon := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.07 * s
		cm.bottom_radius = 0.09 * s
		cm.height = 0.7 * s
		cm.radial_segments = 6
		cannon.mesh = cm
		cannon.material_override = _mat(Color(0.2, 0.2, 0.24), "panel")
		cannon.name = "ArmR"
		cannon.position = Vector3(0, -0.33 * s, 0)
		arm_r.add_child(cannon)
		_parts.append(cannon)
		_glow_mat = Psx.unlit(_eye_color, 1.0)
		var tip := Psx.box(Vector3(0.12, 0.08, 0.12) * s, _glow_mat, Vector3(0, -0.36 * s, 0))
		cannon.add_child(tip)
		muzzle = Node3D.new()
		muzzle.position = Vector3(0, -0.72 * s, 0)
		arm_r.add_child(muzzle)
		_weapon = cannon
		_weapon_glow = _glow_mat
		_weapon_tip = muzzle
		_weapon_color = _eye_color
	else:
		var ar := _part(arm_r, "ArmR", arm_size, arm_mat, Vector3(0, -0.31 * s, 0))
		if kind == "grunt":
			_build_nata(ar, s)
		elif kind == "oni":
			var blade := Psx.box(Vector3(0.06, 0.5, 1.5) * s, _mat(Color(0.7, 0.7, 0.75), "panel"), Vector3(0, -0.33 * s, 0.75 * s))
			blade.add_child(Psx.box(Vector3(0.07, 0.04, 1.5) * s, Psx.unlit(Color(1.0, 0.15, 0.1), 3.0), Vector3(0, -0.24 * s, 0)))
			ar.add_child(blade)
		elif kind == "brute":
			ar.add_child(Psx.box(Vector3(0.26, 0.26, 0.26) * s, _mat(Color(0.2, 0.2, 0.22), "panel"), Vector3(0, -0.36 * s, 0)))
			_build_kanabo(ar, s)

	leg_l = Node3D.new()
	leg_l.position = Vector3(-0.11 * bw * s, _leg_len, 0)
	visual.add_child(leg_l)
	leg_r = Node3D.new()
	leg_r.position = Vector3(0.11 * bw * s, _leg_len, 0)
	visual.add_child(leg_r)
	var leg_size := Vector3(0.16 * bw, _leg_len / s, 0.18) * s
	_part(leg_l, "LegL", leg_size, m_pants, Vector3(0, -_leg_len * 0.5, 0))
	_part(leg_r, "LegR", leg_size, m_pants, Vector3(0, -_leg_len * 0.5, 0))

	# stagger marker over the head (gold when F would finish it)
	marker = Psx.quad(Vector2(0.5, 0.5), Psx.fx(MARKER_RED, TexGen.get_tex("star"), true, true, true, 2.5), Vector3(0, height + 0.55, 0))
	marker.visible = false
	add_child(marker)
	_roll_look()


## The grunt's NATA: a long cleaver held forward from the fist, its lower
## edge a neon strip (the telegraph). About 0.95 m from the hand.
func _build_nata(arm: Node3D, s: float) -> void:
	_weapon = Node3D.new()
	_weapon.name = "Nata"
	_weapon.position = Vector3(0, -0.29 * s, 0.03 * s)
	_weapon.rotation.x = 0.52 # forward and a little down while the arm hangs
	arm.add_child(_weapon)
	var steel := _mat(Color(0.62, 0.64, 0.7), "chrome")
	var grip := _mat(Color(0.08, 0.07, 0.09), "noise")
	_weapon_glow = Psx.unlit(_weapon_color, 1.4)
	_weapon.add_child(Psx.box(Vector3(0.05, 0.05, 0.24) * s, grip, Vector3(0, 0, 0.02 * s)))
	_weapon.add_child(Psx.box(Vector3(0.04, 0.13, 0.04) * s, steel, Vector3(0, -0.01 * s, 0.15 * s)))
	_weapon.add_child(Psx.box(Vector3(0.025, 0.12, 0.76) * s, steel, Vector3(0, 0.01 * s, 0.55 * s)))
	_weapon.add_child(Psx.box(Vector3(0.032, 0.03, 0.78) * s, _weapon_glow, Vector3(0, -0.055 * s, 0.56 * s)))
	_weapon_tip = Node3D.new()
	_weapon_tip.position = Vector3(0, 0, 0.95 * s)
	_weapon.add_child(_weapon_tip)


## The brute's KANABO: a long iron club, studded, with glowing hazard
## strips down its head. Held in the right fist, swung with both hands.
func _build_kanabo(arm: Node3D, s: float) -> void:
	_weapon = Node3D.new()
	_weapon.name = "Kanabo"
	_weapon.position = Vector3(0, -0.36 * s, 0.05 * s)
	_weapon.rotation.x = 0.52
	arm.add_child(_weapon)
	var iron := _mat(Color(0.2, 0.2, 0.23), "panel")
	var stud := _mat(Color(0.55, 0.56, 0.6), "chrome")
	_weapon_color = Color(1.0, 0.6, 0.1)
	_weapon_glow = Psx.unlit(_weapon_color, 1.4)
	_weapon.add_child(Psx.box(Vector3(0.07, 0.07, 0.42) * s, iron, Vector3(0, 0, 0.1 * s)))
	_weapon.add_child(Psx.box(Vector3(0.17, 0.17, 0.95) * s, iron, Vector3(0, 0, 0.78 * s)))
	for k in 4:
		var z := (0.42 + k * 0.24) * s
		for side in [-1.0, 1.0]:
			_weapon.add_child(Psx.box(Vector3(0.06, 0.06, 0.06) * s, stud, Vector3(side * 0.1 * s, 0, z)))
			_weapon.add_child(Psx.box(Vector3(0.06, 0.06, 0.06) * s, stud, Vector3(0, side * 0.1 * s, z + 0.12 * s)))
	for side in [-1.0, 1.0]:
		_weapon.add_child(Psx.box(Vector3(0.18, 0.03, 0.8) * s, _weapon_glow, Vector3(0, side * 0.075 * s, 0.8 * s)))
	_weapon_tip = Node3D.new()
	_weapon_tip.position = Vector3(0, 0, 1.25 * s)
	_weapon.add_child(_weapon_tip)


## How hot the weapon's edge glows: 0 idle, 1 white-hot (the blow lands).
func _set_weapon_heat(h: float) -> void:
	if _weapon_glow == null:
		return
	var c := _weapon_color.lerp(WINDUP_HOT, clampf(h * 1.6, 0.0, 1.0))
	if h > 0.75:
		c = c.lerp(Color(1.0, 0.9, 0.8), (h - 0.75) * 4.0)
	_weapon_glow.set_shader_parameter("albedo_color", c)
	_weapon_glow.set_shader_parameter("energy", 1.4 + h * 4.6)


## Where the weapon's point is now (the telegraph glint starts there).
func weapon_tip() -> Vector3:
	if _weapon_tip and _weapon_tip.is_inside_tree():
		return _weapon_tip.global_position
	return global_position + Vector3(0, height * 0.7, 0)


## The pose the blow lands in: [left arm, right arm, torso lean]. The arms
## snap to it on the strike (no easing), so the hit and the swing are one.
func _strike_pose() -> Array:
	return BRUTE_STRIKE if kind == "brute" else GRUNT_STRIKE


func get_gib_parts() -> Array[Node3D]:
	return _parts


func get_head() -> Node3D:
	return head_mesh


# ---------------------------------------------------------------- state
func _set_state(s: S) -> void:
	state = s
	state_t = 0.0
	if s != S.WINDUP and s != S.RECOVER:
		_set_weapon_heat(0.0) # a windup cut short (a stagger, a leap) must not stay red-hot


func is_staggered() -> bool:
	return state == S.STAGGER and not dead


func _windup_time() -> float:
	match kind:
		"grunt": return 0.5
		"gunner": return 0.72
		"brute": return 0.82
		"oni": return 0.45 if combo_left == 1 else 0.7
	return 0.5


func _physics_process(delta: float) -> void:
	if dead:
		return
	state_t += delta
	exposed_t -= delta
	attack_cd -= delta
	special_cd -= delta
	_update_flash(delta)
	_update_burn(delta)
	if dead:
		return # the burn killed it, and a pooled body has already left the physics world
	_update_poise(delta)
	var p := Game.player
	if p == null:
		return
	if frozen:
		if not is_on_floor():
			velocity.y -= 30.0 * delta
		velocity.x = knock.x
		velocity.z = knock.z
		knock = knock.move_toward(Vector3.ZERO, 26.0 * delta)
		move_and_slide()
		if not shorted:
			visual.rotation.y = 0.0
			face_yaw = 0.0
		if state == S.SPAWN and is_on_floor():
			state = S.RECOVER
			recover_time = 1e9
		_animate(delta, 0.0)
		return
	var ppos := p.global_position
	var to := ppos - global_position
	to.y = 0.0
	var dist := to.length()
	var dir := to / maxf(dist, 0.001)
	var move := Vector3.ZERO
	var face := dir
	if p.dead:
		# victory idle
		face = Vector3(sin(face_yaw), 0, cos(face_yaw))
		if state != S.STAGGER:
			state = S.RECOVER
			state_t = 0.0
	else:
		match state:
			S.SPAWN:
				if state_t > 4.0 and not is_on_floor():
					# wedged on the way down: put it on the nearest walkable floor
					global_position = Game.arena.safe_point(global_position)
					velocity = Vector3.ZERO
					state_t = 0.0
				if is_on_floor():
					if not landed:
						landed = true
						_land_fx()
					if state_t > 0.3:
						_set_state(S.CHASE)
			S.CHASE:
				_to_player = dir
				move = _chase(dist, _steer(ppos, dist, dir, delta), delta)
			S.LEAP_WINDUP:
				face = Vector3(leap_vel.x, 0, leap_vel.z).normalized()
				if state_t >= 0.35:
					velocity.y = leap_vel.y
					_set_state(S.LEAP)
			S.LEAP:
				face = Vector3(leap_vel.x, 0, leap_vel.z).normalized()
				move = Vector3(leap_vel.x, 0, leap_vel.z)
				if state_t > 0.25 and is_on_floor():
					_repath_t = 0.0
					_set_state(S.CHASE)
			S.WINDUP:
				if kind == "gunner" or is_boss:
					face = dir
				else:
					face = Vector3(sin(face_yaw), 0, cos(face_yaw)).lerp(dir, 0.5)
				if state_t >= _windup_time():
					_attack(dist, dir)
			S.RECOVER:
				face = Vector3(sin(face_yaw), 0, cos(face_yaw))
				if state_t >= recover_time:
					_set_state(S.CHASE)
			S.STAGGER:
				face = Vector3(sin(face_yaw), 0, cos(face_yaw))
				if state_t >= stagger_length():
					_end_stagger()
			S.CHARGE_WINDUP:
				if state_t > 0.8:
					charge_dir = dir
					charge_hit = false
					_set_state(S.CHARGE)
			S.CHARGE:
				face = charge_dir
				move = charge_dir * (13.5 if kind == "brute" else 15.5)
				if state_t < 1.15 and int(state_t * 20.0) % 2 == 0:
					Game.gore.sparks(global_position + Vector3(0, 0.1, 0), -charge_dir + Vector3.UP * 0.5, 2)
				if not charge_hit and global_position.distance_to(ppos) < radius + 1.3 and absf(ppos.y - global_position.y) < 2.0:
					charge_hit = true
					p.take_damage(30.0 * damage_mult, global_position)
					p.knockback(charge_dir * 16.0 + Vector3.UP * 7.0)
				if state_t > 1.15 or (state_t > 0.2 and is_on_wall()) or (is_boss and _ledge_ahead(charge_dir)):
					if is_on_wall():
						p.add_trauma(clampf(1.0 - dist / 25.0, 0.0, 0.5))
						Game.gore.sparks(global_position + charge_dir * radius + Vector3(0, 1, 0), -charge_dir, 16)
						Sfx.play_at("slam", global_position, -8.0, 1.3)
					recover_time = 1.4
					_set_state(S.RECOVER)
			S.SLAM:
				face = dir
				move = leap_vel
				if state_t > 0.25 and is_on_floor():
					_slam_land()
			S.VOLLEY_WINDUP:
				face = dir
				if state_t > 0.75:
					_volley(dir)
					recover_time = 0.6
					_set_state(S.RECOVER)
			_:
				var r: Array = _custom_state(dist, dir, delta)
				move = r[0]
				face = r[1]
	var want := move.length()
	if state == S.CHASE:
		if _detour_t > 0.0:
			_detour_t -= delta
			move = (_detour * 0.85 + move.normalized() * 0.15).normalized() * want
		move += _separation() * 4.0
	velocity.x = move.x + knock.x
	velocity.z = move.z + knock.z
	knock = knock.move_toward(Vector3.ZERO, 26.0 * delta)
	if not is_on_floor():
		velocity.y -= 30.0 * delta
	elif state != S.SLAM and state != S.SIDESTEP and state != S.LEAP:
		velocity.y = minf(velocity.y, 0.0)
	move_and_slide()
	# simple unstick: if we're pushing into a wall and not getting anywhere, slide along it for a bit
	if state == S.CHASE and want > 1.0:
		var rv := get_real_velocity()
		if Vector2(rv.x, rv.z).length() < want * 0.35:
			_stuck_t += delta
		else:
			_stuck_t = maxf(0.0, _stuck_t - delta)
		if _stuck_t > 0.3 and _detour_t <= 0.0:
			var n := get_wall_normal() if is_on_wall() else -dir
			var tangent := Vector3(-n.z, 0, n.x).normalized()
			if absf(tangent.dot(dir)) < 0.2:
				tangent *= 1.0 if _rng.randf() < 0.5 else -1.0
			elif tangent.dot(dir) < 0.0:
				tangent = -tangent
			_detour = tangent
			_detour_t = _rng.randf_range(0.6, 1.2)
			_stuck_t = 0.0
	if face.length() > 0.01:
		face_yaw = lerp_angle(face_yaw, atan2(face.x, face.z), 1.0 - exp(-12.0 * delta))
	visual.rotation.y = face_yaw
	_animate(delta, Vector2(velocity.x, velocity.z).length())
	if global_position.y < Game.arena.kill_y + 2.0:
		global_position = Game.arena.enemy_reset
		velocity = Vector3.ZERO
		reset_physics_interpolation()


## True when the floor ends just ahead along `d`: a boss's dash or charge
## stops at the edge rather than carrying it off a roof into the pit, out
## of the fight.
func _ledge_ahead(d: Vector3) -> bool:
	if not is_on_floor():
		return false
	return not _floor_below(global_position + d * (radius + 0.6))


## Floor within a step (1.2 m) below `p`, at about the body's own height.
## One query object, reused: dashes and charges ask every frame.
func _floor_below(p: Vector3) -> bool:
	if _floor_q == null:
		_floor_q = PhysicsRayQueryParameters3D.new()
		_floor_q.collision_mask = 1
	_floor_q.from = p + Vector3(0, 0.5, 0)
	_floor_q.to = p - Vector3(0, 1.2, 0)
	return not get_world_3d().direct_space_state.intersect_ray(_floor_q).is_empty()


## Touching down after the spawn drop.
func _land_fx() -> void:
	Game.gore.sparks(global_position + Vector3(0, 0.1, 0), Vector3.UP, 10, Color(1.5, 0.3, 0.4))
	Sfx.play_at("land", global_position, -6.0)


## Which way to walk toward the player. Straight at them on maps without a
## navmesh or when close on the same level; otherwise toward the next corner
## of a navmesh path, which uses ramps and leap links between levels. At a
## leap link going up, the enemy crouches (telegraph) and jumps.
func _steer(ppos: Vector3, dist: float, dir: Vector3, delta: float) -> Vector3:
	var a := Game.arena
	if a == null or a.nav_region == null:
		return dir
	if dist < 3.0 and absf(ppos.y - global_position.y) < 1.5:
		return dir
	_repath_t -= delta
	if _repath_t <= 0.0:
		# spread the queries over frames, by the spawn's own dice: the session-wide
		# spawn_id would make a seed path differently after an earlier run
		_repath_t = 0.3 + float(absi(dice_seed) % 5) * 0.04
		var map := get_world_3d().navigation_map
		if NavigationServer3D.map_get_iteration_id(map) == 0:
			return dir
		if _query == null:
			_query = NavigationPathQueryParameters3D.new()
			_query.metadata_flags = NavigationPathQueryParameters3D.PATH_METADATA_INCLUDE_TYPES
			_query.navigation_layers = Arena.NAV_WALK | Arena.NAV_LEAP
			_query_result = NavigationPathQueryResult3D.new()
		_query.map = map
		_query.start_position = global_position
		_query.target_position = ppos
		NavigationServer3D.query_path(_query, _query_result)
		_path = _query_result.path
		_path_types = _query_result.path_types
		_path_i = 1
	var pos := global_position
	while _path_i < _path.size():
		var c: Vector3 = _path[_path_i]
		# a drop link close by: head for its foot at once, so a wide body (a
		# boss) walks off the ledge instead of lining up on its top corner
		# and turning back to it on every repath
		var drop_top := _path_i + 1 < _path.size() and _path_types.size() > _path_i and _path_types[_path_i] == NavigationPathQueryResult3D.PATH_SEGMENT_TYPE_LINK and pos.y - _path[_path_i + 1].y > 0.9
		if drop_top and Vector2(c.x - pos.x, c.z - pos.z).length() < radius + 1.0:
			_path_i += 1
			continue
		if Vector2(c.x - pos.x, c.z - pos.z).length() > 0.6:
			break
		# right above or below a corner (on a bridge over it, say): skip it unless
		# it's the top of a leap still to make
		var leap_top := c.y - pos.y > 0.9 and _path_types.size() >= _path_i and _path_types[_path_i - 1] == NavigationPathQueryResult3D.PATH_SEGMENT_TYPE_LINK
		# ...or the bottom of a drop it still stands above (a wide body is
		# still on the ledge with its middle past the corner)
		var drop_foot := pos.y - c.y > 0.9 and is_on_floor()
		if leap_top or drop_foot:
			break
		_path_i += 1
	if _path_i >= _path.size():
		return dir
	var next: Vector3 = _path[_path_i]
	var flat := Vector3(next.x - pos.x, 0, next.z - pos.z)
	var rise := next.y - pos.y
	# a link's type sits on its start corner, the one just passed
	var on_link := _path_types.size() >= _path_i and _path_types[_path_i - 1] == NavigationPathQueryResult3D.PATH_SEGMENT_TYPE_LINK
	if on_link and rise > 0.9 and is_on_floor():
		_leap(next)
		return Vector3.ZERO
	if rise < -0.9 and is_on_floor() and flat.length() < 1.5:
		# stepping off a ledge: keep walking the way down until the floor
		# gives, instead of turning back to a corner it is already over
		var way := next - _path[_path_i - 1]
		way.y = 0.0
		if way.length() > 0.01:
			return way.normalized()
	if flat.length() < 0.01:
		return dir
	return flat.normalized()


## Crouch, then jump up to `to` (a leap link's top end): high enough to clear
## the lip, slow enough sideways to land just inside it.
func _leap(to: Vector3) -> void:
	var flat := Vector3(to.x - global_position.x, 0, to.z - global_position.z)
	var up := sqrt(2.0 * 30.0 * (to.y - global_position.y + 1.3))
	leap_vel = flat.normalized() * maxf(flat.length() * 1.6, 3.0) + Vector3(0, up, 0)
	_path_i += 1
	_set_state(S.LEAP_WINDUP)
	Game.gore.sparks(global_position + Vector3(0, 0.1, 0), Vector3.UP, 6)
	Sfx.play_at("windup", global_position, -8.0, 1.5)


## Boss subclasses handle their own states here. Returns [move, face].
func _custom_state(_dist: float, dir: Vector3, _delta: float) -> Array:
	return [Vector3.ZERO, dir]


func _chase(dist: float, dir: Vector3, delta: float) -> Vector3:
	var p := Game.player
	var dy := absf(p.global_position.y - global_position.y)
	match kind:
		"grunt":
			if dist < 2.0 + radius and attack_cd <= 0.0 and dy < 1.8:
				_set_state(S.WINDUP)
				_eye_mat.set_shader_parameter("energy", 6.0)
				Sfx.play_at("windup", global_position, -8.0, 1.2)
				Game.fx.glint(weapon_tip(), WINDUP_HOT, 0.7)
				return Vector3.ZERO
			return dir * speed
		"gunner":
			strafe_t -= delta
			if strafe_t <= 0.0:
				strafe = -strafe
				strafe_t = _rng.randf_range(1.0, 2.4)
			var side := Vector3(-dir.z, 0, dir.x) * strafe
			var m := side * speed * 0.7
			if dist > 17.0:
				m += dir * speed
			elif dist < 8.0:
				m -= dir * speed * 0.9
			if attack_cd <= 0.0 and dist < 34.0 and _has_los():
				_set_state(S.WINDUP)
				Sfx.play_at("windup", global_position, -4.0, 1.6)
				Game.fx.glint(weapon_tip(), _eye_color, 0.8)
				return Vector3.ZERO
			return m
		"brute":
			if special_cd <= 0.0 and dist > 6.5 and dist < 24.0 and dy < 1.5 and _has_los():
				special_cd = _rng.randf_range(6.0, 8.5)
				_set_state(S.CHARGE_WINDUP)
				Sfx.play_at("roar", global_position, 0.0)
				Game.show_hint_once("brute", "KANABO BRUTES ARE ARMORED: SHOTGUN THEM TO STAGGER, THEN GLORY KILL")
				return Vector3.ZERO
			if dist < 2.8 + radius and attack_cd <= 0.0:
				_set_state(S.WINDUP)
				Sfx.play_at("windup", global_position, -2.0, 0.7)
				Game.fx.glint(weapon_tip(), WINDUP_HOT, 1.1)
				return Vector3.ZERO
			return dir * speed
		"oni":
			if not enraged and hp < max_hp * 0.5:
				enraged = true
				speed = 5.6
				Sfx.play("roar", 3.0, 0.6)
				Game.hud_message.emit("%s IS ENRAGED" % display_name, Color(1, 0.2, 0.1), false)
				_eye_mat.set_shader_parameter("albedo_color", Color(1, 0.2, 0.1))
			# his leap, charge and volley wait until he is on your level, within
			# a leap and with a clear line, as the brute's charge does: never
			# across the pit
			if special_cd <= 0.0 and dist > 5.0 and dist < SLAM_REACH and dy < SAME_LEVEL and _has_los():
				special_cd = _rng.randf_range(3.5, 5.0) if enraged else _rng.randf_range(5.0, 7.0)
				special_seq += 1
				var pick := special_seq % 3
				if pick == 0 and enraged:
					_set_state(S.VOLLEY_WINDUP)
					Sfx.play_at("windup", global_position, 2.0, 0.6)
				elif pick == 1 or (pick == 0 and not enraged):
					_set_state(S.SLAM)
					velocity.y = 14.0
					leap_vel = _to_player * minf(dist, SLAM_REACH) / 1.0 # aimed at the player, not the path
					Sfx.play("roar", 0.0, 0.8)
				else:
					_set_state(S.CHARGE_WINDUP)
					Sfx.play("roar", 0.0, 0.75)
				return Vector3.ZERO
			if dist < 3.4 + radius and attack_cd <= 0.0:
				combo_left = 2
				_set_state(S.WINDUP)
				Sfx.play_at("windup", global_position, 0.0, 0.6)
				return Vector3.ZERO
			return dir * speed
	return dir * speed


func _attack(dist: float, dir: Vector3) -> void:
	var p := Game.player
	var dy := absf(p.global_position.y - global_position.y)
	var fwd := Vector3(sin(face_yaw), 0, cos(face_yaw))
	_eye_mat.set_shader_parameter("energy", 3.0)
	match kind:
		"grunt":
			knock += fwd * 6.0
			_strike(strike_reach(), -1.0)
			Sfx.play_at("swing1", global_position, -4.0, 0.8)
			if dist < strike_reach() and dy < 1.8 and fwd.dot(dir) > 0.3:
				p.take_damage(11.0 * damage_mult, global_position)
			recover_time = 0.55
			attack_cd = _rng.randf_range(0.9, 1.5)
		"gunner":
			var shots := 1 if Game.wave < 6 else 3
			for i in shots:
				var target := p.global_position + Vector3(0, 1.1, 0)
				var origin := muzzle.global_position if muzzle else global_position + Vector3(0, 1.4, 0)
				var aim := (target - origin).normalized()
				if shots > 1:
					aim = aim.rotated(Vector3.UP, (i - 1) * 0.12)
				Game.main.director.fire_bolt(true, origin, aim * 11.0, 12.0 * damage_mult, "bolt", self)
			Game.fx.glint(weapon_tip(), Color(1.0, 0.85, 0.5), 1.0, 0.08)
			Sfx.play_at("enemy_shot", global_position, 0.0)
			Game.show_hint_once("bolt", "SLASH INCOMING BOLTS TO DEFLECT THEM")
			recover_time = 0.35
			attack_cd = _rng.randf_range(2.2, 3.2)
		"brute", "oni":
			var reach := strike_reach() if kind == "brute" else 4.6 + radius
			knock += fwd * (5.0 if kind == "brute" else 8.0)
			if kind == "brute":
				_strike(reach, -0.55)
				Game.fx.glint(global_position + fwd * reach * 0.8 + Vector3(0, 0.3, 0), Color(1.0, 0.6, 0.2), 1.8, 0.12)
			Sfx.play_at("swing0", global_position, 0.0, 0.55)
			Game.gore.sparks(global_position + fwd * reach * 0.8 + Vector3(0, 0.2, 0), Vector3.UP, 12)
			if dist < reach and dy < 2.5 and fwd.dot(dir) > 0.2:
				p.take_damage((26.0 if kind == "brute" else 32.0) * damage_mult, global_position)
				p.knockback(dir * 11.0 + Vector3.UP * 4.0)
			if kind == "oni" and combo_left > 1:
				combo_left -= 1
				_set_state(S.WINDUP)
				return
			recover_time = 0.85 if kind == "brute" else 0.7
			attack_cd = _rng.randf_range(1.3, 2.0)
	_set_state(S.RECOVER)


## How far (flat, centre to centre) a grunt's or brute's blow reaches.
func strike_reach() -> float:
	return (BRUTE_REACH if kind == "brute" else GRUNT_REACH) + radius


## The blow lands: the arms snap to the strike pose, the edge burns
## white-hot and a red arc shows where the weapon cut (spec §4). `reach` is
## how far past the body's centre the blow hits; the arc ends exactly there,
## so standing outside it means you were missed. `tilt` leans it across the
## body (negative: high on the weapon side), so it reads from the front too
## instead of edge-on.
func _strike(reach: float, tilt: float) -> void:
	var sp := _strike_pose()
	arm_l.rotation = sp[0]
	arm_r.rotation = sp[1]
	torso_pivot.rotation.x = sp[2]
	_set_weapon_heat(1.0)
	var fwd := Vector3(sin(face_yaw), 0, cos(face_yaw))
	var side := Vector3(cos(face_yaw), 0, -sin(face_yaw)) # toward the weapon arm
	var shoulder := global_position + Vector3(0, height * 0.74, 0) + fwd * radius * 0.4
	if kind == "grunt":
		shoulder += side * 0.3 * height / 1.8
	Game.fx.enemy_swing(shoulder, fwd, swing_radius(reach), tilt, SWING_COLOR)


## The swing arc's radius from the shoulder (which sits radius × 0.4 ahead
## of the centre) that makes its far edge land at `reach`.
func swing_radius(reach: float) -> float:
	return reach - radius * 0.4


func _slam_land() -> void:
	Sfx.play_at("slam", global_position, 4.0)
	Game.fx.shockwave(global_position, 24.0, 15.0, 26.0 * damage_mult)
	Game.gore.sparks(global_position + Vector3(0, 0.2, 0), Vector3.UP, 30, Color(1.8, 0.6, 0.2))
	Game.player.add_trauma(0.7)
	Game.show_hint_once("slam", "JUMP OVER THE SHOCKWAVE", true)
	recover_time = 1.0
	leap_vel = Vector3.ZERO
	_set_state(S.RECOVER)


func _volley(dir: Vector3) -> void:
	var origin := global_position + Vector3(0, height * 0.6, 0)
	var target := Game.player.global_position + Vector3(0, 1.0, 0)
	var aim := (target - origin).normalized()
	# Shuten's signature volley (spec §3.2 Perfect deflect): white-hot bolts
	var sig := next_signature() if is_boss else 0
	for i in 9:
		var b: Bolt = Game.main.director.fire_bolt(true, origin + dir * radius, aim.rotated(Vector3.UP, (i - 4) * 0.13) * 11.0, 14.0 * damage_mult, "bolt", self)
		if sig != 0:
			b.mark_signature(sig)
	Sfx.play_at("enemy_shot", global_position, 4.0, 0.7)


func _has_los() -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, head_y, 0), Game.player.global_position + Vector3(0, 1.4, 0), 1)
	return space.intersect_ray(q).is_empty()


func _separation() -> Vector3:
	var push := Vector3.ZERO
	for o in Game.enemy_list:
		if o == self or not is_instance_valid(o):
			continue
		var d: Vector3 = global_position - o.global_position
		d.y = 0.0
		var min_d: float = radius + o.radius + 0.25
		var l2 := d.length_squared()
		if l2 < min_d * min_d and l2 > 0.0001:
			var l := sqrt(l2)
			push += d / l * (min_d - l)
	return push


# ---------------------------------------------------------------- damage
func take_hit(dmg: float, source: String, dir: Vector3, headshot := false, poise_dmg := -1.0, knockback := 0.0) -> bool:
	if dead:
		return false
	var mult := 1.0
	var armored := false
	if source in ["katana", "wave", "dashcut"] and armor < 1.0 and state != S.STAGGER and exposed_t <= 0.0:
		mult = armor
		armored = true
	var final := dmg * mult
	hp -= final
	flash_t = 0.09
	visual.scale = Vector3(1.14, 0.88, 1.14)
	if source == "shotgun":
		shock(0.45)
	var flat := Vector3(dir.x, 0, dir.z)
	flat = flat.normalized() if flat.length() > 0.01 else Vector3.ZERO
	knock += flat * knockback / mass
	if source != "burn":
		# the body recoils from the blow (looks only); heavy bodies rock less
		_flinch = maxf(_flinch, clampf(final / 40.0, 0.35, 1.0) / sqrt(mass))
		_flinch_twist = clampf(flat.dot(Vector3(cos(face_yaw), 0, -sin(face_yaw))), -1.0, 1.0)
	var hit_pos := global_position + Vector3(0, head_y + 0.05 if headshot else height * 0.6, 0)
	Game.fx.damage_number(global_position + Vector3(0, height + 0.25, 0), final, headshot, armored)
	if armored:
		Game.gore.sparks(hit_pos, -flat + Vector3.UP * 0.3, 12)
		Sfx.play_at("deflect", hit_pos, -10.0, 0.6)
	elif source != "burn":
		Game.gore.burst(hit_pos, flat + Vector3(0, 0.4, 0), int(clampf(final * 0.45, 6.0, 40.0)), 6.0, 0.5, 2.0)
		if final > 30.0:
			Game.gore.mist(hit_pos, 0.9, 1)
	if hp <= 0.0:
		die(source, dir, headshot)
		return true
	if not _wrath and not is_boss and hp < max_hp * WRATH_AT and Game.mut("enrage", false):
		_enrage()
	if poise_dmg < 0.0:
		poise_dmg = final
	if is_boss:
		press_kamae(BossKamae.gain_for(source, poise_dmg, dmg))
	else:
		_apply_poise(poise_dmg)
	return false


## Called by the player's katana on a staggered enemy. Returns true if it died.
## Glory kill hold: the enemy is pinned in place facing the player while the
## finisher plays out.
func glory_hold(by: Node3D) -> void:
	set_finisher_lit(false)
	frozen = true
	shorted = true
	marker.visible = false
	var to := by.global_position - global_position
	face_yaw = atan2(to.x, to.z)
	visual.rotation.y = face_yaw


func glory_release() -> void:
	if dead:
		return
	frozen = false
	shorted = false


## A beat of the finisher landing: squash, flash, a lurch.
func glory_hit(dir: Vector3, amount := 1.0) -> void:
	flash_t = 0.08
	visual.scale = Vector3(1.0 + 0.2 * amount, 1.0 - 0.2 * amount, 1.0 + 0.2 * amount)
	visual.rotation.x = clampf(-0.35 * amount, -0.5, 0.0)
	knock += Vector3(dir.x, 0, dir.z).normalized() * 0.6 * amount


func execute(dir: Vector3, gore_mode := "execution", tag := "GLORY KILL") -> bool:
	visual.rotation.x = 0.0
	if is_boss and hp > max_hp * BossKamae.BLOW_SHARE + 1.0:
		# the ONIKIRI blow on a broken boss; its name was the cut-in
		var dmg := max_hp * BossKamae.BLOW_SHARE
		hp -= dmg
		Game.fx.damage_number(global_position + Vector3(0, height + 0.5, 0), dmg, true, false)
		var chest := global_position + Vector3(0, height * 0.7, 0)
		Game.gore.burst(chest, Vector3.UP + dir, 160, 10.0, 0.6, 4.0, 0.1)
		Game.gore.mist(chest, 3.0, 4)
		Game.gore.chunks(chest, 8, 7.0)
		Game.gore.emitter(self, Vector3(0, height * 0.75, 0), Vector3.UP, 90.0, 1.4, 8.0, 0.3)
		Game.gore.pool(global_position, 4.5)
		knock += Vector3(dir.x, 0, dir.z).normalized() * 6.0
		_end_stagger()
		return false
	glory_gore = gore_mode
	_exec_tag = tag
	die("execution", dir, false)
	return true


func ignite(rank: int) -> void:
	if burn_t <= 0.0:
		Sfx.play_at("ignite", global_position, -6.0)
	# a weaker flame refreshes the burn but never cools a stronger one
	burn_dps = maxf(burn_dps, 10.0 * rank) if burn_t > 0.0 else 10.0 * rank
	burn_t = 3.0


## Staggers on the spot (Hyakunin-giri). Bosses only reel when their KAMAE
## breaks, never from this.
func stagger_now() -> void:
	if dead or is_boss or state == S.STAGGER or state == S.SPAWN:
		return
	_stagger()


## How long a stagger lasts; a boss's KAMAE break runs a little longer so
## the ONIKIRI is never a race.
func stagger_length() -> float:
	return stagger_time + (BossKamae.BREAK_EXTRA if is_boss else 0.0)


## Bosses: the number of a new signature volley, the white bolts meant to be
## PERFECT deflected (spec §3.2). Its bolts carry it.
func next_signature() -> int:
	_signature_seq += 1
	if Game.hints_shown.has("bolt"):
		Game.show_hint_once("perfect", "WHITE BOLTS: DEFLECT AT THE LAST MOMENT FOR A PERFECT")
	return _signature_seq


## A PERFECT deflect on signature volley `id`: true for the first one only,
## so each volley pays its big KAMAE hit once.
func claim_signature(id: int) -> bool:
	if not is_boss or id == _signature_paid:
		return false
	_signature_paid = id
	return true


## Bosses: adds pressure to the KAMAE bar and breaks the stance when it fills.
func press_kamae(amount: float) -> void:
	if kamae == null or dead or state == S.STAGGER or state == S.SPAWN:
		return
	if exposed_t > 0.0:
		amount *= EXPOSED_KAMAE
	if kamae.add(amount):
		_break_kamae()


## The stance shatters: a heavy clang, a held frame, KAMAE BROKEN, and the
## boss reels for the ONIKIRI.
func _break_kamae() -> void:
	_stagger()
	knock = Vector3.ZERO
	# a break can land mid-blink: always reel where the player can see it
	visual.visible = true
	collision_layer = 4
	Game.hitstop(0.12)
	Sfx.play("deflect", 4.0, 0.55, 0.0)
	Sfx.play_at("slam", global_position, 0.0, 1.3)
	Game.gore.sparks(global_position + Vector3(0, height * 0.7, 0), Vector3.UP, 40, Color(2.0, 1.5, 0.4))
	if Game.player:
		Game.player.add_trauma(0.5)
	Game.hud.kamae_broken()
	if Game.debug_autoplay:
		print("[kamae] %s broken hp=%.0f/%.0f frame=%d" % [kind, hp, max_hp, Engine.get_frames_drawn()])
	Game.show_hint_once("kamae_break", "KAMAE BROKEN!  PRESS %s FOR ONIKIRI" % Ui.key_name("finisher"))


func _apply_poise(amount: float) -> void:
	if state == S.STAGGER or state == S.SPAWN:
		return
	poise -= amount
	poise_t = 2.0
	if poise <= 0.0:
		_stagger()


func _stagger() -> void:
	_set_state(S.STAGGER)
	poise = 0.0
	marker.visible = true
	_eye_mat.set_shader_parameter("energy", 0.8)
	Sfx.play_at("windup", global_position, -2.0, 0.45)
	if not is_boss:
		Game.show_hint_once("stagger", "STAGGERED!  PRESS %s FOR A GLORY KILL" % Ui.key_name("finisher"))


func _end_stagger() -> void:
	set_finisher_lit(false)
	marker.visible = false
	poise = max_poise
	if kamae:
		kamae.recover()
	_eye_mat.set_shader_parameter("energy", 3.0)
	_set_state(S.CHASE)


func _update_poise(delta: float) -> void:
	poise_t -= delta
	if kamae:
		kamae.update(delta, hp / max_hp if max_hp > 0.0 else 1.0)
	elif poise_t <= 0.0 and state != S.STAGGER:
		poise = minf(max_poise, poise + max_poise * 0.35 * delta)
	if marker.visible:
		var k := 1.0 + sin(Time.get_ticks_msec() * 0.02) * 0.25
		if finisher_lit:
			k += 0.4
		marker.scale = Vector3.ONE * k * (height / 1.8)


## The stagger marker turns gold and grows on the enemy F would finish, so
## the player can see which one the glory kill will take. A plunge can take
## an enemy that isn't staggered, so the gold marker shows on it too.
func set_finisher_lit(on: bool) -> void:
	if finisher_lit == on:
		return
	finisher_lit = on
	marker.visible = on or is_staggered()
	var m := marker.material_override as ShaderMaterial
	m.set_shader_parameter("color", FINISHER_GOLD if on else MARKER_RED)


func _update_burn(delta: float) -> void:
	if burn_t <= 0.0:
		return
	burn_t -= delta
	burn_tick -= delta
	Game.gore.embers(global_position, 1)
	if burn_tick <= 0.0:
		burn_tick = 0.5
		take_hit(burn_dps * 0.5, "burn", Vector3.ZERO, false, 0.0)


## Electrified: the arc shotgun leaves its target flickering blue with small
## arcs crawling over the body. Purely visual.
func shock(duration: float) -> void:
	if shock_t <= 0.0:
		for m in _mats:
			m.set_shader_parameter("flash_color", Color(0.45, 0.8, 1.0))
	shock_t = maxf(shock_t, duration)
	if duration > 1.0:
		shorted = true


func _update_shock(delta: float) -> void:
	shock_t -= delta
	_shock_arc_t -= delta
	if _shock_arc_t <= 0.0:
		var r := Game.rng_fx
		_shock_arc_t = r.randf_range(0.04, 0.11)
		var a := global_position + Vector3(r.randf_range(-radius, radius) * 0.8, r.randf_range(0.2, height), r.randf_range(-radius, radius) * 0.8)
		var b := a + Vector3(r.randf_range(-0.7, 0.7), r.randf_range(-0.7, 0.5), r.randf_range(-0.7, 0.7)) * (height / 1.8)
		Game.fx.arc(a, b, 0.07, 0.018, 0.8, 0)
	var on := fmod(shock_t, 0.07) < 0.035
	for m in _mats:
		m.set_shader_parameter("flash", 0.7 if on else 0.2)
	if shock_t <= 0.0:
		for m in _mats:
			m.set_shader_parameter("flash_color", Color(1, 1, 1))
			m.set_shader_parameter("flash", 0.0)
		_flash_on = false


func _update_flash(delta: float) -> void:
	visual.scale = visual.scale.lerp(Vector3.ONE, 1.0 - exp(-18.0 * delta))
	visual.rotation.x = lerpf(visual.rotation.x, 0.0, 1.0 - exp(-7.0 * delta))
	if shock_t > 0.0:
		_update_shock(delta)
		# a hit under the shock still runs out its flash, unseen, so it
		# doesn't fire late once the shock ends
		flash_t = maxf(flash_t - delta, 0.0)
		return
	if flash_t > 0.0:
		flash_t -= delta
		if not _flash_on:
			_flash_on = true
			for m in _mats:
				m.set_shader_parameter("flash", 0.85)
	elif _flash_on:
		_flash_on = false
		for m in _mats:
			m.set_shader_parameter("flash", 0.0)


func die(source: String, dir: Vector3, headshot := false) -> void:
	if dead:
		return
	dead = true
	remove_from_group("enemies")
	Enemy.list_dirty = true
	collision_layer = 0
	var tag := ""
	var col := Color.WHITE
	var pts := points
	match source:
		"execution":
			tag = "ONIKIRI" if is_boss else _exec_tag
			col = Color(1.0, 0.15, 0.2)
			pts *= 2
			if not is_boss:
				_feed_boss_kamae()
		"deflect":
			tag = "RETURN TO SENDER"
			col = Color(0.3, 0.95, 1.0)
			pts = int(pts * 1.5)
		"burn":
			tag = "CREMATED"
			col = Color(1.0, 0.55, 0.15)
		"dashcut":
			tag = "KAGE STEP"
			col = Color(0.6, 1.0, 0.5)
		"wave":
			tag = "SUSANOO'S WAVE"
			col = Color(1.0, 0.3, 0.4)
	if headshot:
		tag = "HEADSHOT"
		col = Color(1.0, 0.9, 0.3)
		pts = int(pts * 1.5)
		Game.headshots += 1
	if Game.mut("bounty", false):
		# Senryo Bounty: the skilful kills pay double, the rest half
		pts = pts * 2 if (headshot or source == "execution") else int(pts * 0.5)
	if tag == "" and kind == "brute":
		tag = "KANABO DOWN"
		col = Color(1.0, 0.7, 0.2)
	Game.register_kill(pts, xp, tag, col)
	var mode := source
	if source in ["wave", "dashcut", "heavy"]:
		mode = "katana"
	elif source == "burn":
		mode = "explode"
	if glory_gore != "":
		mode = glory_gore
	if dir.length() < 0.01:
		dir = (global_position - Game.player.global_position)
	for m in _mats:
		m.set_shader_parameter("flash", 0.0)
	Game.gore.dismember(self, mode, dir, headshot)
	Game.hud.kill_burst(global_position + Vector3(0, height * 0.6, 0), source == "execution" or kind != "grunt")
	if source == "shotgun":
		# fried: blue sparks, smoke and a last arc off the body
		var cp := global_position + Vector3(0, height * 0.55, 0)
		Game.gore.sparks(cp, Vector3.UP, 16, Color(0.6, 1.6, 2.2))
		Game.fx.smoke(cp, 1.1)
		var r := Game.rng_fx
		Game.fx.arc(cp, cp + Vector3(r.randf_range(-1, 1), r.randf_range(-0.6, 0.2), r.randf_range(-1, 1)) * 1.4, 0.12, 0.025, 1.0, 1)
	var pos := global_position + Vector3(0, height * 0.5, 0)
	if mode == "shotgun" or mode == "explode" or kind != "grunt":
		Sfx.play_at("gore_big", pos, 0.0)
	else:
		Sfx.play_at("gore%d" % (Game.rng_fx.randi() % 3), pos, 0.0)
	var pd := global_position.distance_to(Game.player.global_position)
	if pd < 3.6 or source == "execution":
		Game.hud.screen_blood(3 if source == "execution" else 1)
	var orbs := 0
	match kind:
		"grunt": orbs = 1 if _rng.randf() < 0.3 else 0
		"gunner": orbs = 1 if _rng.randf() < 0.5 else 0
		"brute": orbs = 4
		"oni": orbs = 12
	if source == "execution":
		orbs += 4
	if orbs > 0:
		Game.fx.health_orbs(pos, orbs)
	if Game.mut("grudge", false) and not is_boss:
		# Onryo's Grudge: the body bursts a moment later; the ring shows where
		Game.fx.missile_strike(global_position, GRUDGE_DELAY, GRUDGE_RADIUS, GRUDGE_DAMAGE, "grudge")
	if burn_t > 0.0 and Game.rank("hitodama") > 0:
		_hitodama_burst()
	var hk := float(Game.mut("heal_kill", 0.0))
	if hk > 0.0:
		Game.player.heal(hk)
	if is_boss:
		Game.main.on_boss_killed(self)
	if pool:
		_park()
		pool.recycle(self)
	else:
		queue_free()


## A glory kill close to the boss shakes its stance (spec §5.5).
func _feed_boss_kamae() -> void:
	var b: Enemy = Game.main.boss if Game.main else null
	if b == null or not is_instance_valid(b) or b.dead or b.kamae == null:
		return
	if b.global_position.distance_to(global_position) <= BossKamae.GLORY_RANGE:
		b.press_kamae(b.kamae.max_value * BossKamae.GLORY_SHARE)


## Hannya's Wrath: a wounded enemy enrages, faster and harder hitting, eyes red.
func _enrage() -> void:
	_wrath = true
	speed *= WRATH_SPEED
	damage_mult *= WRATH_DAMAGE
	_eye_mat.set_shader_parameter("albedo_color", Color(1.0, 0.1, 0.1))
	Sfx.play_at("windup", global_position, -4.0, 1.4)


## Hitodama Chain: a burning enemy's death spreads the fire to everyone close.
func _hitodama_burst() -> void:
	var c := global_position + Vector3(0, height * 0.5, 0)
	Game.gore.embers(global_position, 8)
	Game.gore.sparks(c, Vector3.UP, 18, Color(2.0, 0.9, 0.3))
	for o in Game.enemy_list:
		if is_instance_valid(o) and o != self and not o.dead and o.global_position.distance_to(global_position) < 5.0:
			o.ignite(maxi(1, Game.rank("dragon")))


# ---------------------------------------------------------------- animation
func _animate(delta: float, spd: float) -> void:
	var s := height / 1.8
	var k := 1.0 - exp(-16.0 * delta)
	var moving := clampf(spd / maxf(speed, 0.1), 0.0, 1.5)
	walk_phase += spd * delta * 1.7 / s
	var sw := sin(walk_phase) * minf(moving, 1.0) * 0.75
	var t_leg_l := sw
	var t_leg_r := -sw
	var t_arm_l := Vector3(-sw * 0.8, 0, 0)
	var t_arm_r := Vector3(sw * 0.8, 0, 0)
	var t_torso := 0.12 * minf(moving, 1.0)
	var t_hips := _leg_len + absf(sin(walk_phase)) * 0.05 * s * minf(moving, 1.0)
	match state:
		S.WINDUP:
			var w := clampf(state_t / _windup_time(), 0.0, 1.0)
			_set_weapon_heat(w)
			match kind:
				"gunner":
					t_arm_r = Vector3(-PI * 0.5, 0, 0)
				"grunt":
					# the blade goes up over the right shoulder, the free hand guards
					t_arm_r = Vector3(-2.75 * w, 0, -0.35 * w)
					t_arm_l = Vector3(-0.9 * w, 0, 0.25 * w)
					t_torso = -0.3 * w
				"brute":
					# the club comes up two-handed, high over the head
					t_arm_l = Vector3(-2.9 * w, 0, -0.35 * w)
					t_arm_r = Vector3(-2.9 * w, 0, -0.1 * w)
					t_torso = -0.35 * w
				_:
					t_arm_l = Vector3(-2.6 * w, 0, 0.3 * w)
					t_arm_r = Vector3(-2.6 * w, 0, -0.3 * w)
					t_torso = -0.25 * w
		S.RECOVER:
			if state_t < STRIKE_HOLD and kind in ["grunt", "brute"]:
				# the follow-through: held where the blow landed (_strike_pose)
				var sp := _strike_pose()
				t_arm_l = sp[0]
				t_arm_r = sp[1]
				t_torso = sp[2]
				_set_weapon_heat(1.0 - state_t / STRIKE_HOLD)
			elif state_t < 0.2 and kind != "gunner":
				t_arm_l = Vector3(-1.1, 0, 0)
				t_arm_r = Vector3(-1.1, 0, 0)
				t_torso = 0.45
			elif state_t < 0.1:
				_set_weapon_heat(0.0)
		S.STAGGER:
			t_hips = _leg_len * 0.55
			t_leg_l = -1.3
			t_leg_r = -0.2
			t_torso = 0.55
			t_arm_l = Vector3(0.15, 0, 0.15)
			t_arm_r = Vector3(0.15, 0, -0.15)
		S.CHARGE_WINDUP, S.RED_WINDUP:
			t_torso = -0.35
			t_arm_l = Vector3(-0.4, 0, 1.2)
			t_arm_r = Vector3(-0.4, 0, -1.2)
		S.CHARGE, S.RED_ACT, S.SIDESTEP:
			t_torso = 0.6
			t_arm_l = Vector3(0.9, 0, 0.2)
			t_arm_r = Vector3(0.9, 0, -0.2)
		S.SLAM, S.AREA_WINDUP:
			t_arm_l = Vector3(-2.9, 0, 0.2)
			t_arm_r = Vector3(-2.9, 0, -0.2)
			t_torso = -0.2
		S.VOLLEY_WINDUP:
			t_arm_l = Vector3(-1.6, 0, 0.8)
			t_arm_r = Vector3(-1.6, 0, -0.8)
		S.SPAWN:
			if not is_on_floor():
				t_arm_l = Vector3(-0.5, 0, 0.8)
				t_arm_r = Vector3(-0.5, 0, -0.8)
				t_leg_l = -0.5
				t_leg_r = 0.3
	leg_l.rotation.x = lerpf(leg_l.rotation.x, t_leg_l, k)
	leg_r.rotation.x = lerpf(leg_r.rotation.x, t_leg_r, k)
	arm_l.rotation = arm_l.rotation.lerp(t_arm_l, k)
	arm_r.rotation = arm_r.rotation.lerp(t_arm_r, k)
	torso_pivot.rotation.x = lerpf(torso_pivot.rotation.x, t_torso - 0.55 * _flinch, k)
	torso_pivot.rotation.y = 0.45 * _flinch_twist * _flinch
	hips.position.y = lerpf(hips.position.y, t_hips, k)
	_flinch = maxf(0.0, _flinch - delta * 6.0)
