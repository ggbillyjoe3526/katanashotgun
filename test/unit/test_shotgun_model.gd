extends GutTest
## The RAIJIN-12 shotgun model (assets/models/shotgun): it loads with the
## parts the viewmodel moves on their own, stays inside its triangle budget,
## and gets the game's materials (the glowing surfaces take the viewmodel's).

const MAX_TRIANGLES := 30000


func _glow() -> Dictionary:
	var out := {}
	for slot: String in ShotgunModel.GLOW_SLOTS:
		out[slot] = StandardMaterial3D.new()
	return out


func test_model_has_its_moving_parts() -> void:
	var model := ShotgunModel.build(_glow())
	add_child_autofree(model)
	assert_true(ShotgunModel.part(model, "drum") is MeshInstance3D, "drum")
	assert_not_null(ShotgunModel.part(model, "muzzle"), "muzzle")
	for i in ShotgunModel.ARC_POINTS:
		assert_not_null(ShotgunModel.part(model, "arc_point_%d" % i), "arc point %d" % i)
	for i in ShotgunModel.LED_COUNT:
		assert_true(ShotgunModel.part(model, "led_%d" % i) is MeshInstance3D, "led %d" % i)
	# the muzzle sits at the front of the barrels, in the code-built gun's frame
	var mz := ShotgunModel.part(model, "muzzle").global_position
	assert_almost_eq(mz, Vector3(0, 0.05, -0.9), Vector3.ONE * 0.01, "muzzle position")


func test_model_materials_and_budget() -> void:
	var glow := _glow()
	var model := ShotgunModel.build(glow)
	add_child_autofree(model)
	var tris := 0
	var glows := {}
	var textured := 0
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		assert_eq(mi.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, mi.name)
		for i in mi.mesh.get_surface_count():
			tris += mi.mesh.surface_get_array_index_len(i) / 3
			var m := mi.get_surface_override_material(i)
			var slot: Variant = glow.find_key(m)
			if slot != null:
				glows[slot] = true
			else:
				textured += 1
				assert_true(m is ShaderMaterial, "textured surface uses psx_model")
				assert_not_null(m.get_shader_parameter("albedo_tex"))
				assert_not_null(m.get_shader_parameter("retro_tex"))
	assert_eq(glows.size(), ShotgunModel.GLOW_SLOTS.size(), "every glowing surface takes its material")
	assert_gt(textured, 0, "textured surfaces")
	assert_between(tris, 1000, MAX_TRIANGLES, "triangle budget")
