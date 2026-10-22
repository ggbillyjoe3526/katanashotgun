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
var hp_label: Label
var cell_label: Label
var xp_bg: ColorRect
var xp_fill: ColorRect
var wave_label: Label
var foes_label: Label
var score_label: Label
var combo_label: Label
var combo_bar: ColorRect
var crosshair: Crosshair
var soda_hud: SodaHud # soda cans round the vitals frame (dev-only play-test)
var pause_cans_plate: Shard # the pause screen: the soda cans in hand and what they do
var finisher_prompt: FinisherPromptScript
var finisher_demo := false # --juicetest shows the prompt with no enemy around
var hint_label: Label # warnings and hints: the head line, in the lane's colour
var hint_sub: Label # and the line under it, white
var hint_bg: Shard
var warn_band: HazardBand # warnings (HIJACK); hints keep hint_bg
var hint_t := 99.0
var _hint_wait := "" # a hint held back until the wave intro has finished
var _hint_wait_warn := false
var _hint_wait_tint := Color(0, 0, 0, 0)
var _popup_wait: Array = [] # tags held back the same way ([text, colour])
var popups: Array = []
var _popup_free: Array[Label] = [] # kill tags and screen blood are pooled (spec §14)
var boss_root: Control
var boss_fill: ColorRect
var boss_ghost: ColorRect
var _boss_ghost_v := 1.0
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
var title_menu: MenuList
var title_panel: Shard # hi-scores, armory or how to play, beside the menu
var title_howto: Control
var title_best: Label
var title_xp_bg: ColorRect
var title_xp_fill: ColorRect
var _title_panel_kind := ""
var pause_root: Control
var pause_menu: MenuList
var pause_copy: MenuList
var pause_armory_plate: Shard
var pause_builds_plate: Shard
var sens_label: Label
var death_root: Control
var death_stats: Label
var death_vals: Label # the numbers, in their own column so they line up
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
var mut_label: Label
var boss_bar_sub: Label
var title_scores: Label
var title_version: Label
var death_score: Label
var death_best: Label # the NEW BEST chip under the score
var death_stats_plate: Shard
var death_scores_plate: Shard
var death_scores_head: Label
var death_rows: Array = [] # hi-score rows: [highlight, rank, name, score, wave]
var death_level_plate: Shard
var death_seed: Label
var death_menu: MenuList
var death_exit: MenuList # MAIN MENU, top left: the bottom row has no room for a fifth item
var entering := false
var initials := ""
var run_card: RunCardPanel # results: save a postcard of the run (spec §19.1 #10)

var post: PostFx
var juice: Juice
var settings_menu: SettingsMenu
# seeds to share (spec §7.5): PLAY A SEED on the title, COPY on pause and results
var seed_entry: SeedEntry

# profile (spec §11): the Player Level on the title and results, the armory,
# and the boss-reward card
var armory: ArmoryPanel
var pause_armory: ArmoryPanel
var level_bar: LevelBar
var reward_card: RewardCard
var _xp_rolled := false
var _reward_t := 99.0

var logo_k: GlitchText
var logo_s: GlitchText
var logo_slash: Shard
var _title_t := 0.0
var _title_hit := false

# juice state
const COMBO_MILESTONES := [10, 20, 30, 50, 75, 100, 150, 200, 300]
## Level-up input is ignored this long after the cards appear, so a click or
## key already flying from combat can't select anything.
const CARD_ARM_TIME := 0.45
const LEVELUP_PROMPT := "CHOOSE ONE  -  CLICK OR PRESS 1 / 2 / 3"
const CARD_W := 136.0 # level-up augment card; its height fits the tallest text dealt
const CARD_MIN_H := 150.0
const CARD_GAP := 10.0
const CARD_PAD := 8.0 # text starts this far in from the card's edge
const CARD_TOP := 70.0 # the cards' top edge, from the top of the screen
const LEVELUP_SHADOW := Color(0.59, 1.0, 0.38) # the LEVEL UP block's hard shadow (HIJACK)
const CARD_EDGE := Color(0.27, 0.24, 0.39) # an unlit card's outline
const CARD_TEXT := Color(0.63, 0.62, 0.75) # descriptions
const CARD_INK := Color(0.03, 0.02, 0.07) # dark words on the tag ribbon
const PIP_OFF := Color(0.2, 0.2, 0.29)
const CARD_LINE_GAP := -1 # card text lines 15 px apart
# the Focus menus (spec §9.7): words on the left over the scene, plates only
# where there is a table to hold
const TITLE_X := 32.0
const TITLE_PITCH := 16.0
const TITLE_MENU_W := 140.0 # the side panel opens this far right of the menu
const LOGO_PX := 32
const LOGO_LINE := 36.0 # SHOTGUN sits this far under KATANA
const LOGO_CAP := 23.0 # Orbitron's capital height at LOGO_PX
const LOGO_CAP_TOP := 10.0 # and its capitals' top inside the text box
const SLASH_W := 16.0
const HOWTO_KEY_W := 46.0 # HOW TO PLAY: the keys' column
const T_START := 0 # title menu items
const T_NEW := 1
const T_SEED := 2
const T_SCORES := 3
const T_ARMORY := 4
const T_HOWTO := 5
const T_SETTINGS := 6
const T_QUIT := 7
const PAUSE_X := 40.0
const PAUSE_PITCH := 20.0
const P_RESUME := 0 # pause menu items
const P_ARMORY := 1
const P_SETTINGS := 2
const P_QUIT := 3
const RESULTS_W := 400.0 # the results block: two 192 px plates and a gap
const RESULTS_PLATE_W := 192.0
const RESULTS_ROW := 15.0
const SCORE_ROWS := 4 # hi-score rows on the results
const GOLD := Color(1.0, 0.72, 0.15)
const D_CARD := 2 # results row items: RETRY SEED, NEW RUN, RUN CARD, COPY SEED
const D_COPY := 3
const KAMAE_GOLD := Color(1.0, 0.72, 0.15)
const KAMAE_HOT := Color(1.0, 0.93, 0.55) # nearly full: the bar runs white-hot
const KAMAE_HOT_AT := 0.8
const BOSS_W := 220.0 # the boss bar's plate
const POPUP_LEN := 1.4 # kill callouts, seconds
const POPUP_STEP := 16.0 # callout line spacing, pixels
const MAX_POPUPS := 3
const HINT_WARN := Color(1.0, 0.25, 0.3) # warnings ("MISSILES INBOUND"); hints are YELLOW
const HINT_BOTTOM := 24.0 # the warning lane ends this far above the bottom edge
const LOW_RED := Color(1.0, 0.32, 0.34) # health below 30%, no cells left
const LINE := 14.0 # line pitch of stacked small text (Jersey 10: 10 px capitals)
const SCORE_Y := -4.0
const COMBO_GAP := 11.0 # the combo sits this far under the vitals frame
const CALLOUT_X := 32.0 # kill callouts start this far right of the frame
const HP_PLATE_W := 22.0 # the health number's plate at three digits
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
var _last_cells := 0
var _cell_flash: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var _death_counted := false
var _scores_shown := false # the hi-score rows, once the score has counted up
var _popup_plate: StyleBoxFlat


## The crosshair, and round it the player's vitals as a square frame drawn by
## its corners (spec §9.7): health up the left edge, one block per power cell
## up the right edge, dash charges along the bottom. The middle stays open, so
## the enemy under the crosshair is never covered.
class Crosshair:
	extends Control
	const H := 24 # half the side of the square
	const ARM := 5 # corner bracket arms
	const INSET := 8 # the health and cell columns stop this far short of the corners
	const INK := Color(0.02, 0.0, 0.05, 0.85)
	const LIME := Color(0.55, 1.0, 0.35)
	var hit_t := 0.0
	var frame := true
	var hp_k := 1.0
	var ghost_k := 1.0
	var low_t := -1.0 # below 30% health: the time, for the bar's soft pulse
	var cells := 0
	var max_cells := 4
	var cell_flash: Array[float] = []
	var dash := 0.0
	var max_dash := 2

	func _draw() -> void:
		var col := Color(1, 1, 1, 0.9)
		draw_rect(Rect2(0, 0, 1, 1), col)
		draw_rect(Rect2(3, 0, 3, 1), col)
		draw_rect(Rect2(-5, 0, 3, 1), col)
		draw_rect(Rect2(0, 3, 1, 3), col)
		draw_rect(Rect2(0, -5, 1, 3), col)
		if hit_t > 0.0:
			for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
				draw_line(d * 5, d * 8, Color(1, 0.3, 0.3), 1.0)
		if not frame:
			return
		# corner brackets: the square is drawn by its corners only
		for c: Vector2i in [Vector2i(-H, -H), Vector2i(H, -H), Vector2i(-H, H), Vector2i(H, H)]:
			var x := c.x if c.x < 0 else c.x - ARM + 1
			var y := c.y if c.y < 0 else c.y - ARM + 1
			draw_rect(Rect2(x, c.y, ARM, 1), col)
			draw_rect(Rect2(c.x, y, 1, ARM), col)
		var by0 := -H + INSET
		var bh := 2 * (H - INSET) + 1
		var bot := by0 + bh
		# health: the left edge, filling from the bottom, with a white trail
		draw_rect(Rect2(-H - 2, by0 - 1, 5, bh + 2), INK)
		draw_rect(Rect2(-H - 1, by0, 3, bh), Color(0.32, 0.06, 0.12))
		var gh := roundi(bh * ghost_k)
		draw_rect(Rect2(-H - 1, bot - gh, 3, gh), Color(1, 1, 1, 0.75))
		var fh := roundi(bh * hp_k)
		var red := Hud.RED
		if low_t >= 0.0:
			red = Hud.RED.lerp(Color(1, 0.6, 0.6), 0.5 + 0.5 * sin(low_t * 12.0))
		draw_rect(Rect2(-H - 1, bot - fh, 3, fh), red)
		# cells: the right edge, one block each, filled from the bottom
		draw_rect(Rect2(H - 2, by0 - 1, 5, bh + 2), INK)
		var n := maxi(1, max_cells)
		var gap := 2 if n <= 6 else 1
		var seg := maxi(1, floori(float(bh - gap * (n - 1)) / n))
		for k in n:
			var top := bot - (k + 1) * seg - k * gap
			var on := k < cells
			var f: float = cell_flash[k] if k < cell_flash.size() else 0.0
			draw_rect(Rect2(H - 1, top, 3, seg), Hud.CYAN.lerp(Color.WHITE, f) if on else Color(0.17, 0.2, 0.32))
		# dash: pips along the bottom edge, between the corners
		var w := 8 if max_dash <= 3 else 6
		var g := 4 if max_dash <= 3 else 3
		var x0 := -floori((max_dash * w + (max_dash - 1) * g) * 0.5)
		for i in max_dash:
			var px := x0 + i * (w + g)
			var fill := clampf(dash - i, 0.0, 1.0)
			draw_rect(Rect2(px, H - 1, w, 3), Color(0.14, 0.24, 0.12))
			if fill >= 1.0:
				draw_rect(Rect2(px, H - 1, w, 3), LIME)
			elif fill > 0.0:
				draw_rect(Rect2(px, H - 1, roundi(w * fill), 3), LIME.darkened(0.45))


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
	# added after the settings screen so it sees keys first: Tab is typed
	# into it, never opens settings behind it
	seed_entry = SeedEntry.new()
	seed_entry.theme = root.theme
	add_child(seed_entry)
	seed_entry.visibility_changed.connect(func(): root.visible = not seed_entry.visible)
	seed_entry.chosen.connect(func(s: int): Game.main.play_seed(s))
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
	# The Focus layout (spec §9.7): no corner panels. Wave and score sit bare
	# in the top corners with a dark outline, the vitals frame the crosshair,
	# and every other kind of message has a fixed lane of its own.

	# run XP: a hairline along the bottom edge
	xp_bg = Ui.rect(Color(0.12, 0.08, 0.2, 0.85), Vector2.ZERO, Vector2(480, 2))
	xp_fill = Ui.rect(Color(0.75, 0.35, 1.0), Vector2.ZERO, Vector2(0, 2))
	xp_bg.add_child(xp_fill)
	play_root.add_child(xp_bg)

	wave_label = Ui.label("WAVE 01", Ui.font_bold, 10, Color.WHITE, 2)
	play_root.add_child(wave_label)
	foes_label = Ui.label("", Ui.font_bold, 10, Color(0.75, 0.73, 0.88), 2)
	play_root.add_child(foes_label)
	mut_label = Ui.label("", Ui.font_bold, 10, Color(pal.neon_c), 2)
	play_root.add_child(mut_label)
	score_label = Ui.label("0", Ui.font_mono, 30, Color.WHITE, 3)
	play_root.add_child(score_label)

	crosshair = Crosshair.new()
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_root.add_child(crosshair)
	soda_hud = SodaHud.new()
	play_root.add_child(soda_hud)
	# the numbers beside the vitals frame: red side health, cyan side cells
	hp_label = _plated("100", Color.WHITE)
	cell_label = _plated("4", CYAN)
	# out of cells: a short steady warning left of the health number
	noammo_bg = Shard.make(Color(0.08, 0.0, 0.02, 0.85), 4.0, Color(0, 0, 0, 0), RED)
	noammo_bg.visible = false
	play_root.add_child(noammo_bg)
	noammo_label = Ui.label("NO CHARGE", Ui.font_bold, 10, Color(1.0, 0.35, 0.35), 0)
	noammo_bg.add_child(noammo_label)
	# the combo under the frame, with its timer as a line under the number
	combo_label = _plated("", YELLOW)
	combo_bar = Ui.rect(YELLOW, Vector2.ZERO, Vector2(10, 1))
	play_root.add_child(combo_bar)
	finisher_prompt = FinisherPromptScript.new()
	play_root.add_child(finisher_prompt)

	# warnings and hints: bottom centre, one at a time, edged in their colour
	hint_bg = Shard.make(Color(0.02, 0.0, 0.05, 0.86), 4.0, Color(0, 0, 0, 0), YELLOW)
	hint_bg.visible = false
	play_root.add_child(hint_bg)
	hint_label = Ui.label("", Ui.font_bold, 10, YELLOW, 0)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_bg.add_child(hint_label)
	hint_sub = Ui.label("", Ui.font_bold, 10, Color.WHITE, 0)
	hint_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_bg.add_child(hint_sub)
	warn_band = HazardBand.new()
	warn_band.visible = false
	play_root.add_child(warn_band)
	warn_band.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# boss bar: top centre, the name, its health and the KAMAE row (spec §5.5)
	boss_root = Control.new()
	boss_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_root.visible = false
	play_root.add_child(boss_root)
	var boss_plate := Shard.make(Color(0.02, 0.01, 0.06, 0.8), 5.0, Color(0, 0, 0, 0), Color(0.85, 0.08, 0.1, 0.8))
	boss_plate.name = "Plate"
	boss_plate.size = Vector2(BOSS_W, 10)
	boss_root.add_child(boss_plate)
	boss_name = Ui.label("", Ui.font_bold, 10, Color(1.0, 0.3, 0.32), 0)
	boss_root.add_child(boss_name)
	var bb := Ui.rect(Color(0.24, 0.05, 0.09, 0.95), Vector2(8, 16), Vector2(BOSS_W - 16, 5))
	bb.name = "Bar"
	boss_root.add_child(bb)
	boss_ghost = Ui.rect(Color(1, 1, 1, 0.75), Vector2(1, 1), Vector2(BOSS_W - 18, 3))
	bb.add_child(boss_ghost)
	boss_fill = Ui.rect(Color(0.92, 0.1, 0.14), Vector2(1, 1), Vector2(BOSS_W - 18, 3))
	bb.add_child(boss_fill)
	# KAMAE (posture, spec §5.5): fills from the middle out as the player
	# presses the boss; full means the stance breaks
	kamae_label = Ui.label("KAMAE", Ui.font_bold, 10, KAMAE_GOLD, 0)
	boss_root.add_child(kamae_label)
	kamae_bg = Ui.rect(Color(0.22, 0.15, 0.04, 0.95), Vector2.ZERO, Vector2(BOSS_W - 60, 5))
	boss_root.add_child(kamae_bg)
	kamae_fill = Ui.rect(KAMAE_GOLD, Vector2(1, 1), Vector2(BOSS_W - 62, 3))
	kamae_bg.add_child(kamae_fill)

	exec_rect = Ui.rect(Color(1, 1, 1, 0), Vector2.ZERO, Vector2(480, 270))
	exec_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	play_root.add_child(exec_rect)


## A small readout on a dark plate: the numbers beside the vitals frame and
## the combo.
func _plated(text: String, col: Color) -> Label:
	var l := Ui.label(text, Ui.font_bold, 10, col, 0)
	l.add_theme_stylebox_override("normal", _popup_plate)
	play_root.add_child(l)
	return l


func _build_title() -> void:
	title_root = Control.new()
	title_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title_root)
	# a light shade: the city behind the title is part of the look
	var shade := Ui.rect(Color(0.02, 0.0, 0.05, 0.35), Vector2.ZERO, Vector2(480, 270))
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_root.add_child(shade)
	var a: Color = Game.palette.neon_a
	var b: Color = Game.palette.neon_b
	# the logo, left on two lines: KATANA, then the neon slash and SHOTGUN
	logo_k = GlitchText.new().setup("KATANA", LOGO_PX, Color.WHITE, a, 11, {"accent2": b, "decode": 0.4})
	logo_s = GlitchText.new().setup("SHOTGUN", LOGO_PX, Color.WHITE, a, 12, {"accent2": b, "decode": 0.5})
	title_root.add_child(logo_k)
	title_root.add_child(logo_s)
	logo_slash = Shard.make(a, 0.0, a.darkened(0.6))
	logo_slash.points = PackedVector2Array([Vector2(0.7, 0), Vector2(1, 0), Vector2(0.3, 1), Vector2(0, 1)])
	logo_slash.shadow_off = Vector2(1, 1)
	title_root.add_child(logo_slash)
	# the menu: every choice is a word to click (spec §9.7)
	title_menu = MenuList.new()
	title_menu.pitch = TITLE_PITCH
	title_menu.add("START RUN", func(): Game.main.start_run())
	title_menu.add("NEW RUN", func(): Game.main.abandon_suspended_run(), "N")
	title_menu.add("PLAY A SEED", open_seed_entry, "S")
	title_menu.add("HI-SCORES", func(): _toggle_title_panel("scores"))
	title_menu.add("ARMORY", func(): _toggle_title_panel("armory"))
	title_menu.add("HOW TO PLAY", func(): _toggle_title_panel("howto"))
	title_menu.add("SETTINGS", _open_settings, "TAB")
	title_menu.add("QUIT", Game.quit_game, "Q", {"confirm": "QUIT?  CLICK AGAIN"})
	title_root.add_child(title_menu)
	# the side panel: hi-scores, armory or how to play, one at a time
	title_panel = _side_plate()
	title_panel.visible = false
	title_root.add_child(title_panel)
	title_scores = Ui.label("", Ui.font_mono, 9, Color(0.95, 0.92, 1.0))
	title_panel.add_child(title_scores)
	armory = ArmoryPanel.new()
	title_panel.add_child(armory)
	title_howto = Control.new()
	title_howto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_panel.add_child(title_howto)
	# the controls, a key (or a word) and what it does
	var lines := [
		["LMB", "KATANA - CHARGES THE SHOTGUN", b],
		["RMB", "SHOTGUN - STAGGERS FOES", Color(Game.palette.neon_c)],
		[Ui.key_name("finisher"), "GLORY KILL A STAGGERED FOE", a],
		["SLASH", "DEFLECTS ENEMY BOLTS", b.lerp(Color.WHITE, 0.4)],
		["WASD", "MOVE", Color(0.9, 0.9, 0.95)],
		["SPACE", "JUMP, AGAIN IN THE AIR", Color(0.9, 0.9, 0.95)],
		["SHIFT", "DASH", Color(0.9, 0.9, 0.95)],
		["HEAD", "HEADSHOTS DEAL DOUBLE DAMAGE", a.lerp(Color.WHITE, 0.3)],
		["BOSS", "EVERY 3RD WAVE", a.lerp(Color.WHITE, 0.3)],
	]
	for i in lines.size():
		var k := Ui.label(lines[i][0], Ui.font_bold, 10, lines[i][2])
		k.position = Vector2(0, i * LINE)
		title_howto.add_child(k)
		var l := Ui.label(lines[i][1], Ui.font_bold, 10, Color.WHITE)
		l.position = Vector2(HOWTO_KEY_W, i * LINE)
		title_howto.add_child(l)
	# bottom left: your best and your Player Level, with its XP as a hairline
	title_best = Ui.label("", Ui.font_bold, 10, MenuList.REST, 2)
	title_root.add_child(title_best)
	title_xp_bg = Ui.rect(Color(0.16, 0.13, 0.26, 0.9), Vector2.ZERO, Vector2(1, 1))
	title_root.add_child(title_xp_bg)
	title_xp_fill = Ui.rect(Color(b), Vector2.ZERO, Vector2(1, 1))
	title_root.add_child(title_xp_fill)
	# version name ("0.1 Dev 1"), set once in project.godot (VERSIONING.md, spec S3.2)
	title_version = Ui.label(str(ProjectSettings.get_setting("application/config/version", "")).to_upper(), Ui.font_bold, 10, MenuList.KEY_DIM, 2)
	title_root.add_child(title_version)
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
	title_scores.text = "HI-SCORES\n" + _score_table(-1, 5)
	title_best.text = "BEST %07d     PLAYER LV %d" % [Game.best_score(), Profile.player_level]


## A click on the title away from the menu closes an open side panel
## rather than starting a run; returns whether it closed one.
func close_title_panel() -> bool:
	if _title_panel_kind == "":
		return false
	_toggle_title_panel(_title_panel_kind)
	return true


## HI-SCORES, ARMORY and HOW TO PLAY open beside the menu; choosing the open
## one again closes it.
func _toggle_title_panel(kind: String) -> void:
	_title_panel_kind = "" if _title_panel_kind == kind else kind
	title_menu.current = {"scores": T_SCORES, "armory": T_ARMORY, "howto": T_HOWTO}.get(_title_panel_kind, T_START)
	_refresh_title()


func _build_pause() -> void:
	pause_root = Control.new()
	pause_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_root.visible = false
	root.add_child(pause_root)
	var shade := Ui.rect(Color(0.02, 0.0, 0.05, 0.62), Vector2.ZERO, Vector2(480, 270))
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_root.add_child(shade)
	var t := Ui.label("PAUSED", Ui.font_big, 19, Color.WHITE, 2)
	t.name = "Title"
	pause_root.add_child(t)
	# in a run Q is a dash key, so QUIT GAME has no key here (a lost mouse
	# lock pauses mid-dash); a click anywhere else still resumes
	pause_menu = MenuList.new()
	pause_menu.pitch = PAUSE_PITCH
	pause_menu.add("RESUME", func(): Game.main.resume_game())
	pause_menu.add("ARMORY", func():
		pause_armory_plate.visible = not pause_armory_plate.visible
		pause_menu.current = P_ARMORY if pause_armory_plate.visible else P_RESUME)
	pause_menu.add("SETTINGS", _open_settings, "TAB")
	pause_menu.add("QUIT GAME", Game.quit_game, "", {"confirm": "QUIT?  CLICK AGAIN"})
	pause_root.add_child(pause_menu)
	pause_armory_plate = _side_plate()
	pause_armory_plate.visible = false
	pause_root.add_child(pause_armory_plate)
	pause_armory = ArmoryPanel.new()
	pause_armory.position = Vector2(10, 6)
	pause_armory_plate.add_child(pause_armory)
	# your builds so far, top right, out of the way of the menu
	pause_builds_plate = _side_plate()
	pause_root.add_child(pause_builds_plate)
	var bl := Ui.label("", Ui.font_bold, 10, Upgrades.LINK_COLOR)
	bl.name = "Builds"
	bl.position = Vector2(10, 6)
	pause_builds_plate.add_child(bl)
	# under the builds: the soda cans in hand, each with what it does
	pause_cans_plate = _side_plate()
	pause_cans_plate.visible = false
	pause_root.add_child(pause_cans_plate)
	# bottom: the run's seed to copy (rather than cluttering the live HUD),
	# and the mouse sensitivity, which [ and ] change anywhere
	var sd := Ui.label("", Ui.font_bold, 10, MenuList.REST, 2)
	sd.name = "Seed"
	pause_root.add_child(sd)
	pause_copy = MenuList.new()
	pause_copy.horizontal = true
	pause_copy.current = -1
	pause_copy.add("COPY", copy_seed, "C", {"col": CYAN})
	pause_root.add_child(pause_copy)
	sens_label = Ui.label("", Ui.font_bold, 10, MenuList.KEY_DIM, 2)
	pause_root.add_child(sens_label)
	var lock := Ui.label("MOUSE NOT LOCKING?  CLICK INSIDE THE GAME WINDOW", Ui.font_bold, 10, Color(1.0, 0.6, 0.4), 2)
	lock.name = "LockHint"
	lock.visible = false
	pause_root.add_child(lock)


## A dark plate for a panel beside a menu.
func _side_plate() -> Shard:
	return Shard.make(Color(0.02, 0.01, 0.06, 0.82), 6.0, Color(0, 0, 0, 0), Color(1, 1, 1, 0.18))


func _layout_pause() -> void:
	var t: Label = pause_root.get_node("Title")
	_fit([t])
	t.position = Vector2(PAUSE_X, 44)
	pause_menu.position = Vector2(PAUSE_X, 94)
	# the armory opens under the menu; the builds hold the right side
	pause_armory_plate.size = (pause_armory.size + Vector2(20, 12)).round()
	pause_armory_plate.position = Vector2(PAUSE_X, pause_menu.position.y + pause_menu.size.y + 10.0).round()
	var bl: Label = pause_builds_plate.get_node("Builds")
	bl.size = Vector2.ZERO
	pause_builds_plate.visible = bl.text != ""
	pause_builds_plate.size = (bl.size + Vector2(20, 12)).round()
	pause_builds_plate.position = Vector2(vs.x - PAUSE_X - pause_builds_plate.size.x, 44).round()
	if pause_cans_plate.visible:
		var cw := 0.0
		var ch := 0.0
		for l in pause_cans_plate.get_children():
			if l is Label:
				l.size = Vector2.ZERO
				cw = maxf(cw, l.size.x)
				ch = maxf(ch, l.position.y + l.size.y)
		pause_cans_plate.size = Vector2(cw + 20.0, ch + 4.0).round()
		var cy := 44.0
		if pause_builds_plate.visible:
			cy = pause_builds_plate.position.y + pause_builds_plate.size.y + 6.0
		pause_cans_plate.position = Vector2(vs.x - PAUSE_X - pause_cans_plate.size.x, cy).round()
	var sd: Label = pause_root.get_node("Seed")
	sd.text = "SEED %s" % Game.seed_string(Game.run_seed)
	sd.size = Vector2.ZERO
	var by := vs.y - 24.0
	sd.position = Vector2(PAUSE_X, by)
	pause_copy.position = Vector2(PAUSE_X + sd.size.x + 8.0, by)
	sens_label.text = "MOUSE SENSITIVITY %.1f   [ ]" % (Game.mouse_sensitivity / 0.0024)
	sens_label.size = Vector2.ZERO
	sens_label.position = Vector2(vs.x - PAUSE_X - sens_label.size.x, by)
	var lh: Label = pause_root.get_node("LockHint")
	# the open armory takes the hint's place; the mouse is in use there anyway
	lh.visible = Game.main and Game.main.lock_failures >= 2 and not pause_armory_plate.visible
	lh.size = Vector2.ZERO
	lh.position = Vector2(PAUSE_X, by - 18.0)


func _build_death() -> void:
	death_root = Control.new()
	death_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_root.visible = false
	root.add_child(death_root)
	var shade := Ui.rect(Color(0.12, 0.0, 0.04, 0.62), Vector2.ZERO, Vector2(480, 270))
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_root.add_child(shade)
	var pair := _shadowed("FLATLINED", Ui.font_big, 13, RED, Color(0.3, 0, 0.05), Vector2(1, 1))
	pair[0].name = "Title"
	death_root.add_child(pair[0])
	death_score = Ui.label("", Ui.font_big, 26, Color.WHITE, 2)
	death_root.add_child(death_score)
	death_best = Ui.label("NEW BEST", Ui.font_bold, 10, CARD_INK)
	death_best.add_theme_stylebox_override("normal", _chip(GOLD))
	death_best.visible = false
	death_root.add_child(death_best)
	# every stat of the run, names left and numbers right on one plate
	death_stats_plate = _side_plate()
	death_root.add_child(death_stats_plate)
	death_stats = Ui.label("", Ui.font_bold, 10, MenuList.REST)
	death_stats.add_theme_constant_override("line_spacing", int(RESULTS_ROW) - 16)
	death_stats.position = Vector2(10, 4)
	death_stats_plate.add_child(death_stats)
	death_vals = Ui.label("", Ui.font_bold, 10, Color.WHITE)
	death_vals.add_theme_constant_override("line_spacing", int(RESULTS_ROW) - 16)
	death_vals.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	death_vals.position = Vector2(10, 4)
	death_stats_plate.add_child(death_vals)
	# the hi-score table, with this run's row lit (and its initials typed in)
	death_scores_plate = _side_plate()
	death_root.add_child(death_scores_plate)
	death_scores_head = Ui.label("HI-SCORES", Ui.font_bold, 10, CYAN)
	death_scores_head.position = Vector2(10, 4)
	death_scores_plate.add_child(death_scores_head)
	for i in SCORE_ROWS:
		var y := 4.0 + (i + 1) * RESULTS_ROW + 2.0
		var lit := Ui.rect(Color(GOLD.r, GOLD.g, GOLD.b, 0.25), Vector2(4, y + 2), Vector2(RESULTS_PLATE_W - 8, 13))
		death_scores_plate.add_child(lit)
		var row := [lit]
		# rank and name from the left, score and wave to a right edge
		for c in [[10.0, MenuList.REST, false], [24.0, Color.WHITE, false], [144.0, Color.WHITE, true], [184.0, MenuList.REST, true]]:
			var l := Ui.label("", Ui.font_mono, 9, c[1])
			l.position = Vector2(c[0], y)
			if c[2]:
				l.set_meta("right", c[0])
			death_scores_plate.add_child(l)
			row.append(l)
		death_rows.append(row)
	# the Player Level the run's XP counts into, and the seed to retry or share
	death_level_plate = _side_plate()
	death_root.add_child(death_level_plate)
	level_bar = LevelBar.new(RESULTS_PLATE_W - 20.0)
	level_bar.position = Vector2(10, 4)
	level_bar.leveled.connect(_on_player_level)
	level_bar.finished.connect(_on_level_roll_done)
	death_level_plate.add_child(level_bar)
	death_seed = Ui.label("", Ui.font_bold, 10, MenuList.REST)
	death_level_plate.add_child(death_seed)
	run_card = RunCardPanel.new()
	death_root.add_child(run_card)
	death_menu = MenuList.new()
	death_menu.horizontal = true
	death_menu.current = -1
	death_menu.add("RETRY SEED", func(): Game.main.restart(true), "R", {"col": CYAN})
	death_menu.add("NEW RUN", func(): Game.main.restart(false), "CLICK", {"col": Color.WHITE})
	death_menu.add("RUN CARD", func():
		if run_card.state == RunCardPanel.State.SAVED:
			run_card.open_folder()
		else:
			run_card.make(), "P")
	death_menu.add("COPY SEED", copy_seed, "C")
	death_root.add_child(death_menu)
	death_exit = MenuList.new()
	death_exit.horizontal = true
	death_exit.current = -1
	death_exit.add("MAIN MENU", func(): Game.main.to_title(), "ESC")
	death_root.add_child(death_exit)


## A small solid chip behind a word ("NEW BEST", "RECOMMENDED").
func _chip(col: Color) -> StyleBoxFlat:
	var plate := StyleBoxFlat.new()
	plate.bg_color = col
	plate.content_margin_left = 4
	plate.content_margin_right = 4
	return plate


func _layout_death() -> void:
	var x0 := roundf((vs.x - RESULTS_W) * 0.5)
	var t: Label = death_root.get_node("Title")
	_fit([t, death_score, death_best, death_stats, death_seed])
	t.position = Vector2(roundf((vs.x - t.size.x) * 0.5), 4)
	death_score.position = Vector2(roundf((vs.x - death_score.size.x) * 0.5), 24)
	death_score.pivot_offset = death_score.size * 0.5
	death_best.position = Vector2(roundf((vs.x - death_best.size.x) * 0.5), 66)
	var top := 88.0
	death_stats_plate.position = Vector2(x0, top)
	death_stats_plate.size = Vector2(RESULTS_PLATE_W, 4.0 + _death_full.size() * RESULTS_ROW + 8.0)
	death_vals.size = Vector2(RESULTS_PLATE_W - 20.0, 0)
	var rx := x0 + RESULTS_W - RESULTS_PLATE_W
	death_scores_plate.position = Vector2(rx, top)
	death_scores_plate.size = Vector2(RESULTS_PLATE_W, 4.0 + (SCORE_ROWS + 1) * RESULTS_ROW + 5.0)
	_layout_score_rows()
	var ly := death_scores_plate.position.y + death_scores_plate.size.y + 6.0
	death_level_plate.position = Vector2(rx, ly)
	death_level_plate.size = Vector2(RESULTS_PLATE_W, death_stats_plate.position.y + death_stats_plate.size.y - ly)
	death_seed.text = "SEED %s" % Game.seed_string(Game.run_seed)
	death_seed.position = Vector2(10, level_bar.position.y + level_bar.size.y)
	run_card.place(vs)
	# P saves a card only once the results have counted up
	run_card.set_process_unhandled_input(death_ready())
	death_menu.visible = death_ready()
	death_menu.position = Vector2(roundf((vs.x - death_menu.size.x) * 0.5), vs.y - 22.0)
	death_exit.visible = death_menu.visible
	death_exit.position = Vector2(6, 4) # mirrors the run card's note, top right
	var card_item := "OPEN FOLDER" if run_card.state == RunCardPanel.State.SAVED else ("SAVING..." if run_card.state == RunCardPanel.State.BUSY else "RUN CARD")
	death_menu.set_text(D_CARD, card_item)
	death_menu.set_key(D_CARD, "O" if run_card.state == RunCardPanel.State.SAVED else "P")


## The hi-score rows: the top four, or the top three and this run's row
## when it ranks lower. While initials are typed, they show in the row.
func _layout_score_rows() -> void:
	var shown := _scores_shown
	var rank := Game.last_rank
	var idx: Array[int] = []
	for i in SCORE_ROWS:
		idx.append(i)
	if rank >= SCORE_ROWS:
		idx[SCORE_ROWS - 1] = rank
	var typing := entering and shown
	death_scores_head.text = "TYPE INITIALS + ENTER" if typing else "HI-SCORES"
	death_scores_head.add_theme_color_override("font_color", GOLD if typing else CYAN)
	for r in SCORE_ROWS:
		var row: Array = death_rows[r]
		var i: int = idx[r]
		var have := i < Game.high_scores.size()
		var e: Dictionary = Game.high_scores[i] if have else {}
		var name := str(e.get("name", "---")) if have else "---"
		if typing and i == rank:
			name = ""
			for k in 3:
				name += initials[k] if k < initials.length() else ("_" if (k != initials.length() or fmod(_t, 0.6) < 0.35) else " ")
		var texts := [str(i + 1), name, "%07d" % int(e.score) if have else "-------", "W%d" % int(e.get("wave", 0)) if have else ""]
		(row[0] as ColorRect).visible = shown and i == rank and rank >= 0
		(row[0] as ColorRect).color = Color(GOLD.r, GOLD.g, GOLD.b, 0.25 + (0.15 * sin(_t * 6.0) if typing else 0.0))
		for c in 4:
			var l: Label = row[c + 1]
			l.text = texts[c]
			l.visible = shown
			l.size = Vector2.ZERO
			if l.has_meta("right"):
				l.position.x = float(l.get_meta("right")) - l.size.x


func _build_levelup() -> void:
	levelup_root = Control.new()
	levelup_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	levelup_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	levelup_root.visible = false
	root.add_child(levelup_root)
	var shade := Ui.rect(Color(0.02, 0.0, 0.06, 0.72), Vector2.ZERO, Vector2(480, 270))
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	levelup_root.add_child(shade)
	# HIJACK (spec §9.8): LEVEL UP in dark letters on a solid gold block with
	# a hard lime shadow, like a broadcast caption
	var tb := Shard.make(YELLOW, 0.0, LEVELUP_SHADOW)
	tb.shadow_alpha = 1.0
	tb.shadow_off = Vector2(6, 5)
	tb.name = "TitleBlock"
	levelup_root.add_child(tb)
	var t := Ui.label("LEVEL UP", Ui.font_big, 16, CARD_INK, 0)
	t.name = "Title"
	levelup_root.add_child(t)
	var st := Ui.label(LEVELUP_PROMPT, Ui.font_bold, 10, MenuList.REST, 2)
	st.name = "Sub"
	levelup_root.add_child(st)
	for i in 3:
		var card := Control.new()
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.size = Vector2(CARD_W, CARD_MIN_H)
		# a dark card with a hard shadow in its tag's colour (HIJACK)
		var bg := Shard.make(Color(0.03, 0.02, 0.07, 0.97), 0.0, Color(0, 0, 0, 0), CARD_EDGE)
		bg.shadow_alpha = 1.0
		bg.shadow_off = Vector2(5, 5)
		bg.name = "Bg"
		card.add_child(bg)
		# the tag ribbon across the top: the tag left, the card's key right,
		# dark on the tag's colour
		var ribbon := Ui.rect(Color.WHITE, Vector2(CARD_PAD, 1), Vector2(CARD_W - CARD_PAD - 1, 15))
		ribbon.name = "Ribbon"
		card.add_child(ribbon)
		var tag := Ui.label("", Ui.font_bold, 10, CARD_INK)
		tag.name = "Tag"
		tag.position = Vector2(CARD_PAD + 4, 1)
		card.add_child(tag)
		var key := Ui.label(str(i + 1), Ui.font_bold, 10, CARD_INK)
		key.position = Vector2(CARD_W - 6 - 20, 1)
		key.size = Vector2(20, 0)
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		card.add_child(key)
		var nm := Ui.label("", Ui.font_bold, 10, Color.WHITE)
		nm.name = "Name"
		nm.position = Vector2(CARD_PAD, 20)
		nm.size = Vector2(CARD_W - CARD_PAD * 2, 0)
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD
		nm.add_theme_constant_override("line_spacing", CARD_LINE_GAP)
		card.add_child(nm)
		# rank: a pip per rank, lit up to the rank this pick gives
		var pips := Control.new()
		pips.name = "Pips"
		pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for k in 3:
			pips.add_child(Ui.rect(PIP_OFF, Vector2(k * 11, 0), Vector2(8, 3)))
		card.add_child(pips)
		var rk := Ui.label("", Ui.font_bold, 10, Color.WHITE)
		rk.name = "Rank"
		card.add_child(rk)
		var desc := Ui.label("", Ui.font_bold, 10, CARD_TEXT)
		desc.name = "Desc"
		desc.size = Vector2(CARD_W - CARD_PAD * 2, 0)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc.add_theme_constant_override("line_spacing", CARD_LINE_GAP)
		card.add_child(desc)
		# the builds this card belongs to, over a rule at the bottom edge
		var rule := Ui.rect(CARD_EDGE, Vector2(CARD_PAD, 0), Vector2(CARD_W - CARD_PAD * 2, 1))
		rule.name = "Rule"
		card.add_child(rule)
		var bl := Ui.label("", Ui.font_bold, 10, MenuList.KEY_DIM)
		bl.name = "Builds"
		bl.position.x = CARD_PAD
		bl.add_theme_constant_override("line_spacing", CARD_LINE_GAP)
		card.add_child(bl)
		# a tab above the card when it links to a card you already own
		var rec := Ui.label("RECOMMENDED", Ui.font_bold, 10, CARD_INK)
		rec.name = "Rec"
		rec.add_theme_stylebox_override("normal", _chip(Upgrades.LINK_COLOR))
		rec.visible = false
		card.add_child(rec)
		levelup_root.add_child(card)
		cards.append(card)
	# a first click lifts a card; this plate asks for the second
	var confirm := Ui.label("", Ui.font_bold, 10, Color.WHITE)
	confirm.name = "Confirm"
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(0.02, 0.01, 0.06, 0.9)
	plate.border_color = Upgrades.LINK_COLOR
	plate.set_border_width_all(1)
	plate.content_margin_left = 8
	plate.content_margin_right = 8
	confirm.add_theme_stylebox_override("normal", plate)
	confirm.visible = false
	levelup_root.add_child(confirm)
	cursor = Ui.label("+", Ui.font_big, 8, Color.WHITE, 2)
	cursor.set_meta("uiaudit_skip", true) # the pointer may pass over anything
	levelup_root.add_child(cursor)


# ---------------------------------------------------------------- overlays
func show_title() -> void:
	_title_t = 0.0
	_title_hit = false
	# a suspended run is the default: click carries on, N starts over
	var snap: Dictionary = Game.main.resume if Game.main else {}
	title_menu.set_text(T_START, "START RUN" if snap.is_empty() else "CONTINUE  WAVE %d" % int(snap.get("next_wave", 1)))
	title_menu.set_visible_item(T_NEW, not snap.is_empty())
	_title_panel_kind = ""
	title_menu.current = T_START
	title_menu.disarm()
	_refresh_title()
	title_root.visible = true
	play_root.visible = false


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
	# the pieces of it that live under the HUD freeze with it
	warn_band.process_mode = juice.process_mode
	juice.giant().process_mode = juice.process_mode
	pause_menu.disarm()
	pause_menu.current = P_RESUME
	pause_armory_plate.visible = false
	var lines := Upgrades.build_lines(Game.upgrades)
	var bl: Label = pause_builds_plate.get_node("Builds")
	bl.text = "BUILDS\n" + "\n".join(lines) if not lines.is_empty() else ""
	_fill_pause_cans()
	if not on:
		settings_menu.close()


## The pause screen's soda can plate: a line per can in hand, its name in its
## colour and what it does, crash included, under it.
func _fill_pause_cans() -> void:
	for ch in pause_cans_plate.get_children():
		if ch is Label:
			ch.queue_free()
			pause_cans_plate.remove_child(ch)
	var cans := Game.cans
	if not is_instance_valid(cans) or not cans.enabled or cans.held.is_empty():
		pause_cans_plate.visible = false
		return
	pause_cans_plate.visible = true
	var y := 6.0
	var head := Ui.label("SODA CANS IN HAND", Ui.font_bold, 10, Color.WHITE)
	head.position = Vector2(10, y)
	pause_cans_plate.add_child(head)
	for id in cans.held:
		var def := Soda.get_def(id)
		y += LINE
		var n := Ui.label(str(def.name), Ui.font_bold, 10, def.color)
		n.position = Vector2(10, y)
		pause_cans_plate.add_child(n)
		y += LINE
		var d := Ui.label(str(def.desc), Ui.font_bold, 10, CARD_TEXT)
		d.position = Vector2(10, y)
		pause_cans_plate.add_child(d)


func _open_settings() -> void:
	if settings_menu.can_open():
		settings_menu.open()


## The title's PLAY A SEED box (S or its button).
func open_seed_entry() -> void:
	if Game.state != "title" or settings_menu.visible or seed_entry.visible:
		return
	title_menu.disarm()
	seed_entry.open(Game.main != null and not Game.main.resume.is_empty())


## Puts this run's seed on the clipboard, to paste to a friend.
func copy_seed() -> void:
	DisplayServer.clipboard_set(Game.seed_string(Game.run_seed))
	if pause_root.visible:
		pause_copy.flash(0, "COPIED")
	elif death_root.visible:
		death_menu.flash(D_COPY, "COPIED")
	Sfx.play("ui_click", -4.0)


## Q on the title: QUIT asks once more, like a click on it.
func press_title_quit() -> void:
	title_menu.press(T_QUIT)


func show_death() -> void:
	_death_t = 0.0
	_death_lines = 0
	_death_counted = false
	_scores_shown = false
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
	# names and numbers are two columns: padding with spaces drifts by a few
	# pixels in this font, so the numbers would not line up
	_death_full = PackedStringArray(["WAVE REACHED", "BOSSES SLAIN", "KILLS", "GLORY KILLS", "HEADSHOT KILLS", "DEFLECTS", "BEST COMBO", "RUN LV", "TIME"])
	_death_vals_full = PackedStringArray([str(Game.wave), str(Game.bosses_killed), str(Game.kills), str(Game.executions), str(Game.headshots), str(Game.deflects), "x%d" % Game.best_combo, str(Game.level), "%d:%02d" % [mins, secs]])
	entering = Game.last_rank >= 0 and not Game.debug_autoplay
	initials = ""
	death_best.visible = false
	death_stats.text = ""
	death_vals.text = ""
	death_score.text = "%07d" % 0
	death_menu.disarm()
	death_exit.disarm()
	run_card.reset()


func _finish_initials() -> void:
	var tag := initials
	while tag.length() < 3:
		tag += "-"
	Game.submit_score(tag)
	entering = false
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
	death_score.text = "%07d" % shown
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
		_scores_shown = true
		death_best.visible = Game.last_rank == 0 and Game.score > 0
		if entering:
			Sfx.play("highscore", -2.0)
			juice.firework(Vector2(vs.x * 0.25, vs.y * 0.3), Color(Game.palette.neon_a))
			juice.later(0.25, func(): juice.firework(Vector2(vs.x * 0.75, vs.y * 0.28), Color(Game.palette.neon_b)))
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
	warn_band.stop()
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
	# the card deals into the bottom of the screen: the warning lane clears
	hint_bg.visible = false
	warn_band.stop()
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
	juice.boss_card(title_text, sub_text)


## The boss name card makes way for a newer message in the top lane.
func end_boss_card() -> void:
	juice.end_boss_card()


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
	var h := CARD_MIN_H
	for i in cards.size():
		var card: Control = cards[i]
		card.visible = i < choices.size()
		if i >= choices.size():
			continue
		h = maxf(h, _fill_card(card, choices[i]))
	# every card takes the tallest card's height, the builds on its bottom edge
	for card: Control in cards:
		card.size.y = h
		(card.get_node("Bg") as Shard).size = card.size
		var bl: Label = card.get_node("Builds")
		bl.position.y = h - 6.0 - _lines_h(bl)
		var rule: ColorRect = card.get_node("Rule")
		rule.visible = bl.text != ""
		rule.position.y = bl.position.y - 2.0
	levelup_root.get_node("Confirm").visible = false


## Writes one augment onto a card; returns the height its text needs.
func _fill_card(card: Control, u: Dictionary) -> float:
	var col: Color = Upgrades.TAG_COLORS.get(u.tag, Color.WHITE)
	(card.get_node("Ribbon") as ColorRect).color = col
	card.get_node("Tag").text = u.tag
	var nm: Label = card.get_node("Name")
	nm.text = u.name
	var y := nm.position.y + _lines_h(nm)
	# the rank this pick gives, for cards taken more than once
	var r := Game.rank(u.id)
	var pips: Control = card.get_node("Pips")
	var rk: Label = card.get_node("Rank")
	pips.visible = u.max > 1
	rk.visible = u.max > 1
	if u.max > 1:
		for k in 3:
			var p: ColorRect = pips.get_child(k)
			p.visible = k < u.max
			p.color = col if k <= r else PIP_OFF
		rk.text = "RANK %d" % (r + 1)
		rk.add_theme_color_override("font_color", col)
		pips.position = Vector2(CARD_PAD, y + 5.0)
		rk.position = Vector2(CARD_PAD + u.max * 11 + 3, y - 1.0)
		y += 15.0
	var desc: Label = card.get_node("Desc")
	desc.text = u.desc
	desc.position = Vector2(CARD_PAD, y + 4.0)
	y = desc.position.y + _lines_h(desc)
	var rec := Upgrades.is_recommended(u.id, Game.upgrades)
	var tab: Label = card.get_node("Rec")
	tab.visible = rec
	tab.size = Vector2.ZERO
	tab.position = Vector2(roundf((CARD_W - tab.size.x) * 0.5), -tab.size.y)
	# each build line counts what you would own after this pick
	var after := Game.upgrades.duplicate()
	after[u.id] = Game.rank(u.id) + 1
	var lines := []
	for b in Upgrades.builds_of(u.id):
		lines.append("%s %d/3" % [b.name, Upgrades.build_count(b, after)])
	var bl: Label = card.get_node("Builds")
	bl.text = "\n".join(lines)
	bl.add_theme_color_override("font_color", Upgrades.LINK_COLOR if rec else MenuList.KEY_DIM)
	card.set_meta("rec", rec)
	card.set_meta("col", col)
	var builds_h := _lines_h(bl) + 10.0 if not lines.is_empty() else 0.0
	return ceilf(y + 8.0 + builds_h)


## The height of a label's text lines, without the gap after the last.
static func _lines_h(l: Label) -> float:
	var gap := l.get_theme_constant("line_spacing")
	return l.get_line_count() * (l.get_line_height() + gap) - gap


func hide_levelup() -> void:
	levelup_root.visible = false
	play_root.visible = not death_root.visible and not title_root.visible


func _input(event: InputEvent) -> void:
	if entering and death_root.visible and _scores_shown:
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
	var cf: Label = levelup_root.get_node("Confirm")
	cf.visible = i >= 0
	if i >= 0:
		cf.text = "TAKE %s?  CLICK AGAIN OR PRESS %d" % [_choices[i].name, i + 1]


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
	juice.burst(base + c.size * 0.5, LEVELUP_SHADOW, 24, 160.0)
	if post:
		post.invert_flash(0.05)
	var id: String = _choices[i].id
	juice.later(0.34, func():
		_choices = []
		_choice_cb.call(id))


# ---------------------------------------------------------------- events
## A boss message ("<NAME> IS ENRAGED"): a stamp in the top lane, where the
## big moments go (spec §9.7).
func show_message(text: String, color: Color, big := true) -> void:
	juice.stamp(text, color, 16 if big else 14, {"lane": "top", "font": Ui.font_big, "from": 1.8, "hold": 1.6, "shake": 3.0, "sound": "", "shadow": color.darkened(0.8)})


## The text box's bottom, less the empty space a label keeps under its capitals.
static func _text_bottom(l: Control) -> float:
	return l.position.y + roundf(l.size.y * 0.85)


## A soda can was opened: its name slams into the top lane in its colour, a
## burst of its colour sprays off the can and the frame's corners flash.
func soda_drank(def: Dictionary) -> void:
	var col: Color = def.color
	# one message per lane: the name waits out nothing, but never covers FIGHT
	if not juice.intro_showing():
		juice.stamp(str(def.name), col, 16, {"lane": "top", "from": 2.2, "hold": 0.9, "shake": 3.0, "sound": "", "burst": 16, "shadow": col.darkened(0.75)})
	juice.burst((vs * Vector2(0.54, 0.6)).round(), col, 22, 120.0)
	soda_hud.flash(col)


## Where the top lane starts: under the wave, the score and the boss bar. The
## big moments, the wave intro and the boss card sit here, so they never
## cover the top row (spec §9.7).
func top_lane() -> float:
	var y := maxf(_text_bottom(score_label), _text_bottom(foes_label))
	if boss_root.visible:
		y = maxf(y, boss_root.position.y + _boss_plate_h)
	return roundf(y + 3.0)


## The KAMAE row under the boss's HP bar. While the stance is broken the bar
## shows the time left to land the ONIKIRI, glowing gold to white; the word
## itself never moves or changes (spec §9.9).
func _layout_kamae(boss: Enemy) -> void:
	var row_y := 19.0
	var lh := kamae_label.size.y
	kamae_label.position = Vector2(8, row_y - 2)
	var bar_x := 8.0 + kamae_label.size.x + 4.0
	var bar_w := BOSS_W - 8.0 - bar_x
	kamae_bg.size = Vector2(bar_w, 5)
	kamae_bg.position = Vector2(bar_x, row_y + roundf((lh - 5.0) * 0.5) - 1.0)
	_boss_plate_h = row_y + roundf(lh * 0.85) - 1.0
	var k := 0.0
	var col := KAMAE_GOLD
	if boss.is_staggered():
		k = clampf(1.0 - boss.state_t / boss.stagger_length(), 0.0, 1.0)
		col = KAMAE_GOLD.lerp(Color.WHITE, 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012))
	elif boss.kamae:
		k = boss.kamae.ratio()
		if k >= KAMAE_HOT_AT:
			col = KAMAE_HOT
	var inner := bar_w - 2.0
	var w := roundf(inner * k)
	kamae_fill.size.x = w
	kamae_fill.position.x = 1.0 + roundf((inner - w) * 0.5)
	kamae_fill.color = col


## A boss's stance just broke: the KIRI card in the top lane on a gold
## impact frame (Juice.kamae_broken). The prompt under the crosshair says
## what F does next.
func kamae_broken() -> void:
	juice.kamae_broken()


## Warnings and hints share one lane at the bottom centre: the head line in
## the lane's colour (red for a warning, yellow for a hint, or `tint`: a soda
## can's pickup line takes its can's colour), the rest of the sentence white
## under it. A new one replaces the old.
func show_hint(text: String, warn := false, tint := Color(0, 0, 0, 0)) -> void:
	if juice.intro_showing() or juice.panel_showing() or reward_card.visible:
		# the intro, a big panel or the reward card holds the screen; the hint waits
		_hint_wait = text
		_hint_wait_warn = warn
		_hint_wait_tint = tint
		return
	var parts := split_hint(text)
	warn_band.stop()
	if warn:
		# HIJACK: an emergency band across the screen in the same lane
		hint_bg.visible = false
		warn_band.bottom = vs.y - HINT_BOTTOM
		warn_band.play(parts[0], parts[1] if parts.size() > 1 else "", 4.5)
		if post:
			post.roll(0.1)
		return
	var col := tint if tint.a > 0.0 else YELLOW
	hint_label.text = _wrap(parts[0], hint_label, vs.x - 80.0)
	hint_label.add_theme_color_override("font_color", col)
	hint_sub.visible = parts.size() > 1
	hint_sub.text = _wrap(parts[1], hint_sub, vs.x - 80.0) if parts.size() > 1 else ""
	hint_bg.outline = col
	hint_bg.visible = true
	# hidden until its first layout, so it never shows a frame at the corner
	hint_bg.modulate.a = 0.0
	hint_t = 0.0


## Splits a hint into its head and the line under it, at the first dash,
## colon, "!" or "?" ("MISSILES INBOUND - GET OUT OF THE RED CIRCLES").
static func split_hint(text: String) -> PackedStringArray:
	var at := -1
	var sep := ""
	for s in [" - ", ": ", "! ", "? "]:
		var i := text.find(s)
		if i > 0 and (at < 0 or i < at):
			at = i
			sep = s
	if at < 0:
		return PackedStringArray([text.strip_edges()])
	var head := text.left(at + (1 if sep[0] in "!?" else 0)).strip_edges()
	var rest := text.substr(at + sep.length()).strip_edges()
	if rest == "":
		return PackedStringArray([head])
	return PackedStringArray([head, rest])


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
	if juice.kiri_points(text):
		# a glory kill's points join its card in the top lane
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
		# HIJACK (spec §9.8): the newest callout is a solid chip in its colour
		# with dark letters and a hard shadow; older ones turn to a dark plate
		# with coloured letters and a coloured edge. Each owns its plate.
		l = Ui.label(text, Ui.font_bold, 10, color, 0)
		var plate := StyleBoxFlat.new()
		plate.content_margin_left = 3
		plate.content_margin_right = 3
		plate.content_margin_top = 0
		plate.content_margin_bottom = 0
		l.add_theme_stylebox_override("normal", plate)
		var sh := Ui.rect(CARD_INK, Vector2(4, 3), Vector2(10, 10))
		sh.name = "Shadow"
		sh.set_meta("uiaudit_skip", true) # the callout's own shadow, not a panel
		sh.show_behind_parent = true
		l.add_child(sh)
		play_root.add_child(l)
	else:
		l = _popup_free.pop_back()
		l.text = text
		l.visible = true
	_style_popup(l, color, true)
	l.position = Vector2((vs * 0.5).floor().x + Crosshair.H + CALLOUT_X, (vs * 0.5).floor().y - 16.0)
	if not popups.is_empty() and popups[0].live:
		_style_popup(popups[0].l, popups[0].c, false)
		popups[0].live = false
	popups.push_front({"l": l, "t": 0.0, "y": l.position.y, "text": text, "n": 1, "c": color, "live": true})


## A callout's look: live (the newest) is a solid chip with dark letters and
## a hard shadow; older ones are dark with coloured letters and edge.
func _style_popup(l: Label, color: Color, live: bool) -> void:
	var plate: StyleBoxFlat = l.get_theme_stylebox("normal")
	plate.bg_color = color if live else Color(0.02, 0.0, 0.05, 0.86)
	plate.border_color = color
	plate.border_width_left = 0 if live else 2
	l.add_theme_color_override("font_color", CARD_INK if live else color)
	l.get_node("Shadow").visible = live


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
	_fit([hint_label, hint_sub, combo_label, score_label, foes_label, wave_label, hp_label, sens_label, death_stats])
	vs = root.get_rect().size
	if vs.x < 10:
		vs = Vector2(480, 270)
	if title_root.visible:
		_layout_title()
	if pause_root.visible:
		_layout_pause()
	if death_root.visible:
		_death_t += delta
		_death_countup()
		_layout_death()
	if levelup_root.visible:
		_layout_levelup()
	if play_root.visible:
		_update_play(delta)


func _layout_title() -> void:
	_fit([title_best, title_version, title_scores])
	# logo: KATANA flies in from the left, SHOTGUN from the right, then the
	# slash cuts down in front of SHOTGUN
	_title_t += Game.real_dt
	var tt := _title_t
	var x0 := TITLE_X
	var kin := Juice.ease_out(tt / 0.3)
	var pad := logo_k._pad()
	var ky := 18.0
	var sy := ky + LOGO_LINE
	logo_k.position = Vector2(x0 - pad.x - (1.0 - kin) * 300.0, ky).round()
	logo_s.position = Vector2(x0 + SLASH_W + 6.0 - pad.x + (1.0 - kin) * 300.0, sy).round()
	var cap_top := sy + pad.y + LOGO_CAP_TOP
	var sk := clampf((tt - 0.32) / 0.07, 0.0, 1.0)
	logo_slash.visible = tt > 0.32
	logo_slash.size = Vector2(SLASH_W, LOGO_CAP * sk)
	logo_slash.position = Vector2(x0, cap_top)
	if tt > 0.39 and not _title_hit:
		_title_hit = true
		Sfx.play("swing2", -3.0, 1.1)
		Sfx.play("slice", -2.0)
		juice.add_shake(6.0)
		juice.speed_lines(0.8, 0.1)
		juice._shards.burst(logo_slash.position + Vector2(SLASH_W * 0.5, LOGO_CAP * 0.5), Color(Game.palette.neon_a), 16, 260.0, true)
	logo_slash.color = Color.WHITE if fmod(_t, 3.1) < 0.06 else Color(Game.palette.neon_a)
	# the menu under the logo, the side panel beside it
	title_menu.position = Vector2(x0, cap_top + LOGO_CAP + 18.0).round()
	_layout_title_panel()
	# bottom row: best and level left (the XP as a hairline under it), version right
	var by := vs.y - 22.0
	title_best.position = Vector2(x0, by)
	var need := Progression.xp_to_next(Profile.player_level)
	title_xp_bg.position = Vector2(x0, _text_bottom(title_best) + 2.0)
	title_xp_bg.size = Vector2(title_best.size.x, 2)
	title_xp_fill.position = title_xp_bg.position
	title_xp_fill.size = Vector2(roundf(title_best.size.x * clampf(Profile.player_xp / float(need), 0.0, 1.0)), 2)
	title_version.position = Vector2(vs.x - 8.0 - title_version.size.x, by)


func _layout_title_panel() -> void:
	title_panel.visible = _title_panel_kind != ""
	if not title_panel.visible:
		return
	title_scores.visible = _title_panel_kind == "scores"
	armory.visible = _title_panel_kind == "armory"
	title_howto.visible = _title_panel_kind == "howto"
	var inner := Vector2.ZERO
	match _title_panel_kind:
		"scores":
			inner = title_scores.size
		"armory":
			inner = armory.size
		"howto":
			for l: Label in title_howto.get_children():
				l.size = Vector2.ZERO
				inner = Vector2(maxf(inner.x, l.position.x + l.size.x), l.position.y + l.size.y)
	var pad := Vector2(10, 6)
	for c: Control in [title_scores, armory, title_howto]:
		c.position = pad
	title_panel.size = (inner + pad * 2.0).round()
	title_panel.position = Vector2(title_menu.position.x + TITLE_MENU_W + 16.0, title_menu.position.y - pad.y).round()


func _layout_levelup() -> void:
	var rd := Game.real_dt
	_deal_t += rd
	if _picked >= 0:
		_pick_t += rd
	var t: Label = levelup_root.get_node("Title")
	var tb: Shard = levelup_root.get_node("TitleBlock")
	t.size = Vector2.ZERO
	# the block opens from a scan line, the word lands with a short stretch,
	# and on a pick the block collapses back into a line
	var ok := Juice.ease_out(_deal_t / 0.06)
	if _picked >= 0:
		ok *= 1.0 - clampf(_pick_t / 0.14, 0.0, 1.0)
	var bw := t.size.x + 52.0
	var bh := roundf(t.size.y * 0.8) + 6.0
	var hh := maxf(1.0, roundf(bh * 0.5 * ok))
	tb.position = Vector2(roundf((vs.x - bw) * 0.5), 6.0 + roundf(bh * 0.5) - hh)
	tb.size = Vector2(bw, hh * 2.0)
	var sk := clampf((_deal_t - 0.02) / 0.08, 0.0, 1.0)
	t.pivot_offset = (t.size * 0.5).round()
	t.scale = Vector2(lerpf(2.2, 1.0, sk * sk), 1.0)
	t.modulate.a = 1.0 if ok > 0.6 else 0.0
	t.position = Vector2(roundf((vs.x - t.size.x) * 0.5), 6.0 + roundf((bh - t.size.y) * 0.5))
	var st: Label = levelup_root.get_node("Sub")
	st.size = Vector2.ZERO
	st.position = Vector2(roundf((vs.x - st.size.x) * 0.5), 6.0 + bh + 2.0)
	var n := _choices.size()
	var total := n * CARD_W + (n - 1) * CARD_GAP
	var bottom := CARD_TOP
	for i in cards.size():
		var card: Control = cards[i]
		if not card.visible:
			continue
		var hov := i == hovered and _picked < 0
		var sel := i == _selected and _picked < 0
		var base := Vector2((vs.x - total) * 0.5 + i * (CARD_W + CARD_GAP), CARD_TOP).round()
		card.set_meta("base", base)
		bottom = maxf(bottom, base.y + card.size.y)
		# HIJACK: each card opens from a scan line in turn, then holds still:
		# once open a card is never squashed or scaled, so its pixel text
		# stays sharp (§9.9)
		var dk := clampf((_deal_t - (0.06 + i * 0.11)) / 0.08, 0.0, 1.0)
		var sy := Juice.ease_out(dk)
		var off_y := 0.0
		var off_x := 0.0
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
				# the others are pulled off the air: they collapse into a line
				# and are shoved aside
				var ck := clampf(_pick_t / 0.14, 0.0, 1.0)
				sy *= 1.0 - ck
				off_x = (-1.0 if i < _picked else 1.0) * ck * ck * 120.0
				card.modulate.a = 1.0 - ck * 0.7
		card.pivot_offset = card.size * 0.5
		card.scale = Vector2(sc, sc * maxf(sy, 0.02))
		card.rotation = 0.0
		card.position = base + Vector2(roundf(off_x), roundf(off_y))
		# the outline: white when chosen, gold when it links to your build,
		# the tag's colour while pointed at
		var col: Color = card.get_meta("col", Color.WHITE)
		var bg: Shard = card.get_node("Bg")
		var edge := CARD_EDGE
		if card.get_meta("rec", false):
			edge = Upgrades.LINK_COLOR
		if hov:
			edge = col
		if sel or i == _picked:
			edge = Color.WHITE
		bg.outline = edge
		# the hard shadow: the tag's colour, gold and deeper when chosen, and
		# the ribbon turns white
		var chosen := sel or i == _picked
		bg.shadow = YELLOW if chosen else col
		bg.shadow_off = Vector2(8, 8) if chosen else Vector2(5, 5)
		(card.get_node("Ribbon") as ColorRect).color = Color.WHITE if chosen else col
		var glow := 0.6 * exp(-_pick_t * 6.0) if i == _picked else 0.0
		bg.color = Color(0.03, 0.02, 0.07, 0.96).lerp(Color(col.r, col.g, col.b, 0.96), glow)
	var cf: Label = levelup_root.get_node("Confirm")
	cf.visible = _selected >= 0 and _picked < 0
	cf.size = Vector2.ZERO
	cf.position = Vector2(roundf((vs.x - cf.size.x) * 0.5), minf(bottom + 10.0, vs.y - cf.size.y - 4.0))
	cursor.position = cursor_pos - Vector2(4, 4)


func _update_play(delta: float) -> void:
	var p := Game.player
	if p == null:
		return
	var m := 8.0
	_fit([wave_label, foes_label, mut_label, boss_name, kamae_label, hp_label, cell_label, noammo_label, combo_label])
	var c := (vs * 0.5).floor()
	var fh := float(Crosshair.H)
	# ---- the vitals frame round the crosshair. FINISH, the payout and the
	# boss-defeated card own the middle of the screen: it steps aside for them
	var vitals := not juice.panel_showing()
	var hpk := clampf(p.hp / p.max_hp, 0.0, 1.0)
	_hp_ghost_v = move_toward(_hp_ghost_v, hpk, delta * 0.6) if _hp_ghost_v > hpk else hpk
	# low health pulses the bar and turns the number red; the number never flashes
	var low := hpk < 0.3
	for i in _cell_flash.size():
		if i < p.cells and i >= _last_cells:
			_cell_flash[i] = 1.0
		_cell_flash[i] = move_toward(_cell_flash[i], 0.0, delta * 5.0)
	_last_cells = p.cells
	crosshair.position = c
	crosshair.frame = vitals
	crosshair.hp_k = hpk
	crosshair.ghost_k = _hp_ghost_v
	crosshair.low_t = _t if low else -1.0
	crosshair.cells = p.cells
	crosshair.max_cells = p.max_cells
	crosshair.cell_flash = _cell_flash
	crosshair.dash = p.dash_charges
	crosshair.max_dash = p.max_dash
	crosshair.queue_redraw()
	soda_hud.refresh(c, vitals, delta)
	hp_label.visible = vitals
	cell_label.visible = vitals
	hp_label.text = str(int(ceil(p.hp)))
	hp_label.add_theme_color_override("font_color", LOW_RED if low else Color.WHITE)
	hp_label.size = Vector2.ZERO
	hp_label.position = Vector2(c.x - fh - 5.0 - hp_label.size.x, roundf(c.y - hp_label.size.y * 0.5))
	cell_label.text = str(p.cells)
	cell_label.add_theme_color_override("font_color", CYAN if p.cells > 0 else LOW_RED)
	cell_label.size = Vector2.ZERO
	cell_label.position = Vector2(c.x + fh + 5.0, roundf(c.y - cell_label.size.y * 0.5))
	# ---- out of cells: a short steady warning left of the health number
	noammo_t += delta
	noammo_bg.visible = vitals and noammo_t < 1.4
	if noammo_bg.visible:
		noammo_label.position = Vector2(5, 0)
		noammo_bg.size = noammo_label.size + Vector2(10, 0)
		# placed for a three-digit health number, so it never shifts as health changes
		var hp_w := maxf(hp_label.size.x, HP_PLATE_W)
		noammo_bg.position = Vector2(c.x - fh - 5.0 - hp_w - 4.0 - noammo_bg.size.x, roundf(c.y - noammo_bg.size.y * 0.5))
		noammo_bg.modulate.a = clampf((1.4 - noammo_t) / 0.25, 0.0, 1.0)
	# ---- run XP: a hairline along the bottom edge
	xp_bg.position = Vector2(0, vs.y - 2)
	xp_bg.size = Vector2(vs.x, 2)
	xp_fill.size = Vector2(roundf(vs.x * clampf(Game.xp / Game.xp_next, 0.0, 1.0)), 2)
	# ---- top-left: the wave and the hostiles left
	wave_label.text = "WAVE %02d" % Game.wave
	wave_label.position = Vector2(m, 1)
	foes_label.text = ("%d LEFT" % Game.main.hostiles_left()) if Game.main else ""
	foes_label.position = Vector2(m, wave_label.position.y + LINE)
	# ---- bottom-left: the wave's mutator (the reward card takes the bottom
	# of the screen between waves)
	mut_label.visible = not Game.mutator.is_empty() and not reward_card.visible
	mut_label.position = Vector2(m, vs.y - 5 - mut_label.size.y)
	# ---- NEW HI-SCORE: one cut-in when the run passes the best score
	var best := Game.best_score()
	var shown_score := Game.score - score_hold
	if shown_score > best and best > 0 and not _hi_stamped and Game.state == "playing" and not Game.cans_run:
		_hi_stamped = true
		juice.hiscore_stamp()
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
	score_label.size = Vector2.ZERO
	score_label.pivot_offset = Vector2(score_label.size.x, score_label.size.y * 0.5)
	score_label.scale = Vector2.ONE * (1.0 + 0.2 * _score_bump * _score_bump)
	score_label.add_theme_color_override("font_color", Color.WHITE.lerp(Juice.GOLD, minf(1.0, _score_bump * 1.5)))
	score_label.position = Vector2(vs.x - m - score_label.size.x, SCORE_Y)
	# ---- boss bar: top centre, between the wave and the score
	var boss: Enemy = Game.main.boss if Game.main else null
	var boss_on := boss != null and is_instance_valid(boss) and not boss.dead
	boss_root.visible = boss_on
	if boss_on:
		boss_name.text = boss.display_name
		var bx := roundf((vs.x - BOSS_W) * 0.5)
		var by := 3.0
		# a narrow screen: under the top row, never on the wave or the score
		var left := m + maxf(wave_label.size.x, foes_label.size.x) + 6.0
		if bx < left or bx + BOSS_W > score_label.position.x - 6.0:
			by = maxf(_text_bottom(score_label), _text_bottom(foes_label)) + 2.0
		boss_root.position = Vector2(bx, by)
		boss_name.position = Vector2(roundf((BOSS_W - boss_name.size.x) * 0.5), -2)
		var bk := clampf(boss.hp / boss.max_hp, 0.0, 1.0)
		_boss_ghost_v = move_toward(_boss_ghost_v, bk, delta * 0.5) if _boss_ghost_v > bk else bk
		boss_fill.size.x = roundf((BOSS_W - 18.0) * bk)
		boss_ghost.size.x = roundf((BOSS_W - 18.0) * _boss_ghost_v)
		_layout_kamae(boss)
		var bp: Shard = boss_root.get_node("Plate")
		bp.size = Vector2(BOSS_W, _boss_plate_h)
	else:
		_boss_ghost_v = 1.0
	# ---- combo: under the frame; pops on every kill, heats up, milestones stamp
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
	var combo_on := Game.combo >= 2 and vitals
	combo_label.visible = combo_on
	combo_bar.visible = combo_on
	if combo_on:
		combo_label.text = "x%d" % Game.combo
		combo_label.size = Vector2.ZERO
		var heat := clampf(Game.combo / 50.0, 0.0, 1.0)
		var ccol := YELLOW.lerp(Color(1.0, 0.25, 0.55), heat)
		if Game.combo >= 50:
			ccol = Color.from_hsv(fmod(_t * 0.5, 1.0), 0.55, 1.0)
		combo_label.add_theme_color_override("font_color", ccol.lerp(Color.WHITE, _combo_pop * 0.5))
		combo_label.position = Vector2(roundf(c.x - combo_label.size.x * 0.5), c.y + fh + COMBO_GAP)
		combo_label.pivot_offset = (combo_label.size * 0.5).round()
		combo_label.scale = Vector2.ONE * (1.0 + 0.15 * _combo_pop * _combo_pop)
		var cw := combo_label.size.x - 6.0
		combo_bar.color = ccol
		combo_bar.size = Vector2(roundf(cw * clampf(Game.combo_timer / Game.combo_window(), 0.0, 1.0)), 1)
		combo_bar.position = Vector2(combo_label.position.x + 3.0, combo_label.position.y + combo_label.size.y - 4.0)
	# ---- glory kill prompt: a fixed spot under the combo
	var move := ""
	if is_instance_valid(p.gk_ready):
		if p.gk_ready_plunge:
			move = "PLUNGE"
		else:
			move = FinisherPromptScript.BOSS_MOVE if p.gk_ready.is_boss else "GLORY KILL"
	elif finisher_demo:
		move = "GLORY KILL"
	finisher_prompt.refresh(move, c, delta)
	# ---- warnings and hints: bottom centre, one at a time
	hint_t += delta
	if juice.panel_showing():
		# FINISH, the payout and the boss-defeated card own the screen
		hint_bg.visible = false
		warn_band.stop()
	warn_band.bottom = vs.y - HINT_BOTTOM
	if hint_bg.visible:
		_fit([hint_label, hint_sub])
		var w := maxf(hint_label.size.x, hint_sub.size.x if hint_sub.visible else 0.0)
		hint_label.position = Vector2(10, -1)
		hint_label.size.x = w
		var hh := _text_bottom(hint_label) + 2.0
		if hint_sub.visible:
			hint_sub.position = Vector2(10, hint_label.position.y + LINE)
			hint_sub.size.x = w
			hh = _text_bottom(hint_sub) + 2.0
		hint_bg.size = Vector2(w + 20.0, hh)
		hint_bg.position = Vector2(roundf((vs.x - hint_bg.size.x) * 0.5), vs.y - HINT_BOTTOM - hh)
		hint_bg.modulate.a = clampf((4.5 - hint_t) / 0.3, 0.0, 1.0)
		if hint_t > 4.5:
			hint_bg.visible = false
	if not juice.intro_showing() and not juice.panel_showing() and not reward_card.visible:
		if _hint_wait != "":
			show_hint(_hint_wait, _hint_wait_warn, _hint_wait_tint)
			_hint_wait = ""
		for w in _popup_wait:
			add_popup(w[0], w[1])
		_popup_wait.clear()
	# ---- kill callouts: right of the frame, newest on top; the stack slides
	# smoothly instead of jumping, and each callout holds still once it lands
	var px0 := c.x + fh + CALLOUT_X
	var py0 := c.y - 16.0
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
		# it opens from a scan line and leaves by collapsing back into one,
		# like a CRT; while held it is still (spec §9.9)
		var k := Juice.ease_out(pp.t / 0.06)
		var out := clampf((POPUP_LEN - pp.t) / 0.12, 0.0, 1.0)
		l.size = Vector2.ZERO
		var sh: ColorRect = l.get_node("Shadow")
		sh.size = l.size
		l.pivot_offset = Vector2(0, roundf(l.size.y * 0.5))
		l.scale = Vector2(1.0, maxf(0.08, minf(k, out)))
		# a long one ("GASHADOKURO BURST ONLINE") moves in to stay on screen
		l.position = Vector2(minf(px0, vs.x - 8.0 - l.size.x), roundf(pp.y))
		l.modulate.a = clampf((POPUP_LEN - pp.t) / 0.2, 0.0, 1.0)
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
