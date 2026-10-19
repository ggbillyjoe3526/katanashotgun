extends GutTest
## The Focus menus' clickable word lists (spec §9.7): an item runs its
## action, QUIT-style items ask twice, and a flash note gives the words back.

var _list: MenuList
var _hits := 0


func before_each() -> void:
	_hits = 0
	_list = MenuList.new()
	add_child_autofree(_list)


func test_an_item_runs_its_action() -> void:
	var i := _list.add("RESUME", func(): _hits += 1)
	_list.press(i)
	assert_eq(_hits, 1)


func test_a_confirm_item_arms_first_then_goes_through() -> void:
	var i := _list.add("QUIT", func(): _hits += 1, "Q", {"confirm": "QUIT?  CLICK AGAIN"})
	_list.press(i)
	assert_eq(_hits, 0, "the first press only arms it")
	assert_true(_list.armed(i))
	_list.press(i)
	assert_eq(_hits, 1)
	assert_false(_list.armed(i))


func test_disarm_puts_the_words_back() -> void:
	var i := _list.add("QUIT", func(): _hits += 1, "", {"confirm": "QUIT?  CLICK AGAIN"})
	_list.press(i)
	_list.disarm()
	assert_false(_list.armed(i))
	_list.press(i)
	assert_eq(_hits, 0, "after a disarm the next press arms again")


func test_hidden_items_do_nothing() -> void:
	var i := _list.add("NEW RUN", func(): _hits += 1, "N")
	_list.set_visible_item(i, false)
	_list.press(i)
	assert_eq(_hits, 0)


func test_a_row_lays_items_side_by_side() -> void:
	_list.horizontal = true
	_list.add("RETRY SEED", func(): pass, "R")
	_list.add("NEW RUN", func(): pass, "CLICK")
	_list.layout()
	assert_gt(_list.size.x, 60.0)
	assert_lt(_list.size.y, 20.0, "one row tall")

