extends GutTest
## Pooling and quality presets (spec §14): effects come from pools built at
## load, stay under the preset's cap, and never add nodes mid-fight.

var _changed_to := ""


func after_each() -> void:
	Quality.apply(Quality.DEFAULT)


func _on_quality(id: String) -> void:
	_changed_to = id


func test_presets_cut_counts_and_high_is_largest() -> void:
	for key in Quality.CAPS.high:
		var low := float(Quality.CAPS.low[key])
		var medium := float(Quality.CAPS.medium[key])
		var high := float(Quality.CAPS.high[key])
		assert_true(low <= medium and medium <= high, "%s shrinks from high to low" % key)
		assert_eq(Quality.max_cap(key), int(high), "pools are sized for high: %s" % key)


func test_apply_switches_preset_and_signals() -> void:
	_changed_to = ""
	Quality.on_changed(_on_quality)
	Quality.apply("low")
	assert_eq(Quality.preset, "low")
	assert_eq(_changed_to, "low")
	assert_eq(Quality.cap("numbers"), int(Quality.CAPS.low.numbers))
	Quality.off_changed(_on_quality)


func test_unknown_preset_keeps_current() -> void:
	Quality.apply("medium")
	Quality.apply("ultra")
	assert_eq(Quality.preset, "medium")


func test_damage_numbers_reuse_nodes_and_respect_the_cap() -> void:
	Quality.apply("low")
	var fx := Fx.new()
	add_child_autofree(fx)
	var before := fx.get_child_count()
	for i in 200:
		fx.damage_number(Vector3.ZERO, float(i))
	assert_eq(fx.get_child_count(), before, "no new nodes for 200 hits")
	assert_true(fx._numbers.size() <= Quality.cap("numbers"), "live numbers stay under the cap")


func test_effects_reuse_nodes_and_respect_caps() -> void:
	Quality.apply("medium")
	var fx := Fx.new()
	add_child_autofree(fx)
	var before := fx.get_child_count()
	for i in 300:
		fx.arc(Vector3.ZERO, Vector3(0, 0, 5), 0.5)
		fx.smoke(Vector3.ZERO)
	assert_eq(fx.get_child_count(), before, "no new nodes for 300 arcs and smoke puffs")
	assert_true(fx._live.arc <= Quality.cap("arcs"), "arcs stay under the cap")
	assert_true(fx._live.smoke <= Quality.cap("smoke"), "smoke stays under the cap")


func test_health_orbs_grow_instead_of_dropping() -> void:
	var fx := Fx.new()
	add_child_autofree(fx)
	fx.health_orbs(Vector3.ZERO, Fx.ORB_POOL + 5)
	assert_eq(fx._orbs.size(), Fx.ORB_POOL + 5, "every orb spawns: they heal")


func test_enemy_reuse_resets_run_state() -> void:
	var e := Enemy.new()
	e.prewarm = true
	e.setup("grunt", 1.0)
	add_child_autofree(e)
	assert_false(Enemy._defaults.is_empty(), "starting values were captured")
	assert_false(e.visible, "a prewarmed enemy waits hidden")
	e.hp = 1.0
	e.dead = true
	e.frozen = true
	e.state = Enemy.S.STAGGER
	e.glory_gore = "split"
	e.visual.scale = Vector3(1.2, 0.8, 1.2)
	e.marker.visible = true
	e.reuse()
	e.setup("grunt", 1.0)
	assert_false(e.dead)
	assert_false(e.frozen)
	assert_eq(e.state, Enemy.S.SPAWN)
	assert_eq(e.glory_gore, "")
	assert_eq(e.hp, e.max_hp)
	assert_eq(e.kind, "grunt", "kind survives (pools are per kind)")
	assert_eq(e.visual.scale, Vector3.ONE)
	assert_false(e.marker.visible)
	assert_true(e.visible)
