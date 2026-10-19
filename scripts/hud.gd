class_name Hud
extends CanvasLayer
## All 2D UI: gameplay HUD, title, pause, level-up picker, death screen.
## Drawn at 480x270 with pixel fonts, laid out every frame from the visible
## rect so it adapts to any browser window shape.

const MAGENTA := Color(1.0, 0.2, 0.7)
const CYAN := Color(0.25, 0.95, 1.0)
const RED := Color(1.0, 0.15, 0.2)
const YELLOW := Color(1.0, 0.85, 0.25)
# preloaded rather than found by class name, so the HUD still compiles when
# the editor hasn't rescanned yet (e.g. right after switching git branches)
const FinisherPromptScript := preload("res://scripts/ui/finisher_prompt.gd")

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
var finisher_prompt: FinisherPromptScript
var finisher_demo := false # --juicetest shows the prompt with no enemy around
var center_label: Label
var center_shadow: Label
var center_t := 99.0
var hint_label: Label
var hint_bg: ColorRect
var hint_t := 99.0
var _hint_wait := "" # a hint held back until the wave intro has finished
var _popup_wait: Array = [] # tags held back the same way ([text, colour])
var popups: Array = []
var _popup_free: Array[Label] = [] # kill tags and screen blood are pooled (spec §14)
var boss_root: Control
var boss_fill: ColorRect
var boss_name: Label
var kamae_label: Label
var kamae_bg: ColorRect
var kamae_fill: ColorRect
var _boss_plate_h := 27.0
var noammo_label: Label
var noammo_bg: Shard
var noammo_t := 99.0
var blood_root: Control
var bloods: Array = []
var _blood_free: Array[TextureRect] = []
var _blood_rng := RandomNumberGenerator.new() # presentation only
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
var death_vals: Label # the numbers, in their own column so they line up
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
var run_card: RunCardPanel # results: save a postcard of the run (spec §19.1 #10)

var post: PostFx
var juice: Juice
var settings_menu: SettingsMenu
var title_settings: TechButton
var pause_settings: TechButton
var title_quit: TechButton
var pause_quit: TechButton

# profile (spec §11): the Player Level on the title and results, the armory,
# and the boss-reward card
var title_level: LevelBar
var armory: ArmoryPanel
var pause_armory: ArmoryPanel
var level_bar: LevelBar
var reward_card: RewardCard
var _xp_rolled := false
var _reward_t := 99.0

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
## Level-up input is ignored this long after the cards appear, so a click or
## key already flying from combat can't select anything.
const CARD_ARM_TIME := 0.45
const LEVELUP_PROMPT := "CHOOSE AN AUGMENT   (CLICK OR PRESS 1 / 2 / 3)"
const CARD_SIZE := Vector2(148, 188) # level-up augment card: a two-line name and a four-line description fit
const CARD_GAP := 8.0
const CARD_TEXT_W := 132.0 # text width inside the card's solid plate (140 wide, text 6 px in)
const CARD_NAME_PT := 12 # card name and description sizes (Ui.px scales them)
const CARD_DESC_PT := 12
const BOSS_CARD_LEN := 3.6 # boss name card, seconds
const CENTER_LEN := 2.4 # centre message, seconds
const KAMAE_GOLD := Color(1.0, 0.72, 0.15)
const KAMAE_HOT := Color(1.0, 0.93, 0.55) # nearly full: the bar runs white-hot
const KAMAE_HOT_AT := 0.8
const KAMAE_BAR_W := 190.0
const POPUP_LEN := 1.4 # kill tags, seconds
const POPUP_STEP := 15.0 # kill tag line spacing, pixels
const MAX_POPUPS := 4
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
var _selected := -1 # level-up: the card a first click or key chose; a second one takes it
var _pick_t := 0.0
var _death_lines := 0
var _death_full: PackedStringArray = []
var _death_vals_full: PackedStringArray = []
var _death_cols := Vector2.ZERO # full widths of the name and number columns
var _last_cells := 0
var _cell_flash: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var _death_counted := false
var _popup_plate: StyleBoxFlat


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
	_blood_rng.randomize()
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
	reward_card = RewardCard.new()
	root.add_child(reward_card)
	# outside the root, so HUD shake never moves the settings screen
	settings_menu = SettingsMenu.new()
	settings_menu.theme = root.theme
	add_child(settings_menu)
	# the settings screen covers the title or pause screen; the text behind it
	# would peek out at its edges
	settings_menu.visibility_changed.connect(func(): root.visible = not settings_menu.visible)
	title_settings = TechButton.make("SETTINGS  [TAB]", Color(Game.palette.neon_a))
	title_settings.pressed.connect(_open_settings)
	title_root.add_child(title_settings)
	pause_settings = TechButton.make("SETTINGS  [TAB]", Color(Game.palette.neon_a))
	pause_settings.pressed.connect(_open_settings)
	pause_root.add_child(pause_settings)
	title_quit = _quit_button("QUIT GAME  [Q]")
	title_root.add_child(title_quit)
	pause_quit = _quit_button("QUIT GAME")
	pause_root.add_child(pause_quit)
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
	_popup_plate = StyleBoxFlat.new()
	_popup_plate.bg_color = Color(0.02, 0.0, 0.05, 0.72)
	_popup_plate.content_margin_left = 3
	_popup_plate.content_margin_right = 3
	_popup_plate.content_margin_top = 0
	_popup_plate.content_margin_bottom = 0
	play_root = Control.new()
	play_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(play_root)
	blood_root = Control.new()
	blood_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blood_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	play_root.add_child(blood_root)
	var pal := Game.palette
	# tech panels behind each HUD cluster: dark glass, neon edge, brackets.
	# Dark enough to read text over any part of the city, and no scanlines
	# behind the numbers (spec §9.9).
	var glass := Color(0.02, 0.01, 0.06, 0.78)
	plate_tl = Shard.make(glass, 7.0, Color(0, 0, 0, 0), Color(pal.neon_b))
	plate_tr = Shard.make(glass, 7.0, Color(0, 0, 0, 0), Color(pal.neon_a))
	plate_bl = Shard.make(glass, 7.0, Color(0, 0, 0, 0), Color(pal.neon_a))
	plate_br = Shard.make(glass, 7.0, Color(0, 0, 0, 0), Color(pal.neon_b))
	combo_plate = Shard.make(Color(pal.neon_a), 4.0, Color(0, 0, 0, 0), Color.WHITE)
	for pl in [plate_tl, plate_tr, plate_bl, plate_br]:
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
	hp_label = Ui.label("100", Ui.font_big, 10, Color.WHITE, 2)
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
	cell_label = Ui.label("CELLS", Ui.font_bold, 10, Color(0.45, 0.85, 1.0), 2)
	play_root.add_child(cell_label)
	# short and steady (no blinking), left of the crosshair so it never
	# collides with the kill tags on the right
	noammo_bg = Shard.make(Color(0.08, 0.0, 0.02, 0.85), 4.0, Color(0, 0, 0, 0), RED)
	noammo_bg.visible = false
	play_root.add_child(noammo_bg)
	noammo_label = Ui.label("NO CHARGE", Ui.font_big, 10, Color(1.0, 0.35, 0.35), 2)
	noammo_bg.add_child(noammo_label)

	xp_bg = Ui.rect(Color(0.05, 0.02, 0.07, 0.8), Vector2.ZERO, Vector2(200, 4))
	xp_fill = Ui.rect(Color(0.75, 0.35, 1.0), Vector2(1, 1), Vector2(0, 2))
	xp_bg.add_child(xp_fill)
	play_root.add_child(xp_bg)
	lvl_label = Ui.label("RUN LV 1", Ui.font_bold, 10, Color(0.85, 0.6, 1.0), 2)
	play_root.add_child(lvl_label)

	wave_label = Ui.label("WAVE 1", Ui.font_big, 10, Color.WHITE, 2)
	play_root.add_child(wave_label)
	foes_label = Ui.label("", Ui.font_mono, 9, Color(0.85, 0.85, 0.95), 2)
	play_root.add_child(foes_label)
	mut_label = Ui.label("", Ui.font_bold, 10, Color(Game.palette.neon_c), 2)
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
	# boss name card: solid letters on a dark outline with a dark drop shadow
	# (a coloured copy of the name read as a double image)
	var bo := _shadowed("", Ui.font_big, 24, Color.WHITE, Color(0.02, 0.0, 0.05, 0.9), Vector2(2, 2))
	boss_title = bo[0]
	boss_title.add_theme_constant_override("outline_size", 4)
	boss_title.add_theme_color_override("font_outline_color", Color(0.02, 0.0, 0.05, 1.0))
	boss_title.visible = false
	play_root.add_child(boss_title)
	boss_sub = Ui.label("", Ui.font_bold, 11, Color.WHITE, 2)
	boss_sub.visible = false
	play_root.add_child(boss_sub)
	score_label = Ui.label("0", Ui.font_mono, 13, Color.WHITE, 2)
	play_root.add_child(score_label)
	# dark letters on the bright accent plate: readable whatever the heat
	combo_label = Ui.label("", Ui.font_big, 10, Color(0.03, 0.0, 0.06), 0)
	play_root.add_child(combo_label)
	combo_bar = Ui.rect(YELLOW, Vector2.ZERO, Vector2(40, 2))
	play_root.add_child(combo_bar)

	crosshair = Crosshair.new()
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_root.add_child(crosshair)
	finisher_prompt = FinisherPromptScript.new()
	play_root.add_child(finisher_prompt)

	var cl := _shadowed("", Ui.font_big, 16, Color.WHITE, Color(0.1, 0, 0.04), Vector2(1, 1))
	center_label = cl[0]
	center_shadow = cl[1]
	center_label.add_theme_constant_override("outline_size", 2)
	center_label.add_theme_color_override("font_outline_color", Color(0.02, 0.0, 0.05, 1.0))
	center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_shadow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_label.visible = false
	play_root.add_child(center_label)

	hint_bg = Ui.rect(Color(0.02, 0.0, 0.05, 0.85), Vector2.ZERO, Vector2(10, 12))
	hint_bg.visible = false
	play_root.add_child(hint_bg)
	hint_label = Ui.label("", Ui.font_bold, 10, YELLOW, 0)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_bg.add_child(hint_label)

	boss_root = Control.new()
	boss_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_root.visible = false
	play_root.add_child(boss_root)
	var boss_plate := Shard.make(Color(0.02, 0.01, 0.06, 0.78), 5.0, Color(0, 0, 0, 0), Color(0.85, 0.08, 0.1, 0.8))
	boss_plate.name = "Plate"
	boss_root.add_child(boss_plate)
	var bb := Ui.rect(Color(0.05, 0.02, 0.05, 0.9), Vector2(0, 16), Vector2(242, 7))
	boss_root.add_child(bb)
	boss_fill = Ui.rect(Color(0.85, 0.08, 0.1), Vector2(1, 1), Vector2(240, 5))
	bb.add_child(boss_fill)
	boss_name = Ui.label("", Ui.font_bold, 10, Color(1.0, 0.78, 0.65), 2)
	boss_root.add_child(boss_name)
	# KAMAE (posture, spec §5.5): fills from the middle out as the player
	# presses the boss; full means the stance breaks
	kamae_label = Ui.label("KAMAE", Ui.font_bold, 10, KAMAE_GOLD, 2)
	boss_root.add_child(kamae_label)
	kamae_bg = Ui.rect(Color(0.05, 0.02, 0.05, 0.9), Vector2.ZERO, Vector2(KAMAE_BAR_W + 2, 6))
	boss_root.add_child(kamae_bg)
	kamae_fill = Ui.rect(KAMAE_GOLD, Vector2(1, 1), Vector2(KAMAE_BAR_W, 4))
	kamae_bg.add_child(kamae_fill)

	exec_rect = Ui.rect(Color(1, 1, 1, 0), Vector2.ZERO, Vector2(480, 270))
	exec_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	play_root.add_child(exec_rect)


func _build_title() -> void:
	title_root = Control.new()
	title_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title_root)
	var shade := Ui.rect(Color(0.02, 0.0, 0.05, 0.6), Vector2.ZERO, Vector2(480, 270))
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_root.add_child(shade)
	var a: Color = Game.palette.neon_a
	var b: Color = Game.palette.neon_b
	for spec in [["KATANA", a, b], ["/", Color.WHITE, a], ["SHOTGUN", b, a]]:
		var pair := _shadowed(spec[0], Ui.font_big, 24, spec[1], spec[2], Vector2(2, 2))
		title_root.add_child(pair[0])
		title_labels.append(pair[0])
		title_labels.append(pair[1])
	# short lines, so the controls and the hi-score table fit side by side at
	# a readable size
	var lines := [
		["LMB  DOJIGIRI KATANA - CHARGES THE SHOTGUN", b],
		["RMB  RAIJIN-12 SHOTGUN - STAGGERS FOES", Color(Game.palette.neon_c)],
		["%s  GLORY KILL A STAGGERED FOE" % Ui.key_name("finisher"), a],
		["SLASH ENEMY BOLTS TO DEFLECT", b.lerp(Color.WHITE, 0.4)],
		["WASD MOVE   SPACE JUMP x2   SHIFT DASH", Color(0.9, 0.9, 0.95)],
		["EVERY 3RD WAVE: BOSS  -  HEADSHOTS x2", a.lerp(Color.WHITE, 0.3)],
	]
	var y := 0
	for ln in lines:
		var l := Ui.label(ln[0], Ui.font_bold, 9, ln[1], 2)
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
	var sub_l := Ui.label("ARCADE HORDE SHOOTER  -  HOW FAR CAN YOU GET?", Ui.font_bold, 10, Color(0.92, 0.85, 1.0), 2)
	sub_l.name = "Sub"
	title_root.add_child(sub_l)
	title_hi = Ui.label("", Ui.font_big, 10, Color(Game.palette.neon_c), 2)
	title_root.add_child(title_hi)
	title_scores = Ui.label("", Ui.font_mono, 8, Color(0.95, 0.92, 1.0), 2)
	title_root.add_child(title_scores)
	title_seed = Ui.label("", Ui.font_bold, 9, Color(0.8, 0.76, 0.95), 2)
	title_root.add_child(title_seed)
	# version name ("0.1 Dev 1"), set once in project.godot (VERSIONING.md, spec S3.2)
	title_version = Ui.label(str(ProjectSettings.get_setting("application/config/version", "")), Ui.font_mono, 9, Color(0.75, 0.7, 0.9), 2)
	title_root.add_child(title_version)
	title_blink = Ui.label("CLICK TO START", Ui.font_big, 10, Color.WHITE, 2)
	title_root.add_child(title_blink)
	title_level = LevelBar.new().make_slim()
	title_root.add_child(title_level)
	armory = ArmoryPanel.new()
	title_root.add_child(armory)
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
	title_scores.text = _score_table(-1, 3)
	title_level.show_static(Profile.player_level, Profile.player_xp)
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
	var c := Ui.label("CLICK TO RESUME", Ui.font_big, 10, Color.WHITE, 2)
	c.name = "Click"
	pause_root.add_child(c)
	sens_label = Ui.label("", Ui.font_bold, 10, CYAN, 2)
	pause_root.add_child(sens_label)
	# the run's seed lives here rather than cluttering the live HUD
	var sd := Ui.label("", Ui.font_mono, 9, Color(0.8, 0.76, 0.95), 2)
	sd.name = "Seed"
	pause_root.add_child(sd)
	var lock := Ui.label("MOUSE NOT LOCKING?  CLICK INSIDE THE GAME WINDOW", Ui.font_bold, 10, Color(1.0, 0.6, 0.4), 2)
	lock.name = "LockHint"
	lock.visible = false
	pause_root.add_child(lock)
	pause_armory = ArmoryPanel.new()
	pause_root.add_child(pause_armory)
	# your builds so far, top left, out of the way of the menu
	var bl := Ui.label("", Ui.font_bold, 10, Upgrades.LINK_COLOR, 2)
	bl.name = "Builds"
	bl.position = Vector2(8, 44) # under the wave plate, on a plate of its own
	bl.add_theme_stylebox_override("normal", _popup_plate)
	pause_root.add_child(bl)


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
	death_stats = Ui.label("", Ui.font_mono, 9, Color(0.95, 0.85, 0.9), 2)
	death_stats.add_theme_constant_override("line_spacing", 0)
	death_root.add_child(death_stats)
	death_vals = Ui.label("", Ui.font_mono, 9, Color.WHITE, 2)
	death_vals.add_theme_constant_override("line_spacing", 0)
	death_root.add_child(death_vals)
	death_table = Ui.label("", Ui.font_mono, 9, Color(0.95, 0.92, 1.0), 2)
	death_table.add_theme_constant_override("line_spacing", 0)
	death_root.add_child(death_table)
	death_prompt = Ui.label("", Ui.font_bold, 10, Color.WHITE, 2)
	death_root.add_child(death_prompt)
	death_blink = death_prompt
	initials_root = Control.new()
	initials_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	initials_root.visible = false
	death_root.add_child(initials_root)
	initials_label = Ui.label("NEW HIGH SCORE!\nTYPE YOUR INITIALS, THEN ENTER", Ui.font_bold, 10, Color(Game.palette.neon_c), 2)
	initials_root.add_child(initials_label)
	for i in 3:
		var slot := Ui.label("_", Ui.font_big, 24, Color(Game.palette.neon_b), 2)
		initials_root.add_child(slot)
		initials_slots.append(slot)
	level_bar = LevelBar.new()
	level_bar.leveled.connect(_on_player_level)
	level_bar.finished.connect(_on_level_roll_done)
	death_root.add_child(level_bar)
	run_card = RunCardPanel.new()
	death_root.add_child(run_card)


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
	var st := Ui.label(LEVELUP_PROMPT, Ui.font_bold, 10, Color(0.85, 0.8, 1.0), 2)
	st.name = "Sub"
	levelup_root.add_child(st)
	for i in 3:
		var card := Control.new()
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.size = CARD_SIZE
		var bg := Shard.make(Color(0.03, 0.02, 0.08, 1.0), 12.0, Color(Game.palette.neon_a), Color.WHITE)
		bg.size = CARD_SIZE
		bg.shadow_off = Vector2(0, 4)
		bg.brackets = Color(1, 1, 1, 0.6)
		bg.bracket_len = 8.0
		bg.name = "Bg"
		card.add_child(bg)
		var ribbon := Shard.make(Color.WHITE, 4.0)
		ribbon.size = Vector2(96, 15)
		ribbon.position = Vector2(14, 3)
		ribbon.name = "Ribbon"
		card.add_child(ribbon)
		# a solid plate under the text: the glow only tints the rim around it,
		# so nothing shows through behind the words
		var text_plate := Shard.make(Color(0.012, 0.008, 0.03, 1.0), 8.0)
		text_plate.position = Vector2(4, 20)
		text_plate.size = CARD_SIZE - Vector2(8, 24)
		text_plate.name = "Plate"
		card.add_child(text_plate)
		for b in 4:
			var br := Ui.rect(Color.WHITE, Vector2.ZERO, Vector2.ONE)
			br.name = "B%d" % b
			br.visible = false
			card.add_child(br)
		# the key sits on the ribbon row, so a long description never reaches it
		var key := Ui.label("[%d]" % (i + 1), Ui.font_bold, 10, Color(0.75, 0.75, 0.85))
		key.position = Vector2(CARD_SIZE.x - 40, 2)
		key.size = Vector2(34, 15)
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		card.add_child(key)
		var tag := Ui.label("", Ui.font_bold, 10, Color.WHITE)
		tag.name = "Tag"
		tag.position = Vector2(19, 3)
		card.add_child(tag)
		# the text sits on the solid plate, so it needs no outline to read
		var nm := Ui.label("", Ui.font_bold, CARD_NAME_PT, Color.WHITE)
		nm.name = "Name"
		nm.position = Vector2(10, 23)
		nm.size = Vector2(CARD_TEXT_W, 34)
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD
		card.add_child(nm)
		var rk := Ui.label("", Ui.font_bold, 11, YELLOW)
		rk.name = "Rank"
		rk.position = Vector2(10, 56)
		card.add_child(rk)
		var desc := Ui.label("", Ui.font_bold, CARD_DESC_PT, Color(0.96, 0.95, 1.0))
		desc.name = "Desc"
		desc.position = Vector2(10, 72)
		desc.size = Vector2(CARD_TEXT_W, 80)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD
		card.add_child(desc)
		# the builds this card belongs to, pinned to the bottom edge
		var bl := Ui.label("", Ui.font_bold, 10, Color(0.7, 0.7, 0.82))
		bl.name = "Builds"
		bl.position = Vector2(10, CARD_SIZE.y - 37)
		bl.size = Vector2(CARD_TEXT_W, 30)
		bl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		bl.add_theme_constant_override("line_spacing", -2) # two build lines fit the bottom edge
		card.add_child(bl)
		# a tab above the card when it links to a card you already own
		var rec := Ui.label("RECOMMENDED", Ui.font_bold, 10, Color(0.08, 0.04, 0.0))
		rec.name = "Rec"
		var plate := StyleBoxFlat.new()
		plate.bg_color = Upgrades.LINK_COLOR
		plate.content_margin_left = 4
		plate.content_margin_right = 4
		rec.add_theme_stylebox_override("normal", plate)
		rec.visible = false
		card.add_child(rec)
		levelup_root.add_child(card)
		cards.append(card)
	cursor = Ui.label("+", Ui.font_big, 8, Color.WHITE, 2)
	cursor.set_meta("uiaudit_skip", true) # the pointer may pass over anything
	levelup_root.add_child(cursor)


# ---------------------------------------------------------------- overlays
func show_title() -> void:
	_title_t = 0.0
	_title_hit = false
	# a suspended run is the default: click carries on, N starts over
	var snap: Dictionary = Game.main.resume if Game.main else {}
	if snap.is_empty():
		title_blink.text = "CLICK TO START"
	else:
		title_blink.text = "CLICK  CONTINUE RUN - WAVE %d       N  NEW RUN" % int(snap.get("next_wave", 1))
	title_root.visible = true
	play_root.visible = false
	title_quit.disarm()


func hide_title() -> void:
	title_root.visible = false
	play_root.visible = true


func show_pause(on: bool) -> void:
	pause_root.visible = on
	# the pause screen replaces the live HUD and freezes the big messages
	# where they are; they carry on when the game resumes
	play_root.visible = not on
	juice.visible = not on
	juice.process_mode = Node.PROCESS_MODE_PAUSABLE if on else Node.PROCESS_MODE_ALWAYS
	pause_quit.disarm()
	var lines := Upgrades.build_lines(Game.upgrades)
	var bl: Label = pause_root.get_node("Builds")
	bl.text = "BUILDS\n" + "\n".join(lines) if not lines.is_empty() else ""
	if not on:
		settings_menu.close()


func _quit_button(label: String) -> TechButton:
	var b := TechButton.make(label, Color(Game.palette.neon_b))
	b.confirm_text = "PRESS AGAIN TO QUIT"
	b.pressed.connect(Game.quit_game)
	return b


func _open_settings() -> void:
	if settings_menu.can_open():
		settings_menu.open()


func show_death() -> void:
	_death_t = 0.0
	_death_lines = 0
	_death_counted = false
	_xp_rolled = false
	var res: Dictionary = Game.main.results if Game.main else {}
	level_bar.show_static(int(res.get("level_before", Profile.player_level)), int(res.get("xp_before", Profile.player_xp)))
	score_hold = 0
	juice.end_card()
	# the results replace the live HUD rather than sitting on top of it
	play_root.visible = false
	death_root.visible = true
	var mins := int(Game.run_time) / 60
	var secs := int(Game.run_time) % 60
	death_score.text = "SCORE  %07d" % Game.score
	# names and numbers are two columns: padding with spaces drifts by a few
	# pixels in this font, so the numbers would not line up
	_death_full = PackedStringArray(["WAVE REACHED", "BOSSES SLAIN", "KILLS", "GLORY KILLS", "HEADSHOT KILLS", "DEFLECTS", "BEST COMBO", "RUN LV", "TIME"])
	_death_vals_full = PackedStringArray([str(Game.wave), str(Game.bosses_killed), str(Game.kills), str(Game.executions), str(Game.headshots), str(Game.deflects), "x%d" % Game.best_combo, str(Game.level), "%d:%02d" % [mins, secs]])
	var mpx := Ui.px(Ui.font_mono, 9)
	_death_cols = Vector2.ZERO
	for i in _death_full.size():
		_death_cols.x = maxf(_death_cols.x, Ui.font_mono.get_string_size(_death_full[i], HORIZONTAL_ALIGNMENT_LEFT, -1, mpx).x)
		_death_cols.y = maxf(_death_cols.y, Ui.font_mono.get_string_size(_death_vals_full[i], HORIZONTAL_ALIGNMENT_LEFT, -1, mpx).x)
	entering = Game.last_rank >= 0 and not Game.debug_autoplay
	initials = ""
	initials_root.visible = false # shown once the score has counted up
	death_table.visible = false
	if not entering:
		death_table.text = "HI-SCORES\n" + _score_table(-1, 8)
	death_stats.text = ""
	death_vals.text = ""
	death_score.text = "SCORE  %07d" % 0
	run_card.reset()
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
	return death_root.visible and _death_t > 2.4 and not entering and _xp_rolled and level_bar.done()


## The death screen counts up: stats line by line, then the score rolls up and
## slams; a qualifying score then asks for initials.
func _death_countup() -> void:
	var lines := clampi(int((_death_t - 0.25) / 0.09), 0, _death_full.size())
	if lines > _death_lines:
		_death_lines = lines
		Sfx.play("type", -10.0, 0.9 + lines * 0.04, 0.0)
	death_stats.text = "\n".join(_death_full.slice(0, _death_lines))
	death_vals.text = "\n".join(_death_vals_full.slice(0, _death_lines))
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
	# then, once any initials are in, the run's XP counts into the Player
	# Level bar (spec §11.1)
	if _death_t > 2.1 and not _xp_rolled and not entering:
		_xp_rolled = true
		level_bar.roll(Game.main.results if Game.main else {})
	if _death_counted:
		_score_bump = move_toward(_score_bump, 0.0, Game.real_dt * 4.0)
		death_score.scale = Vector2.ONE * (1.0 + 0.4 * _score_bump * _score_bump)


## The wave intro: WAVE N stamp, typed-out mutator, 3-2-1 countdown, FIGHT.
func wave_intro(wave: int, sub_text: String, color: Color, boss: bool) -> void:
	juice.wave_intro(wave, sub_text, color, boss)
	# the intro has the middle of the screen to itself: older tags and hints
	# go, and a fresh tag (an augment just picked: "<UPGRADE> ONLINE") waits
	# and shows at FIGHT
	for pp in popups:
		if pp.t < 1.0:
			_popup_wait.append([pp.l.text, pp.c])
	_clear_tags()
	hint_bg.visible = false
	mut_label.text = ("%s  x%.1f" % [Game.mutator.name, Game.mutator.score]) if not Game.mutator.is_empty() else ""


func intro_ready() -> bool:
	return juice.intro_ready()


## Each Player Level gained on the results screen gets a LEVEL UP stamp in
## the bar's plate, sparks and a sound as the bar fills; when the count ends, one holographic cut-in names
## the new level (spec §11.1). One cut-in, not one per level, so a big run
## never stacks them over the results.
func _on_player_level(lv: int) -> void:
	Sfx.play("levelup", -3.0, 1.0 + 0.05 * (lv % 6), 0.0)
	juice.burst(level_bar.position + level_bar.size * 0.5, YELLOW, 30, 120.0)
	juice.add_shake(3.0)


func _on_level_roll_done(levels: int) -> void:
	if levels <= 0:
		return
	# no cut-in here: its strip would cover the score and the level bar, which
	# already shows the new level
	Sfx.play("highscore", -3.0, 1.0, 0.0)
	juice.firework(Vector2(vs.x * 0.2, vs.y * 0.7), Color(Game.palette.neon_a))
	juice.later(0.2, func(): juice.firework(Vector2(vs.x * 0.8, vs.y * 0.7), Color(Game.palette.neon_b)))


## A boss reward unlocked this wave: the cut-in, then the item card.
func show_reward(def: Dictionary) -> void:
	juice.cut_in("REWARD UNLOCKED")
	_reward_t = 0.0
	juice.later(0.8, func(): reward_card.play(def))


func reward_ready() -> bool:
	return _reward_t > 1.0 and reward_card.ready_to_continue()


## A suspended run picked up again: the score is already earned, so it
## shows at once rather than rolling up, and NEW HI-SCORE doesn't replay.
func on_run_resumed() -> void:
	_score_shown = Game.score
	_hi_stamped = Game.score > Game.best_score()


func show_tally(d: Dictionary) -> void:
	score_hold += int(d.total)
	juice.show_tally(d)
	_clear_tags()


func _clear_tags() -> void:
	for pp in popups:
		_free_popup(pp.l)
	popups.clear()


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
	_clear_tags()


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
	_clear_tags()


func show_boss_intro(title_text: String, sub_text: String) -> void:
	# the boss card replaces the wave intro (one message per region)
	juice.end_intro()
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
	_selected = -1
	_pick_t = 0.0
	# the cursor starts below the cards, never on one
	cursor_pos = Vector2(vs.x * 0.5, vs.y - 8)
	levelup_root.get_node("Sub").text = LEVELUP_PROMPT
	levelup_root.visible = true
	# the cards replace the live HUD: they would otherwise cover its numbers
	play_root.visible = false
	# deal the cards one by one
	for i in choices.size():
		juice.later(0.06 + i * 0.11, func(): Sfx.play("deal", -4.0, 0.95 + i * 0.1, 0.0))
		# a card that links to your build lands with a brighter sting
		if Upgrades.is_recommended(choices[i].id, Game.upgrades):
			juice.later(0.2 + i * 0.11, func(): Sfx.play("chime", -5.0, 1.25, 0.0))
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
		# single-pick cards skip the rank line to leave room for the text
		card.get_node("Rank").text = "RANK %s   %s" % [str(r + 1), pips] if u.max > 1 else ""
		card.get_node("Desc").text = u.desc
		var rec := Upgrades.is_recommended(u.id, Game.upgrades)
		var lit: Label = card.get_node("Rec")
		lit.visible = rec
		lit.size = Vector2.ZERO
		lit.position = Vector2(roundf((CARD_SIZE.x - lit.get_minimum_size().x) * 0.5), -lit.get_minimum_size().y)
		# each build line counts what you would own after this pick
		var after := Game.upgrades.duplicate()
		after[u.id] = Game.rank(u.id) + 1
		var lines := []
		for b in Upgrades.builds_of(u.id):
			lines.append("%s %d/3" % [b.name, Upgrades.build_count(b, after)])
		var bl: Label = card.get_node("Builds")
		bl.text = "\n".join(lines)
		bl.add_theme_color_override("font_color", Upgrades.LINK_COLOR if rec else Color(0.7, 0.7, 0.82))
		card.set_meta("rec", rec)
		# the rank and description sit under the name, which may take two lines
		var nm: Label = card.get_node("Name")
		nm.size = Vector2(CARD_TEXT_W, 0)
		var ry := nm.position.y + nm.get_minimum_size().y
		card.get_node("Rank").position.y = ry
		card.get_node("Desc").position.y = ry + (18.0 if u.max > 1 else 3.0)
		card.set_meta("col", col)


func hide_levelup() -> void:
	levelup_root.visible = false
	play_root.visible = not death_root.visible and not title_root.visible


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
		elif _deal_t < CARD_ARM_TIME:
			pass # the cards are still landing: swallow stray combat input
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# first click selects, a second click on the same card takes it
			if hovered >= 0 and hovered == _selected:
				_pick(hovered)
			else:
				_select(hovered)
		elif event is InputEventKey and event.pressed and not event.echo:
			var idx := -1
			match event.physical_keycode:
				KEY_1, KEY_KP_1: idx = 0
				KEY_2, KEY_KP_2: idx = 1
				KEY_3, KEY_KP_3: idx = 2
				KEY_ENTER, KEY_KP_ENTER: idx = _selected
			if idx >= 0 and idx < _choices.size():
				if idx == _selected:
					_pick(idx)
				else:
					_select(idx)
		get_viewport().set_input_as_handled()


func _card_at(p: Vector2) -> int:
	for i in cards.size():
		var c: Control = cards[i]
		if c.visible and Rect2(c.get_meta("base", c.position), c.size).has_point(p):
			return i
	return -1


## A first click or key lifts a card and asks to confirm; -1 clears it.
func _select(i: int) -> void:
	if _picked >= 0 or i == _selected or i >= _choices.size():
		return
	_selected = i
	if i >= 0:
		Sfx.play("ui_hover", -4.0, 1.3, 0.0)
	var st: Label = levelup_root.get_node("Sub")
	if i < 0:
		st.text = LEVELUP_PROMPT
	else:
		st.text = "TAKE %s?   CLICK IT AGAIN, OR PRESS %d OR ENTER" % [_choices[i].name, i + 1]


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
	var f := Ui.face(Ui.font_big, 16 if big else 10)
	var sz := Ui.px(f, 16 if big else 10)
	for l in [center_label, center_shadow]:
		l.add_theme_font_override("font", f)
		l.add_theme_font_size_override("font_size", sz)
	center_label.size = Vector2.ZERO
	center_shadow.size = Vector2.ZERO
	center_label.visible = true
	center_t = 0.0


## The KAMAE row under the boss's HP bar. While the stance is broken the bar
## shows the time left to land the ONIKIRI, glowing gold to white; the word
## itself never moves or changes (spec §9.9).
func _layout_kamae(boss: Enemy) -> void:
	var row_y := 23.0
	var lh := kamae_label.size.y
	var row_w := kamae_label.size.x + 4.0 + KAMAE_BAR_W + 2.0
	var x0 := roundf((242.0 - row_w) * 0.5)
	kamae_label.position = Vector2(x0, row_y)
	kamae_bg.position = Vector2(x0 + kamae_label.size.x + 4.0, row_y + roundf((lh - kamae_bg.size.y) * 0.5))
	_boss_plate_h = row_y + lh + 1.0
	var k := 0.0
	var col := KAMAE_GOLD
	if boss.is_staggered():
		k = clampf(1.0 - boss.state_t / boss.stagger_length(), 0.0, 1.0)
		col = KAMAE_GOLD.lerp(Color.WHITE, 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012))
	elif boss.kamae:
		k = boss.kamae.ratio()
		if k >= KAMAE_HOT_AT:
			col = KAMAE_HOT
	var w := roundf(KAMAE_BAR_W * k)
	kamae_fill.size.x = w
	kamae_fill.position.x = 1.0 + roundf((KAMAE_BAR_W - w) * 0.5)
	kamae_fill.color = col


## A boss's stance just broke: the centre stamp, a held impact frame and
## speed lines. The prompt under the crosshair says what F does next.
func kamae_broken() -> void:
	juice.stamp("KAMAE BROKEN", KAMAE_GOLD, 16, {"anchor": Vector2(0.5, 0.5), "off": Vector2(0, -44), "hold": 1.0, "rot": -0.04, "shake": 8.0, "vol": -1.0, "pitch": 0.8, "burst": 30, "shadow": Color(0.25, 0.12, 0.0)})
	juice.speed_lines(1.0, 0.3)
	impact_frame(0.1)


func show_hint(text: String) -> void:
	if juice.intro_showing():
		# the countdown and FIGHT use the lower middle of the screen
		_hint_wait = text
		return
	hint_label.text = _wrap(text, hint_label, vs.x - 60.0)
	hint_bg.visible = true
	hint_t = 0.0


## Breaks `text` at word gaps into lines of about equal width, none wider
## than `max_w`. Text that already fits is returned as it is.
func _wrap(text: String, l: Label, max_w: float) -> String:
	var f: Font = l.get_theme_font("font")
	var fs := l.get_theme_font_size("font_size")
	var full := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if full <= max_w:
		return text
	var target := minf(max_w, full / ceilf(full / max_w) + 24.0)
	var out := PackedStringArray()
	var line := ""
	for w in text.split(" ", false):
		var t := w if line == "" else line + " " + w
		if line != "" and f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > target:
			out.append(line)
			line = w
		else:
			line = t
	out.append(line)
	return "\n".join(out)


func add_popup(text: String, color: Color) -> void:
	if juice.intro_showing():
		# e.g. "<UPGRADE> ONLINE" picked just before a wave: it shows at FIGHT
		_popup_wait.append([text, color])
		return
	if juice.panel_showing():
		# kill tags would sit on FINISH, the payout or the boss-defeated card
		return
	# a repeat of the newest tag counts up ("DEFLECT! x3") instead of stacking
	# identical lines
	if not popups.is_empty() and popups[0].text == text and popups[0].t < 0.8:
		var top: Dictionary = popups[0]
		top.n += 1
		top.l.text = "%s x%d" % [text, top.n]
		top.t = 0.0
		return
	while popups.size() >= MAX_POPUPS:
		_free_popup(popups.pop_back().l)
	var l: Label
	if _popup_free.is_empty():
		l = Ui.label(text, Ui.font_bold, 10, color, 2)
		# a dark plate: the tags must read over gore and neon alike
		l.add_theme_stylebox_override("normal", _popup_plate)
		play_root.add_child(l)
	else:
		l = _popup_free.pop_back()
		l.text = text
		l.add_theme_color_override("font_color", color)
		l.visible = true
	l.position = Vector2(vs.x * 0.5 + 18, vs.y * 0.5 - 8)
	popups.push_front({"l": l, "t": 0.0, "y": l.position.y, "text": text, "n": 1, "c": color})


func _free_popup(l: Label) -> void:
	l.visible = false
	_popup_free.append(l)


func damage_flash(amount: float, _from: Vector3) -> void:
	if post:
		post.hurt(clampf(amount / 30.0, 0.3, 1.0))
	juice.add_shake(clampf(amount / 8.0, 1.0, 5.0))


func execution_flash() -> void:
	exec_rect.color = Color(1, 1, 1, 0.4 * Settings.flash)
	juice.add_shake(4.0)
	if post:
		post.flash(0.25)


func no_ammo() -> void:
	noammo_t = 0.0


func screen_blood(n: int) -> void:
	var rng := _blood_rng
	for i in n + rng.randi() % 2:
		while bloods.size() >= 10:
			_free_blood(bloods.pop_front().n)
		var tr: TextureRect
		if _blood_free.is_empty():
			tr = TextureRect.new()
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_SCALE
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			blood_root.add_child(tr)
		else:
			tr = _blood_free.pop_back()
			tr.visible = true
		tr.texture = TexGen.get_tex("splat_b" if rng.randf() < 0.5 else "splat")
		var s := rng.randf_range(40, 95)
		tr.size = Vector2(s, s)
		tr.pivot_offset = tr.size * 0.5
		tr.rotation = rng.randf() * TAU
		var edge := rng.randf() < 0.7
		var px := rng.randf_range(0, vs.x - s) if not edge else (rng.randf_range(-s * 0.4, s * 0.3) if rng.randf() < 0.5 else rng.randf_range(vs.x - s * 0.7, vs.x - s * 0.2))
		tr.position = Vector2(px, rng.randf_range(-s * 0.3, vs.y - s * 0.6))
		tr.modulate = Color(0.5, 0.0, 0.03, 0.7)
		bloods.append({"n": tr, "t": 0.0, "life": rng.randf_range(1.4, 2.4)})


func _free_blood(tr: TextureRect) -> void:
	tr.visible = false
	_blood_free.append(tr)


# ---------------------------------------------------------------- frame
func _fit(labels: Array) -> void:
	for l in labels:
		l.size = Vector2.ZERO


func _process(_delta: float) -> void:
	var delta := Game.real_dt
	_t += delta
	_reward_t += delta
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
		sens_label.position = Vector2((vs.x - sens_label.size.x) * 0.5, vs.y * 0.5 + 22)
		var sd: Label = pause_root.get_node("Seed")
		sd.text = "SEED %s" % Game.seed_string(Game.run_seed)
		sd.size = Vector2.ZERO
		sd.position = Vector2((vs.x - sd.size.x) * 0.5, vs.y * 0.5 + 40)
		var lh: Label = pause_root.get_node("LockHint")
		lh.visible = Game.main and Game.main.lock_failures >= 2
		lh.size = Vector2.ZERO
		lh.position = Vector2((vs.x - lh.size.x) * 0.5, vs.y * 0.5 + 62)
		pause_armory.position = Vector2(8, vs.y - pause_armory.size.y - 6)
		pause_settings.position = Vector2(roundf((vs.x - pause_settings.size.x) * 0.5), vs.y * 0.5 + 84)
		pause_quit.position = Vector2(roundf((vs.x - pause_quit.size.x) * 0.5), pause_settings.position.y + 20)
	if death_root.visible:
		_death_t += delta
		_death_countup()
		var t: Label = death_root.get_node("Title")
		t.size = Vector2.ZERO
		t.position = Vector2((vs.x - t.size.x) * 0.5, vs.y * 0.05)
		_fit([death_score, death_table, death_prompt, initials_label])
		# each line sits under the real height of the one above (the label
		# boxes include empty space under capitals, so they tuck in a little)
		death_score.position = Vector2((vs.x - death_score.size.x) * 0.5, t.position.y + t.size.y - 6)
		# column widths come from the full text, so nothing shifts as lines appear
		_fit([death_stats, death_vals])
		var stats_w := _death_cols.x + 12.0 + _death_cols.y
		var col_w := stats_w + 32.0 + maxf(death_table.size.x, 190.0)
		var x0 := (vs.x - col_w) * 0.5
		level_bar.position = Vector2(roundf((vs.x - level_bar.size.x) * 0.5), roundf(death_score.position.y + death_score.size.y))
		var y0 := level_bar.position.y + level_bar.size.y + 4
		death_stats.position = Vector2(x0, y0)
		death_vals.position = Vector2(x0 + _death_cols.x + 12.0, y0)
		death_table.position = Vector2(x0 + stats_w + 32.0, y0)
		if entering:
			_update_initials()
			initials_root.position = Vector2(x0 + stats_w + 32.0, y0)
			initials_label.position = Vector2.ZERO
			for i in 3:
				initials_slots[i].position = Vector2(i * 30, initials_label.size.y + 4)
		death_prompt.text = "CLICK  NEW RUN        R  RETRY SEED %s" % Game.seed_string(Game.run_seed)
		# a soft pulse instead of a blink: readable on every frame
		death_prompt.visible = death_ready()
		death_prompt.modulate.a = 0.7 + 0.3 * sin(_t * 4.0)
		death_prompt.position = Vector2((vs.x - death_prompt.size.x) * 0.5, vs.y - 22)
		run_card.visible = death_ready()
		run_card.place(vs)
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
	logo_k.position = Vector2(lx0 - (1.0 - kin) * 300.0, ly).round()
	logo_s.position = Vector2(lx0 + logo_k.size.x + gap + (1.0 - kin) * 300.0, ly + 4).round()
	logo_band.position = Vector2(lx0 - 18, ly - 8)
	logo_band.size = Vector2(lw + 36, logo_k.size.y + 16)
	var sk := clampf((tt - 0.32) / 0.07, 0.0, 1.0)
	logo_slash.visible = tt > 0.32
	# the slash stops above the subtitle line
	logo_slash.size = Vector2(22, (logo_k.size.y + 22) * sk)
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
	sub_l.position = Vector2((vs.x - sub_l.size.x) * 0.5, logo_band.position.y + logo_band.size.y + 3)
	# the persistent Player Level under the subtitle (spec §11.1)
	title_level.position = Vector2(roundf((vs.x - title_level.size.x) * 0.5), sub_l.position.y + sub_l.size.y + 3)
	# two columns: how to play | hi-scores over the armory
	var left_w := 0.0
	for i in range(6, title_labels.size()):
		left_w = maxf(left_w, title_labels[i].size.x)
	var right_w := maxf(maxf(title_scores.size.x, title_hi.size.x), armory.size.x)
	var total := left_w + 28.0 + right_w
	var lx := (vs.x - total) * 0.5
	var top := title_level.position.y + title_level.size.y + 5
	for i in range(6, title_labels.size()):
		var l: Label = title_labels[i]
		var row: int = l.get_meta("row")
		l.position = Vector2(lx, top + row * 15)
	title_hi.position = Vector2(lx + left_w + 28.0, top - 2)
	title_scores.position = Vector2(lx + left_w + 28.0, top + 16)
	armory.position = Vector2(lx + left_w + 28.0, title_scores.position.y + title_scores.size.y + 4)
	title_seed.position = Vector2((vs.x - title_seed.size.x) * 0.5, vs.y - 48)
	# bottom row: SETTINGS left, version and QUIT right; the start prompt sits
	# just above it, so even the long continue-run prompt clears both buttons
	title_settings.position = Vector2(8, vs.y - title_settings.size.y - 4)
	title_quit.position = Vector2(vs.x - title_quit.size.x - 8, title_settings.position.y)
	title_version.position = Vector2(title_quit.position.x - title_version.size.x - 6,
		roundf(title_quit.position.y + (title_quit.size.y - title_version.size.y) * 0.5))
	title_blink.modulate.a = 0.7 + 0.3 * sin(_t * 4.0)
	title_blink.position = Vector2((vs.x - title_blink.size.x) * 0.5, title_settings.position.y - title_blink.size.y)


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
	t.rotation = 0.0
	t.position = Vector2((vs.x - t.size.x) * 0.5, vs.y * 0.5 - 119)
	var st: Label = levelup_root.get_node("Sub")
	st.size = Vector2.ZERO
	st.position = Vector2((vs.x - st.size.x) * 0.5, vs.y * 0.5 - 100)
	var n := _choices.size()
	var total := n * CARD_SIZE.x + (n - 1) * CARD_GAP
	for i in cards.size():
		var card: Control = cards[i]
		if not card.visible:
			continue
		var hov := i == hovered and _picked < 0
		var sel := i == _selected and _picked < 0
		var base := Vector2((vs.x - total) * 0.5 + i * (CARD_SIZE.x + CARD_GAP), vs.y * 0.5 - 64).round()
		card.set_meta("base", base)
		# deal in from below with a spin, then hold still: once dealt a card is
		# never rotated or scaled, so its pixel text stays sharp (§9.9)
		var dk := clampf((_deal_t - (0.06 + i * 0.11)) / 0.3, 0.0, 1.0)
		var e := Juice.ease_out_back(dk)
		var off_y := (1.0 - e) * 190.0
		var rot := (1.0 - e) * (0.4 if i % 2 == 0 else -0.4) if dk < 1.0 else 0.0
		var sc := 1.0
		card.modulate.a = 1.0 if dk > 0.0 else 0.0
		if hov:
			off_y -= 3.0
		if sel:
			# selected: lifted higher and held there until confirmed
			off_y -= 6.0
		if _picked >= 0:
			var pk := clampf(_pick_t / 0.3, 0.0, 1.0)
			if i == _picked:
				sc = 1.0 + 0.14 * sin(pk * PI)
				off_y -= 6.0 + 8.0 * sin(pk * PI)
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
		if card.get_meta("rec", false):
			bcol = Upgrades.LINK_COLOR if hov else Upgrades.LINK_COLOR.darkened(0.2)
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
		var glow := 0.3 if sel else (0.18 if hov else 0.0)
		if i == _picked:
			glow = 0.85 * exp(-_pick_t * 6.0) + 0.25
		bg.color = Color(0.06, 0.03, 0.1, 0.95).lerp(Color(col.r, col.g, col.b, 0.95), glow)
		bg.outline = Color.WHITE if (hov or sel) else bcol
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
	_fit([mut_label, hi_label, boss_sub, boss_name, kamae_label, cell_label, noammo_label])
	# ---- bottom-left: HP number and dash pips over the HP bar
	var hpk := clampf(p.hp / p.max_hp, 0.0, 1.0)
	hp_bg.position = Vector2(m, vs.y - m - 9)
	hp_bg.size = Vector2(122, 9)
	hp_fill.size.x = 120.0 * hpk
	_hp_ghost_v = move_toward(_hp_ghost_v, hpk, delta * 0.6) if _hp_ghost_v > hpk else hpk
	hp_ghost.size.x = 120.0 * _hp_ghost_v
	var low := hpk < 0.3
	# low HP pulses the bar, never the number
	hp_fill.color = RED if not low else RED.lerp(Color(1, 0.6, 0.6), 0.5 + 0.5 * sin(_t * 12.0))
	hp_label.text = str(int(ceil(p.hp)))
	hp_label.position = Vector2(m, hp_bg.position.y - hp_label.size.y)
	for i in dash_pips.size():
		var pip := dash_pips[i]
		pip.visible = i < p.max_dash
		pip.position = Vector2(m + maxf(hp_label.size.x, 26.0) + 8 + i * 13, hp_bg.position.y - 9)
		var fill := clampf(p.dash_charges - i, 0.0, 1.0)
		pip.color = CYAN if fill >= 1.0 else Color(0.2, 0.35, 0.4)
		pip.size = Vector2(10, 4)
	# ---- bottom-right: power cells
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
	cell_label.position = Vector2(vs.x - m - cell_label.size.x, vs.y - m - 12 - cell_label.size.y)
	# ---- out of cells: a short steady warning left of the crosshair (the
	# kill tags own the right side)
	noammo_t += delta
	noammo_bg.visible = noammo_t < 1.4
	if noammo_bg.visible:
		noammo_label.position = Vector2(5, 1)
		noammo_bg.size = noammo_label.size + Vector2(10, 2)
		noammo_bg.position = Vector2(roundf(vs.x * 0.5 - 20.0 - noammo_bg.size.x), roundf(vs.y * 0.5 - noammo_bg.size.y * 0.5))
		noammo_bg.modulate.a = clampf((1.4 - noammo_t) / 0.25, 0.0, 1.0)
	# ---- bottom-centre: run level and XP
	xp_bg.size = Vector2(200, 4)
	xp_bg.position = Vector2((vs.x - 200) * 0.5, vs.y - m - 4)
	xp_fill.size.x = 198.0 * clampf(Game.xp / Game.xp_next, 0.0, 1.0)
	lvl_label.text = "RUN LV %d" % Game.level
	lvl_label.position = Vector2((vs.x - lvl_label.size.x) * 0.5, xp_bg.position.y - 1 - lvl_label.size.y)
	# ---- top-left: wave, hostiles, mutator
	wave_label.text = "WAVE %02d" % Game.wave
	wave_label.position = Vector2(m + 1, m - 2)
	foes_label.text = "HOSTILES %d" % Game.main.hostiles_left() if Game.main else ""
	foes_label.position = Vector2(m + 1, wave_label.position.y + wave_label.size.y - 1)
	mut_label.visible = not Game.mutator.is_empty()
	mut_label.position = Vector2(m + 1, foes_label.position.y + foes_label.size.y - 1)
	var tl_bottom := (mut_label.position.y + mut_label.size.y) if mut_label.visible else (foes_label.position.y + foes_label.size.y)
	plate_tl.position = Vector2(3, 3)
	plate_tl.size = Vector2(maxf(maxf(wave_label.size.x, foes_label.size.x), mut_label.size.x if mut_label.visible else 0.0) + 14, tl_bottom - 1)
	# ---- top-centre: best score (steady, never blinking)
	var best := Game.best_score()
	var shown_score := Game.score - score_hold
	if shown_score > best and best > 0 and not _hi_stamped and Game.state == "playing":
		_hi_stamped = true
		juice.hiscore_stamp()
	if shown_score > best and best > 0:
		hi_label.text = "NEW HI-SCORE"
	else:
		hi_label.text = "HI %07d" % maxi(best, shown_score)
	# the wave payout panel reaches up to it, so it steps aside meanwhile
	hi_label.visible = not juice.tally_showing()
	hi_label.position = Vector2(roundf((vs.x - hi_label.size.x) * 0.5), m - 3)
	# ---- boss name card (the big one when a boss arrives)
	var band_on := boss_title.visible
	banner_band.visible = band_on
	if band_on:
		var bh := 58.0
		var by := roundf(vs.y * 0.24)
		banner_band.position = Vector2(0, by)
		banner_band.size = Vector2(vs.x, bh)
		banner_band.get_node("EdgeA").size = Vector2(vs.x, 1)
		var eb: ColorRect = banner_band.get_node("EdgeB")
		eb.size = Vector2(vs.x, 1)
		eb.position = Vector2(0, bh - 1)
		banner_band.modulate.a = clampf((BOSS_CARD_LEN - boss_t) / 0.4, 0.0, 1.0)
	boss_t += delta
	if boss_title.visible:
		var slide := Juice.ease_out(boss_t / 0.25)
		var by2 := roundf(vs.y * 0.24)
		boss_title.position = Vector2(roundf((vs.x - boss_title.size.x) * 0.5 + (1.0 - slide) * -80.0), by2 + 3)
		boss_sub.position = Vector2(roundf((vs.x - boss_sub.size.x) * 0.5 + (1.0 - slide) * 80.0), by2 + 37)
		var ba := clampf((BOSS_CARD_LEN - boss_t) / 0.4, 0.0, 1.0) * clampf(boss_t / 0.08, 0.0, 1.0)
		boss_title.modulate.a = ba
		boss_sub.modulate.a = ba
		if boss_t > BOSS_CARD_LEN:
			boss_title.visible = false
			boss_sub.visible = false
	# ---- top-right: score rolls up; big gains bump it and tint it gold
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
	score_label.scale = Vector2.ONE * (1.0 + 0.2 * _score_bump * _score_bump)
	score_label.add_theme_color_override("font_color", Color.WHITE.lerp(Juice.GOLD, minf(1.0, _score_bump * 1.5)))
	score_label.position = Vector2(vs.x - m - score_label.size.x, m - 2)
	var score_bottom := score_label.position.y + score_label.size.y - 2.0
	# ---- combo: pops on every kill, the plate heats up, milestones stamp
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
	var combo_on := Game.combo >= 2
	combo_label.visible = combo_on
	combo_bar.visible = combo_on
	combo_plate.visible = combo_on
	var tr_bottom := score_bottom
	if combo_on:
		combo_label.text = "x%d COMBO" % Game.combo
		combo_label.size = Vector2.ZERO
		var heat := clampf(Game.combo / 50.0, 0.0, 1.0)
		var ccol := YELLOW.lerp(Color(1.0, 0.25, 0.55), heat)
		if Game.combo >= 50:
			ccol = Color.from_hsv(fmod(_t * 0.5, 1.0), 0.55, 1.0)
		var cw := combo_label.size.x + 10.0
		var ch := combo_label.size.y
		var cpos := Vector2(vs.x - m - cw, score_bottom + 1)
		combo_plate.size = Vector2(cw, ch)
		combo_plate.position = cpos
		combo_plate.color = ccol.lerp(Color.WHITE, _combo_pop * 0.5)
		combo_label.position = cpos + Vector2(5, 0)
		# grows down and to the left, never into the score above
		var pop := Vector2.ONE * (1.0 + 0.15 * _combo_pop * _combo_pop)
		combo_plate.pivot_offset = Vector2(cw, 0)
		combo_plate.scale = pop
		combo_label.pivot_offset = Vector2(cw - 5, 0)
		combo_label.scale = pop
		combo_bar.color = ccol
		combo_bar.size = Vector2(roundf(60.0 * clampf(Game.combo_timer / Game.combo_window(), 0.0, 1.0)), 2)
		combo_bar.position = Vector2(vs.x - m - combo_bar.size.x, cpos.y + ch + 3)
		tr_bottom = combo_bar.position.y + 2
	plate_tr.size = Vector2(maxf(score_label.size.x, combo_plate.size.x if combo_on else 0.0) + 14, tr_bottom + 3 - 3)
	plate_tr.position = Vector2(vs.x - plate_tr.size.x - 3, 3)
	# ---- bottom plates
	var bl_top := hp_label.position.y - 2
	plate_bl.position = Vector2(3, bl_top)
	plate_bl.size = Vector2(134, vs.y - 3 - bl_top)
	var br_top := cell_label.position.y - 2
	plate_br.size = Vector2(maxf(p.max_cells * 7.0 + 10.0, cell_label.size.x + 12.0) + 6.0, vs.y - 3 - br_top)
	plate_br.position = Vector2(vs.x - plate_br.size.x - 3, br_top)

	# crosshair
	crosshair.position = (vs * 0.5).floor()
	crosshair.katana_k = clampf(1.0 - p.katana_cd / p.KATANA_FINISHER_CD, 0.0, 1.0)
	crosshair.shotgun_k = clampf(1.0 - p.shotgun_cd / p.SHOTGUN_CD, 0.0, 1.0) if p.cells > 0 else 0.0
	crosshair.queue_redraw()
	# ---- glory kill prompt: a fixed spot under the crosshair
	var move := ""
	if is_instance_valid(p.gk_ready):
		if p.gk_ready_plunge:
			move = "PLUNGE"
		else:
			move = FinisherPromptScript.BOSS_MOVE if p.gk_ready.is_boss else "GLORY KILL"
	elif finisher_demo:
		move = "GLORY KILL"
	finisher_prompt.refresh(move, crosshair.position, delta)
	# ---- boss bar: top centre, under the best score
	var boss: Enemy = Game.main.boss if Game.main else null
	var boss_on := boss != null and is_instance_valid(boss) and not boss.dead
	boss_root.visible = boss_on
	if boss_on:
		boss_name.text = "%s - %s" % [boss.display_name, boss.subtitle]
		boss_root.position = Vector2(roundf((vs.x - 242) * 0.5), hi_label.position.y + hi_label.size.y)
		boss_name.position = Vector2(roundf((242 - boss_name.size.x) * 0.5), 0)
		var bp: Shard = boss_root.get_node("Plate")
		var bpw := maxf(250.0, boss_name.size.x + 16.0)
		bp.position = Vector2(roundf((242 - bpw) * 0.5), -1)
		boss_fill.size.x = 240.0 * clampf(boss.hp / boss.max_hp, 0.0, 1.0)
		_layout_kamae(boss)
		bp.size = Vector2(bpw, _boss_plate_h)
	# ---- centre message ("<NAME> IS ENRAGED"): a fixed spot under the boss bar
	center_t += delta
	if center_label.visible:
		var pop := 1.0 + maxf(0.0, 0.1 - center_t) * 3.0
		center_label.scale = Vector2.ONE * pop
		center_label.pivot_offset = center_label.size * 0.5
		var cy := (boss_root.position.y + _boss_plate_h + 1.0) if boss_on else (hi_label.position.y + hi_label.size.y + 4.0)
		center_label.position = Vector2(roundf((vs.x - center_label.size.x) * 0.5), cy)
		center_label.modulate.a = clampf((CENTER_LEN - center_t) / 0.3, 0.0, 1.0)
		if center_t > CENTER_LEN:
			center_label.visible = false
	# ---- hint: bottom centre, above the level
	hint_t += delta
	if hint_bg.visible:
		hint_label.size = Vector2.ZERO
		hint_bg.size = Vector2(hint_label.size.x + 12, hint_label.size.y + 2)
		hint_label.position = Vector2(6, 1)
		# above the level and the bottom plates, so it never sits on them
		var hb := minf(lvl_label.position.y, minf(plate_bl.position.y, plate_br.position.y))
		hint_bg.position = Vector2(roundf((vs.x - hint_bg.size.x) * 0.5), hb - 4 - hint_bg.size.y)
		hint_bg.modulate.a = clampf((4.5 - hint_t) / 0.3, 0.0, 1.0)
		if hint_t > 4.5:
			hint_bg.visible = false
	if not juice.intro_showing():
		if _hint_wait != "":
			show_hint(_hint_wait)
			_hint_wait = ""
		for w in _popup_wait:
			add_popup(w[0], w[1])
		_popup_wait.clear()
	# ---- kill tags: right of the crosshair, newest on top; the stack slides
	# smoothly instead of jumping, and each tag holds still once it lands
	var px0 := roundf(vs.x * 0.5 + 18)
	var py0 := roundf(vs.y * 0.5 - 8)
	var i := 0
	while i < popups.size():
		var pp: Dictionary = popups[i]
		pp.t += delta
		var l: Label = pp.l
		if pp.t > POPUP_LEN:
			_free_popup(l)
			popups.remove_at(i)
			continue
		var ty := py0 + i * POPUP_STEP
		pp.y = ty if pp.t <= delta else lerpf(pp.y, ty, 1.0 - exp(-delta * 25.0))
		var k := clampf(pp.t / 0.1, 0.0, 1.0)
		l.size = Vector2.ZERO
		l.pivot_offset = Vector2(0, l.size.y * 0.5)
		l.scale = Vector2.ONE * lerpf(1.4, 1.0, Juice.ease_out(k))
		l.position = Vector2(px0, roundf(pp.y))
		var bright := 1.0 + 0.6 * exp(-pp.t * 16.0)
		l.modulate = Color(bright, bright, bright, clampf((POPUP_LEN - pp.t) / 0.3, 0.0, 1.0))
		i += 1
	# screen blood
	i = 0
	while i < bloods.size():
		var b: Dictionary = bloods[i]
		b.t += delta
		var n: TextureRect = b.n
		if b.t > b.life:
			_free_blood(n)
			bloods.remove_at(i)
			continue
		n.position.y += delta * 6.0
		n.modulate.a = 0.7 * clampf((b.life - b.t) / 0.6, 0.0, 1.0)
		i += 1
	exec_rect.color.a = move_toward(exec_rect.color.a, 0.0, delta * 4.0)
