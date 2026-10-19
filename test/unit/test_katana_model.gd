extends GutTest
## The DOJIGIRI katana model (assets/models/katana): it loads, stays inside
## its triangle budget, and gets the game's materials (the glow takes the
## viewmodel's edge material).

const MAX_TRIANGLES := 30000


func _meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for n in root.find_children("*", "MeshInstance3D", true, false):
		out.append(n)
	return out


func test_model_loads_with_its_three_surfaces() -> void:
	var edge := StandardMaterial3D.new()
	var model := KatanaModel.build(edge)
	add_child_autofree(model)
	var meshes := _meshes(model)
	assert_eq(meshes.size(), 1, "one mesh")
	var mi := meshes[0]
	assert_eq(mi.mesh.get_surface_count(), 3, "steel, grip and edge")
	var tris := 0
	var edges := 0
	for i in mi.mesh.get_surface_count():
		tris += mi.mesh.surface_get_array_index_len(i) / 3
		var m := mi.get_surface_override_material(i)
		if m == edge:
			edges += 1
		else:
			assert_true(m is ShaderMaterial, "textured surface uses psx_model")
			assert_not_null(m.get_shader_parameter("albedo_tex"))
			assert_not_null(m.get_shader_parameter("retro_tex"))
	assert_eq(edges, 1, "the glow takes the edge material")
	assert_between(tris, 1000, MAX_TRIANGLES, "triangle budget")
	assert_eq(mi.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)

