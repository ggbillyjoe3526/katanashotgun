class_name ShaderWarmup
extends Node
## Compiles every combat shader at load (spec §14): the first shotgun blast,
## kill or explosion would otherwise stall a frame while the GPU driver
## compiles its shader. For a few frames one of each pooled effect, enemy
## and bolt is drawn, tiny, just in front of the camera, then everything is
## put back exactly as it was. Nothing is visible to the player.

const FRAMES := 3
const DIST := 2.0
const TINY := 0.001

var _saved: Array = [] # [node, transform, visible]
var _markers: Array[Node3D] = []
var _frame := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cam := get_viewport().get_camera_3d()
	if cam == null or DisplayServer.get_name() == "headless":
		queue_free()
		return
	var at := cam.global_position - cam.global_basis.z * DIST
	var nodes: Array[Node3D] = []
	nodes.append_array(Game.fx.warmup_nodes())
	nodes.append_array(Game.gore.warmup_nodes())
	nodes.append_array(Game.main.director.warmup_nodes())
	for n in nodes:
		_saved.append([n, n.global_transform, n.visible])
		n.global_transform = Transform3D(Basis.from_scale(Vector3.ONE * TINY), at)
		n.visible = true
		var e := n as Enemy
		if e and e.marker:
			e.marker.visible = true
			_markers.append(e.marker)
	Game.fx.warmup_arc(at, at + cam.global_basis.x * TINY)
	Game.gore.warmup_at(at)


func _process(_delta: float) -> void:
	_frame += 1
	if _frame < FRAMES:
		return
	for s in _saved:
		var n: Node3D = s[0]
		if is_instance_valid(n):
			n.global_transform = s[1]
			n.visible = s[2]
	for m in _markers:
		if is_instance_valid(m):
			m.visible = false
	Game.gore.warmup_done()
	queue_free()
