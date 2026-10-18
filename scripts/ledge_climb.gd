class_name LedgeClimb
extends RefCounted
## Ledge climbing (spec §3.1): when a jump falls short of a ledge the player
## is pushing into, they grab it and pull themselves up. Only ledges the hands
## can believably reach count: the top must be no higher than REACH above the
## feet (arms overhead), and the climb path must be clear for the whole body.
## Walls taller than that are never climbable, however hard you push.

const REACH := 2.0 # highest ledge top above the feet the hands can grab
const MIN_RISE := 0.3 # anything lower is just landed on
const PROBE := 0.35 # how far past the body the ledge is looked for
const CLEAR_MARGIN := 0.15 # a jump that clears the ledge by this much needs no climb
const FACING := 0.3 # look within ~72 degrees of the wall to grab it
const LIFT := 0.05 # the body ends this far above the ledge, then settles

static var _q: PhysicsRayQueryParameters3D # reused, so probing allocates no query


## The highest point the feet reach if nothing else changes (metres above now).
static func apex_gain(vy: float, gravity: float) -> float:
	return vy * vy / (2.0 * gravity) if vy > 0.0 else 0.0


## Looks for a grabbable ledge in front of `body` (a CharacterBody3D whose
## origin is at its feet), moving along `dir` and looking along `look`.
## Returns {} when there's nothing to climb, else {"rise": metres up,
## "forward": the horizontal move onto the ledge, "ledge_y": the top}.
static func find(body: CharacterBody3D, dir: Vector3, look: Vector3, radius: float, vy: float, gravity: float) -> Dictionary:
	dir.y = 0.0
	look.y = 0.0
	if dir.length() < 0.3:
		return {}
	dir = dir.normalized()
	var space := body.get_world_3d().direct_space_state
	var feet := body.global_position
	# 1. the ledge top: straight down just past the front of the body
	var probe := feet + dir * (radius + PROBE)
	var q := _ray(probe + Vector3.UP * (REACH + 0.05), probe + Vector3.UP * (MIN_RISE - 0.05), body.collision_mask)
	var top := space.intersect_ray(q)
	if top.is_empty() or (top.normal as Vector3).y < 0.7:
		return {}
	var ledge_y: float = (top.position as Vector3).y
	var rise := ledge_y - feet.y
	if rise < MIN_RISE or rise > REACH:
		return {}
	# 2. a face just under that top that we're moving into and looking at
	var face_from := Vector3(feet.x, ledge_y - 0.1, feet.z)
	q = _ray(face_from, face_from + dir * (radius + PROBE + 0.1), body.collision_mask)
	var face := space.intersect_ray(q)
	if face.is_empty():
		return {}
	var n: Vector3 = face.normal
	if absf(n.y) > 0.3 or n.dot(dir) > -0.5:
		return {}
	if look.length() > 0.1 and -n.dot(look.normalized()) < FACING:
		return {}
	# 3. a jump that clears it cleanly lands on it; no climb needed
	if feet.y + apex_gain(vy, gravity) > ledge_y + CLEAR_MARGIN:
		return {}
	# 4. room for the whole body: straight up, then over the edge
	var face_d := Vector2((face.position as Vector3).x - feet.x, (face.position as Vector3).z - feet.z).length()
	var up := Vector3(0, rise + LIFT, 0)
	var forward := dir * (face_d + radius + 0.15)
	if body.test_move(body.global_transform, up):
		return {}
	if body.test_move(body.global_transform.translated(up), forward):
		return {}
	return {"rise": rise, "forward": forward, "ledge_y": ledge_y}


static func _ray(from: Vector3, to: Vector3, mask: int) -> PhysicsRayQueryParameters3D:
	if _q == null:
		_q = PhysicsRayQueryParameters3D.new()
	_q.from = from
	_q.to = to
	_q.collision_mask = mask
	return _q
