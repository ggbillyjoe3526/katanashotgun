class_name Fx
extends Node3D
## Non-gore effects: damage numbers, lightning arcs, impact flashes, spawn
## beams, slash trails, shockwaves and health orbs.

var _numbers: Array = []
var _temps: Array = [] # {n, t, life, kind}
var _orbs: Array = []
var _waves: Array = []
var _strikes: Array = []
var _tracer_mat: ShaderMaterial
var _arc_mat: ShaderMaterial
var _zap_flash_mat: ShaderMaterial
var _orb_mesh: SphereMesh
var _orb_mat: ShaderMaterial
var _orb_halo: ShaderMaterial
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	Ui.init()
	_tracer_mat = Psx.fx(Color(1.0, 0.85, 0.5, 0.9), null, true, false, false, 1.6)
	_arc_mat = Psx.fx(Color(1, 1, 1, 1), null, true, false, false, 2.2)
	_arc_mat.set_shader_parameter("use_vertex_color", true)
	_zap_flash_mat = Psx.fx(Color(0.5, 0.8, 1.0, 1.0), TexGen.get_tex("star"), true, true, false, 2.0)
	_orb_mesh = SphereMesh.new()
	_orb_mesh.radius = 0.16
	_orb_mesh.height = 0.32
	_orb_mesh.radial_segments = 4
	_orb_mesh.rings = 2
	_orb_mat = Psx.unlit(Color(0.4, 1.0, 0.55), 2.2, null, {"fog_amount": 0.3})
	_orb_halo = Psx.fx(Color(0.3, 1.0, 0.5, 0.7), TexGen.get_tex("glow"), true, true, false, 1.0)


## Elliptical ring sector in the XY plane. UV.x runs 0..1 along the arc and
## vertex alpha fades in toward the leading edge, so it reads as a sweep.
static func arc_mesh(rx: float, ry: float, thick: float, a0: float, a1: float, seg := 24) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts_o := []
	var pts_i := []
	for i in seg + 1:
		var t := float(i) / seg
		var a := lerpf(a0, a1, t)
		var w := thick * sin(t * PI) * (0.4 + 0.6 * t)
		pts_o.append([Vector3(cos(a) * rx, sin(a) * ry, 0), t])
		pts_i.append([Vector3(cos(a) * (rx - w), sin(a) * (ry - w * 0.6), 0), t])
	for i in seg:
		var quad := [pts_o[i], pts_o[i + 1], pts_i[i + 1], pts_o[i], pts_i[i + 1], pts_i[i]]
		for j in quad.size():
			var v: Array = quad[j]
			var t: float = v[1]
			var inner := j >= 4 or j == 2
			var c := Color(1, 1, 1, pow(t, 1.4)) if not inner else Color(0.5, 0.9, 1.0, pow(t, 1.4) * 0.6)
			st.set_color(c)
			st.set_uv(Vector2(t, 1.0 if inner else 0.0))
			st.add_vertex(v[0])
	return st.commit()


func damage_number(pos: Vector3, amount: float, crit := false, armored := false) -> void:
	var l := Label3D.new()
	l.font = Ui.font_big
	# big enough to read at a glance (spec §9.9); crits and big hits larger
	l.font_size = 40 if crit else 24
	if amount >= 100.0:
		l.font_size = 40
	l.pixel_size = 0.0034
	l.fixed_size = true
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	l.outline_size = 4
	l.outline_modulate = Color(0, 0, 0, 1)
	l.render_priority = 10
	l.outline_render_priority = 9
	l.text = str(int(round(amount)))
	if armored:
		l.modulate = Color(0.6, 0.65, 0.75)
	elif crit:
		l.modulate = Color(1.0, 0.9, 0.25)
	elif amount >= 100.0:
		l.modulate = Color(1.0, 0.35, 0.3)
	else:
		l.modulate = Color(1, 1, 1)
	l.position = pos + Vector3(_rng.randf_range(-0.4, 0.4), _rng.randf_range(0, 0.3), _rng.randf_range(-0.4, 0.4))
	add_child(l)
	_numbers.append({"n": l, "t": 0.0, "v": Vector3(_rng.randf_range(-0.6, 0.6), 2.4, _rng.randf_range(-0.6, 0.6))})
	while _numbers.size() > 40:
		var old: Dictionary = _numbers.pop_front()
		old.n.queue_free()


func tracer(a: Vector3, b: Vector3) -> void:
	var len := a.distance_to(b)
	if len < 0.5:
		return
	var mi := Psx.box(Vector3(0.025, 0.025, len), _tracer_mat)
	add_child(mi)
	mi.look_at_from_position((a + b) * 0.5, b, Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT)
	_temps.append({"n": mi, "t": 0.0, "life": 0.06, "kind": "tracer"})


func impact(pos: Vector3, normal: Vector3, electric := false) -> void:
	if electric:
		Game.gore.sparks(pos + normal * 0.05, normal, 4, Color(0.6, 1.5, 2.2))
		var qe := Psx.quad(Vector2(0.7, 0.7), _zap_flash_mat, pos + normal * 0.08)
		qe.rotation.z = _rng.randf() * TAU
		add_child(qe)
		_temps.append({"n": qe, "t": 0.0, "life": 0.06, "kind": "flash"})
		return
	Game.gore.sparks(pos + normal * 0.05, normal, 3)
	var q := Psx.quad(Vector2(0.5, 0.5), Psx.fx(Color(1.0, 0.8, 0.5, 1.0), TexGen.get_tex("star"), true, true, false, 1.5), pos + normal * 0.08)
	add_child(q)
	_temps.append({"n": q, "t": 0.0, "life": 0.05, "kind": "flash"})


## A jagged lightning arc from a to b that re-forks every couple of frames
## while it lives (the arc shotgun's "pellets", shocked bodies, sparks).
func arc(a: Vector3, b: Vector3, life := 0.09, width := 0.03, jag := 1.0, branches := 1) -> void:
	if a.distance_to(b) < 0.05:
		return
	var mi := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	mi.mesh = im
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var tp := {"n": mi, "t": 0.0, "life": life, "kind": "arc", "a": a, "b": b, "w": width, "jag": jag, "br": branches, "re": 0.0, "im": im}
	_build_arc(tp, 1.0)
	_temps.append(tp)


static func jagged(a: Vector3, b: Vector3, jag: float, rng: RandomNumberGenerator) -> PackedVector3Array:
	var d := b - a
	var L := d.length()
	var n := clampi(int(L / 0.45) + 3, 4, 20)
	var dn := d / L
	var s1 := dn.cross(Vector3.UP if absf(dn.y) < 0.95 else Vector3.RIGHT).normalized()
	var s2 := dn.cross(s1)
	var amp := jag * clampf(L * 0.07, 0.03, 0.7)
	var pts := PackedVector3Array()
	for i in n + 1:
		var t := float(i) / n
		var p := a + d * t
		if i > 0 and i < n:
			var env := sqrt(sin(t * PI))
			p += (s1 * rng.randf_range(-1, 1) + s2 * rng.randf_range(-1, 1)) * amp * env
		pts.append(p)
	return pts


## Adds a camera-facing ribbon through `pts` to an ImmediateMesh.
static func ribbon(im: ImmediateMesh, pts: PackedVector3Array, w: float, col: Color, eye: Vector3) -> void:
	for i in pts.size() - 1:
		var p0 := pts[i]
		var p1 := pts[i + 1]
		var side := (p1 - p0).cross(eye - p0).normalized() * w * 0.5
		im.surface_set_color(col)
		im.surface_add_vertex(p0 - side)
		im.surface_add_vertex(p0 + side)
		im.surface_add_vertex(p1 + side)
		im.surface_add_vertex(p0 - side)
		im.surface_add_vertex(p1 + side)
		im.surface_add_vertex(p1 - side)


func _build_arc(tp: Dictionary, k: float) -> void:
	var im: ImmediateMesh = tp.im
	im.clear_surfaces()
	var cam := get_viewport().get_camera_3d()
	var eye := cam.global_position if cam else Vector3.ZERO
	var pts := jagged(tp.a, tp.b, tp.jag, _rng)
	var w: float = tp.w * (0.4 + 0.6 * k)
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _arc_mat)
	ribbon(im, pts, w * 4.0, Color(0.25, 0.45, 1.0, 0.3), eye)
	ribbon(im, pts, w, Color(0.8, 0.95, 1.0, 1.0), eye)
	for bi in tp.br:
		if pts.size() < 4:
			break
		var at: Vector3 = pts[_rng.randi_range(1, pts.size() - 3)]
		var L: float = tp.a.distance_to(tp.b)
		var tip: Vector3 = at + ((tp.b - tp.a).normalized() + Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1))).normalized() * L * _rng.randf_range(0.12, 0.3)
		var bp := jagged(at, tip, tp.jag * 0.8, _rng)
		ribbon(im, bp, w * 2.5, Color(0.25, 0.45, 1.0, 0.25), eye)
		ribbon(im, bp, w * 0.6, Color(0.7, 0.9, 1.0, 0.9), eye)
	im.surface_end()


func spawn_beam(pos: Vector3, color: Color, h := 1.8) -> void:
	var mat := Psx.fx(Color(color.r, color.g, color.b, 0.9), TexGen.get_tex("glow"), true, false, false, 2.0)
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	for k in 2:
		var q := Psx.quad(Vector2(1.6 * h / 1.8, 14.0), mat, Vector3(0, 7.0, 0))
		q.rotation.y = k * PI * 0.5
		root.add_child(q)
	var ring := Psx.quad(Vector2(3.0, 3.0), Psx.fx(Color(color.r, color.g, color.b, 1.0), TexGen.get_tex("ring"), true, false, false, 2.0), Vector3(0, 0.05, 0))
	ring.rotation.x = -PI * 0.5
	root.add_child(ring)
	_temps.append({"n": root, "t": 0.0, "life": 0.7, "kind": "beam", "m": mat})


func shockwave(pos: Vector3, max_r: float, spd: float, dmg: float) -> void:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.85
	tm.outer_radius = 1.0
	tm.rings = 24
	tm.ring_segments = 4
	mi.mesh = tm
	var mat := Psx.fx(Color(1.0, 0.45, 0.15, 1.0), null, true, false, false, 2.5)
	mi.material_override = mat
	mi.position = pos + Vector3(0, 0.25, 0)
	mi.scale = Vector3(0.1, 1.0, 0.1)
	add_child(mi)
	_waves.append({"n": mi, "m": mat, "r": 0.5, "max": max_r, "spd": spd, "dmg": dmg, "hit": false, "y": pos.y})


func health_orbs(pos: Vector3, count: int) -> void:
	for i in count:
		var root := Node3D.new()
		var mi := MeshInstance3D.new()
		mi.mesh = _orb_mesh
		mi.material_override = _orb_mat
		root.add_child(mi)
		root.add_child(Psx.quad(Vector2(0.9, 0.9), _orb_halo))
		root.position = pos
		add_child(root)
		var v := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(1.5, 3.0), _rng.randf_range(-1, 1)) * 3.0
		_orbs.append({"n": root, "v": v, "t": 0.0})


func slash_trail(parent: Node3D, variant: int, color := Color(0.8, 1.0, 1.0)) -> void:
	var root := Node3D.new()
	parent.add_child(root)
	var mi := MeshInstance3D.new()
	var mat := Psx.fx(color, null, true, false, true, 2.0)
	mat.set_shader_parameter("use_vertex_color", true)
	mat.set_shader_parameter("reveal", 0.0)
	mi.material_override = mat
	mi.mesh = arc_mesh(1.25, 0.6, 0.28, -2.75, -0.4)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	root.position = Vector3(0, 0.15, -1.05)
	match variant:
		0:
			root.rotation.z = 0.12
		1:
			root.scale.x = -1.0
			root.rotation.z = -0.18
		2:
			root.rotation.z = 1.15
			root.position = Vector3(0.05, 0.05, -1.05)
	_temps.append({"n": root, "t": 0.0, "life": 0.17, "kind": "trail", "m": mat})


## Glowing line on the floor showing where a dash will go. Returns the node so
## the caller can steer or remove it.
func telegraph_line(from: Vector3, dir: Vector3, length: float, duration: float, color: Color) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	root.global_position = from + Vector3(0, 0.06, 0)
	root.look_at(root.global_position + Vector3(dir.x, 0, dir.z).normalized(), Vector3.UP)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1.1, length)
	mi.mesh = pm
	var mat := Psx.fx(Color(color.r, color.g, color.b, 0.85), null, true, false, false, 1.6)
	mi.material_override = mat
	mi.position = Vector3(0, 0, -length * 0.5)
	root.add_child(mi)
	_temps.append({"n": root, "t": 0.0, "life": duration + 0.6, "kind": "line", "m": mat})
	return root


func smoke(pos: Vector3, size := 1.5) -> void:
	for k in 5:
		var mat := Psx.fx(Color(0.12, 0.06, 0.18, 0.85), TexGen.get_tex("glow"), false, true)
		var q := Psx.quad(Vector2.ONE, mat, pos + Vector3(_rng.randf_range(-0.5, 0.5), _rng.randf_range(-0.6, 0.6), _rng.randf_range(-0.5, 0.5)))
		q.scale = Vector3.ONE * size * 0.5
		add_child(q)
		_temps.append({"n": q, "t": 0.0, "life": _rng.randf_range(0.5, 0.8), "kind": "smoke", "m": mat, "s": size * _rng.randf_range(0.9, 1.5)})


## A missile lands on `target` after `delay` seconds; the red ring shows where.
## `style` "lightning" (Raijin's Storm) drops a bolt from the sky instead;
## "grudge" (Onryo's Grudge) just bursts, with nothing falling.
func missile_strike(target: Vector3, delay: float, radius: float, dmg: float, style := "missile") -> void:
	var fh := Game.arena.floor_height_at(target.x, target.z)
	if fh > target.y + 1.0:
		fh = 0.0
	var pos := Vector3(target.x, fh, target.z)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(radius * 2.0, radius * 2.0)
	mi.mesh = pm
	var mat := Psx.fx(Color(1.0, 0.12, 0.2, 1.0), TexGen.get_tex("ring"), true, false, false, 1.5)
	mi.material_override = mat
	mi.position = pos + Vector3(0, 0.07, 0)
	add_child(mi)
	_strikes.append({"n": mi, "m": mat, "t": 0.0, "delay": delay, "pos": pos, "r": radius, "dmg": dmg, "missile": null, "beeped": 0, "style": style})


func explosion(pos: Vector3, dmg: float, hurt := true, radius := 2.6) -> void:
	var c: Color = Game.palette.get("neon_c", Color(1, 0.8, 0.3))
	Game.gore.sparks(pos + Vector3(0, 0.3, 0), Vector3.UP, 26, c * 1.8)
	Game.gore.embers(pos, 6)
	Game.gore.scorch(pos, radius * 1.1)
	var q := Psx.quad(Vector2(radius * 3.0, radius * 3.0), Psx.fx(Color(1.0, 0.7, 0.4, 1.0), TexGen.get_tex("star"), true, true, false, 3.0), pos + Vector3(0, 0.9, 0))
	add_child(q)
	_temps.append({"n": q, "t": 0.0, "life": 0.22, "kind": "boom"})
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = 6.0
	l.omni_range = radius * 4.0
	l.position = pos + Vector3(0, 1.2, 0)
	add_child(l)
	_temps.append({"n": l, "t": 0.0, "life": 0.3, "kind": "light"})
	Sfx.play_at("explosion", pos, 2.0)
	var p := Game.player
	if p:
		p.add_trauma(clampf(1.0 - p.global_position.distance_to(pos) / 20.0, 0.0, 0.6))
	if not hurt:
		return
	if p and not p.dead:
		var d := Vector2(p.global_position.x - pos.x, p.global_position.z - pos.z).length()
		if d < radius + 0.4 and absf(p.global_position.y - pos.y) < 2.2:
			p.take_damage(dmg, pos)
			var out := Vector3(p.global_position.x - pos.x, 0, p.global_position.z - pos.z).normalized()
			p.knockback(out * 7.0 + Vector3.UP * 5.0)
	for e in Game.enemy_list.duplicate():
		if not is_instance_valid(e) or e.dead or e.is_boss:
			continue
		var de: float = Vector2(e.global_position.x - pos.x, e.global_position.z - pos.z).length()
		if de < radius + e.radius:
			var outv: Vector3 = (e.global_position - pos)
			outv.y = 0.0
			e.take_hit(dmg * 2.0, "explode", outv.normalized(), false, 60.0, 8.0)


func _process(delta: float) -> void:
	var i := 0
	while i < _numbers.size():
		var d: Dictionary = _numbers[i]
		d.t += delta
		var n: Label3D = d.n
		n.position += d.v * delta
		d.v.y -= 4.0 * delta
		var pop := 1.0 + maxf(0.0, 0.12 - d.t) * 6.0
		n.scale = Vector3.ONE * pop
		if d.t > 0.55:
			n.modulate.a = clampf(1.0 - (d.t - 0.55) / 0.3, 0.0, 1.0)
			n.outline_modulate.a = n.modulate.a
		if d.t > 0.85:
			n.queue_free()
			_numbers.remove_at(i)
			continue
		i += 1
	i = 0
	while i < _temps.size():
		var tp: Dictionary = _temps[i]
		if not is_instance_valid(tp.n):
			_temps.remove_at(i)
			continue
		tp.t += delta
		var k: float = tp.t / tp.life
		if k >= 1.0:
			tp.n.queue_free()
			_temps.remove_at(i)
			continue
		match tp.kind:
			"trail":
				tp.m.set_shader_parameter("reveal", minf(1.0, k * 3.0))
				tp.m.set_shader_parameter("intensity", 2.0 * (1.0 - k * k))
			"beam":
				tp.m.set_shader_parameter("intensity", 2.0 * (1.0 - k))
				tp.n.scale = Vector3(1.0 - k * 0.8, 1.0, 1.0 - k * 0.8)
			"line":
				tp.m.set_shader_parameter("intensity", 1.2 + 1.2 * absf(sin(tp.t * 22.0)))
			"smoke":
				tp.n.scale = Vector3.ONE * tp.s * (0.5 + k)
				tp.m.set_shader_parameter("color", Color(0.12, 0.06, 0.18, 0.85 * (1.0 - k)))
			"boom":
				tp.n.scale = Vector3.ONE * (0.6 + k * 0.8)
			"light":
				tp.n.light_energy = 6.0 * (1.0 - k)
			"arc":
				tp.re -= delta
				if tp.re <= 0.0:
					tp.re = 0.022
					_build_arc(tp, 1.0 - k)
			"missile":
				pass
		i += 1
	_update_orbs(delta)
	_update_waves(delta)
	_update_strikes(delta)


func _update_orbs(delta: float) -> void:
	var p := Game.player
	var i := 0
	while i < _orbs.size():
		var o: Dictionary = _orbs[i]
		o.t += delta
		var n: Node3D = o.n
		if o.t > 14.0 or not is_instance_valid(n):
			if is_instance_valid(n):
				n.queue_free()
			_orbs.remove_at(i)
			continue
		var target := p.global_position + Vector3(0, 0.9, 0) if p else Vector3.ZERO
		var to := target - n.global_position
		var d := to.length()
		if p and not p.dead and o.t > 0.35 and d < 7.0:
			o.v = o.v.lerp(to.normalized() * 22.0, 1.0 - exp(-8.0 * delta))
			if d < 1.0:
				p.heal(6.0)
				Sfx.play("pickup", -6.0)
				n.queue_free()
				_orbs.remove_at(i)
				continue
		else:
			o.v.y -= 14.0 * delta
			o.v.x *= 0.98
			o.v.z *= 0.98
		var np: Vector3 = n.global_position + o.v * delta
		var fh := Game.arena.floor_height_at(np.x, np.z)
		if fh > n.global_position.y + 0.5:
			fh = 0.0
		if np.y < fh + 0.35:
			np.y = fh + 0.35
			o.v.y = absf(o.v.y) * 0.3
		n.global_position = np
		n.position.y += sin(o.t * 6.0) * 0.004
		i += 1


func _update_waves(delta: float) -> void:
	var p := Game.player
	var i := 0
	while i < _waves.size():
		var w: Dictionary = _waves[i]
		w.r += w.spd * delta
		var n: MeshInstance3D = w.n
		n.scale = Vector3(w.r, 1.0 + w.r * 0.04, w.r)
		var k: float = w.r / w.max
		w.m.set_shader_parameter("intensity", 2.5 * (1.0 - k))
		if p and not w.hit and not p.dead:
			var flat := Vector2(p.global_position.x - n.global_position.x, p.global_position.z - n.global_position.z).length()
			if absf(flat - w.r) < 0.9 and p.global_position.y < w.y + 0.9:
				w.hit = true
				p.take_damage(w.dmg, n.global_position)
				p.knockback(Vector3(p.global_position.x - n.global_position.x, 0, p.global_position.z - n.global_position.z).normalized() * 10.0 + Vector3.UP * 8.0)
		if _rng.randf() < 0.6:
			var a := _rng.randf() * TAU
			Game.gore.sparks(n.global_position + Vector3(cos(a) * w.r, -0.15, sin(a) * w.r), Vector3.UP, 1, Color(1.8, 0.6, 0.2))
		if k >= 1.0:
			n.queue_free()
			_waves.remove_at(i)
			continue
		i += 1


func _update_strikes(delta: float) -> void:
	var i := 0
	while i < _strikes.size():
		var st: Dictionary = _strikes[i]
		st.t += delta
		var left: float = st.delay - st.t
		var pulse := 1.0 + 1.5 * absf(sin(st.t * (8.0 + (1.0 - clampf(left / st.delay, 0.0, 1.0)) * 20.0)))
		st.m.set_shader_parameter("intensity", pulse)
		if left < 0.4 and st.missile == null and st.style == "missile":
			var m := Psx.box(Vector3(0.25, 1.4, 0.25), Psx.unlit(Color(1.0, 0.9, 0.6), 3.0), st.pos + Vector3(0, 16, 0))
			add_child(m)
			st.missile = m
		if st.missile != null and is_instance_valid(st.missile):
			var mk := clampf(1.0 - left / 0.4, 0.0, 1.0)
			st.missile.position = st.pos + Vector3(0, 16.0 * (1.0 - mk) + 0.7, 0)
		if left <= 0.0:
			if st.missile != null and is_instance_valid(st.missile):
				st.missile.queue_free()
			st.n.queue_free()
			if st.style == "lightning":
				var top: Vector3 = st.pos + Vector3(_rng.randf_range(-3, 3), 22.0, _rng.randf_range(-3, 3))
				arc(top, st.pos, 0.25, 0.12, 1.6, 3)
				arc(top, st.pos, 0.2, 0.06, 2.2, 2)
				Sfx.play("thunder", -2.0, 1.2, 0.1)
				if Game.hud and Game.hud.post:
					Game.hud.post.flash(0.25)
			explosion(st.pos, st.dmg, true, st.r)
			_strikes.remove_at(i)
			continue
		i += 1
