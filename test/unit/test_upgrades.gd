extends GutTest
## Level-up augments and builds (spec §3.8): the card data hangs together,
## offers are seeded (same seed and same picks give the same cards), and a
## card that links to your build is always among the offers when one is left.

const SEED := 0x5EED0001


func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash(s)
	return r


func _ids(cards: Array) -> Array:
	return cards.map(func(u): return u.id)


## Plays `levels` level-ups, always taking the card in slot `slot`, and
## returns every offer seen.
func _run(s: int, levels: int, slot: int) -> Array:
	var rng := _rng(s)
	var owned := {}
	var seen := []
	for i in levels:
		var offer := Upgrades.roll(owned, 3, rng)
		if offer.is_empty():
			break
		seen.append(_ids(offer))
		var pick: Dictionary = offer[mini(slot, offer.size() - 1)]
		owned[pick.id] = owned.get(pick.id, 0) + 1
	return seen


func test_card_data_is_consistent() -> void:
	var ids := {}
	var names := {}
	for u in Upgrades.LIST:
		assert_false(ids.has(u.id), "duplicate id %s" % u.id)
		assert_false(names.has(u.name), "duplicate name %s" % u.name)
		ids[u.id] = true
		names[u.name] = true
		assert_true(Upgrades.TAG_COLORS.has(u.tag), "%s has no tag colour" % u.id)
		assert_between(int(u.max), 1, 3, "%s max rank" % u.id)
		# a card holds a two-line name and about five lines of text
		assert_lt(String(u.desc).length(), 100, "%s description too long for the card" % u.id)
		for r in u.get("requires", []):
			assert_true(Upgrades.get_def(r) != {}, "%s requires unknown card %s" % [u.id, r])


func test_every_build_is_three_real_cards() -> void:
	for b in Upgrades.BUILDS:
		assert_eq(b.cards.size(), 3, b.name)
		for c in b.cards:
			assert_true(Upgrades.get_def(c) != {}, "%s lists unknown card %s" % [b.name, c])


func test_every_card_but_the_filler_is_in_a_build() -> void:
	for u in Upgrades.LIST:
		if u.id == "chrome":
			continue
		assert_false(Upgrades.builds_of(u.id).is_empty(), "%s links to nothing" % u.id)


func test_same_seed_and_picks_give_same_offers() -> void:
	var a := _run(SEED, 20, 0)
	var b := _run(SEED, 20, 0)
	assert_eq(a.size(), 20)
	assert_eq_deep(b, a)


func test_different_picks_can_change_later_offers() -> void:
	# offers depend on what you own, so a different pick may change them
	assert_ne(_run(SEED, 12, 0), _run(SEED, 12, 2))


func test_roll_uses_the_run_stream() -> void:
	Game.next_seed = SEED
	Game.reset_run()
	var a := _ids(Upgrades.roll({}, 3))
	Game.next_seed = SEED
	Game.reset_run()
	assert_eq_deep(_ids(Upgrades.roll({}, 3)), a)


func test_offers_are_distinct_and_never_maxed() -> void:
	var owned := {"chrome": 3, "chain": 1, "wave": 1}
	for s in 50:
		var offer := _ids(Upgrades.roll(owned, 3, _rng(s)))
		assert_eq(offer.size(), 3)
		assert_false("chrome" in offer, "maxed card offered")
		assert_false("chain" in offer, "maxed card offered")
		var uniq := {}
		for id in offer:
			uniq[id] = true
		assert_eq(uniq.size(), 3, "a card offered twice")


func test_onibi_needs_a_fire_card() -> void:
	for s in 200:
		assert_false("onibi" in _ids(Upgrades.roll({}, 3, _rng(s))))
	var seen := false
	for s in 200:
		if "onibi" in _ids(Upgrades.roll({"homura": 1}, 3, _rng(s))):
			seen = true
	assert_true(seen, "Onibi Chain is never offered with Homura Edge owned")


func test_a_linking_card_is_always_offered() -> void:
	for owned in [{"idaten": 1}, {"yoichi": 1}, {"chrome": 1, "kurama": 1}, {"sanzu": 1}]:
		for s in 100:
			var offer := Upgrades.roll(owned, 3, _rng(s))
			var any := false
			for u in offer:
				any = any or Upgrades.is_recommended(u.id, owned)
			assert_true(any, "no linking card for %s on seed %d" % [owned, s])


func test_nothing_is_recommended_before_the_first_pick() -> void:
	for u in Upgrades.LIST:
		assert_false(Upgrades.is_recommended(u.id, {}))
	# the filler links to nothing, and a rank-up isn't a link
	assert_false(Upgrades.is_recommended("fujin", {"chrome": 1}))
	assert_false(Upgrades.is_recommended("wave", {"wave": 1}))
	assert_true(Upgrades.is_recommended("fujin", {"idaten": 1}))


func test_build_news() -> void:
	assert_eq(Upgrades.build_news("idaten", {"idaten": 1}), "")
	assert_eq(Upgrades.build_news("fujin", {"idaten": 1, "fujin": 1}), "STORM RUNNER LINKED")
	assert_eq(Upgrades.build_news("inazuma", {"idaten": 1, "fujin": 1, "inazuma": 1}), "STORM RUNNER COMPLETE")
	# a rank-up changes no build
	assert_eq(Upgrades.build_news("wave", {"edge": 1, "wave": 2}), "")
	assert_eq_deep(Upgrades.build_lines({"edge": 1, "wave": 1}), ["RONIN 2/3"])
