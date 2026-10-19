# Rebuilds the DOJIGIRI katana and exports the game mesh as a .glb.
#
# Headless (no Blender install needed beyond the `bpy` module):
#   python export_dojigiri.py [output.glb]
# Or in Blender's Scripting tab after build_dojigiri.py has run.
#
# Every visible part is turned into plain mesh (booleans and bevels applied)
# and joined into one object, "DOJIGIRI", with three material slots
# (steel, grip, edge): one MeshInstance3D and three draw calls in Godot.
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bmesh  # noqa: E402
import build_dojigiri  # noqa: E402
import surface_dojigiri  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_OUT = os.path.join(HERE, "..", "dojigiri.glb")
TEX_DIR = os.path.join(HERE, "..", "textures")


def bake_to_single_mesh(col):
    dg = bpy.context.evaluated_depsgraph_get()
    parts = [o for o in col.objects if o.type == "MESH" and not o.hide_render]
    meshes = []
    for o in parts:
        me = bpy.data.meshes.new_from_object(o.evaluated_get(dg), depsgraph=dg)
        me.transform(o.matrix_world)
        obj = bpy.data.objects.new(o.name + "_baked", me)
        bpy.context.scene.collection.objects.link(obj)
        meshes.append(obj)
    for o in list(col.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.join()
    out = bpy.context.view_layer.objects.active
    out.name = "DOJIGIRI"
    out.data.name = "DOJIGIRI"
    # merge duplicate material slots left over from the join
    bpy.ops.object.material_slot_remove_unused()
    return out


def triangulate(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.triangulate(bm, faces=bm.faces, quad_method="BEAUTY", ngon_method="BEAUTY")
    bm.to_mesh(obj.data)
    bm.free()


# where the long blade faces are cut into separate UV islands, between the
# bridges, so the strips pack tightly into the square texture
SEAM_Z = (0.40, 0.59, 0.82, 1.0)


def unwrap(obj):
    """UV the textured slots, each filling its own 0-1 square (smart project).
    The blade is cut at SEAM_Z first and welded back after, so its faces
    unwrap as short strips. The glow slot keeps the UVs the build gave it."""
    rings = build_dojigiri.stations(build_dojigiri.Z_BASE, build_dojigiri.ZT)
    cuts = [min(rings, key=lambda z: abs(z - c)) for c in SEAM_Z]
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    edges = [e for e in bm.edges if any(abs(e.verts[0].co.z - c) < 1e-6 and abs(e.verts[1].co.z - c) < 1e-6 for c in cuts)]
    bmesh.ops.split_edges(bm, edges=edges)
    bm.to_mesh(obj.data)
    bm.free()

    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    for slot in surface_dojigiri.SLOTS:
        idx = obj.data.materials.find(slot)
        bm = bmesh.from_edit_mesh(obj.data)
        for f in bm.faces:
            f.select_set(f.material_index == idx)
        bmesh.update_edit_mesh(obj.data)
        bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.003, area_weight=0.0, correct_aspect=True, scale_to_bounds=False)
        bpy.ops.uv.pack_islands(rotate=True, rotate_method="AXIS_ALIGNED", shape_method="CONCAVE", margin=0.003)
    bpy.ops.object.mode_set(mode="OBJECT")

    bm = bmesh.new()
    bm.from_mesh(obj.data)
    seam_verts = [v for v in bm.verts if any(abs(v.co.z - c) < 1e-6 for c in cuts)]
    bmesh.ops.remove_doubles(bm, verts=seam_verts, dist=1e-6)
    bm.to_mesh(obj.data)
    bm.free()


def export(path=DEFAULT_OUT, bake=True):
    col = build_dojigiri.build()
    tris = build_dojigiri.triangle_count(col)
    obj = bake_to_single_mesh(col)
    triangulate(obj)
    unwrap(obj)
    if bake:
        surface_dojigiri.bake(obj, TEX_DIR)
    surface_dojigiri.final_materials(obj, TEX_DIR)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=os.path.abspath(path),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_texcoords=True,
        export_normals=True,
        export_tangents=True,
        export_materials="EXPORT",
        export_image_format="NONE",
        export_animations=False,
    )
    print("exported", os.path.abspath(path), "triangles", tris, "materials", [m.name for m in obj.data.materials])


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    no_bake = "--no-bake" in args
    args = [a for a in args if a != "--no-bake"]
    export(args[0] if args else DEFAULT_OUT, bake=not no_bake)
