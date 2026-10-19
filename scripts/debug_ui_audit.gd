extends Node
## Debug: watches every on-screen text and reports text that leaves the
## screen, spills out of (or across) a panel, or overlaps other text, once it
## has held for a moment (spec §9.9). Run alongside anything, e.g.
##   godot --path . -- --juicetest --uiaudit
##   godot --headless --path . --quit-after 6000 -- --autoplay --uiaudit
## Prints one "[uiaudit]" line per problem and a summary at exit.

const EVERY := 0.25 # seconds between samples
const HOLD := 3 # samples a problem must persist before it is reported
const TOL := 1.0 # pixels of slack
# a text box includes empty space above capitals and below the baseline;
# these fractions of its height are trimmed before boxes are compared
const INSET_TOP := 0.12
const INSET_BOTTOM := 0.15

var _t := 0.0
var _seen := {} # problem key -> consecutive samples
var _reported := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	_t += Game.real_dt
	if _t < EVERY:
		return
	_t = 0.0
	_sample()


func _exit_tree() -> void:
	print("[uiaudit] done: %d problem(s)" % _reported.size())


func _sample() -> void:
	var vs := get_viewport().get_visible_rect().size
	var screen := Rect2(Vector2.ZERO, vs).grow(TOL)
	var texts: Array = []
	var plates: Array = []
	_collect(get_tree().root, texts, plates, vs)
	var now := {}
	for a in texts:
		if not screen.encloses(a.r as Rect2):
			now["offscreen|%s" % a.id] = "offscreen  %s  %s" % [_desc(a), a.r]
		if a.get("over", false):
			now["overflow|%s" % a.id] = "overflow   %s  text %s > box %s" % [_desc(a), a.need, a.box]
		for p in plates:
			if _layer(p.node) != _layer(a.node):
				continue
			var hit: Rect2 = a.r.intersection(p.r)
			if hit.size.x > TOL * 2 and hit.size.y > TOL * 2 and not p.r.grow(TOL).encloses(a.r) and not _in_tab(a, p, plates):
				now["plate|%s|%s" % [a.id, p.id]] = "crosses    %s  %s  panel %s %s" % [_desc(a), a.r, p.id, p.r]
	for i in texts.size():
		for j in range(i + 1, texts.size()):
			var a: Dictionary = texts[i]
			var b: Dictionary = texts[j]
			if a.node == b.node or a.node.is_ancestor_of(b.node) or b.node.is_ancestor_of(a.node):
				continue
			var hit: Rect2 = a.r.intersection(b.r)
			if hit.size.x > TOL * 2 and hit.size.y > TOL * 2:
				now["overlap|%s|%s" % [a.id, b.id]] = "overlap    %s  WITH  %s" % [_desc(a), _desc(b)]
	var next := {}
	for k in now:
		next[k] = int(_seen.get(k, 0)) + 1
		if next[k] == HOLD and not _reported.has(k):
			_reported[k] = true
			print("[uiaudit] t=%.1f %s" % [Time.get_ticks_msec() / 1000.0, now[k]])
	_seen = next


## Text inside a small plate that straddles a bigger one (a ribbon or tab on
## a card's edge) is where it is meant to be.
func _in_tab(a: Dictionary, p: Dictionary, plates: Array) -> bool:
	for q in plates:
		if q != p and q.r.grow(TOL).encloses(a.r) and q.r.get_area() < p.r.get_area():
			return true
	return false


func _desc(a: Dictionary) -> String:
	return "'%s' (%s)" % [str(a.text).replace("\n", " / ").left(48), a.id]


func _layer(n: Node) -> Node:
	var p := n.get_parent()
	while p != null and not (p is CanvasLayer):
		p = p.get_parent()
	return p


func _alpha(c: CanvasItem) -> float:
	var a := c.self_modulate.a
	var n: Node = c
	while n != null and n is CanvasItem:
		a *= (n as CanvasItem).modulate.a
		n = n.get_parent()
	return a


func _id(n: Node) -> String:
	var s := str(n.name)
	var p := n.get_parent()
	for i in 2:
		if p == null or p is Window:
			break
		s = "%s/%s" % [p.name, s]
		p = p.get_parent()
	return s


func _collect(n: Node, texts: Array, plates: Array, vs: Vector2) -> void:
	if n is CanvasLayer and not (n as CanvasLayer).visible:
		return
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if n is Control:
		var c := n as Control
		if _alpha(c) > 0.6:
			if n is Label:
				var l := n as Label
				if l.text.strip_edges() != "" and l.visible_ratio >= 1.0 and not l.has_meta("uiaudit_skip"):
					texts.append(_label_entry(l))
			elif n is GlitchText:
				var g := n as GlitchText
				if g.text != "":
					_glitch_entries(g, texts)
			elif n is Shard or n is ColorRect:
				# panels: a full-width band or a thin bar is not a panel
				var fill: Color = n.color
				var r := c.get_global_rect()
				if fill.a > 0.3 and r.size.x >= 8.0 and r.size.y >= 8.0 and r.size.x < vs.x - 1.0 and not c.has_meta("uiaudit_skip"):
					plates.append({"node": c, "id": _id(c), "r": r})
	for ch in n.get_children():
		_collect(ch, texts, plates, vs)


## The glyph boxes of a GlitchText: its text and its small tag.
func _glitch_entries(g: GlitchText, texts: Array) -> void:
	var t := g.get_global_transform()
	var sc := t.get_scale()
	var pad: Vector2 = g._pad()
	var top: float = g._tag_h()
	var h := g.font.get_height(g.px)
	var r := Rect2(t * Vector2((g.size.x - g._text_w) * 0.5, pad.y + top), Vector2(g._text_w, h) * sc)
	texts.append({"node": g, "id": _id(g), "text": g.text, "r": _inset(r)})
	if g.tag != "":
		var tx: float = g.size.x - g._tag_w - 2.0 if g.tag_right else (g.size.x - g._tag_w) * 0.5
		var tr := Rect2(t * Vector2(tx, 0), Vector2(g._tag_w, top) * sc)
		texts.append({"node": g, "id": _id(g) + ":tag", "text": g.tag, "r": _inset(tr)})


func _inset(r: Rect2) -> Rect2:
	return r.grow_individual(0, -r.size.y * INSET_TOP, 0, -r.size.y * INSET_BOTTOM)


func _label_entry(l: Label) -> Dictionary:
	var r := l.get_global_rect()
	var sc := l.get_global_transform().get_scale()
	var e := {"node": l, "id": _id(l), "text": l.text}
	if l.autowrap_mode != TextServer.AUTOWRAP_OFF:
		var lines := l.get_line_count()
		var sp := l.get_theme_constant("line_spacing")
		var h := (lines * l.get_line_height() + maxi(0, lines - 1) * sp) * sc.y
		if h > r.size.y + TOL:
			e.over = true
			e.need = Vector2(r.size.x, h)
			e.box = r.size
		e.r = _inset(Rect2(r.position, Vector2(r.size.x, maxf(h, 1.0))))
		return e
	var ms := l.get_minimum_size() * sc
	var x := r.position.x
	match l.horizontal_alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			x += (r.size.x - ms.x) * 0.5
		HORIZONTAL_ALIGNMENT_RIGHT:
			x += r.size.x - ms.x
	var y := r.position.y
	match l.vertical_alignment:
		VERTICAL_ALIGNMENT_CENTER:
			y += (r.size.y - ms.y) * 0.5
		VERTICAL_ALIGNMENT_BOTTOM:
			y += r.size.y - ms.y
	e.r = _inset(Rect2(Vector2(x, y), ms))
	return e
