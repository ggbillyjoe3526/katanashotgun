extends GutTest
## Multi-colour palettes (spec §9.2): every palette keeps several strong,
## distinct neon hues, never a purple wash, and picking one never shifts the
## rest of the seeded map stream.


func test_every_palette_is_multi_colour() -> void:
	for entry in Palette.LIST:
		var p := Palette.expand(entry)
		assert_eq(Array(Palette.problems(p)), [], p.name)


func test_names_are_unique() -> void:
	var names := {}
	for entry in Palette.LIST:
		names[entry.name] = true
	assert_eq(names.size(), Palette.LIST.size())


func test_neon_trio_comes_from_accents() -> void:
	var p := Palette.expand(Palette.LIST[0])
	assert_eq(p.neon_a, p.accents[0])
	assert_eq(p.neon_b, p.accents[1])
	assert_eq(p.neon_c, p.accents[2])


func test_expand_does_not_touch_the_table() -> void:
	var p := Palette.expand(Palette.LIST[0])
	p.accents[0] = Color.BLACK
	assert_ne(Palette.LIST[0].accents[0], Color.BLACK)


func test_pick_draws_exactly_one_number() -> void:
	for force in ["", "2", "toxic tokyo"]:
		var a := RandomNumberGenerator.new()
		a.seed = 99
		var b := RandomNumberGenerator.new()
		b.seed = 99
		Palette.pick(a, force)
		b.randi()
		assert_eq(a.randi(), b.randi(), "force=%s" % force)


func test_force_by_name_or_index() -> void:
	var rng := RandomNumberGenerator.new()
	assert_eq(Palette.pick(rng, "3").name, Palette.LIST[3].name)
	assert_eq(Palette.pick(rng, "miami nights").name, "MIAMI NIGHTS")


func test_checker_catches_a_purple_wash() -> void:
	var p := Palette.expand(Palette.LIST[0])
	var violet := Color("b44dff")
	p.accents = [violet, Color("c45dff"), Color("9a3dff"), violet, violet]
	for k in ["sky_mid", "fog", "ambient", "floor"]:
		p[k] = Color("3b0a7a")
	var found := " ".join(Palette.problems(p))
	assert_string_contains(found, "share a hue")
	assert_string_contains(found, "purple accents")
	assert_string_contains(found, "purple base")
