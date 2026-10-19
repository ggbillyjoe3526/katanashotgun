class_name Viewmodel
extends Node3D
## First-person hands: the DOJIGIRI katana in the left hand, the RAIJIN-12 arc shotgun in
## the right. The shotgun is a "shotgun taser": an electrode muzzle, glowing
## capacitor coils and a drum of power cells that turns after every blast.
## Everything is modelled at "full" scale and the root is scaled to 0.5 so the
## weapons sit closer to the lens than the player's collision radius, which
## means they never clip into walls.

const SLASH_DUR := 0.13
const RETURN_DUR := 0.2

var katana: Node3D
var blade_edge_mat: ShaderMaterial
# the DOJIGIRI model, and the code-built blade kept as its fallback
var _code_blade: Node3D
var _model_blade: Node3D
var shotgun: Node3D
var spin_pivot: Node3D
var drum: Node3D
var muzzle: Node3D
var flash: MeshInstance3D
var flash_mat: ShaderMaterial
var cell_leds: Array[MeshInstance3D] = []
var led_on: ShaderMaterial
var led_off: ShaderMaterial
var coil_mat: ShaderMaterial
var core_mat: ShaderMaterial
var tip_mat: ShaderMaterial
var drum_cell_mat: ShaderMaterial
# tinted by the equipped boss-reward looks (Rewards, spec §11.2)
var trim_mat: ShaderMaterial
var strip_mats: Array[ShaderMaterial] = []
var arc_glow := Color(0.25, 0.45, 1.0, 0.35)
var prong_tips: Array[Node3D] = []
var idle_arc: MeshInstance3D
# the code-built gun, and the RAIJIN-12 model that replaces it from the dev
# menu (drum, prong_tips, cell_leds and muzzle then point at the model's)
var _code_gun: Node3D
var _model_gun: Node3D
var _gun_model_on := false
var _code_drum: Node3D
var _code_tips: Array[Node3D] = []
var _code_leds: Array[MeshInstance3D] = []
var _code_muzzle := Vector3.ZERO
# one blast turns the drum one cell: six on the code-built drum, four on
# the model's square one
var _drum_step := TAU / 6.0
var _max_cells := 10
var _idle_im: ImmediateMesh
var _idle_t := 0.5
var _idle_life := 0.0
var _charge := 1.0
var _cells := 4
var _drum_from := 0.0
var _drum_to := 0.0
var _rng := RandomNumberGenerator.new()

# how far the Blender katana turns in the hand (radians, around its blade)
const KATANA_MODEL_ROLL := -0.9
# glory kill poses (weapon targets the hands snap to between beats)
const K_POSES := {
	"ready": [Vector3(-0.4, -0.3, -0.42), Vector3(-1.0, 0.5, -0.4)],
	"thrust": [Vector3(-0.08, -0.16, -0.78), Vector3(-1.5, -0.1, 0.0)],
	"rip_up": [Vector3(-0.05, 0.12, -0.6), Vector3(-0.15, 0.0, 0.0)],
	"overhead": [Vector3(-0.1, 0.12, -0.32), Vector3(0.45, -0.4, -0.3)],
	"chop": [Vector3(0.02, -0.4, -0.6), Vector3(-2.25, -0.3, -0.3)],
	"aside": [Vector3(-0.55, -0.5, -0.45), Vector3(-0.6, 0.6, -0.5)],
	# plunge: raised high in a blade-down grip, then driven down and in
	"plunge_raise": [Vector3(-0.12, 0.2, -0.36), Vector3(-2.0, 0.1, 0.0)],
	"plunge": [Vector3(-0.04, -0.36, -0.68), Vector3(-2.35, 0.05, 0.0)],
}
# ledge climb: both hands reach up for the edge, then press down on it
const CLIMB_REACH_K := [Vector3(0.1, 0.22, -0.06), Vector3(-0.5, 0.0, 0.0)]
const CLIMB_PRESS_K := [Vector3(0.08, -0.34, 0.1), Vector3(0.8, 0.0, 0.0)]
const CLIMB_REACH_S := [Vector3(-0.08, 0.24, -0.06), Vector3(-0.5, 0.0, 0.0)]
const CLIMB_PRESS_S := [Vector3(-0.06, -0.34, 0.1), Vector3(0.85, 0.0, 0.0)]
const S_POSES := {
	"ready": [Vector3(0.42, -0.4, -0.45), Vector3(0.0, 0.25, 0.1)],
	"chin": [Vector3(0.1, -0.2, -0.55), Vector3(0.75, 0.05, 0.0)],
	"point": [Vector3(0.12, -0.18, -0.62), Vector3(0.05, 0.05, 0.0)],
	"down": [Vector3(0.1, -0.12, -0.55), Vector3(-0.75, 0.0, 0.0)],
}
var _glory := false
var _kpose: Array = []
var _spose: Array = []
var _spos_cur := Vector3.ZERO
var _srot_cur := Vector3.ZERO

var katana_idle_pos := Vector3(-0.5, -0.44, -0.6)
var katana_idle_rot := Vector3(-0.55, 0.3, -0.3)
var shotgun_idle_pos := Vector3(0.36, -0.3, -0.52)
var shotgun_idle_rot := Vector3(0.04, 0.16, 0.05)

var _slash_t := -1.0
var _slash_from_pos := Vector3.ZERO
var _slash_from_rot := Vector3.ZERO
var _slash_to_pos := Vector3.ZERO
var _slash_to_rot := Vector3.ZERO
var _fire_t := -1.0
var _flash_t := 0.0
var _pump_sound_done := true
var _sway := Vector2.ZERO
var _sway_vel := Vector2.ZERO
var _bob := 0.0
var _bob_amt := 0.0
var _kpos := Vector3.ZERO
var _krot := Vector3.ZERO
var _glow := 0.0
var _climb_p := -1.0 # 0..1 through a ledge climb, below 0 when not climbing
var _reach := 0.0
var _press := 0.0


func _ready() -> void:
	scale = Vector3.ONE * 0.5
	_build_katana()
	_build_shotgun()
	# the weapons float in front of the camera: a shadow of them (INSANE's
	# moon) would land on the floor far from the player
	for g in find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	apply_looks()
	# equipping from the armory (title or pause) recolours the live weapons
	Profile.changed.connect(apply_looks)
	_kpos = katana_idle_pos
	_krot = katana_idle_rot


func _lit(c: Color, tex := "noise", params := {}) -> ShaderMaterial:
	var p := {"snap": 0.35, "affine": 0.0, "fog_start": 50.0}
	p.merge(params, true)
	return Psx.lit(c, TexGen.get_tex(tex), false, 1.0, p)


func _build_katana() -> void:
	katana = Node3D.new()
	add_child(katana)
	_code_blade = Node3D.new()
	katana.add_child(_code_blade)
	var wrap := _lit(Color(0.55, 0.07, 0.1), "cloth", {"uv_tiling": Vector2(1, 6)})
	var gold := _lit(Color(0.85, 0.65, 0.25), "noise")
	var steel := _lit(Color(0.85, 0.88, 0.95), "noise", {"emission_color": Color(0.5, 0.6, 0.8), "emission_strength": 0.15})
	var glove := _lit(Color(0.12, 0.12, 0.15), "cloth")
	var chrome := _lit(Color(0.55, 0.58, 0.65), "panel")
	blade_edge_mat = Psx.unlit(Color(0.4, 0.95, 1.0), 2.4, null, {"snap": 0.35, "fog_amount": 0.0})
	_code_blade.add_child(Psx.box(Vector3(0.042, 0.27, 0.042), wrap, Vector3(0, 0.0, 0)))
	_code_blade.add_child(Psx.box(Vector3(0.05, 0.03, 0.05), gold, Vector3(0, -0.15, 0)))
	_code_blade.add_child(Psx.box(Vector3(0.12, 0.018, 0.1), gold, Vector3(0, 0.145, 0)))
	_code_blade.add_child(Psx.box(Vector3(0.05, 0.03, 0.05), gold, Vector3(0, 0.168, 0)))
	var blade := Psx.box(Vector3(0.012, 0.86, 0.042), steel, Vector3(0, 0.6, 0))
	_code_blade.add_child(blade)
	_code_blade.add_child(Psx.box(Vector3(0.016, 0.86, 0.008), blade_edge_mat, Vector3(0, 0.6, 0.022)))
	var tip := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.042, 0.09, 0.012)
	pm.left_to_right = 1.0
	tip.mesh = pm
	tip.material_override = steel
	tip.position = Vector3(0, 1.075, 0)
	tip.rotation.y = PI * 0.5
	_code_blade.add_child(tip)
	# hand + cyber forearm
	katana.add_child(Psx.box(Vector3(0.1, 0.11, 0.11), glove, Vector3(0, 0.02, 0)))
	var arm := Node3D.new()
	arm.rotation = Vector3(0.9, 0, 0.35)
	katana.add_child(arm)
	arm.add_child(Psx.box(Vector3(0.085, 0.42, 0.085), chrome, Vector3(0, -0.26, 0)))
	trim_mat = Psx.unlit(Color(1.0, 0.2, 0.6), 2.2, null, {"snap": 0.35, "fog_amount": 0.0})
	arm.add_child(Psx.box(Vector3(0.09, 0.3, 0.012), trim_mat, Vector3(0, -0.28, 0.046)))
	_model_blade = KatanaModel.build(blade_edge_mat)
	# turned on its long axis so the flat and the hilt's windows face the
	# player; the code-built blade showed its edge strip instead
	_model_blade.rotation.y = KATANA_MODEL_ROLL
	katana.add_child(_model_blade)
	# the code-built blade only shows if the model failed to load
	_code_blade.visible = _model_blade.get_child_count() == 0


func _build_shotgun() -> void:
	_rng.randomize()
	shotgun = Node3D.new()
	add_child(shotgun)
	spin_pivot = Node3D.new()
	shotgun.add_child(spin_pivot)
	var gun := _lit(Color(0.17, 0.18, 0.23), "panel")
	var dark := _lit(Color(0.07, 0.07, 0.09), "noise")
	var glove := _lit(Color(0.12, 0.12, 0.15), "cloth")
	var chrome := _lit(Color(0.55, 0.58, 0.65), "panel")
	var copper := _lit(Color(0.8, 0.42, 0.2), "noise", {"emission_color": Color(1.0, 0.5, 0.2), "emission_strength": 0.2})
	var fx_p := {"snap": 0.35, "fog_amount": 0.0}
	coil_mat = Psx.unlit(Color(0.35, 0.75, 1.0), 3.0, null, fx_p)
	core_mat = Psx.unlit(Color(0.75, 0.92, 1.0), 3.0, null, fx_p)
	tip_mat = Psx.unlit(Color(0.85, 0.95, 1.0), 3.5, null, fx_p)
	drum_cell_mat = Psx.unlit(Color(0.3, 0.85, 1.0), 2.6, null, fx_p)
	# the code-built gun; the Blender model takes its place when the dev
	# menu asks for it (_show_shotgun_model)
	_code_gun = Node3D.new()
	spin_pivot.add_child(_code_gun)
	# receiver, grip and top heat sink
	_code_gun.add_child(Psx.box(Vector3(0.09, 0.12, 0.34), gun, Vector3(0, 0.03, -0.12)))
	_code_gun.add_child(Psx.box(Vector3(0.06, 0.03, 0.3), dark, Vector3(0, 0.105, -0.14)))
	for i in 5:
		_code_gun.add_child(Psx.box(Vector3(0.075, 0.012, 0.014), dark, Vector3(0, 0.125, -0.24 + i * 0.05)))
	strip_mats.append(Psx.unlit(Color(0.25, 0.8, 1.0), 2.2, null, fx_p))
	_code_gun.add_child(Psx.box(Vector3(0.092, 0.01, 0.3), strip_mats[-1], Vector3(0, 0.09, -0.12)))
	_code_gun.add_child(Psx.box(Vector3(0.055, 0.13, 0.07), gun, Vector3(0, -0.07, 0.07)))
	_code_gun.add_child(Psx.box(Vector3(0.06, 0.09, 0.12), dark, Vector3(0, 0.02, 0.11)))
	# the glowing core inside an open cage of rails
	var core := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.016
	cm.bottom_radius = 0.016
	cm.height = 0.5
	cm.radial_segments = 6
	core.mesh = cm
	core.material_override = core_mat
	core.rotation.x = PI * 0.5
	core.position = Vector3(0, 0.05, -0.55)
	_code_gun.add_child(core)
	for sx in [-1.0, 1.0]:
		_code_gun.add_child(Psx.box(Vector3(0.016, 0.075, 0.5), dark, Vector3(sx * 0.044, 0.05, -0.55)))
	_code_gun.add_child(Psx.box(Vector3(0.1, 0.02, 0.05), gun, Vector3(0, 0.09, -0.78)))
	_code_gun.add_child(Psx.box(Vector3(0.1, 0.02, 0.05), gun, Vector3(0, 0.01, -0.78)))
	# capacitor coils
	for i in 4:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.03
		tm.outer_radius = 0.05
		tm.rings = 8
		tm.ring_segments = 4
		ring.mesh = tm
		ring.material_override = coil_mat if i % 2 == 0 else copper
		ring.rotation.x = PI * 0.5
		ring.position = Vector3(0, 0.05, -0.38 - i * 0.1)
		_code_gun.add_child(ring)
	# three electrode prongs at the muzzle
	for i in 3:
		var a := PI * 0.5 + i * TAU / 3.0
		var off := Vector3(cos(a), sin(a), 0) * 0.045
		var prong := Node3D.new()
		prong.position = Vector3(0, 0.05, -0.84) + off
		prong.rotation = Vector3(sin(a) * 0.25, -cos(a) * 0.25, 0)
		_code_gun.add_child(prong)
		prong.add_child(Psx.box(Vector3(0.014, 0.014, 0.12), chrome, Vector3(0, 0, -0.04)))
		var tip := Psx.box(Vector3(0.022, 0.022, 0.022), tip_mat, Vector3(0, 0, -0.105))
		prong.add_child(tip)
		prong_tips.append(tip)
	# drum of power cells under the receiver (turns one cell per blast)
	drum = Node3D.new()
	drum.position = Vector3(0, -0.03, -0.25)
	_code_gun.add_child(drum)
	var hexm := CylinderMesh.new()
	hexm.top_radius = 0.052
	hexm.bottom_radius = 0.052
	hexm.height = 0.12
	hexm.radial_segments = 6
	var hexi := MeshInstance3D.new()
	hexi.mesh = hexm
	hexi.material_override = gun
	hexi.rotation.x = PI * 0.5
	drum.add_child(hexi)
	for i in 6:
		var a := i * TAU / 6.0 + TAU / 12.0
		var cell := Psx.box(Vector3(0.02, 0.02, 0.09), drum_cell_mat, Vector3(cos(a), sin(a), 0) * 0.047)
		cell.rotation.z = a
		drum.add_child(cell)
	# charge gauge LEDs along the side
	led_on = Psx.unlit(Color(0.3, 0.9, 1.0), 3.0, null, fx_p)
	led_off = Psx.unlit(Color(0.04, 0.08, 0.14), 1.0, null, fx_p)
	for i in 10:
		var led := Psx.box(Vector3(0.012, 0.014, 0.02), led_on, Vector3(-0.047, 0.065 - (i / 5) * 0.025, -0.24 + (i % 5) * 0.03))
		_code_gun.add_child(led)
		cell_leds.append(led)
	# hand + forearm
	spin_pivot.add_child(Psx.box(Vector3(0.1, 0.1, 0.11), glove, Vector3(0, -0.07, 0.0)))
	var arm := Node3D.new()
	arm.rotation = Vector3(1.0, 0, -0.3)
	shotgun.add_child(arm)
	arm.add_child(Psx.box(Vector3(0.09, 0.44, 0.09), chrome, Vector3(0, -0.3, 0.02)))
	strip_mats.append(Psx.unlit(Color(0.2, 0.9, 1.0), 2.2, null, fx_p))
	arm.add_child(Psx.box(Vector3(0.095, 0.3, 0.012), strip_mats[-1], Vector3(0, -0.3, 0.07)))
	muzzle = Node3D.new()
	muzzle.position = Vector3(0, 0.05, -0.95)
	spin_pivot.add_child(muzzle)
	flash_mat = Psx.fx(Color(0.55, 0.8, 1.0, 1.0), TexGen.get_tex("star"), true, false, false, 3.2)
	flash = Psx.quad(Vector2(0.7, 0.7), flash_mat)
	flash.visible = false
	muzzle.add_child(flash)
	var flash2 := Psx.quad(Vector2(0.16, 0.8), flash_mat, Vector3(0, 0, -0.25))
	flash2.rotation.x = PI * 0.5
	flash.add_child(flash2)
	# idle crackle between the prongs
	idle_arc = MeshInstance3D.new()
	_idle_im = ImmediateMesh.new()
	idle_arc.mesh = _idle_im
	idle_arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spin_pivot.add_child(idle_arc)
	_code_drum = drum
	_code_tips = prong_tips.duplicate()
	_code_leds = cell_leds.duplicate()
	_code_muzzle = muzzle.position
	_show_shotgun_model()
	shotgun.position = shotgun_idle_pos
	_spos_cur = shotgun_idle_pos
	_srot_cur = shotgun_idle_rot


## Shows the Blender model or the code-built gun, as the dev menu says. The
## code-built one stays until the model is approved (spec §9.6), so the model
## (and its large textures) loads only the first time it is asked for.
func _show_shotgun_model() -> void:
	_gun_model_on = DevSettings.shotgun_model
	if _gun_model_on and _model_gun == null:
		_model_gun = ShotgunModel.build({
			"coil": coil_mat, "core": core_mat, "emitter": tip_mat, "cell": drum_cell_mat, "led": led_on,
		})
		spin_pivot.add_child(_model_gun)
	var use_model := _gun_model_on and _model_gun.get_child_count() > 0 and _has_parts(_model_gun)
	if _model_gun:
		_model_gun.visible = use_model
	_code_gun.visible = not use_model
	if use_model:
		drum = ShotgunModel.part(_model_gun, "drum")
		prong_tips.clear()
		for i in ShotgunModel.ARC_POINTS:
			prong_tips.append(ShotgunModel.part(_model_gun, "arc_point_%d" % i))
		cell_leds.clear()
		for i in ShotgunModel.LED_COUNT:
			cell_leds.append(ShotgunModel.part(_model_gun, "led_%d" % i) as MeshInstance3D)
		muzzle.position = _in_gun(ShotgunModel.part(_model_gun, "muzzle"))
		_drum_step = TAU / 4.0
	else:
		drum = _code_drum
		prong_tips = _code_tips.duplicate()
		cell_leds = _code_leds.duplicate()
		muzzle.position = _code_muzzle
		_drum_step = TAU / 6.0
	# a swap mid-turn just lands the drum square
	_drum_from = 0.0
	_drum_to = 0.0
	drum.rotation.z = 0.0
	set_cells(_cells, _max_cells)


## True if the model has every node the viewmodel drives (a bad export
## would otherwise crash set_cells or the idle crackle).
func _has_parts(model: Node3D) -> bool:
	var names: Array[String] = ["drum", "muzzle"]
	for i in ShotgunModel.ARC_POINTS:
		names.append("arc_point_%d" % i)
	for i in ShotgunModel.LED_COUNT:
		names.append("led_%d" % i)
	for n in names:
		if ShotgunModel.part(model, n) == null:
			push_warning("ShotgunModel: no '%s' node, keeping the code-built gun" % n)
			return false
	return ShotgunModel.part(model, "led_0") is MeshInstance3D


## Where `node` (inside the model) sits in spin_pivot's space.
func _in_gun(node: Node3D) -> Vector3:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != spin_pivot and n is Node3D:
		t = (n as Node3D).transform * t
		n = n.get_parent()
	return t.origin


func _exit_tree() -> void:
	if Profile.changed.is_connected(apply_looks):
		Profile.changed.disconnect(apply_looks)


## Tints the katana edge and wrap and the shotgun's coils, cells and idle
## crackle with the equipped looks. The stock look keeps the original colours.
func apply_looks() -> void:
	var k := Rewards.look("katana", Profile.get_equipped("katana"))
	blade_edge_mat.set_shader_parameter("albedo_color", k.edge)
	trim_mat.set_shader_parameter("albedo_color", k.trim)
	var g := Rewards.look("shotgun", Profile.get_equipped("shotgun"))
	var stock: bool = g.name == Rewards.STOCK.shotgun.name
	coil_mat.set_shader_parameter("albedo_color", g.coil)
	core_mat.set_shader_parameter("albedo_color", g.core)
	drum_cell_mat.set_shader_parameter("albedo_color", Color(0.3, 0.85, 1.0) if stock else g.coil)
	led_on.set_shader_parameter("albedo_color", Color(0.3, 0.9, 1.0) if stock else g.coil)
	strip_mats[0].set_shader_parameter("albedo_color", Color(0.25, 0.8, 1.0) if stock else g.coil)
	strip_mats[1].set_shader_parameter("albedo_color", Color(0.2, 0.9, 1.0) if stock else g.coil)
	var gl: Color = g.glow
	arc_glow = Color(gl.r, gl.g, gl.b, 0.35)


func set_cells(n: int, max_n: int) -> void:
	_cells = n
	_max_cells = max_n
	for i in cell_leds.size():
		var led := cell_leds[i]
		led.visible = i < max_n
		led.material_override = led_on if i < n else led_off


## Draws a crackle between two prong tips (in the gun's local space).
func _draw_idle_arc() -> void:
	_idle_im.clear_surfaces()
	var i := _rng.randi() % 3
	var a := spin_pivot.to_local(prong_tips[i].global_position)
	var b := spin_pivot.to_local(prong_tips[(i + 1) % 3].global_position)
	var eye := spin_pivot.to_local(get_viewport().get_camera_3d().global_position) if get_viewport().get_camera_3d() else Vector3(0, 0, 1)
	var pts := Fx.jagged(a, b, 2.2, _rng)
	_idle_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, Game.fx._arc_mat if Game.fx else null)
	Fx.ribbon(_idle_im, pts, 0.03, arc_glow, eye)
	Fx.ribbon(_idle_im, pts, 0.008, Color(0.85, 0.95, 1.0, 1.0), eye)
	_idle_im.surface_end()


func add_sway(rel: Vector2) -> void:
	_sway_vel += rel * 0.00045


func slash(variant: int) -> void:
	_slash_t = 0.0
	_glow = 1.0
	match variant:
		0: # left -> right
			_slash_from_pos = Vector3(-0.45, -0.12, -0.42)
			_slash_from_rot = Vector3(-1.45, 1.15, 0.1)
			_slash_to_pos = Vector3(0.25, -0.3, -0.5)
			_slash_to_rot = Vector3(-1.5, -1.3, 0.1)
		1: # right -> left backhand
			_slash_from_pos = Vector3(0.25, -0.12, -0.45)
			_slash_from_rot = Vector3(-1.35, -1.2, PI)
			_slash_to_pos = Vector3(-0.5, -0.32, -0.42)
			_slash_to_rot = Vector3(-1.4, 1.25, PI)
		_: # overhead diagonal chop
			_slash_from_pos = Vector3(-0.1, 0.05, -0.38)
			_slash_from_rot = Vector3(0.35, -0.4, -0.3)
			_slash_to_pos = Vector3(0.05, -0.42, -0.55)
			_slash_to_rot = Vector3(-2.3, -0.3, -0.3)


func fire() -> void:
	_fire_t = 0.0
	_flash_t = 0.06
	_pump_sound_done = false
	_charge = 0.0
	_drum_from = drum.rotation.z
	_drum_to = _drum_from + _drum_step
	flash.visible = true
	flash.rotation.z = Game.rng_fx.randf() * TAU
	flash.scale = Vector3.ONE * Game.rng_fx.randf_range(0.8, 1.3)


func glory_begin() -> void:
	_glory = true
	_kpose = K_POSES.ready
	_spose = S_POSES.ready
	_spos_cur = shotgun.position
	_srot_cur = shotgun.rotation
	_glow = 1.0


func glory_pose(name: String) -> void:
	if K_POSES.has(name):
		_kpose = K_POSES[name]
		_slash_t = -1.0
		_glow = 1.0
	if S_POSES.has(name):
		_spose = S_POSES[name]
		_kpose = K_POSES.aside


func glory_end() -> void:
	_glory = false


## How far through a ledge climb the player is (0..1), or below 0 for none.
func set_climb(progress: float) -> void:
	_climb_p = progress


func muzzle_position() -> Vector3:
	return muzzle.global_position


func set_bob(amount: float, phase: float) -> void:
	_bob_amt = amount
	_bob = phase


func _process(delta: float) -> void:
	# sway spring
	_sway_vel -= _sway * 60.0 * delta
	_sway_vel *= exp(-9.0 * delta)
	_sway += _sway_vel * delta * 60.0
	_sway = _sway.limit_length(0.12)
	var sway3 := Vector3(-_sway.x, _sway.y, 0)
	var bob3 := Vector3(cos(_bob) * 0.02, -absf(sin(_bob)) * 0.025, 0) * _bob_amt
	# ledge climb: reach for the edge, then press down on it to pull over
	var want_reach := 0.0
	var want_press := 0.0
	if _climb_p >= 0.0:
		want_reach = 1.0 - smoothstep(0.3, 0.6, _climb_p)
		want_press = smoothstep(0.3, 0.6, _climb_p) * (1.0 - smoothstep(0.85, 1.0, _climb_p))
	_reach = lerpf(_reach, want_reach, 1.0 - exp(-35.0 * delta))
	_press = lerpf(_press, want_press, 1.0 - exp(-35.0 * delta))

	# ---- katana
	var tpos := katana_idle_pos
	var trot := katana_idle_rot
	if _slash_t >= 0.0:
		_slash_t += delta
		if _slash_t < SLASH_DUR:
			var k := 1.0 - pow(1.0 - _slash_t / SLASH_DUR, 3.0)
			tpos = _slash_from_pos.lerp(_slash_to_pos, k)
			trot = _slash_from_rot.lerp(_slash_to_rot, k)
			_kpos = tpos
			_krot = trot
		elif _slash_t < SLASH_DUR + 0.04:
			_kpos = _slash_to_pos
			_krot = _slash_to_rot
		else:
			var k2 := clampf((_slash_t - SLASH_DUR - 0.04) / RETURN_DUR, 0.0, 1.0)
			k2 = k2 * k2 * (3.0 - 2.0 * k2)
			_kpos = _slash_to_pos.lerp(katana_idle_pos, k2)
			_krot = _slash_to_rot.lerp(katana_idle_rot, k2)
			if k2 >= 1.0:
				_slash_t = -1.0
	elif _glory:
		_kpos = _kpos.lerp(_kpose[0], 1.0 - exp(-30.0 * delta))
		_krot = _krot.lerp(_kpose[1], 1.0 - exp(-30.0 * delta))
	else:
		_kpos = _kpos.lerp(katana_idle_pos, 1.0 - exp(-12.0 * delta))
		_krot = _krot.lerp(katana_idle_rot, 1.0 - exp(-12.0 * delta))
	katana.position = _kpos + sway3 + bob3 + CLIMB_REACH_K[0] * _reach + CLIMB_PRESS_K[0] * _press
	katana.rotation = _krot + Vector3(_sway.y, _sway.x, 0) * 0.6 + CLIMB_REACH_K[1] * _reach + CLIMB_PRESS_K[1] * _press
	_glow = maxf(0.0, _glow - delta * 4.0)
	blade_edge_mat.set_shader_parameter("energy", 2.4 + _glow * 4.0)

	# ---- shotgun: kick, then the drum turns and the coils recharge
	if _gun_model_on != DevSettings.shotgun_model:
		_show_shotgun_model()
	var base_pos := shotgun_idle_pos
	var base_rot := shotgun_idle_rot
	if _glory:
		base_pos = _spose[0]
		base_rot = _spose[1]
	_spos_cur = _spos_cur.lerp(base_pos, 1.0 - exp(-(30.0 if _glory else 14.0) * delta))
	_srot_cur = _srot_cur.lerp(base_rot, 1.0 - exp(-(30.0 if _glory else 14.0) * delta))
	var spos := _spos_cur
	var srot := _srot_cur
	if _fire_t >= 0.0:
		_fire_t += delta
		var t := _fire_t
		if t < 0.05:
			var k := t / 0.05
			spos += Vector3(0, 0.02, 0.13) * k
			srot += Vector3(0.45, 0, 0) * k
		elif t < 0.2:
			var k := 1.0 - (t - 0.05) / 0.15
			spos += Vector3(0, 0.02, 0.13) * k
			srot += Vector3(0.45, 0, 0) * k
		if t >= 0.16 and t < 0.52:
			var k := (t - 0.16) / 0.36
			var e := 1.0 + 2.70158 * pow(k - 1.0, 3.0) + 1.70158 * pow(k - 1.0, 2.0)
			drum.rotation.z = lerpf(_drum_from, _drum_to, e)
			srot += Vector3(0.05, 0.0, -0.32) * sin(k * PI)
			spos += Vector3(-0.02, 0.03, 0.0) * sin(k * PI)
			_charge = k
		if t >= 0.16 and not _pump_sound_done:
			_pump_sound_done = true
			if _cells > 0:
				Sfx.play("recharge", -5.0)
		if t >= 0.55:
			_fire_t = -1.0
			drum.rotation.z = _drum_to
			_charge = 1.0
	shotgun.position = spos + sway3 * 0.8 + bob3 * 1.1 + CLIMB_REACH_S[0] * _reach + CLIMB_PRESS_S[0] * _press
	shotgun.rotation = srot + Vector3(_sway.y, _sway.x, 0) * 0.5 + CLIMB_REACH_S[1] * _reach + CLIMB_PRESS_S[1] * _press
	# coils: flare on the blast, sit dim while recharging, hum when ready;
	# with no cells left they sputter
	var live := _cells > 0
	var hum := 0.15 * sin(Time.get_ticks_msec() * 0.012)
	var coil_e := 0.6 + 2.6 * _charge + hum
	if _flash_t > 0.0:
		coil_e = 7.0
	if not live:
		coil_e = 0.35 if _rng.randf() > 0.05 else 2.0
	coil_mat.set_shader_parameter("energy", coil_e)
	core_mat.set_shader_parameter("energy", coil_e * 1.15)
	tip_mat.set_shader_parameter("energy", 1.2 + 2.6 * _charge if live else 0.6)
	drum_cell_mat.set_shader_parameter("energy", 0.8 + 2.0 * _charge if live else 0.4)
	# idle crackle between prongs every now and then
	_idle_t -= delta
	if _idle_t <= 0.0 and live and _charge >= 1.0:
		_idle_t = _rng.randf_range(0.25, 1.1)
		_idle_life = 0.06
		_draw_idle_arc()
	if _idle_life > 0.0:
		_idle_life -= delta
		if _idle_life <= 0.0:
			_idle_im.clear_surfaces()
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			flash.visible = false
