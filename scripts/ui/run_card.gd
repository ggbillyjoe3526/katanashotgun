class_name RunCard
extends RefCounted
## Run Cards (spec §19.1 #10): one key on the results screen saves a neon
## postcard of the run as a PNG, with the seed code on it, so a player can
## post it on Discord or send it by text (the game is offline). Drawn at the
## UI's own 480x270 like the rest of the UI, then scaled up 4x with hard
## pixels to 1920x1080. The backdrop is the run's palette: sky, sun, skyline
## and floor grid; every word sits on a dark plate or has an outline.

const W := 480
const H := 270
const SCALE := 4 # 1920x1080: a share-friendly size that keeps every pixel square
const HORIZON := 150
const SUN := Vector2i(352, 146)
const SUN_R := 64
const FOLDER := "KatanaShotgun" # inside Pictures; no slash (CLAUDE.md)
const FALLBACK_DIR := "user://run_cards"
const BOSS_NAMES := {"ninja": "KUROKAGE", "mech": "TETSUGUMO", "oni": "SHUTEN"} # as in boss.gd / enemy.gd
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
const LEVELS := 20.0 # colour steps per channel in the backdrop (posterised, PS1 style)
const TEXT_MIN_LUMINANCE := 0.45 # accents darker than this frame things, never words
const PLATE := Color(0.02, 0.02, 0.06, 0.9)


## Everything the card shows, read from the run that just ended.
static func facts() -> Dictionary:
	var initials := ""
	if Game.last_rank >= 0 and Game.last_rank < Profile.high_scores.size():
		initials = str(Profile.high_scores[Game.last_rank].get("name", ""))
	if initials.replace("-", "") == "":
		initials = ""
	return {
		"seed": Game.seed_string(Game.run_seed), "seed_int": Game.run_seed,
		"score": Game.score, "wave": Game.wave, "best_combo": Game.best_combo,
		"kills": Game.kills, "glory_kills": Game.executions, "time": Game.run_time,
		"bosses": Game.bosses_felled.duplicate(), "upgrades": Game.upgrades.duplicate(),
		"best_tally": Game.best_tally, "best_tally_wave": Game.best_tally_wave,
		"initials": initials, "rank": Game.last_rank if initials != "" else -1,
		"player_level": Profile.player_level,
		"map": Game.arena.map_name if Game.arena else "", "palette": Game.palette.duplicate(true),
		"version": str(ProjectSettings.get_setting("application/config/version", "")),
	}


# ---------------------------------------------------------------- words
static func commas(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if n < 0 else "") + s + out


static func time_text(seconds: float) -> String:
	var t := int(seconds)
	return "%d:%02d" % [t / 60, t % 60]


## "KUROKAGE x2, TETSUGUMO", in the order they first fell.
static func bosses_text(kinds: Array) -> String:
	if kinds.is_empty():
		return "NONE YET"
	var order: Array[String] = []
	var count := {}
	for k in kinds:
		var n: String = BOSS_NAMES.get(str(k), str(k).to_upper())
		if not count.has(n):
			order.append(n)
		count[n] = int(count.get(n, 0)) + 1
	var parts := PackedStringArray()
	for n in order:
		parts.append(n if count[n] == 1 else "%s x%d" % [n, count[n]])
	return ", ".join(parts)


## The builds the run linked (2 of 3) or completed, completed first.
static func builds_text(owned: Dictionary) -> String:
	var parts := PackedStringArray()
	for need in [3, 2]:
		for b in Upgrades.BUILDS:
			if Upgrades.build_count(b, owned) == need:
				parts.append("%s %d/3" % [b.name, need])
	return ", ".join(parts) if not parts.is_empty() else "NONE LINKED"


## The run's best moment: its biggest end-of-wave payout, else its combo.
static func best_moment(f: Dictionary) -> String:
	if int(f.get("best_tally", 0)) > 0:
		return "WAVE %d PAYOUT  +%s" % [int(f.best_tally_wave), commas(int(f.best_tally))]
	if int(f.get("best_combo", 0)) > 1:
		return "A x%d COMBO" % int(f.best_combo)
	return "THE FIRST CUT"


# ---------------------------------------------------------------- files
static func file_name(f: Dictionary) -> String:
	return "runcard_%s_wave%02d_%d.png" % [f.seed, int(f.wave), int(f.score)]


## Where cards go: the player's Pictures folder, in a KatanaShotgun folder
## (spec §19.1). Debug runs and tests keep theirs beside their own profile.
static func folders() -> PackedStringArray:
	var out := PackedStringArray()
	if Profile.dir != "user://":
		out.append(ProjectSettings.globalize_path(Profile.dir.path_join("run_cards")))
		return out
	var pics := OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	if pics != "" and DirAccess.dir_exists_absolute(pics):
		out.append(pics.path_join(FOLDER))
	# no Pictures folder, or it can't be written: the save folder takes it
	out.append(ProjectSettings.globalize_path(FALLBACK_DIR))
	return out


## `dir/name`, or `name_2`, `name_3`... when a card of that name exists.
static func unique_path(dir: String, file: String) -> String:
	var path := dir.path_join(file)
	var n := 2
	while FileAccess.file_exists(path):
		path = dir.path_join("%s_%d.%s" % [file.get_basename(), n, file.get_extension()])
		n += 1
	return path


## Writes the card; returns its full path, or "" if no folder took it.
static func save(img: Image, f: Dictionary) -> String:
	for dir in folders():
		if DirAccess.make_dir_recursive_absolute(dir) != OK:
			continue
		var path := unique_path(dir, file_name(f))
		if img.save_png(path) == OK:
			return path
	return ""


## Where the results screen says the card went, in a few plain words (the
## corner it sits in is narrow; OPEN FOLDER shows the exact place).
static func folder_label(path: String) -> String:
	var pics := OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	if pics != "" and path.begins_with(pics.path_join(FOLDER)):
		return "IN YOUR PICTURES"
	return "IN THE SAVE FOLDER"


# ---------------------------------------------------------------- picture
## Draws the card and returns it at full size, or null when nothing can be
## drawn (headless runs have no renderer). `host` is any node in the tree.
static func render(host: Node, f: Dictionary) -> Image:
	if DisplayServer.get_name() == "headless":
		return null
	var vp := SubViewport.new()
	vp.size = Vector2i(W, H)
	vp.transparent_bg = false
	vp.disable_3d = true
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	Ui.pixelate_viewport(vp)
	var art := Art.new()
	art.f = f
	art.backdrop = ImageTexture.create_from_image(backdrop(f.palette, int(f.seed_int)))
	art.size = Vector2(W, H)
	vp.add_child(art)
	host.add_child(vp)
	# one frame to draw it, one more so the read-back sees the finished frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	# the screen that asked may have been torn down while we waited
	if not is_instance_valid(vp) or not vp.is_inside_tree():
		return null
	var img := vp.get_texture().get_image()
	vp.queue_free()
	if img == null or img.is_empty():
		return null
	img.convert(Image.FORMAT_RGB8)
	img.resize(W * SCALE, H * SCALE, Image.INTERPOLATE_NEAREST)
	return img


## The accents bright enough for words, brightest first; the rest only
## colour frames and windows.
static func text_accents(accents: Array) -> Array[Color]:
	var out: Array[Color] = []
	for c in accents:
		if Palette.luminance(c) >= TEXT_MIN_LUMINANCE:
			out.append(c)
	if out.size() < 2:
		out.append_array([Color(0.95, 0.95, 1.0), Color(1.0, 0.9, 0.6)])
	return out


## The scenery behind the words, from the run's palette: a dithered sky, the
## striped synthwave sun, a skyline with neon windows and the horizon line.
## Presentation only: it draws from its own RNG, never the run's streams.
static func backdrop(p: Dictionary, seed_int: int) -> Image:
	var img := Image.create_empty(W, H, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_int * 17 + 9)
	for y in HORIZON:
		var t := float(y) / HORIZON
		var c: Color = Color(p.sky_top).lerp(p.sky_mid, t / 0.6) if t < 0.6 else Color(p.sky_mid).lerp(p.sky_horizon, (t - 0.6) / 0.4)
		for x in 4:
			var q := _dither(c, (BAYER[(y % 4) * 4 + x] + 0.5) / 16.0)
			for xx in range(x, W, 4):
				img.set_pixel(xx, y, q)
	_sun(img, p)
	var accents: Array = p.accents
	# far skyline: low and hazy; near skyline: tall, with lit windows and signs
	_skyline(img, rng, Color(p.mountain).lerp(p.sky_horizon, 0.3), 8, 34, [], 0.0)
	_skyline(img, rng, Color(p.mountain), 14, 70, accents, 0.16)
	img.fill_rect(Rect2i(0, HORIZON, W, H - HORIZON), Color(p.floor))
	img.fill_rect(Rect2i(0, HORIZON, W, 1), Color(p.grid))
	return img


static func _dither(c: Color, d: float) -> Color:
	return Color(floorf(c.r * LEVELS + d) / LEVELS, floorf(c.g * LEVELS + d) / LEVELS, floorf(c.b * LEVELS + d) / LEVELS)


static func _sun(img: Image, p: Dictionary) -> void:
	for y in range(SUN.y - SUN_R, HORIZON):
		var dy := float(y - SUN.y) + 0.5
		if absf(dy) > SUN_R:
			continue
		var t := float(y - (SUN.y - SUN_R)) / SUN_R
		# the stripes thicken toward the horizon
		if t > 0.5 and posmod(y - SUN.y, 7) < int(1.0 + (t - 0.5) * 7.0):
			continue
		var hw := int(sqrt(SUN_R * SUN_R - dy * dy))
		var c: Color = Color(p.sun_top).lerp(p.sun_bottom, clampf(t, 0.0, 1.0))
		img.fill_rect(Rect2i(SUN.x - hw, y, hw * 2, 1), _dither(c, 0.5))


static func _skyline(img: Image, rng: RandomNumberGenerator, col: Color, lo: int, hi: int, accents: Array, lit: float) -> void:
	var x := -rng.randi_range(0, 12)
	while x < W:
		var w := rng.randi_range(12, 30)
		var h := rng.randi_range(lo, hi)
		var top := HORIZON - h
		img.fill_rect(Rect2i(x, top, w, h), col)
		if not accents.is_empty():
			for wy in range(top + 3, HORIZON - 2, 4):
				for wx in range(x + 2, x + w - 2, 3):
					if wx >= 0 and wx < W and rng.randf() < lit:
						img.set_pixel(wx, wy, Color(accents[rng.randi() % accents.size()]).darkened(0.15))
			# a neon sign down one edge of some towers
			if h > 34 and rng.randf() < 0.4:
				var sx := clampi(x + (1 if rng.randf() < 0.5 else w - 3), 0, W - 2)
				img.fill_rect(Rect2i(sx, top + 4, 2, rng.randi_range(8, 18)), Color(accents[rng.randi() % accents.size()]))
		x += w + rng.randi_range(-4, 3)


## The card itself: the backdrop, the floor grid, then the plates and words.
class Art:
	extends Control
	var f: Dictionary
	var backdrop: Texture2D

	func _draw() -> void:
		var p: Dictionary = f.palette
		var acc: Array = p.accents
		var ta := RunCard.text_accents(acc)
		draw_texture(backdrop, Vector2.ZERO)
		_grid(Color(p.grid))
		var white := Color(0.97, 0.97, 1.0)
		var soft := Color(0.8, 0.8, 0.9)

		# the title, outlined over the sky
		var big := Ui.font_big
		var lpx := Ui.px(big, 16)
		var x := 12.0
		for part in [["KATANA", acc[0]], [" / ", white], ["SHOTGUN", acc[1]]]:
			x += _word(Vector2(x, 9), part[0], big, lpx, part[1], 2)
		_word(Vector2(14, 34), "RUN CARD  //  %s" % str(f.map), Ui.font, Ui.PIX, white, 2)

		# top right: who and how far they've come
		var tag := "PLAYER LV %d" % int(f.player_level)
		var tag_w := Ui.font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.PIX).x
		if str(f.initials) != "":
			var ipx := Ui.px(big, 20)
			var rank := "#%d LOCAL TOP 10" % (int(f.rank) + 1)
			var iw := big.get_string_size(str(f.initials), HORIZONTAL_ALIGNMENT_LEFT, -1, ipx).x
			var rw := maxf(Ui.font.get_string_size(rank, HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.PIX).x, tag_w)
			var r := Rect2(W - 12 - iw - rw - 26, 8, iw + rw + 26, 40)
			_plate(r, acc[2])
			_text(Vector2(r.position.x + 8, r.position.y + 3), str(f.initials), big, ipx, ta[0])
			_text(Vector2(r.end.x - 8 - rw, r.position.y + 5), rank, Ui.font, Ui.PIX, white)
			_text(Vector2(r.end.x - 8 - rw, r.position.y + 21), tag, Ui.font, Ui.PIX, soft)
		else:
			var r := Rect2(W - 12 - tag_w - 16, 8, tag_w + 16, 22)
			_plate(r, acc[2])
			_text(Vector2(r.position.x + 8, r.position.y + 3), tag, Ui.font, Ui.PIX, white)

		# left: the score and the run in numbers
		var lp := Rect2(12, 52, 214, 180)
		_plate(lp, acc[0])
		var lx := lp.position.x + 8
		var lw := lp.size.x - 16
		_text(Vector2(lx, lp.position.y + 4), "SCORE", Ui.font, Ui.PIX, ta[0])
		_text(Vector2(lx, lp.position.y + 18), RunCard.commas(int(f.score)), big, Ui.px(big, 24), Color(p.neon_c))
		var rows := [
			["WAVE REACHED", str(int(f.wave))],
			["BEST COMBO", "x%d" % int(f.best_combo)],
			["KILLS", RunCard.commas(int(f.kills))],
			["GLORY KILLS", RunCard.commas(int(f.glory_kills))],
			["TIME", RunCard.time_text(float(f.time))],
		]
		var y := lp.position.y + 60
		for row in rows:
			_text(Vector2(lx, y), row[0], Ui.font, Ui.PIX, soft)
			_text(Vector2(lx, y), row[1], Ui.font_mono, Ui.PIX, white, lw, HORIZONTAL_ALIGNMENT_RIGHT)
			y += 16
		y += 4
		_text(Vector2(lx, y), "BEST MOMENT", Ui.font, Ui.PIX, ta[1 % ta.size()])
		_text(Vector2(lx, y + 16), RunCard.best_moment(f), Ui.font, Ui.PIX, white)

		# right: who fell and what the build was
		var rp := Rect2(238, 132, 230, 100)
		_plate(rp, acc[1])
		var rx := rp.position.x + 8
		var rw2 := rp.size.x - 16
		y = rp.position.y + 4
		for sect in [["BOSSES FELLED", RunCard.bosses_text(f.bosses), ta[2 % ta.size()]], ["BUILDS", RunCard.builds_text(f.upgrades), ta[3 % ta.size()]]]:
			_text(Vector2(rx, y), sect[0], Ui.font, Ui.PIX, sect[2])
			y += 16
			for line in RunCard.wrap(sect[1], Ui.font, Ui.PIX, rw2, 2):
				_text(Vector2(rx, y), line, Ui.font, Ui.PIX, white)
				y += 16
			y += 2

		# bottom: the seed, the thing to share
		# the code in the pixel face at double size: its 0 and D, 8 and B never
		# look alike, so it types (or pastes) straight into the title's seed box
		var sp := Rect2(12, 236, W - 24, 32)
		_plate(sp, acc[3 % acc.size()])
		_text(Vector2(sp.position.x + 8, sp.position.y + 9), "SEED", Ui.font, Ui.PIX, ta[0])
		var spx := Ui.PIX * 2
		var seed_x := sp.position.x + 42
		_text(Vector2(seed_x, sp.position.y + 1), str(f.seed), Ui.font_mono, spx, white)
		var sw := Ui.font_mono.get_string_size(str(f.seed), HORIZONTAL_ALIGNMENT_LEFT, -1, spx).x
		_text(Vector2(seed_x + sw + 14, sp.position.y + 1), "PLAY THIS SEED", Ui.font, Ui.PIX, soft)
		_text(Vector2(seed_x + sw + 14, sp.position.y + 15), "AND BEAT THIS SCORE", Ui.font, Ui.PIX, soft)
		_text(Vector2(sp.position.x, sp.position.y + 9), str(f.version).to_upper(), Ui.font, Ui.PIX, soft, sp.size.x - 8, HORIZONTAL_ALIGNMENT_RIGHT)

	## A dark plate with a neon edge and a thicker bar down its left side.
	func _plate(r: Rect2, edge: Color) -> void:
		draw_rect(r, RunCard.PLATE)
		draw_rect(Rect2(r.position + Vector2(0.5, 0.5), r.size - Vector2.ONE), edge, false, 1.0)
		draw_rect(Rect2(r.position, Vector2(2, r.size.y)), edge)

	## Text placed by the top of its line box rather than its baseline.
	func _text(top_left: Vector2, s: String, font: Font, px: int, col: Color, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
		draw_string(font, Vector2(top_left.x, top_left.y + font.get_ascent(px)).round(), s, align, width, px, col)

	## Outlined text over the scenery; returns its width.
	func _word(top_left: Vector2, s: String, font: Font, px: int, col: Color, outline: int) -> float:
		var pos := Vector2(top_left.x, top_left.y + font.get_ascent(px)).round()
		draw_string_outline(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, outline * 2, Color(0.02, 0.0, 0.05))
		draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
		return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x

	## The floor grid: rows that crowd toward the horizon, lines that meet at
	## the vanishing point.
	func _grid(col: Color) -> void:
		var c := Color(col, 0.55)
		var depth := float(RunCard.H - RunCard.HORIZON)
		for i in range(1, 9):
			var k := float(i) / 8.0
			var y := roundf(RunCard.HORIZON + k * k * depth)
			draw_line(Vector2(0, y), Vector2(RunCard.W, y), c, -1.0)
		var vp := Vector2(RunCard.W * 0.5, RunCard.HORIZON)
		for j in range(-10, 11):
			draw_line(vp, Vector2(vp.x + j * 64.0, RunCard.H), c, -1.0)


## Splits `text` into lines no wider than `max_w`, at most `max_lines`; a
## line that still doesn't fit ends in "...".
static func wrap(text: String, font: Font, px: int, max_w: float, max_lines: int) -> PackedStringArray:
	var lines := PackedStringArray()
	var cur := ""
	for word in text.split(" ", false):
		var test := word if cur == "" else cur + " " + word
		if cur != "" and font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > max_w:
			lines.append(cur)
			cur = word
		else:
			cur = test
	if cur != "":
		lines.append(cur)
	if lines.size() > max_lines:
		lines.resize(max_lines)
		lines[max_lines - 1] = lines[max_lines - 1].trim_suffix(",") + " ..."
	return lines
