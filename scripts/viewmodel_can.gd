class_name ViewmodelCan
extends Node3D
## The soda can in the first-person hands (spec §19.1 #11). On a drink the
## shotgun drops to the hip, the right hand brings the can up, the katana's
## left-to-right cut takes the top off (fizz, a lid spinning away), the
## player downs it in one go with the head tipped back, tosses it, and the
## shotgun comes back. Lives under the Viewmodel, in its space; drawn and
## timed on game time like the rest of the hands. Its dice are presentation
## only.

const DROPS := 10
const HOLD_POS := Vector3(0.06, -0.32, -0.5) # held up in front, top level with the cut
const LOW_POS := Vector3(0.34, -0.85, -0.42) # where it comes up from
const SIP_POS := Vector3(0.04, -0.21, -0.42) # at the mouth
const TOSS_POS := Vector3(0.55, -0.9, -0.3)
const SIP_TILT := 1.95 # radians the can tips toward the face
const SLASH_LEAD := 0.09 # the katana starts its cut this long before the top comes off

var vm: Viewmodel
var holster := 0.0 # 0..1: how far the shotgun is down at the hip
var tilt := 0.0 # 0..1: how far the head is tipped back to drink
var _t := -1.0
var _len := 0.9
var _cut_at := 0.32
var _cut := false
var _slashed := false
var _body: Node3D
var _body_mat: ShaderMaterial
var _band_mat: ShaderMaterial
var _drop_mat: ShaderMaterial
var _lid: Node3D
var _lid_v := Vector3.ZERO
var _drops: Array = [] # {n, v, t}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	var p := {"snap": 0.35, "fog_amount": 0.0}
	_body_mat = Psx.lit(Color.WHITE, TexGen.get_tex("panel"), false, 1.0, p.merged({"emission_strength": 0.35}))
	_band_mat = Psx.unlit(Color.WHITE, 1.3, null, p)
	_drop_mat = Psx.unlit(Color.WHITE, 2.2, null, p)
	var rim := Psx.lit(Color(0.75, 0.78, 0.85), TexGen.get_tex("panel"), false, 1.0, p)
	_body = Node3D.new()
	add_child(_body)
	_body.add_child(_cylinder(0.065, 0.22, _body_mat, 0.0))
	_body.add_child(_cylinder(0.067, 0.07, _band_mat, 0.0))
	_body.add_child(Psx.box(Vector3(0.1, 0.012, 0.1), rim, Vector3(0, -0.114, 0)))
	# the top: the katana cuts it off and it spins away
	_lid = Psx.box(Vector3(0.1, 0.014, 0.1), rim, Vector3(0, 0.114, 0))
	_body.add_child(_lid)
	for i in DROPS:
		var d := Psx.box(Vector3(0.018, 0.018, 0.018), _drop_mat)
		d.visible = false
		add_child(d)
		_drops.append({"n": d, "v": Vector3.ZERO, "t": 9.0})
	for g in find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false


func _cylinder(r: float, h: float, mat: Material, y: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 8
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat
	mi.position.y = y
	return mi


## Starts the drink: `length` seconds in all, the top coming off at `cut_at`.
func drink(color: Color, length: float, cut_at: float) -> void:
	_t = 0.0
	_len = length
	_cut_at = cut_at
	_cut = false
	_slashed = false
	_body_mat.set_shader_parameter("albedo_color", color.darkened(0.15))
	_body_mat.set_shader_parameter("emission_color", color)
	_band_mat.set_shader_parameter("albedo_color", color.lerp(Color.WHITE, 0.35))
	_drop_mat.set_shader_parameter("albedo_color", color.lerp(Color.WHITE, 0.5))
	_lid.position = Vector3(0, 0.114, 0)
	_lid.rotation = Vector3.ZERO
	_lid.reparent(_body, false)
	visible = true


func drinking() -> bool:
	return _t >= 0.0


func _process(delta: float) -> void:
	_update_drops(delta)
	if _t < 0.0:
		holster = move_toward(holster, 0.0, delta * 6.0)
		tilt = move_toward(tilt, 0.0, delta * 6.0)
		return
	_t += delta
	var t := _t
	var sip_from := _cut_at + 0.05
	var sip_to := _len - 0.2
	# the shotgun goes down first and comes back up at the end
	holster = smoothstep(0.0, 0.14, t) * (1.0 - smoothstep(_len - 0.22, _len, t))
	tilt = smoothstep(sip_from, sip_from + 0.12, t) * (1.0 - smoothstep(sip_to - 0.04, sip_to + 0.1, t))
	var pos := LOW_POS
	var rot := Vector3(0.0, 0.0, -0.4)
	if t < _cut_at:
		var k := Juice.ease_out(clampf(t / maxf(0.01, _cut_at - 0.08), 0.0, 1.0))
		pos = LOW_POS.lerp(HOLD_POS, k)
		rot = rot.lerp(Vector3(0.1, 0.0, 0.0), k)
	elif t < sip_to:
		var k := smoothstep(0.0, 1.0, clampf((t - sip_from) / 0.14, 0.0, 1.0))
		pos = HOLD_POS.lerp(SIP_POS, k)
		rot = Vector3(0.1 + (SIP_TILT - 0.1) * k, 0.0, 0.15 * k)
		# the gulps: a small shake as each one goes down
		pos.y += sin(t * 38.0) * 0.006 * k
	else:
		var k := clampf((t - sip_to) / 0.16, 0.0, 1.0)
		pos = SIP_POS.lerp(TOSS_POS, k * k)
		rot = Vector3(SIP_TILT + 2.0 * k, 0.6 * k, 0.15 + 1.5 * k)
	_body.position = pos
	_body.rotation = rot
	if not _slashed and t >= _cut_at - SLASH_LEAD and vm:
		_slashed = true
		vm.slash(0)
	if not _cut and t >= _cut_at:
		_cut = true
		_pop_top()
	if t >= sip_from + 0.12 and t < sip_to and fmod(t, 0.12) < delta:
		Sfx.play("can_gulp", -7.0, _rng.randf_range(0.9, 1.1), 0.0)
	if t >= _len:
		_t = -1.0
		visible = false


## The cut: the lid flies off spinning and the fizz sprays up and away.
func _pop_top() -> void:
	var top := _lid.global_transform
	_lid.reparent(self, false)
	_lid.global_transform = top
	_lid_v = Vector3(-0.25, 1.3, -0.2)
	var at := _body.position + _body.basis.y * 0.12
	for d in _drops:
		var n: MeshInstance3D = d.n
		n.position = at
		n.visible = true
		d.v = Vector3(_rng.randf_range(-0.5, 0.6), _rng.randf_range(0.6, 1.5), _rng.randf_range(-0.4, 0.2))
		d.t = 0.0


func _update_drops(delta: float) -> void:
	if _lid.get_parent() == self:
		_lid_v.y -= 5.0 * delta
		_lid.position += _lid_v * delta
		_lid.rotation += Vector3(14.0, 3.0, 9.0) * delta
		if _lid.position.y < -1.2:
			_lid.reparent(_body, false)
			_lid.visible = true
	for d in _drops:
		if d.t > 0.6:
			continue
		d.t += delta
		var n: MeshInstance3D = d.n
		d.v.y -= 4.0 * delta
		n.position += d.v * delta
		if d.t > 0.6:
			n.visible = false
