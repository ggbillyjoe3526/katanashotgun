class_name BossHazard
extends Node3D
## A telegraphed floor hazard from a boss's area move (spec §5.6): a glowing
## ring or line pulses on the floor for `delay` seconds, then it goes live.
##   zone  a circle (Kurokage's smoke ring, Tetsugumo's EMP field). It hits
##         once when it goes live, or ticks while live for `live` seconds.
##   line  a straight strip (Shuten's fissures). It hits once when it erupts.
## Jumping clears a hazard whose `jumpable` is set. Runs on scaled time.

const PULSE_SLOW := 8.0
const PULSE_FAST := 26.0
const JUMP_CLEAR := 0.9 # metres above the hazard's floor that clear it
const TICK := 0.6 # seconds between hits while a zone is live

var shape := "zone"
var radius := 2.6
var length := 14.0
var width := 1.6
var dir := Vector3.FORWARD
var delay := 1.0
var live := 0.0 # seconds it stays live after the delay (0 = a single hit)
var dmg := 10.0
var color := Color(1, 0.3, 0.2)
var jumpable := true
var sound := "zap"

var _t := 0.0
var _tick_t := 0.0
var _mesh: MeshInstance3D
var _mat: ShaderMaterial
var _fired := false


static func zone(at: Vector3, r: float, wait: float, damage: float, col: Color, live_time := 0.0) -> BossHazard:
	var h := BossHazard.new()
	h.shape = "zone"
	h.radius = r
	h.delay = wait
	h.dmg = damage
	h.color = col
	h.live = live_time
	h.position = at
	return h


static func line(from: Vector3, towards: Vector3, len_m: float, wide: float, wait: float, damage: float, col: Color) -> BossHazard:
	var h := BossHazard.new()
	h.shape = "line"
	h.dir = Vector3(towards.x, 0, towards.z).normalized()
	h.length = len_m
	h.width = wide
	h.delay = wait
	h.dmg = damage
	h.color = col
	h.position = from
	return h


func _ready() -> void:
	position.y = Game.arena.floor_height_at(position.x, position.z, position.y + 1.0)
	_mesh = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	if shape == "zone":
		pm.size = Vector2(radius * 2.0, radius * 2.0)
		_mat = Psx.fx(Color(color.r, color.g, color.b, 1.0), TexGen.get_tex("ring"), true, false, false, 1.5)
	else:
		pm.size = Vector2(width, length)
		_mat = Psx.fx(Color(color.r, color.g, color.b, 0.85), null, true, false, false, 1.5)
		_mesh.position = dir * length * 0.5
		_mesh.rotation.y = atan2(dir.x, dir.z)
	_mesh.mesh = pm
	_mesh.material_override = _mat
	_mesh.position.y = 0.07
	add_child(_mesh)


func _physics_process(delta: float) -> void:
	_t += delta
	var left := delay - _t
	if left > 0.0:
		# pulses faster as it gets close, like the missile rings
		var k := 1.0 - clampf(left / maxf(delay, 0.01), 0.0, 1.0)
		_mat.set_shader_parameter("intensity", 1.0 + 1.5 * absf(sin(_t * lerpf(PULSE_SLOW, PULSE_FAST, k))))
		if shape == "zone" and Engine.get_physics_frames() % 5 == 0:
			_crackle(1)
		return
	if not _fired:
		_fired = true
		_erupt()
		_hit_player()
		_tick_t = TICK
	if _t > delay + live:
		queue_free()
		return
	_mat.set_shader_parameter("intensity", 3.0)
	_crackle(1)
	_tick_t -= delta
	if _tick_t <= 0.0:
		_tick_t = TICK
		_hit_player()


func _erupt() -> void:
	Sfx.play_at(sound, global_position, 2.0, 0.7)
	if shape == "zone":
		_crackle(6)
		Game.gore.sparks(global_position + Vector3(0, 0.2, 0), Vector3.UP, 18, color * 1.8)
	else:
		for i in 6:
			var p := global_position + dir * length * (i + 0.5) / 6.0
			Game.gore.sparks(p + Vector3(0, 0.2, 0), Vector3.UP, 6, color * 1.8)
			Game.gore.embers(p, 2)
		Game.gore.scorch(global_position + dir * length * 0.5, width * 1.5)


## Small arcs crawling over a zone so it reads as live wire, not paint.
func _crackle(n: int) -> void:
	if shape != "zone":
		return
	for i in n:
		var a := float(Engine.get_physics_frames() * 37 + i * 101) * 0.61
		var r := radius * (0.3 + 0.6 * fmod(a * 0.17, 1.0))
		var p := global_position + Vector3(cos(a) * r, 0.15, sin(a) * r)
		Game.fx.arc(p, p + Vector3(cos(a + 1.7), 0.6, sin(a + 1.7)) * 0.9, 0.08, 0.02, 0.8, 0)


func _hit_player() -> void:
	var p := Game.player
	if p == null or p.dead:
		return
	var rel := p.global_position - global_position
	if covers(rel):
		p.take_damage(dmg, global_position)
		p.knockback(Vector3(rel.x, 0, rel.z).normalized() * 6.0 + Vector3.UP * 5.0)


## Whether a player standing `rel` from the hazard's origin is caught by it.
func covers(rel: Vector3) -> bool:
	if (jumpable and rel.y > JUMP_CLEAR) or absf(rel.y) > 2.2:
		return false
	if shape == "zone":
		return Vector2(rel.x, rel.z).length() < radius + 0.3
	var along := rel.x * dir.x + rel.z * dir.z
	var side := absf(rel.x * dir.z - rel.z * dir.x)
	return along > -0.3 and along < length + 0.3 and side < width * 0.5 + 0.35
