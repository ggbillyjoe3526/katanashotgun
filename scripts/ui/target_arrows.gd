class_name TargetArrows
extends Control
## Points the way to foes the player can't find (spec §9.7). When a wave is
## down to its last few foes, each one off screen gets a small arrow at the
## screen's edge pointing toward it, and each one far away on screen a small
## chevron over its head. The boss gets an arrow whenever it is off screen.
## Presentation only: no RNG, and nothing is allocated per frame.

const LAST_FEW := 3 # foes left (none still waiting to spawn) before markers show
const EDGE := 16.0 # arrows sit this far in from the screen's edge
const NEAR := 14.0 # metres: a foe on screen and this close needs no chevron
const MAX_MARKS := 4
const FADE_IN := 0.25 # seconds a new set of markers takes to appear
const FOE := Color(1.0, 0.55, 0.15)
const INK := Color(0.02, 0.0, 0.05, 0.85)

var _pos := PackedVector2Array() # per marker: its spot on screen
var _dir := PackedVector2Array() # where an arrow points (zero for a chevron)
var _big := PackedByteArray() # 1 for the boss
var _n := 0
var _alpha := 0.0
var _tri := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pos.resize(MAX_MARKS)
	_dir.resize(MAX_MARKS)
	_big.resize(MAX_MARKS)


## Called by the HUD each frame of play with the UI size (480x270).
func refresh(vs: Vector2, delta: float) -> void:
	_n = 0
	var main = Game.main
	var cam := get_viewport().get_camera_3d()
	if main != null and cam != null and Game.state == "playing" and not Game.player.dead:
		var d: WaveDirector = main.director
		if stragglers(d):
			for e in Game.enemy_list:
				if is_instance_valid(e) and not e.dead:
					_mark(cam, e, vs)
		elif d.phase == "boss" and is_instance_valid(main.boss) and not main.boss.dead:
			_mark(cam, main.boss, vs)
	_alpha = move_toward(_alpha, 1.0 if _n > 0 else 0.0, delta / FADE_IN)
	queue_redraw()


## Whether the wave is down to its last few foes: nobody left waiting to spawn
## and LAST_FEW or fewer standing.
static func stragglers(d: WaveDirector) -> bool:
	return d.phase == "spawning" and d.queue.is_empty() and Game.enemy_list.size() <= LAST_FEW


func _mark(cam: Camera3D, e: Enemy, vs: Vector2) -> void:
	if _n >= MAX_MARKS:
		return
	var world := e.global_position + Vector3(0, e.height + 0.5, 0)
	var c := (vs * 0.5).floor()
	var inner := Rect2(Vector2(EDGE, EDGE), vs - Vector2(EDGE, EDGE) * 2.0)
	var d := Vector2.ZERO
	if not cam.is_position_behind(world):
		var sp := cam.unproject_position(world) / get_viewport().get_visible_rect().size * vs
		if inner.has_point(sp):
			# on screen: the boss is never lost there; a near foe is plain to see
			if e.is_boss or cam.global_position.distance_to(world) < NEAR:
				return
			_put(sp.round(), Vector2.ZERO, false)
			return
		d = sp - c
	else:
		# behind the camera: the bottom edge means behind you, toward the
		# side it stands on
		var local := cam.global_transform.affine_inverse() * world
		d = Vector2(local.x, maxf(local.z, 0.01))
	d = d.normalized()
	# slide out from the centre along d until it meets the inner rectangle
	var half := c - inner.position
	var t := minf(half.x / maxf(absf(d.x), 0.0001), half.y / maxf(absf(d.y), 0.0001))
	_put((c + d * t).round(), d, e.is_boss)


func _put(p: Vector2, d: Vector2, big: bool) -> void:
	_pos[_n] = p
	_dir[_n] = d
	_big[_n] = 1 if big else 0
	_n += 1


func _draw() -> void:
	if _alpha <= 0.0:
		return
	var foe := Color(FOE, _alpha)
	var boss := Color(Game.palette.neon_a, _alpha)
	var ink := Color(INK, INK.a * _alpha)
	for i in _n:
		var p := _pos[i]
		var d := _dir[i]
		if d == Vector2.ZERO:
			# a chevron over a far foe's head, pointing down at it
			_triangle(p + Vector2(0, 2), Vector2(0, 1), 5.0, 6.0, ink, foe)
			continue
		var big := _big[i] == 1
		_triangle(p, d, 8.0 if big else 6.0, 10.0 if big else 7.0, ink, boss if big else foe)


## A filled triangle with its tip at `tip` pointing along `d`, on a dark rim.
func _triangle(tip: Vector2, d: Vector2, half_w: float, length: float, ink: Color, col: Color) -> void:
	var side := Vector2(-d.y, d.x)
	var back := tip - d * length
	_tri[0] = tip + d * 1.5
	_tri[1] = back + side * (half_w + 1.5) - d
	_tri[2] = back - side * (half_w + 1.5) - d
	draw_colored_polygon(_tri, ink)
	_tri[0] = tip
	_tri[1] = back + side * half_w
	_tri[2] = back - side * half_w
	draw_colored_polygon(_tri, col)
