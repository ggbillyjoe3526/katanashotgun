class_name Hud
extends CanvasLayer
## All 2D UI: gameplay HUD, title, pause, level-up picker, death screen.
## Drawn at 480x270 with pixel fonts, laid out every frame from the visible
## rect so it adapts to any browser window shape.

const MAGENTA := Color(1.0, 0.2, 0.7)
const CYAN := Color(0.25, 0.95, 1.0)
const RED := Color(1.0, 0.15, 0.2)
const YELLOW := Color(1.0, 0.85, 0.25)

var root: Control
var vs := Vector2(480, 270)

# gameplay
var play_root: Control
var hp_bg: ColorRect
var hp_fill: ColorRect
var hp_ghost: ColorRect
var hp_label: Label
var dash_pips: Array[ColorRect] = []
var cell_icons: Array[ColorRect] = []
var cell_label: Label
var xp_bg: ColorRect
var xp_fill: ColorRect
var lvl_label: Label
var wave_label: Label
var foes_label: Label
var score_label: Label
var combo_label: Label
var combo_bar: ColorRect
var crosshair: Crosshair
var center_label: Label
var center_shadow: Label
var center_t := 99.0
var hint_label: Label
var hint_bg: ColorRect
var hint_t := 99.0
var popups: Array = []
var boss_root: Control
var boss_fill: ColorRect
var boss_name: Label
var noammo_label: Label
var noammo_t := 99.0
var blood_root: Control
var bloods: Array = []
var exec_rect: ColorRect
var _hp_ghost_v := 1.0
var _score_shown := 0.0

# overlays
var title_root: Control
var title_labels: Array[Label] = []
var title_blink: Label
var pause_root: Control
var sens_label: Label
var death_root: Control
var death_stats: Label
var death_blink: Label
var levelup_root: Control
var cards: Array = []
var cursor: Label
var cursor_pos := Vector2(240, 160)
var hovered := -1
var _choices: Array = []
var _choice_cb: Callable
var _t := 0.0
var _death_t := 0.0

# arcade
var hi_label: Label
var seed_label: Label
var mut_label: Label
var banner_band: ColorRect
var boss_title: Label
var boss_sub: Label
var boss_t := 99.0
var boss_bar_sub: Label
var title_scores: Label
var title_seed: Label
var title_version: Label
var title_hi: Label
var death_score: Label
var death_table: Label
var death_prompt: Label
var initials_root: Control
var initials_label: Label
var initials_slots: Array[Label] = []
var entering := false
var initials := ""

var post: PostFx
var juice: Juice

# persona plates behind the HUD clusters
var plate_tl: Shard
var plate_tr: Shard
var plate_bl: Shard
var plate_br: Shard
var combo_plate: Shard
var logo_k: GlitchText
var logo_s: GlitchText
var logo_slash: Shard
var logo_band: Shard
var _title_t := 0.0
var _title_hit := false

# juice state
const COMBO_MILESTONES := [10, 20, 30, 50, 75, 100, 150, 200, 300]
var score_hold := 0 # points already scored but held back until a tally slams
var _score_bump := 0.0
var _last_target := 0
var _roll_tick_t := 0.0
var _rolling := false
var _hi_stamped := false
var _combo_ms_idx := 0
var _last_combo := 0
var _combo_pop := 0.0
var _deal_t := 0.0
var _picked := -1
var _pick_t := 0.0
var _death_lines := 0
var _death_full: PackedStringArray = []
var _last_cells := 0
var _cell_flash: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var _death_counted := false


class Crosshair:
	extends Control
	var katana_k := 1.0
	var shotgun_k := 1.0
	var hit_t := 0.0

	func _draw() -> void:
		var c := Vector2.ZERO
		var col := Color(1, 1, 1, 0.9)
		draw_rect(Rect2(c, Vector2(1, 1)), col)
		draw_rect(Rect2(c + Vector2(3, 0), Vector2(3, 1)), col)
		draw_rect(Rect2(c + Vector2(-5, 0), Vector2(3, 1)), col)
		draw_rect(Rect2(c + Vector2(0, 3), Vector2(1, 3)), col)
		draw_rect(Rect2(c + Vector2(0, -5), Vector2(1, 3)), col)
		# katana readiness (left), shotgun readiness (right)
		draw_arc(c, 11.0, PI * 0.7, PI * 0.7 + PI * 0.6 * katana_k, 8, Hud.CYAN, 1.0, false)
		draw_arc(c, 11.0, -PI * 0.3, -PI * 0.3 + PI * 0.6 * shotgun_k, 8, Color(1.0, 0.55, 0.2), 1.0, false)
		if hit_t > 0.0:
			for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
				draw_line(c + d * 5, c + d * 8, Color(1, 0.3, 0.3), 1.0)


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	Ui.init()
	Ui.pixelate_viewport(get_viewport())
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Ui.theme()
	add_child(root)
	_build_play()
	_build_title()
	_build_pause()
	_build_death()
	_build_levelup()
	juice = Juice.new()
	juice.hud = self
	root.add_child(juice)
	Game.hud_message.connect(show_message)
	Game.popup.connect(add_popup)
	Game.hint.connect(show_hint)


# ---------------------------------------------------------------- build
func _shadowed(text: String, f: Font, size: int, color: Color, shadow: Color, off := Vector2(1, 1)) -> Array:
	var sh := Ui.label(text, f, size, shadow)
	var l := Ui.label(text, f, size, color)
	sh.position = off
	l.add_child(sh)
	sh.show_behind_parent = true
	return [l, sh]


func _build_play() -> void:
	play_root = Control.new()
	play_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(play_root)
	blood_root = Control.new()
	blood_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blood_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	play_root.add_child(blood_root)
	var pal := Game.palette
	# tech panels behind each HUD cluster: dark glass, neon edge, brackets
	var glass := Color(0.02, 0.01, 0.06, 0.62)
	plate_tl = Shard.make(glass, 7.0, Color(0, 0, 0, 0), Color(pal.neon_b))
	plate_tr = Shard.make(glass, 7.0, Color(0, 0, 0, 0), Color(pal.neon_a))
	plate_bl = Shard.make(glass, 7.0, Color(0, 0, 0, 0), Color(pal.neon_a))
	plate_br = Shard.make(glass, 7.0, Color(0, 0, 0, 0), Color(pal.neon_b))
	combo_plate = Shard.make(Color(pal.neon_a), 4.0, Color(0, 0, 0, 0), Color.WHITE)
	for pl in [plate_tl, plate_tr, plate_bl, plate_br]:
		pl.scan = 0.04
		pl.brackets = Color(1, 1, 1, 0.55)
		pl.bracket_len = 5.0
	for pl in [plate_tl, plate_tr, plate_bl, plate_br, combo_plate]:
		play_root.add_child(pl)

	hp_bg = Ui.rect(Color(0.05, 0.02, 0.07, 0.85), Vector2.ZERO, Vector2(122, 9))
	hp_ghost = Ui.rect(Color(1, 1, 1, 0.8), Vector2(1, 1), Vector2(120, 7))
	hp_fill = Ui.rect(RED, Vector2(1, 1), Vector2(120, 7))
	hp_bg.add_child(hp_ghost)
	hp_bg.add_child(hp_fill)
	play_root.add_child(hp_bg)
	hp_label = Ui.label("100", Ui.font_big, 8, Color.WHITE, 2)
	play_root.add_child(hp_label)
	for i in 4:
		var pip := Ui.rect(CYAN, Vector2.ZERO, Vector2(10, 3))
		play_root.add_child(pip)
		dash_pips.append(pip)
	for i in 12:
		# a little power cell: body, terminal nub, highlight
		var s := Ui.rect(CYAN, Vector2.ZERO, Vector2(4, 10))
		s.add_child(Ui.rect(Color(0.85, 0.95, 1.0), Vector2(1, -1), Vector2(2, 1)))
		s.add_child(Ui.rect(Color(1, 1, 1, 0.7), Vector2(0, 1), Vector2(1, 7)))
		play_root.add_child(s)
		cell_icons.append(s)
	cell_label = Ui.label("CELLS", Ui.font, 8, Color(0.45, 0.85, 1.0), 2)
	play_root.add_child(cell_label)
	noammo_label = Ui.label("NO CHARGE - USE THE BLADE", Ui.font_bold, 8, RED, 2)
	noammo_label.visible = false
	play_root.add_child(noammo_label)

	xp_bg = Ui.rect(Color(0.05, 0.02, 0.07, 0.8), Vector2.ZERO, Vector2(200, 4))
	xp_fill = Ui.rect(Color(0.75, 0.35, 1.0), Vector2(1, 1), Vector2(0, 2))
	xp_bg.add_child(xp_fill)
	play_root.add_child(xp_bg)
	lvl_label = Ui.label("LV 1", Ui.font, 8, Color(0.85, 0.6, 1.0), 2)
	play_root.add_child(lvl_label)

	wave_label = Ui.label("WAVE 1", Ui.font_big, 8, Color.WHITE, 2)
	play_root.add_child(wave_label)
	foes_label = Ui.label("", Ui.font_mono, 8, Color(0.8, 0.8, 0.9), 2)
	play_root.add_child(foes_label)
	seed_label = Ui.label("", Ui.font_mono, 8, Color(0.6, 0.55, 0.75), 2)
	play_root.add_child(seed_label)
	mut_label = Ui.label("", Ui.font_bold, 8, Color(Game.palette.neon_c), 2)
	play_root.add_child(mut_label)
	hi_label = Ui.label("", Ui.font_mono, 10, Color(Game.palette.neon_c), 2)
	play_root.add_child(hi_label)
	banner_band = Ui.rect(Color(0.02, 0.0, 0.06, 0.7), Vector2.ZERO, Vector2(480, 44))
	banner_band.visible = false
	var edge_a := Ui.rect(Color(Game.palette.neon_a), Vector2(0, 0), Vector2(480, 1))
	edge_a.name = "EdgeA"
	banner_band.add_child(edge_a)
	var edge_b := Ui.rect(Color(Game.palette.neon_b), Vector2(0, 43), Vector2(480, 1))
	edge_b.name = "EdgeB"
	banner_band.add_child(edge_b)
	play_root.add_child(banner_band)
	var bo := _shadowed("", Ui.font_big, 24, Color(Game.palette.neon_a), Color(Game.palette.neon_b), Vector2(3, 3))
	boss_title = bo[0]
	boss_title.visible = false
	play_root.add_child(boss_title)
	boss_sub = Ui.label("", Ui.font_big, 8, Color.WHITE, 2)
	boss_sub.visible = false
	play_root.add_child(boss_sub)
	score_label = Ui.label("0", Ui.font_mono, 13, Color.WHITE, 2)
	play_root.add_child(score_label)
	combo_label = Ui.label("", Ui.font_big, 8, YELLOW, 2)
	play_root.add_child(combo_label)
	combo_bar = Ui.rect(YELLOW, Vector2.ZERO, Vector2(40, 2))
	play_root.add_child(combo_bar)

	crosshair = Crosshair.new()
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_root.add_child(crosshair)

	var cl := _shadowed("", Ui.font_big, 16, Color.WHITE, Color(0.6, 0, 0.2), Vector2(2, 2))
	center_label = cl[0]
	center_shadow = cl[1]
	center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_shadow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_label.visible = false
	play_root.add_child(center_label)

	hint_bg = Ui.rect(Color(0, 0, 0, 0.6), Vector2.ZERO, Vector2(10, 12))
	hint_bg.visible = false
	play_root.add_child(hint_bg)
	hint_label = Ui.label("", Ui.font_bold, 8, YELLOW, 0)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_bg.add_child(hint_label)

	boss_root = Control.new()
	boss_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_root.visible = false
	play_root.add_child(boss_root)
	var bb := Ui.rect(Color(0.05, 0.02, 0.05, 0.9), Vector2(0, 10), Vector2(242, 7))
	boss_root.add_child(bb)
	boss_fill = Ui.rect(Color(0.85, 0.08, 0.1), Vector2(1, 1), Vector2(240, 5))
	bb.add_child(boss_fill)
	boss_name = Ui.label("", Ui.font_bold, 8, Color(1.0, 0.75, 0.6), 2)
	boss_root.add_child(boss_name)

	exec_rect = Ui.rect(Color(1, 1, 1, 0), Vector2.ZERO, Vector2(480, 270))
	exec_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	play_root.add_child(exec_rect)


func _build_title() -> void:
	title_root = Control.new()
	title_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title_root)
	var shade := Ui.rect(Color(0.02, 0.0, 0.05, 0.45), Vector2.ZERO, Vector2(480, 270))
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_root.add_child(shade)
	var a: Color = Game.palette.neon_a
	var b: Color = Game.palette.neon_b
	for spec in [["KATANA", a, b], ["/", Color.WHITE, a], ["SHOTGUN", b, a]]:
		var pair := _shadowed(spec[0], Ui.font_big, 24, spec[1], spec[2], Vector2(2, 2))
		title_root.add_child(pair[0])
		title_labels.append(pair[0])
		title_labels.append(pair[1])
	var lines := [
		["LMB    DOJIGIRI KATANA - KILLS CHARGE THE SHOTGUN", b],
		["RMB    RAIJIN-12 ARC SHOTGUN - STAGGERS, HEADSHOTS x2", Color(Game.palette.neon_c)],
		["SLASH STAGGERED FOES FOR A GLORY KILL", a],
		["SLASH ENEMY BOLTS TO DEFLECT", b.lerp(Color.WHITE, 0.4)],
		["WASD MOVE  SPACE JUMP x2  SHIFT DASH", Color(0.9, 0.9, 0.95)],
		["EVERY 3RD WAVE: BOSS", a.lerp(Color.WHITE, 0.3)],
	]
	var y := 0
	for ln in lines:
		var l := Ui.label(ln[0], Ui.font, 8, ln[1], 2)
		l.set_meta("row", y)
		title_root.add_child(l)
		title_labels.append(l)
		y += 1
	# cyberpunk logo: KATANA / SHOTGUN in heavy glitch type, a neon blade for
	# the slash, on a tech panel
	for i in 6:
		title_labels[i].visible = false
	logo_band = Shard.make(Color(0.02, 0.01, 0.06, 0.8), 14.0, a, b)
	logo_band.shadow_off = Vector2(0, 4)
	logo_band.scan = 0.04
	logo_band.brackets = Color.WHITE
	logo_band.bracket_len = 12.0
	title_root.add_child(logo_band)
	logo_k = GlitchText.new().setup("KATANA", 34, Color.WHITE, a, 11, {"accent2": b, "decode": 0.4})
	logo_s = GlitchText.new().setup("SHOTGUN", 34, Color.WHITE, a, 12, {"accent2": b, "decode": 0.5})
	title_root.add_child(logo_k)
	title_root.add_child(logo_s)
	logo_slash = Shard.make(Color.WHITE, 0.0, a)
	logo_slash.points = PackedVector2Array([Vector2(0.78, 0), Vector2(1, 0), Vector2(0.22, 1), Vector2(0, 1)])
	logo_slash.shadow_off = Vector2(2, 0)
	title_root.add_child(logo_slash)
	var sub_l := Ui.label("ARCADE HORDE SHOOTER  -  HOW FAR CAN YOU GET?", Ui.font_bold, 8, Color(0.92, 0.85, 1.0), 2)
	sub_l.name = "Sub"
	title_root.add_child(sub_l)
	title_hi = Ui.label("", Ui.font_big, 8, Color(Game.palette.neon_c), 2)
	title_root.add_child(title_hi)
	title_scores = Ui.label("", Ui.font_mono, 8, Color(0.95, 0.92, 1.0), 2)
	title_root.add_child(title_scores)
	title_seed = Ui.label("", Ui.font_mono, 8, Color(0.75, 0.7, 0.9), 2)
	title_root.add_child(title_seed)
	# build version, stamped from the release tag by CI (spec S3.2)
	title_version = Ui.label("V" + str(ProjectSettings.get_setting("application/config/version", "0.0.0")), Ui.font_mono, 8, Color(0.75, 0.7, 0.9), 2)
	title_root.add_child(title_version)
	title_blink = Ui.label("CLICK TO START", Ui.font_big, 8, Color.WHITE, 2)
	title_root.add_child(title_blink)
	_refresh_title()


func _score_table(highlight := -1, count := 5) -> String:
	if Game.high_scores.is_empty():
		return "NO SCORES YET\nBE THE FIRST"
	var out := ""
	for i in mini(count, Game.high_scores.size()):
		var e: Dictionary = Game.high_scores[i]
		var mark := ">" if i == highlight else " "
		out += "%s%2d  %-3s  %07d  W%d\n" % [mark, i + 1, str(e.get("name", "???")), int(e.score), int(e.get("wave", 0))]
	return out.strip_edges(false, true)


func _refresh_title() -> void:
	title_hi.text = "HI-SCORES"
	title_scores.text = _score_table(-1, 5)
	title_seed.text = "MAP  %s     PALETTE  %s     SEED  %s" % [Game.arena.map_name if Game.arena else "", Game.palette.name, Game.seed_string(Game.run_seed)]


func _build_pause() -> void:
	pause_root = Control.new()
	pause_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_root.visible = false
	root.add_child(pause_root)
	var shade := Ui.rect(Color(0.02, 0.0, 0.05, 0.7), Vector2.ZERO, Vector2(480, 270))
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_root.add_child(shade)
	var t := Ui.label("PAUSED", Ui.font_big, 16, MAGENTA, 2)
	t.name = "Title"
	pause_root.add_child(t)
	var c := Ui.label("CLICK TO RESUME", Ui.font_big, 8, Color.WHITE, 2)
	c.name = "Click"
	pause_root.add_child(c)
	sens_label = Ui.label("", Ui.font, 8, CYAN, 2)
	pause_root.add_child(sens_label)
	var lock := Ui.label("MOUSE NOT LOCKING?  CLICK INSIDE THE GAME WINDOW", Ui.font, 8, Color(1.0, 0.6, 0.4), 2)
	lock.name = "LockHint"
	lock.visible = false
	pause_root.add_child(lock)


func _build_death() -> void:
	death_root = Control.new()
	death_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_root.visible = false
	root.add_child(death_root)
	var shade := Ui.rect(Color(0.12, 0.0, 0.04, 0.62), Vector2.ZERO, Vector2(480, 270))
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_root.add_child(shade)
	var pair := _shadowed("FLATLINED", Ui.font_big, 24, RED, Color(0.3, 0, 0.05), Vector2(2, 2))
	pair[0].name = "Title"
	death_root.add_child(pair[0])
	death_score = Ui.label("", Ui.font_big, 16, Color(Game.palette.neon_c), 2)
	death_root.add_child(death_score)
	death_stats = Ui.label("", Ui.font_mono, 8, Color(0.95, 0.85, 0.9), 2)
	death_root.add_child(death_stats)
	death_table = Ui.label("", Ui.font_mono, 8, Color(0.95, 0.92, 1.0), 2)
	death_root.add_child(death_table)
	death_prompt = Ui.label("", Ui.font_bold, 8, Color.WHITE, 2)
	death_root.add_child(death_prompt)
	death_blink = death_prompt
	initials_root = Control.new()
	initials_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	initials_root.visible = false
	death_root.add_child(initials_root)
	initials_label = Ui.label("NEW HIGH SCORE!  TYPE YOUR INITIALS, THEN ENTER", Ui.font_bold, 8, Color(Game.palette.neon_c), 2)
	initials_root.add_child(initials_label)
	for i in 3:
		var slot := Ui.label("_", Ui.font_big, 24, Color(Game.palette.neon_b), 2)
		initials_root.add_child(slot)
		initials_slots.append(slot)


func _build_levelup() -> void:
	levelup_root = Control.new()
	levelup_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	levelup_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	levelup_root.visible = false
	root.add_child(levelup_root)
	var shade := Ui.rect(Color(0.02, 0.0, 0.06, 0.72), Vector2.ZERO, Vector2(480, 270))
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	levelup_root.add_child(shade)
	var t := Ui.label("LEVEL UP", Ui.font_big, 16, YELLOW, 2)
	t.name = "Title"
	levelup_root.add_child(t)
	var st := Ui.label("CHOOSE AN AUGMENT   (CLICK OR PRESS 1 / 2 / 3)", Ui.font, 8, Color(0.85, 0.8, 1.0), 2)
	st.name = "Sub"
	levelup_root.add_child(st)
	for i in 3:
		var card := Control.new()
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.size = Vector2(138, 128)
		var bg := Shard.make(Color(0.03, 0.02, 0.08, 0.92), 12.0, Color(Game.palette.neon_a), Color.WHITE)
		bg.size = Vector2(138, 128)
		bg.shadow_off = Vector2(0, 4)
		bg.scan = 0.035
		bg.brackets = Color(1, 1, 1, 0.6)
		bg.bracket_len = 8.0
		bg.name = "Bg"
		card.add_child(bg)
		var ribbon := Shard.make(Color.WHITE, 4.0)
		ribbon.size = Vector2(96, 13)
		ribbon.position = Vector2(14, 3)
		ribbon.name = "Ribbon"
		card.add_child(ribbon)
		for b in 4:
			var br := Ui.rect(Color.WHITE, Vector2.ZERO, Vector2.ONE)
			br.name = "B%d" % b
			br.visible = false
			card.add_child(br)
		var key := Ui.label("[%d]" % (i + 1), Ui.font, 8, Color(0.7, 0.7, 0.8))
		key.position = Vector2(6, 112)
		card.add_child(key)
		var tag := Ui.label("", Ui.font_bold, 8, Color.WHITE)
		tag.name = "Tag"
		tag.position = Vector2(19, 3)
		card.add_child(tag)
		var nm := Ui.label("", Ui.font_big, 8, Color.WHITE, 2)
		nm.name = "Name"
		nm.position = Vector2(6, 22)
		nm.size = Vector2(128, 20)
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD
		card.add_child(nm)
		var rk := Ui.label("", Ui.font, 8, YELLOW)
		rk.name = "Rank"
		rk.position = Vector2(6, 44)
		card.add_child(rk)
		var desc := Ui.label("", Ui.font, 8, Color(0.85, 0.85, 0.92))
		desc.name = "Desc"
		desc.position = Vector2(6, 58)
		desc.size = Vector2(126, 52)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD
		card.add_child(desc)
		levelup_root.add_child(card)
		cards.append(card)
	cursor = Ui.label("+", Ui.font_big, 8, Color.WHITE, 2)
	levelup_root.add_child(cursor)


# ---------------------------------------------------------------- overlays
func show_title() -> void:
	_title_t = 0.0
	_title_hit = false
	title_root.visible = true
	play_root.visible = false


func hide_title() -> void:
	title_root.visible = false
	play_root.visible = true


func show_pause(on: bool) -> void:
	pause_root.visible = on


func show_death() -> void:
	_death_t = 0.0
	_death_lines = 0
	_death_counted = false
	score_hold = 0
	death_root.visible = true
	var mins := int(Game.run_time) / 60
	var secs := int(Game.run_time) % 60
	death_score.text = "SCORE  %07d" % Game.score
	death_stats.text = "WAVE REACHED   %d\nBOSSES SLAIN   %d\nKILLS          %d\nGLORY KILLS    %d\nHEADSHOT KILLS %d\nDEFLECTS       %d\nBEST COMBO     x%d\nLEVEL          %d\nTIME           %d:%02d\nSEED           %s" % [
		Game.wave, Game.bosses_killed, Game.kills, Game.executions, Game.headshots, Game.deflects, Game.best_combo, Game.level, mins, secs, Game.seed_string(Game.run_seed)]
	entering = Game.qualifies(Game.score) and not Game.debug_autoplay
	initials = ""
	initials_root.visible = false # shown once the score has counted up
	death_table.visible = false
	if not entering:
		death_table.text = "HI-SCORES\n" + _score_table(-1, 8)
	_death_full = death_stats.text.split("\n")
	death_stats.text = ""
	death_score.text = "SCORE  %07d" % 0
	_update_initials()


func _update_initials() -> void:
	for i in 3:
		var ch := initials[i] if i < initials.length() else ("_" if (i != initials.length() or fmod(_t, 0.6) < 0.35) else " ")
		initials_slots[i].text = ch


func _finish_initials() -> void:
	var tag := initials
	while tag.length() < 3:
		tag += "-"
	var rank := Game.submit_score(tag)
	entering = false
	initials_root.visible = false
	death_table.visible = true
	death_table.text = "HI-SCORES\n" + _score_table(rank, 8)
	_death_t = maxf(_death_t, 0.8)
	Sfx.play("coin", -2.0)
	juice.add_shake(3.0)


func death_ready() -> bool:
	return death_root.visible and _death_t > 2.4 and not entering


## The death screen counts up: stats line by line, then the score rolls up and
## slams; a qualifying score then asks for initials.
func _death_countup() -> void:
	var lines := clampi(int((_death_t - 0.25) / 0.09), 0, 10)
	if lines > _death_lines:
		_death_lines = lines
		Sfx.play("type", -10.0, 0.9 + lines * 0.04, 0.0)
	death_stats.text = "\n".join(_death_full.slice(0, _death_lines))
	var k := clampf((_death_t - 0.8) / 1.2, 0.0, 1.0)
	var shown := int(Game.score * (k * k * (3.0 - 2.0 * k)))
	death_score.text = "SCORE  %07d" % shown
	death_score.pivot_offset = death_score.size * 0.5
	if k > 0.0 and k < 1.0:
		_roll_tick_t -= Game.real_dt
		if _roll_tick_t <= 0.0:
			_roll_tick_t = 0.05
			Sfx.play("tick", -8.0, 0.9 + k * 1.4, 0.0)
		death_score.scale = Vector2.ONE * (1.0 + 0.12 * k)
	if k >= 1.0 and not _death_counted:
		_death_counted = true
		Sfx.play("cash" if Game.score > 0 else "stamp", -2.0, 1.0, 0.0)
		juice.add_shake(8.0)
		juice.burst(death_score.position + death_score.size * 0.5, Color(Game.palette.neon_c), 60, 140.0)
		_score_bump = 1.0
		if entering:
			initials_root.visible = true
			Sfx.play("highscore", -2.0)
			juice.firework(Vector2(vs.x * 0.25, vs.y * 0.3), Color(Game.palette.neon_a))
			juice.later(0.25, func(): juice.firework(Vector2(vs.x * 0.75, vs.y * 0.28), Color(Game.palette.neon_b)))
		else:
			death_table.visible = true
	if _death_counted:
		_score_bump = move_toward(_score_bump, 0.0, Game.real_dt * 4.0)
		death_score.scale = Vector2.ONE * (1.0 + 0.4 * _score_bump * _score_bump)


## The wave intro: WAVE N stamp, typed-out mutator, 3-2-1 countdown, FIGHT.
func wave_intro(wave: int, sub_text: String, color: Color, boss: bool) -> void:
	juice.wave_intro(wave, sub_text, color, boss)
	mut_label.text = ("%s  x%.1f" % [Game.mutator.name, Game.mutator.score]) if not Game.mutator.is_empty() else ""


func intro_ready() -> bool:
	return juice.intro_ready()


func show_tally(d: Dictionary) -> void:
	score_hold += int(d.total)
	juice.show_tally(d)


func tally_ready() -> bool:
	return juice.tally_ready()


## Called by the tally's cash-out slam: the held points roll into the score.
func release_score(amount: int) -> void:
	score_hold = maxi(0, score_hold - amount)
	_rolling = true
	_score_bump = 1.0


## FromSoftware-style card ("SHADOW DELETED", "FLATLINED").
func souls_card(text: String, col: Color, sub := "", sound := "", length := 4.6) -> void:
	juice.souls_card(text, col, sub, sound, length)


func card_ready() -> bool:
	return juice.card_ready()


func stamp(text: String, color: Color, size := 24, o := {}) -> void:
	juice.stamp(text, color, size, o)


func glory_start(kind: String) -> void:
	juice.glory_start(kind)


func impact_frame(dur: float) -> void:
	if post:
		post.impact_frame(dur)


func kill_burst(world_pos: Vector3, big := false) -> void:
	juice.kill_burst(world_pos, big)


func speed_lines(strength: float, hold := 0.0) -> void:
	juice.speed_lines(strength, hold)


func finish_splash() -> void:
	juice.finish_splash()


func show_boss_intro(title_text: String, sub_text: String) -> void:
	boss_title.text = title_text
	boss_title.get_child(0).text = title_text
	boss_sub.text = sub_text
	boss_title.size = Vector2.ZERO
	boss_title.get_child(0).size = Vector2.ZERO
	boss_sub.size = Vector2.ZERO
	boss_title.visible = true
	boss_sub.visible = true
	boss_t = 0.0
	juice.later(0.25, func():
		juice.add_shake(6.0)
		Sfx.play("stamp", -6.0, 0.7, 0.0))


func show_levelup(choices: Array, cb: Callable) -> void:
	_choices = choices
	_choice_cb = cb
	hovered = -1
	_deal_t = 0.0
	_picked = -1
	_pick_t = 0.0
	cursor_pos = vs * Vector2(0.5, 0.82)
	levelup_root.visible = true
	# deal the cards one by one
	for i in choices.size():
		juice.later(0.06 + i * 0.11, func(): Sfx.play("deal", -4.0, 0.95 + i * 0.1, 0.0))
	juice.later(0.06, func(): juice.add_shake(3.0))
	for i in cards.size():
		var card: Control = cards[i]
		card.visible = i < choices.size()
		if i >= choices.size():
			continue
		var u: Dictionary = choices[i]
		var col: Color = Upgrades.TAG_COLORS.get(u.tag, Color.WHITE)
		card.get_node("Tag").text = u.tag
		card.get_node("Tag").add_theme_color_override("font_color", col)
		card.get_node("Name").text = u.name
		var r := Game.rank(u.id)
		var pips := ""
		for k in u.max:
			pips += "#" if k <= r else "-"
		card.get_node("Rank").text = "RANK %s   %s" % [str(r + 1), pips] if u.max > 1 else "UNIQUE"
		card.get_node("Desc").text = u.desc
		card.set_meta("col", col)


func hide_levelup() -> void:
	levelup_root.visible = false


func _input(event: InputEvent) -> void:
	if entering and death_root.visible and initials_root.visible:
		if event is InputEventKey and event.pressed and not event.echo:
			var kc: int = event.physical_keycode
			if kc == KEY_ENTER or kc == KEY_KP_ENTER:
				_finish_initials()
			elif kc == KEY_BACKSPACE:
				initials = initials.substr(0, maxi(0, initials.length() - 1))
				Sfx.play("type", -6.0, 0.8)
			elif initials.length() < 3:
				var ch := ""
				if kc >= KEY_A and kc <= KEY_Z:
					ch = char(kc)
				elif kc >= KEY_0 and kc <= KEY_9:
					ch = char(kc)
				if ch != "":
					initials += ch
					Sfx.play("type", -6.0)
			_update_initials()
			get_viewport().set_input_as_handled()
		return
	if levelup_root.visible:
		var cs := get_tree().root.content_scale_factor
		if event is InputEventMouseMotion:
			cursor_pos += event.relative / cs if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Vector2.ZERO
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				cursor_pos = event.position / cs
			cursor_pos = cursor_pos.clamp(Vector2.ZERO, vs)
			var h := _card_at(cursor_pos)
			if h != hovered and h >= 0:
				Sfx.play("ui_hover", -8.0)
			hovered = h
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if hovered >= 0:
				_pick(hovered)
		elif event is InputEventKey and event.pressed and not event.echo:
			var idx := -1
			match event.physical_keycode:
				KEY_1, KEY_KP_1: idx = 0
				KEY_2, KEY_KP_2: idx = 1
				KEY_3, KEY_KP_3: idx = 2
			if idx >= 0 and idx < _choices.size():
				_pick(idx)
		get_viewport().set_input_as_handled()


func _card_at(p: Vector2) -> int:
	for i in cards.size():
		var c: Control = cards[i]
		if c.visible and Rect2(c.get_meta("base", c.position), c.size).has_point(p):
			return i
	return -1


## Picking punches the chosen card and drops the others, then applies it.
func _pick(i: int) -> void:
	if i < 0 or i >= _choices.size() or _picked >= 0:
		return
	_picked = i
	_pick_t = 0.0
	Sfx.play("ui_click", -4.0)
	Sfx.play("chime", -6.0, 1.0, 0.0)
	juice.add_shake(4.0)
	var c: Control = cards[i]
	var base: Vector2 = c.get_meta("base", c.position)
	juice.burst(base + c.size * 0.5, c.get_meta("col", Color.WHITE), 50, 120.0)
	var id: String = _choices[i].id
	juice.later(0.34, func():
		_choices = []
		_choice_cb.call(id))


# ---------------------------------------------------------------- events
func show_message(text: String, color: Color, big := true) -> void:
	center_label.text = text
	center_shadow.text = text
	center_label.add_theme_color_override("font_color", color)
	var sz := 16 if big else 8
	center_label.add_theme_font_size_override("font_size", sz)
	center_shadow.add_theme_font_size_override("font_size", sz)
	center_label.size = Vector2.ZERO
	center_shadow.size = Vector2.ZERO
	center_label.visible = true
	center_t = 0.0


func show_hint(text: String) -> void:
	hint_label.text = text
	hint_bg.visible = true
	hint_t = 0.0


func add_popup(text: String, color: Color) -> void:
	var l := Ui.label(text, Ui.font_bold, 8, color, 2)
	l.position = Vector2(vs.x * 0.5 + 26, vs.y * 0.5 + 14)
	play_root.add_child(l)
	popups.push_front({"l": l, "t": 0.0})
	while popups.size() > 6:
		popups.pop_back().l.queue_free()


func damage_flash(amount: float, _from: Vector3) -> void:
	if post:
		post.hurt(clampf(amount / 30.0, 0.3, 1.0))
	juice.add_shake(clampf(amount / 8.0, 1.0, 5.0))


func execution_flash() -> void:
	exec_rect.color = Color(1, 1, 1, 0.4)
	juice.add_shake(4.0)
	if post:
		post.flash(0.25)


func no_ammo() -> void:
	noammo_t = 0.0
	noammo_label.visible = true


func screen_blood(n: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in n + rng.randi() % 2:
		var tr := TextureRect.new()
		tr.texture = TexGen.get_tex("splat_b" if rng.randf() < 0.5 else "splat")
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var s := rng.randf_range(40, 95)
		tr.size = Vector2(s, s)
		tr.pivot_offset = tr.size * 0.5
		tr.rotation = rng.randf() * TAU
		var edge := rng.randf() < 0.7
		var px := rng.randf_range(0, vs.x - s) if not edge else (rng.randf_range(-s * 0.4, s * 0.3) if rng.randf() < 0.5 else rng.randf_range(vs.x - s * 0.7, vs.x - s * 0.2))
		tr.position = Vector2(px, rng.randf_range(-s * 0.3, vs.y - s * 0.6))
		tr.modulate = Color(0.5, 0.0, 0.03, 0.7)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		blood_root.add_child(tr)
		bloods.append({"n": tr, "t": 0.0, "life": rng.randf_range(1.4, 2.4)})
	while bloods.size() > 10:
		bloods.pop_front().n.queue_free()


# ---------------------------------------------------------------- frame
func _fit(labels: Array) -> void:
	for l in labels:
		l.size = Vector2.ZERO


func _process(_delta: float) -> void:
	var delta := Game.real_dt
	_t += delta
	root.position = juice.shake_offset().round() if juice else Vector2.ZERO
	_fit([center_label, center_shadow, hint_label, combo_label, score_label, foes_label, wave_label, hp_label, sens_label, death_stats, lvl_label])
	vs = root.get_rect().size
	if vs.x < 10:
		vs = Vector2(480, 270)
	if title_root.visible:
		_layout_title()
	if pause_root.visible:
		_layout_center(pause_root, ["Title", "Click"], [-30, 0])
		sens_label.text = "MOUSE SENSITIVITY  %.1f   ([ and ] to change)" % (Game.mouse_sensitivity / 0.0024)
		sens_label.position = Vector2((vs.x - sens_label.size.x) * 0.5, vs.y * 0.5 + 24)
		var lh: Label = pause_root.get_node("LockHint")
		lh.visible = Game.main and Game.main.lock_failures >= 2
		lh.position = Vector2((vs.x - lh.size.x) * 0.5, vs.y * 0.5 + 44)
	if death_root.visible:
		_death_t += delta
		_death_countup()
		var t: Label = death_root.get_node("Title")
		t.position = Vector2((vs.x - t.size.x) * 0.5, vs.y * 0.08)
		_fit([death_score, death_table, death_prompt, initials_label])
		death_score.position = Vector2((vs.x - death_score.size.x) * 0.5, vs.y * 0.08 + 32)
		var col_w := death_stats.size.x + 40.0 + maxf(death_table.size.x, 180.0)
		var x0 := (vs.x - col_w) * 0.5
		var y0 := vs.y * 0.08 + 60
		death_stats.position = Vector2(x0, y0)
		death_table.position = Vector2(x0 + death_stats.size.x + 40.0, y0)
		if entering:
			_update_initials()
			initials_root.position = Vector2(x0 + death_stats.size.x + 40.0, y0)
			initials_label.position = Vector2.ZERO
			for i in 3:
				initials_slots[i].position = Vector2(i * 30, 18)
		death_prompt.text = "CLICK  NEW RUN        R  RETRY SEED %s" % Game.seed_string(Game.run_seed)
		death_prompt.visible = death_ready() and fmod(_t, 1.0) < 0.75
		death_prompt.position = Vector2((vs.x - death_prompt.size.x) * 0.5, vs.y - 22)
	if levelup_root.visible:
		_layout_levelup()
	if play_root.visible:
		_update_play(delta)


func _layout_center(node: Control, names: Array, offsets: Array) -> void:
	for i in names.size():
		var l: Control = node.get_node(names[i])
		l.position = Vector2((vs.x - l.size.x) * 0.5, vs.y * 0.5 + offsets[i])


func _layout_title() -> void:
	var fit_list: Array = []
	fit_list.append_array(title_labels)
	fit_list.append_array([title_hi, title_scores, title_seed, title_version, title_blink, title_root.get_node("Sub")])
	_fit(fit_list)
	var y := vs.y * 0.1
	# logo: KATANA flies in from the left, SHOTGUN from the right, then the
	# slash cuts down between them
	_title_t += Game.real_dt
	var tt := _title_t
	var gap := 30.0
	var lw := logo_k.size.x + gap + logo_s.size.x
	var lx0 := (vs.x - lw) * 0.5
	var ly := y - 4.0
	var kin := Juice.ease_out(tt / 0.3)
	var glitch := fmod(_t, 2.3) < 0.08
	logo_k.position = Vector2(lx0 - (1.0 - kin) * 300.0 + (randf_range(-2, 2) if glitch else 0.0), ly).round()
	logo_s.position = Vector2(lx0 + logo_k.size.x + gap + (1.0 - kin) * 300.0, ly + 4).round()
	logo_band.position = Vector2(lx0 - 18, ly - 8)
	logo_band.size = Vector2(lw + 36, logo_k.size.y + 16)
	var sk := clampf((tt - 0.32) / 0.07, 0.0, 1.0)
	logo_slash.visible = tt > 0.32
	logo_slash.size = Vector2(22, (logo_k.size.y + 30) * sk)
	logo_slash.position = Vector2(lx0 + logo_k.size.x + gap * 0.5 - 11, ly - 12)
	if tt > 0.39 and not _title_hit:
		_title_hit = true
		Sfx.play("swing2", -3.0, 1.1)
		Sfx.play("slice", -2.0)
		juice.add_shake(6.0)
		juice.speed_lines(0.8, 0.1)
		juice._shards.burst(logo_slash.position + Vector2(13, logo_slash.size.y * 0.5), Color(Game.palette.neon_a), 16, 260.0, true)
	if fmod(_t, 3.1) < 0.06:
		logo_slash.color = Color(Game.palette.neon_b)
	else:
		logo_slash.color = Color.WHITE
	var sub_l: Label = title_root.get_node("Sub")
	sub_l.position = Vector2((vs.x - sub_l.size.x) * 0.5, y + 34)
	# two columns: how to play | hi-scores
	var left_w := 0.0
	for i in range(6, title_labels.size()):
		left_w = maxf(left_w, title_labels[i].size.x)
	var right_w := maxf(title_scores.size.x, title_hi.size.x)
	var total := left_w + 36.0 + right_w
	var lx := (vs.x - total) * 0.5
	var top := y + 56
	for i in range(6, title_labels.size()):
		var l: Label = title_labels[i]
		var row: int = l.get_meta("row")
		l.position = Vector2(lx, top + row * 13)
	title_hi.position = Vector2(lx + left_w + 36.0, top)
	title_scores.position = Vector2(lx + left_w + 36.0, top + 14)
	title_seed.position = Vector2((vs.x - title_seed.size.x) * 0.5, vs.y - 48)
	title_version.position = Vector2(vs.x - title_version.size.x - 6, vs.y - title_version.size.y - 4)
	title_blink.visible = fmod(_t, 1.0) < 0.65
	title_blink.position = Vector2((vs.x - title_blink.size.x) * 0.5, vs.y - 30)


func _layout_levelup() -> void:
	var rd := Game.real_dt
	_deal_t += rd
	if _picked >= 0:
		_pick_t += rd
	var t: Label = levelup_root.get_node("Title")
	t.size = Vector2.ZERO
	t.pivot_offset = t.size * 0.5
	var tk := clampf(_deal_t / 0.1, 0.0, 1.0)
	t.scale = Vector2.ONE * (lerpf(2.6, 1.0, tk * tk) if tk < 1.0 else 1.0 - 0.12 * sin((_deal_t - 0.1) * 30.0) * exp(-(_deal_t - 0.1) * 9.0))
	t.rotation = sin(_t * 2.0) * 0.02
	t.position = Vector2((vs.x - t.size.x) * 0.5, vs.y * 0.5 - 100)
	var st: Label = levelup_root.get_node("Sub")
	st.position = Vector2((vs.x - st.size.x) * 0.5, vs.y * 0.5 - 80)
	var n := _choices.size()
	var total := n * 138 + (n - 1) * 10
	for i in cards.size():
		var card: Control = cards[i]
		if not card.visible:
			continue
		var hov := i == hovered and _picked < 0
		var base := Vector2((vs.x - total) * 0.5 + i * 148, vs.y * 0.5 - 62).round()
		card.set_meta("base", base)
		# deal in from below with a spin, then sway gently
		var dk := clampf((_deal_t - (0.06 + i * 0.11)) / 0.3, 0.0, 1.0)
		var e := Juice.ease_out_back(dk)
		var off_y := (1.0 - e) * 190.0
		var rot := (1.0 - e) * (0.4 if i % 2 == 0 else -0.4) + sin(_t * 1.7 + i * 1.9) * 0.015
		var sc := 1.0
		card.modulate.a = 1.0 if dk > 0.0 else 0.0
		if hov:
			sc = 1.06
			off_y -= 6.0
			rot += clampf((cursor_pos.x - (base.x + card.size.x * 0.5)) / (card.size.x * 0.5), -1.0, 1.0) * 0.05
		if _picked >= 0:
			var pk := clampf(_pick_t / 0.3, 0.0, 1.0)
			if i == _picked:
				sc = 1.08 + 0.14 * sin(pk * PI)
				off_y -= 8.0 * sin(pk * PI)
			else:
				off_y += pk * pk * 220.0
				rot += pk * (0.5 if i < _picked else -0.5)
				card.modulate.a = 1.0 - pk
		card.pivot_offset = card.size * 0.5
		card.scale = Vector2.ONE * sc
		card.rotation = rot
		card.position = base + Vector2(0, roundf(off_y))
		var col: Color = card.get_meta("col", Color.WHITE)
		var bcol := col if hov else col.darkened(0.45)
		var w := card.size.x
		var h := card.size.y
		var b0: ColorRect = card.get_node("B0")
		var b1: ColorRect = card.get_node("B1")
		var b2: ColorRect = card.get_node("B2")
		var b3: ColorRect = card.get_node("B3")
		b0.position = Vector2.ZERO
		b0.size = Vector2(w, 1)
		b1.position = Vector2(0, h - 1)
		b1.size = Vector2(w, 1)
		b2.position = Vector2.ZERO
		b2.size = Vector2(1, h)
		b3.position = Vector2(w - 1, 0)
		b3.size = Vector2(1, h)
		for b in [b0, b1, b2, b3]:
			b.color = bcol
		var bg: Shard = card.get_node("Bg")
		var glow := 0.18 if hov else 0.0
		if i == _picked:
			glow = 0.85 * exp(-_pick_t * 6.0) + 0.25
		bg.color = Color(0.06, 0.03, 0.1, 0.95).lerp(Color(col.r, col.g, col.b, 0.95), glow)
		bg.outline = bcol if not hov else Color.WHITE
		bg.shadow = col if hov else col.darkened(0.5)
		var rib: Shard = card.get_node("Ribbon")
		rib.color = col
		var tg: Label = card.get_node("Tag")
		tg.add_theme_color_override("font_color", Color(0.02, 0, 0.03))
	cursor.position = cursor_pos - Vector2(4, 4)


func _update_play(delta: float) -> void:
	var p := Game.player
	if p == null:
		return
	var m := 8.0
	# health
	var hpk := clampf(p.hp / p.max_hp, 0.0, 1.0)
	hp_bg.position = Vector2(m, vs.y - m - 9)
	hp_bg.size = Vector2(122, 9)
	hp_fill.size.x = 120.0 * hpk
	_hp_ghost_v = move_toward(_hp_ghost_v, hpk, delta * 0.6) if _hp_ghost_v > hpk else hpk
	hp_ghost.size.x = 120.0 * _hp_ghost_v
	var low := hpk < 0.3
	hp_fill.color = RED if not low or fmod(_t, 0.5) < 0.3 else Color(1, 0.6, 0.6)
	hp_label.text = str(int(ceil(p.hp)))
	hp_label.position = Vector2(m, vs.y - m - 22)
	for i in dash_pips.size():
		var pip := dash_pips[i]
		pip.visible = i < p.max_dash
		pip.position = Vector2(m + 30 + i * 13, vs.y - m - 18)
		var fill := clampf(p.dash_charges - i, 0.0, 1.0)
		pip.color = CYAN if fill >= 1.0 else Color(0.2, 0.35, 0.4)
		pip.size = Vector2(10, 3)
	# cells
	var sx := vs.x - m - 4
	for i in cell_icons.size():
		var s := cell_icons[i]
		s.visible = i < p.max_cells
		s.position = Vector2(sx - i * 7, vs.y - m - 10)
		var full := i < p.cells
		if full and i >= _last_cells:
			_cell_flash[i] = 1.0
		_cell_flash[i] = move_toward(_cell_flash[i], 0.0, delta * 5.0)
		s.color = CYAN.lerp(Color.WHITE, _cell_flash[i]) if full else Color(0.06, 0.1, 0.16)
		s.get_child(0).color = Color(0.85, 0.95, 1.0) if full else Color(0.12, 0.16, 0.22)
		s.get_child(1).visible = full
		s.scale = Vector2.ONE * (1.0 + 0.5 * _cell_flash[i])
		s.pivot_offset = Vector2(2, 5)
	_last_cells = p.cells
	cell_label.position = Vector2(vs.x - m - cell_label.size.x, vs.y - m - 22)
	noammo_t += delta
	noammo_label.visible = noammo_t < 1.4 and fmod(noammo_t, 0.3) < 0.2
	noammo_label.position = Vector2((vs.x - noammo_label.size.x) * 0.5, vs.y * 0.5 + 26)
	# xp
	xp_bg.size = Vector2(200, 4)
	xp_bg.position = Vector2((vs.x - 200) * 0.5, vs.y - m - 4)
	xp_fill.size.x = 198.0 * clampf(Game.xp / Game.xp_next, 0.0, 1.0)
	lvl_label.text = "LV %d" % Game.level
	lvl_label.position = Vector2((vs.x - lvl_label.size.x) * 0.5, vs.y - m - 16)
	# wave / score
	wave_label.text = "WAVE %02d" % Game.wave
	wave_label.position = Vector2(m, m)
	foes_label.text = "HOSTILES %d" % Game.main.hostiles_left() if Game.main else ""
	foes_label.position = Vector2(m, m + 12)
	_fit([seed_label, mut_label, hi_label, boss_sub])
	seed_label.text = "SEED %s" % Game.seed_string(Game.run_seed)
	seed_label.position = Vector2(m, m + 22)
	mut_label.visible = not Game.mutator.is_empty()
	mut_label.position = Vector2(m, m + 34)
	var best := Game.best_score()
	var shown_score := Game.score - score_hold
	if shown_score > best and best > 0 and not _hi_stamped and Game.state == "playing":
		_hi_stamped = true
		juice.hiscore_stamp()
	if shown_score > best and best > 0:
		hi_label.text = "NEW HI-SCORE!"
		hi_label.visible = fmod(_t, 0.8) < 0.55
	else:
		hi_label.text = "HI %07d" % maxi(best, shown_score)
		hi_label.visible = true
	hi_label.position = Vector2((vs.x - hi_label.size.x) * 0.5, m)
	var band_on := boss_title.visible
	banner_band.visible = band_on
	if band_on:
		var bh := 62.0
		var by := vs.y * 0.3 - 10.0
		banner_band.position = Vector2(0, by)
		banner_band.size = Vector2(vs.x, bh)
		banner_band.get_node("EdgeA").size = Vector2(vs.x, 1)
		var eb: ColorRect = banner_band.get_node("EdgeB")
		eb.size = Vector2(vs.x, 1)
		eb.position = Vector2(0, bh - 1)
		banner_band.modulate.a = clampf(3.6 - boss_t, 0.0, 1.0)
	boss_t += delta
	if boss_title.visible:
		var slide := clampf(boss_t / 0.25, 0.0, 1.0)
		boss_title.position = Vector2((vs.x - boss_title.size.x) * 0.5 + (1.0 - slide) * -80.0, vs.y * 0.3)
		boss_sub.position = Vector2((vs.x - boss_sub.size.x) * 0.5 + (1.0 - slide) * 80.0, vs.y * 0.3 + 34)
		var ba := clampf(3.6 - boss_t, 0.0, 1.0)
		boss_title.modulate.a = ba
		boss_sub.modulate.a = ba
		if boss_t > 3.6:
			boss_title.visible = false
			boss_sub.visible = false
	# score: rolls up; big gains bump the label, tally payouts tick as they roll
	var target := float(shown_score)
	if shown_score > _last_target + 400:
		_score_bump = maxf(_score_bump, clampf((shown_score - _last_target) / 3000.0, 0.3, 1.0))
	_last_target = shown_score
	var gap := target - _score_shown
	_score_shown = move_toward(_score_shown, target, maxf(200.0, absf(gap) * (3.0 if _rolling else 8.0)) * delta)
	if _rolling:
		_roll_tick_t -= delta
		if _roll_tick_t <= 0.0 and gap > 1.0:
			_roll_tick_t = 0.045
			Sfx.play("tick", -9.0, 2.2 - clampf(gap / maxf(target, 1.0), 0.0, 1.0) * 1.2, 0.0)
		if gap < 1.0:
			_rolling = false
	_score_bump = move_toward(_score_bump, 0.0, delta * 3.5)
	score_label.text = "%07d" % int(_score_shown)
	score_label.pivot_offset = Vector2(score_label.size.x, score_label.size.y * 0.5)
	score_label.scale = Vector2.ONE * (1.0 + 0.6 * _score_bump * _score_bump)
	score_label.add_theme_color_override("font_color", Color.WHITE.lerp(Juice.GOLD, minf(1.0, _score_bump * 1.5)))
	score_label.position = Vector2(vs.x - m - score_label.size.x, m)
	# combo: pops on every kill, colour heats up, milestones stamp the screen
	if Game.combo == 0:
		_combo_ms_idx = 0
	if Game.combo > _last_combo:
		_combo_pop = 1.0
	_last_combo = Game.combo
	while _combo_ms_idx < COMBO_MILESTONES.size() and Game.combo >= COMBO_MILESTONES[_combo_ms_idx]:
		if Game.state == "playing":
			juice.combo_stamp(COMBO_MILESTONES[_combo_ms_idx], _combo_ms_idx)
		_combo_ms_idx += 1
	_combo_pop = move_toward(_combo_pop, 0.0, delta * 6.0)
	# the screen heats up as the combo climbs
	if post:
		post.heat = move_toward(post.heat, clampf((Game.combo - 4) / 40.0, 0.0, 1.0), delta * 2.0)
	if Game.combo >= 2:
		combo_label.visible = true
		combo_bar.visible = true
		combo_label.text = "x%d  COMBO" % Game.combo
		combo_label.pivot_offset = Vector2(combo_label.size.x, combo_label.size.y * 0.5)
		combo_label.scale = Vector2.ONE * (1.0 + 0.45 * _combo_pop * _combo_pop)
		var heat := clampf(Game.combo / 50.0, 0.0, 1.0)
		var ccol := YELLOW.lerp(Color(1.0, 0.25, 0.55), heat)
		if Game.combo >= 50:
			ccol = Color.from_hsv(fmod(_t * 0.8, 1.0), 0.6, 1.0)
		combo_label.add_theme_color_override("font_color", Color.WHITE)
		combo_bar.color = ccol
		combo_label.position = Vector2(vs.x - m - combo_label.size.x, m + 13)
		combo_bar.size = Vector2(60.0 * Game.combo_timer / Game.COMBO_WINDOW, 2)
		combo_bar.position = Vector2(vs.x - m - combo_bar.size.x, m + 24)
	else:
		combo_label.visible = false
		combo_bar.visible = false
	# persona plates behind each HUD cluster
	plate_tl.position = Vector2(3, 3)
	plate_tl.size = Vector2(maxf(maxf(wave_label.size.x, foes_label.size.x), maxf(seed_label.size.x, mut_label.size.x if mut_label.visible else 0.0)) + 26, (46 if mut_label.visible else 34))
	plate_tr.size = Vector2(maxf(score_label.size.x * score_label.scale.x, 70.0) + 26, 34 if combo_label.visible else 20)
	plate_tr.position = Vector2(vs.x - plate_tr.size.x - 3, 3)
	plate_bl.position = Vector2(3, vs.y - 35)
	plate_bl.size = Vector2(134, 32)
	plate_br.size = Vector2(maxf(p.max_cells * 7.0 + 10.0, cell_label.size.x + 12.0) + 14.0, 32)
	plate_br.position = Vector2(vs.x - plate_br.size.x - 3, vs.y - 35)
	combo_plate.visible = combo_label.visible
	if combo_label.visible:
		var cw := combo_label.size.x * combo_label.scale.x + 12.0
		combo_plate.size = Vector2(cw, 12)
		combo_plate.pivot_offset = Vector2(cw, 6)
		combo_plate.scale = Vector2.ONE * (1.0 + 0.3 * _combo_pop * _combo_pop)
		combo_plate.position = Vector2(vs.x - m - cw + 4, m + 11)
		combo_plate.color = combo_bar.color.darkened(0.25).lerp(Color.WHITE, _combo_pop * 0.5)

	# crosshair
	crosshair.position = (vs * 0.5).floor()
	crosshair.katana_k = clampf(1.0 - p.katana_cd / p.KATANA_FINISHER_CD, 0.0, 1.0)
	crosshair.shotgun_k = clampf(1.0 - p.shotgun_cd / p.SHOTGUN_CD, 0.0, 1.0) if p.cells > 0 else 0.0
	crosshair.queue_redraw()
	# center message
	center_t += delta
	if center_label.visible:
		var pop := 1.0 + maxf(0.0, 0.15 - center_t) * 3.0
		center_label.scale = Vector2.ONE * pop
		center_label.pivot_offset = center_label.size * 0.5
		center_label.position = Vector2((vs.x - center_label.size.x) * 0.5, vs.y * 0.27)
		center_label.modulate.a = clampf(2.4 - center_t, 0.0, 1.0)
		if center_t > 2.4:
			center_label.visible = false
	# hint
	hint_t += delta
	if hint_bg.visible:
		hint_bg.size = Vector2(hint_label.size.x + 10, 12)
		hint_label.position = Vector2(5, 2)
		hint_bg.position = Vector2((vs.x - hint_bg.size.x) * 0.5, vs.y - 44)
		hint_bg.modulate.a = clampf(4.5 - hint_t, 0.0, 1.0)
		if hint_t > 4.5:
			hint_bg.visible = false
	# popups
	var py := vs.y * 0.5 + 14
	var i := 0
	while i < popups.size():
		var pp: Dictionary = popups[i]
		pp.t += delta
		var l: Label = pp.l
		if pp.t > 1.4:
			l.queue_free()
			popups.remove_at(i)
			continue
		# punch in big and bright, wobble, settle
		var k := clampf(pp.t / 0.12, 0.0, 1.0)
		l.pivot_offset = Vector2(0, 4)
		l.scale = Vector2.ONE * lerpf(1.9, 1.0, Juice.ease_out_back(k))
		l.rotation = sin(pp.t * 38.0) * exp(-pp.t * 9.0) * 0.12
		l.position = Vector2(vs.x * 0.5 + 16 + maxf(0.0, 0.1 - pp.t) * 100.0, py + i * 10).round()
		var bright := 1.0 + 0.8 * exp(-pp.t * 14.0)
		l.modulate = Color(bright, bright, bright, clampf((1.4 - pp.t) * 2.0, 0.0, 1.0))
		i += 1
	# boss bar
	var boss: Enemy = Game.main.boss if Game.main else null
	if boss and is_instance_valid(boss) and not boss.dead:
		boss_root.visible = true
		boss_name.text = "%s  -  %s" % [boss.display_name, boss.subtitle]
		boss_root.position = Vector2((vs.x - 242) * 0.5, 22)
		boss_name.position = Vector2((242 - boss_name.size.x) * 0.5, -2)
		boss_fill.size.x = 240.0 * clampf(boss.hp / boss.max_hp, 0.0, 1.0)
	else:
		boss_root.visible = false
	# screen blood
	i = 0
	while i < bloods.size():
		var b: Dictionary = bloods[i]
		b.t += delta
		var n: TextureRect = b.n
		if b.t > b.life:
			n.queue_free()
			bloods.remove_at(i)
			continue
		n.position.y += delta * 6.0
		n.modulate.a = 0.7 * clampf((b.life - b.t) / 0.6, 0.0, 1.0)
		i += 1
	exec_rect.color.a = move_toward(exec_rect.color.a, 0.0, delta * 4.0)
