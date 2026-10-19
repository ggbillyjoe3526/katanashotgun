extends GutTest
## Run Cards (spec §19.1 #10): the words on the card, where it is saved, and
## a backdrop that follows the seed without touching the run's RNG streams.
## Drawing the words needs a renderer, so `--runcard` checks that part
## (scripts/debug_run_card.gd).

const SEED := 0x0BADC0DE


func before_each() -> void:
	Game.next_seed = SEED
	Game.reset_run()


func _facts() -> Dictionary:
	return {"seed": "0BAD-C0DE", "seed_int": SEED, "score": 1284650, "wave": 14, "best_combo": 64,
		"best_tally": 0, "best_tally_wave": 0}


func test_numbers_get_commas() -> void:
	assert_eq(RunCard.commas(0), "0")
	assert_eq(RunCard.commas(999), "999")
	assert_eq(RunCard.commas(1000), "1,000")
	assert_eq(RunCard.commas(1284650), "1,284,650")


func test_bosses_group_in_the_order_they_fell() -> void:
	assert_eq(RunCard.bosses_text([]), "NONE YET")
	assert_eq(RunCard.bosses_text(["mech", "ninja", "mech", "oni"]), "TETSUGUMO x2, KUROKAGE, SHUTEN")


func test_every_boss_kind_has_a_card_name() -> void:
	for k in WaveDirector.BOSS_KINDS:
		assert_true(RunCard.BOSS_NAMES.has(k), "no run card name for boss %s" % k)


func test_builds_show_completed_then_linked() -> void:
	assert_eq(RunCard.builds_text({}), "NONE LINKED")
	assert_eq(RunCard.builds_text({"edge": 1}), "NONE LINKED") # one card is not a build yet
	var owned := {"edge": 1, "wave": 1, "fork": 1, "ikazuchi": 2, "inazuma": 1}
	assert_eq(RunCard.builds_text(owned), "THUNDER CHAIN 3/3, RONIN 2/3")


func test_best_moment_is_the_biggest_payout() -> void:
	var f := _facts()
	assert_eq(RunCard.best_moment(f), "A x64 COMBO")
	f.best_tally = 148200
	f.best_tally_wave = 12
	assert_eq(RunCard.best_moment(f), "WAVE 12 PAYOUT  +148,200")
	f.best_tally = 0
	f.best_combo = 0
	assert_eq(RunCard.best_moment(f), "THE FIRST CUT")


func test_note_tally_keeps_the_biggest() -> void:
	Game.note_tally(3, 5000)
	Game.note_tally(4, 3000)
	Game.note_tally(5, 9000)
	assert_eq([Game.best_tally, Game.best_tally_wave], [9000, 5])
	Game.reset_run()
	assert_eq([Game.best_tally, Game.best_tally_wave], [0, 0])
	assert_has(RunSnapshot.GAME_INTS, "best_tally", "a resumed run keeps its best moment")


func test_card_shows_the_seed_as_the_seed_box_takes_it() -> void:
	var f := RunCard.facts()
	assert_eq(f.seed, "0BAD-C0DE")
	assert_eq(RunCard.file_name(f), "runcard_0BAD-C0DE_wave00_0.png")


func test_test_runs_save_beside_their_own_profile() -> void:
	var dirs := RunCard.folders()
	assert_eq(dirs.size(), 1)
	assert_eq(dirs[0], ProjectSettings.globalize_path(Profile.dir.path_join("run_cards")))


func test_save_writes_a_png_and_never_overwrites() -> void:
	var dir: String = RunCard.folders()[0]
	var f := _facts()
	for old in DirAccess.get_files_at(dir) if DirAccess.dir_exists_absolute(dir) else PackedStringArray():
		DirAccess.remove_absolute(dir.path_join(old))
	var img := RunCard.backdrop(Game.palette, SEED)
	var first := RunCard.save(img, f)
	var second := RunCard.save(img, f)
	assert_eq(first, dir.path_join("runcard_0BAD-C0DE_wave14_1284650.png"))
	assert_eq(second, dir.path_join("runcard_0BAD-C0DE_wave14_1284650_2.png"))
	var back := Image.load_from_file(first)
	assert_not_null(back)
	if back:
		assert_eq(back.get_size(), Vector2i(RunCard.W, RunCard.H))
	for p in [first, second]:
		DirAccess.remove_absolute(p)


func test_backdrop_follows_the_seed_and_leaves_the_run_alone() -> void:
	var states := [Game.rng_map.state, Game.rng_waves.state, Game.rng_upgrades.state]
	var a := RunCard.backdrop(Game.palette, SEED)
	var b := RunCard.backdrop(Game.palette, SEED)
	var c := RunCard.backdrop(Game.palette, SEED + 1)
	assert_eq(a.get_data(), b.get_data(), "same seed, same card")
	assert_ne(a.get_data(), c.get_data(), "another seed, another skyline")
	assert_eq([Game.rng_map.state, Game.rng_waves.state, Game.rng_upgrades.state], states)
	assert_eq(a.get_pixel(5, RunCard.HORIZON).to_html(false), Color(Game.palette.grid).to_html(false), "the horizon line glows in the grid colour")


func test_every_palette_has_bright_words() -> void:
	for entry in Palette.LIST:
		var ta := RunCard.text_accents(Palette.expand(entry).accents)
		assert_gte(ta.size(), 2, "%s: headings in more than one colour" % entry.name)
		for col in ta:
			assert_gte(Palette.luminance(col), RunCard.TEXT_MIN_LUMINANCE, entry.name)


func test_wrap_fits_and_stops_at_its_lines() -> void:
	Ui.init()
	var long := "KUROKAGE x3, TETSUGUMO x2, SHUTEN x2, KUROKAGE, TETSUGUMO, SHUTEN"
	var lines := RunCard.wrap(long, Ui.font, Ui.PIX, 214.0, 2)
	assert_eq(lines.size(), 2)
	assert_true(lines[1].ends_with("..."))
	for l in RunCard.wrap("THUNDER CHAIN 3/3, RONIN 2/3", Ui.font, Ui.PIX, 214.0, 2):
		assert_lte(Ui.font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.PIX).x, 214.0)


func test_headless_render_gives_nothing_rather_than_a_blank_card() -> void:
	var img: Image = await RunCard.render(self, RunCard.facts())
	assert_null(img)
