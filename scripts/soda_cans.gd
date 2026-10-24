class_name SodaCans
extends Node3D
## Soda cans in a run (spec §19.1 #11; flavours in Soda). A dev-only
## play-test experiment: with the DEV menu's SODA CANS switch off (the
## default) no can is ever made, and nothing here draws a single number.
##
## Cans appear at seeded spots when a wave starts (Game.rng_cans, reseeded
## from the seed and the wave, so cans never shift enemies, mutators or card
## offers), glow with a light pillar in their flavour's colour, and vanish
## when the wave is cleared. Walking into one takes it, up to Soda.MAX_HELD.
## The drink key drinks the selected can (the mouse wheel moves the
## selection): about DRINK_LEN seconds, both weapons busy, movement free.
## The katana opens it at CUT_AT and the effect starts there. One effect at a
## time: a new drink replaces the current one and skips its crash.

signal drank(id: String) # the can was opened: the effect starts now

const PICKUP_REACH := 1.5 # metres, across the ground
const PICKUP_HEIGHT := 1.9 # metres, up from the feet
const DRINK_LEN := 0.9
const CUT_AT := 0.32
const DRINK_BUFFER := 0.2 # a press just before the hands are free still counts
const FULL_NOTE_GAP := 4.0 # CANS FULL shows at most this often
const SPOT_GAP := 8.0 # two cans in one wave sit at least this far apart
const MAX_FLOOR := 2 # Soda.count_for_wave never asks for more
const CAN_SCALE := 2.4 # bigger than life, so a can reads from across the roof
const PILLAR_H := 7.0

var enabled := false
var held: Array[String] = []
var selected := 0
var active := "" # the flavour whose effect is on
var phase := "" # "buff", "crash" or ""
var phase_t := 0.0 # seconds left in the phase
var phase_len := 1.0
var _boosts := {} # the active phase's multipliers, cached so the hot paths only look up
var _flags: Array = [] # the active buff's switches
var drinking := "" # the flavour in the hands, while drinking
var drink_t := -1.0
var _cut := false
var _buffer := 0.0
var _full_t := 0.0
var _shown_drink_key := false
var _floor: Array = [] # {n, id, k: how far it has popped up, out}
var _free: Array = [] # floor can nodes, ready to place
var _mats := {} # flavour id -> [body, band]
var _t := 0.0
var _auto_t := 0.0
var _test_at := 0
var _cantest := Game.has_flag("--cantest") # read once: the command line never changes


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF # moved every frame
	if DevSettings.cans or Game.has_flag("--cans"):
		_turn_on()


## The DEV menu's SODA CANS switch moved. On the title it decides the run
## about to start (Main is built once for the title and the run, so _ready
## has already read the old value). Mid-run, turning it on brings cans from
## the next wave and the run makes no top 10 entry; turning it off leaves
## this run's cans as they are, since the run already had them.
func on_switch(on: bool) -> void:
	if Game.state == "title":
		Game.cans_run = on or Game.has_flag("--cans")
		if Game.cans_run:
			_turn_on()
		else:
			switch_off()
	elif on:
		Game.cans_run = true
		_turn_on()


func _turn_on() -> void:
	enabled = true
	for i in MAX_FLOOR + (1 if _cantest else 0) - _free.size() - _floor.size():
		_free.append(_new_can())


## The run is resuming a snapshot with cans: they stay on for the run.
func restore(ids: Array) -> void:
	_turn_on()
	held.clear()
	for id in ids:
		if not Soda.get_def(str(id)).is_empty() and held.size() < Soda.MAX_HELD:
			held.append(str(id))
	selected = 0


## The run is resuming a snapshot made without cans: none for this run.
func switch_off() -> void:
	enabled = false
	held.clear()


## The multiplier the active can puts on `key` (1.0 for none).
func boost(key: String) -> float:
	return float(_boosts.get(key, 1.0))


## Whether the active can's buff switches `key` on.
func flag(key: String) -> bool:
	return key in _flags


## Both hands are on the can: the weapons wait.
func busy() -> bool:
	return drink_t >= 0.0


func selected_id() -> String:
	return held[selected] if selected < held.size() else ""


# ---------------------------------------------------------------- waves
## Called when wave `w` starts, after its streams are reseeded: last wave's
## cans go, and this wave's appear at seeded spots.
func on_wave_start(w: int, boss_wave: bool) -> void:
	clear_floor()
	if not enabled:
		return
	if Game.has_flag("--cantest"):
		_test_fill()
	var n := Soda.count_for_wave(w, boss_wave)
	if n == 0 or Game.arena == null:
		return
	var spots := Game.arena.pickup_spots()
	if spots.is_empty():
		return
	var r := Game.rng_cans
	var pool := Soda.pool_for_wave(w)
	var taken: Array[Vector3] = []
	for i in n:
		var def: Dictionary = pool[r.randi() % pool.size()]
		if DevSettings.can_flavour != "":
			def = Soda.get_def(DevSettings.can_flavour)
		# a few tries for a spot clear of the wave's other can
		var spot := spots[r.randi() % spots.size()]
		for k in 6:
			var ok := true
			for o in taken:
				if o.distance_to(spot) < SPOT_GAP:
					ok = false
			if ok:
				break
			spot = spots[r.randi() % spots.size()]
		taken.append(spot)
		_place(def.id, spot)
	if Game.debug_autoplay:
		var ids := []
		for c in _floor:
			if not c.get("test", false):
				ids.append(c.id)
		print("[cans] wave %d %s" % [w, ",".join(ids)])


## The wave is over: the cans left on the floor fade away.
func on_wave_cleared() -> void:
	for c in _floor:
		c.out = true


func clear_floor() -> void:
	for c in _floor:
		c.n.visible = false
		_free.append(c.n)
	_floor.clear()


func _place(id: String, at: Vector3) -> void:
	if _free.is_empty():
		return
	var n: Node3D = _free.pop_back()
	var m: Array = _mats_for(id)
	var body: MeshInstance3D = n.get_node("Can/Body")
	body.material_override = m[0]
	var band: MeshInstance3D = n.get_node("Can/Band")
	band.material_override = m[1]
	(n.get_node("PillarA") as MeshInstance3D).material_override = m[2]
	(n.get_node("PillarB") as MeshInstance3D).material_override = m[2]
	(n.get_node("Glow") as MeshInstance3D).material_override = m[3]
	(n.get_node("Ring") as MeshInstance3D).material_override = m[4]
	n.position = at
	n.visible = true
	n.scale = Vector3.ONE * 0.01
	_floor.append({"n": n, "id": id, "k": 0.0, "out": false, "can": n.get_node("Can")})


# ---------------------------------------------------------------- the frame
func _unhandled_input(event: InputEvent) -> void:
	if not enabled or Game.state != "playing" or held.size() < 2:
		return
	var step := 0
	if event.is_action_pressed("can_next"):
		step = 1
	elif event.is_action_pressed("can_prev"):
		step = -1
	if step != 0:
		selected = posmod(selected + step, held.size())
		Sfx.play("ui_hover", -4.0, 1.4)
		_announce(selected_id(), false)


func _physics_process(delta: float) -> void:
	if not enabled or Game.state != "playing":
		return
	var p := Game.player
	if p == null or p.dead:
		return
	_full_t -= delta
	_buffer -= delta
	# the active effect runs on game time, so slow-mo stretches it too
	if phase != "":
		phase_t -= delta
		if phase_t <= 0.0:
			_end_phase()
	_pickups(p)
	if Input.is_action_just_pressed("drink") or _auto_drink(delta):
		_buffer = DRINK_BUFFER
	if _buffer > 0.0 and drink_t < 0.0 and not held.is_empty() and p.gk_target == null and p.climb_t < 0.0:
		_buffer = 0.0
		_start_drink(p)
	if drink_t >= 0.0:
		drink_t += delta
		if not _cut and drink_t >= CUT_AT:
			_cut = true
			_open(p)
		if drink_t >= DRINK_LEN:
			drink_t = -1.0
			drinking = ""


func _process(delta: float) -> void:
	_t += delta
	var i := 0
	while i < _floor.size():
		var c: Dictionary = _floor[i]
		var n: Node3D = c.n
		# pops up as the wave starts, shrinks away when it ends
		c.k = clampf(c.k + delta * (-4.0 if c.out else 3.0), 0.0, 1.0)
		if c.out and c.k <= 0.0:
			n.visible = false
			_free.append(n)
			_floor.remove_at(i)
			continue
		n.scale = Vector3.ONE * maxf(0.01, Juice.ease_out(c.k))
		var can: Node3D = c.can
		can.rotation.y = _t * 2.2
		can.position.y = 0.55 + sin(_t * 3.0 + n.position.x) * 0.08
		i += 1


func _pickups(p: Player) -> void:
	var i := 0
	while i < _floor.size():
		var c: Dictionary = _floor[i]
		if c.out:
			i += 1
			continue
		var n: Node3D = c.n
		var d := Vector2(n.position.x - p.global_position.x, n.position.z - p.global_position.z).length()
		var dy := p.global_position.y - n.position.y
		if d > PICKUP_REACH or dy < -PICKUP_HEIGHT or dy > PICKUP_HEIGHT:
			i += 1
			continue
		if held.size() >= Soda.MAX_HELD:
			if _full_t <= 0.0:
				_full_t = FULL_NOTE_GAP
				Game.hud.show_hint("CANS FULL - DRINK ONE (%s) TO CARRY MORE" % Ui.key_name("drink"), false, Soda.get_def(c.id).color)
			i += 1
			continue
		held.append(c.id)
		if held.size() == 1:
			selected = 0
		n.visible = false
		_free.append(n)
		_floor.remove_at(i)
		Sfx.play("can_pickup", -3.0)
		Game.gore.sparks(n.position + Vector3(0, 0.6, 0), Vector3.UP, 10, Soda.get_def(c.id).color * 2.0)
		if Game.hud:
			Game.hud.soda_hud.pop(held.size() - 1)
		_announce(c.id, true)


## The pickup line in the hint lane: the can's name in its colour, then what
## it does. The first can of a run also names the drink key.
func _announce(id: String, picked: bool) -> void:
	var def := Soda.get_def(id)
	if def.is_empty() or Game.hud == null:
		return
	var head: String = def.name
	var fit := Soda.fits_build(def, Game.upgrades)
	if picked and not _shown_drink_key:
		_shown_drink_key = true
		head = "%s  //  %s TO DRINK" % [def.name, Ui.key_name("drink")]
	elif not fit.is_empty():
		head = "%s  //  FITS %s" % [def.name, fit.name]
	Game.hud.show_hint("%s - %s" % [head, def.desc], false, def.color)


func _start_drink(p: Player) -> void:
	drinking = held[selected]
	held.remove_at(selected)
	selected = mini(selected, maxi(0, held.size() - 1))
	drink_t = 0.0
	_cut = false
	p.vm.drink(Soda.get_def(drinking).color, DRINK_LEN, CUT_AT)
	Sfx.play("dash", -10.0, 0.8) # the shotgun drops to the hip


## The katana takes the top off: splash, sting, and the effect is on.
func _open(p: Player) -> void:
	var def := Soda.get_def(drinking)
	if def.is_empty():
		return
	_set_phase(drinking, "buff")
	phase_len = float(def.time)
	phase_t = phase_len
	Sfx.play("can_open", -2.0)
	Sfx.play("slice", -8.0, 1.5)
	p.add_trauma(0.12)
	p.fov_kick = maxf(p.fov_kick, 3.0)
	Game.hitstop(0.03)
	if Game.hud:
		Game.hud.soda_drank(def)
	drank.emit(active)
	if Game.debug_autoplay:
		print("[cans] drank %s at wave %d" % [active, Game.wave])


func _end_phase() -> void:
	var def := Soda.get_def(active)
	if phase == "buff" and float(def.get("crash_time", 0.0)) > 0.0:
		_set_phase(active, "crash")
		phase_len = float(def.crash_time)
		phase_t = phase_len
		Sfx.play("can_crash", -4.0)
		return
	if phase == "buff" and def.get("halve_combo", false) and Game.combo > 1:
		Game.combo = int(Game.combo / 2.0)
		Game.combo_timer = Game.combo_window()
		Sfx.play("can_crash", -4.0)
	_set_phase("", "")


## Puts flavour `id` into `ph` ("buff", "crash" or "" for none) and caches
## what that phase does.
func _set_phase(id: String, ph: String) -> void:
	active = id
	phase = ph
	var def := Soda.get_def(id) if ph != "" else {}
	_boosts = def.get("boosts" if ph == "buff" else "crash", {})
	_flags = def.get("flags", []) if ph == "buff" else []


## Debug (--cantest, with --cans): every wave starts with the hands full of
## the next flavours in the list, so an autoplay run drinks every one, and
## one more can lies 7 m in front of the player, to see how a can looks.
func _test_fill() -> void:
	held.clear()
	for i in Soda.MAX_HELD:
		held.append(Soda.LIST[_test_at % Soda.LIST.size()].id)
		_test_at += 1
	selected = 0
	var p := Game.player
	if p and not _free.is_empty():
		var at := p.global_position - p.global_basis.z * 7.0
		at.y = Game.arena.floor_height_at(at.x, at.z, p.global_position.y + 1.0)
		_place(Soda.LIST[_test_at % Soda.LIST.size()].id, at)
		_floor[-1]["test"] = true


## The bot (autoplay testing, or --cantest) drinks a held can every few
## seconds.
func _auto_drink(delta: float) -> bool:
	if not (Game.debug_autoplay or _cantest) or held.is_empty():
		return false
	_auto_t += delta
	if _auto_t < 2.5:
		return false
	_auto_t = 0.0
	return true


# ---------------------------------------------------------------- looks
func _mats_for(id: String) -> Array:
	if not _mats.has(id):
		var col: Color = Soda.get_def(id).color
		var p := {"snap": 0.35}
		_mats[id] = [
			Psx.lit(col.darkened(0.15), TexGen.get_tex("panel"), false, 1.0, p),
			Psx.unlit(col.lerp(Color.WHITE, 0.35), 2.6, null, p),
			Psx.fx(Color(col.r, col.g, col.b, 0.6), TexGen.get_tex("glow"), true, false, false, 1.8),
			Psx.fx(Color(col.r, col.g, col.b, 0.8), TexGen.get_tex("glow"), true, true, false, 1.6),
			Psx.fx(Color(col.r, col.g, col.b, 0.9), TexGen.get_tex("ring"), true, false, false, 1.4),
		]
	return _mats[id]


## A floor can: the can itself, two crossed light planes for the pillar, a
## glow behind the can and a ring of light on the ground.
func _new_can() -> Node3D:
	var root := Node3D.new()
	root.visible = false
	var can := Node3D.new()
	can.name = "Can"
	can.scale = Vector3.ONE * CAN_SCALE
	root.add_child(can)
	var body := MeshInstance3D.new()
	body.name = "Body"
	var cm := CylinderMesh.new()
	cm.top_radius = 0.07
	cm.bottom_radius = 0.07
	cm.height = 0.24
	cm.radial_segments = 8
	cm.rings = 1
	body.mesh = cm
	can.add_child(body)
	var band := MeshInstance3D.new()
	band.name = "Band"
	var bm := CylinderMesh.new()
	bm.top_radius = 0.073
	bm.bottom_radius = 0.073
	bm.height = 0.07
	bm.radial_segments = 8
	bm.rings = 1
	band.mesh = bm
	can.add_child(band)
	var rim := Psx.lit(Color(0.75, 0.78, 0.85), TexGen.get_tex("panel"), false, 1.0, {"snap": 0.35})
	can.add_child(Psx.box(Vector3(0.11, 0.012, 0.11), rim, Vector3(0, 0.126, 0)))
	can.add_child(Psx.box(Vector3(0.11, 0.012, 0.11), rim, Vector3(0, -0.126, 0)))
	for k in 2:
		var q := Psx.quad(Vector2(0.9, PILLAR_H), null, Vector3(0, PILLAR_H * 0.5, 0))
		q.name = "PillarA" if k == 0 else "PillarB"
		q.rotation.y = k * PI * 0.5
		root.add_child(q)
	var glow := Psx.quad(Vector2(1.1, 1.1), null, Vector3(0, 0.55, 0))
	glow.name = "Glow"
	root.add_child(glow)
	var ring := Psx.quad(Vector2(2.2, 2.2), null, Vector3(0, 0.04, 0))
	ring.name = "Ring"
	ring.rotation.x = -PI * 0.5
	root.add_child(ring)
	for g in root.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(root)
	return root
