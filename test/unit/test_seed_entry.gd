extends GutTest
## PLAY A SEED (spec §7.5): what a player types or pastes must read back as
## the seed the results screen showed, and nothing else may pass as one.

const SEED := 0x1234ABCD


func test_reads_the_shown_seed() -> void:
	assert_eq(SeedEntry.parse(Game.seed_string(SEED)), SEED)


func test_reads_the_forms_players_paste() -> void:
	for text in ["1234abcd", "1234 ABCD", "  1234-abcd\n", "SEED 1234-ABCD", "my seed: 1234-ABCD, beat 120000", "cafe 1234-ABCD"]:
		assert_eq(SeedEntry.parse(text), SEED, text)


func test_rejects_what_is_not_a_seed() -> void:
	for text in ["", "hello", "1234-ABC", "1234-ABCDE", "G234-ABCD", "1234--ABCD"]:
		assert_eq(SeedEntry.parse(text), -1, text)


func test_rejects_seeds_past_31_bits() -> void:
	# reset_run makes 31-bit seeds; 8000-0000 and up never come from a run
	assert_eq(SeedEntry.parse("7FFF-FFFF"), 0x7fffffff)
	assert_eq(SeedEntry.parse("8000-0000"), -1)
	assert_eq(SeedEntry.parse("FFFF-FFFF"), -1)


func test_typed_seed_plays_that_run() -> void:
	var box := SeedEntry.new()
	add_child_autofree(box)
	box.open(false)
	for ch in "0BADC0DE":
		box._type(ch)
	assert_eq(box.slots.text, "0BAD-C0DE")
	var got := []
	box.chosen.connect(func(s: int): got.append(s))
	box._play()
	assert_eq(got, [0x0BADC0DE])
	assert_false(box.visible, "the box closes as the run starts")


func test_short_or_out_of_range_input_never_plays() -> void:
	var box := SeedEntry.new()
	add_child_autofree(box)
	box.open(false)
	box._type("9") # would make the seed 32-bit
	assert_eq(box.digits, "")
	for ch in "0BAD":
		box._type(ch)
	assert_eq(box.slots.text, "0BAD-____")
	var got := []
	box.chosen.connect(func(s: int): got.append(s))
	box._play()
	assert_eq(got, [], "half a seed does not start a run")
	assert_true(box.visible)


func test_saved_run_makes_play_ask_twice() -> void:
	var box := SeedEntry.new()
	add_child_autofree(box)
	box.open(true)
	var got := []
	box.chosen.connect(func(s: int): got.append(s))
	for ch in "0BADC0DE":
		box._type(ch)
	box.play_btn.press()
	assert_eq(got, [], "the first press only warns that the saved run ends")
	box.play_btn.press()
	assert_eq(got, [0x0BADC0DE])


func test_copied_note_keeps_the_button_still() -> void:
	# the seed and prompt are laid out beside COPY; they must not move
	var b := TechButton.make("COPY SEED  [C]", Color.WHITE)
	add_child_autofree(b)
	var w := b.size.x
	b.flash("COPIED")
	assert_eq(b.size.x, w)
