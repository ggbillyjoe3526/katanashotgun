# Rebuilds the RAIJIN-12 shotgun and exports the game model as a .glb.
#
# Headless (no Blender install needed beyond the `bpy` module):
#   python export_raijin.py [output.glb] [--no-bake]
# Or in Blender's Scripting tab.
#
# Every visible part is turned into plain mesh (booleans and bevels applied)
# and joined, so one UV layout and one texture set per slot covers it all.
# It is then split again into the pieces the game moves on their own:
#   RAIJIN12            root node
#     body              receiver, frame, grip, shroud, housing, fins, core, ring
#     drum              the square drum and its cells; origin on its axle
#     led_0 .. led_9    the charge lights
#     muzzle, arc_point_0 .. 2   empty nodes the game reads positions from
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import build_raijin as B  # noqa: E402
import surface_raijin  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_OUT = os.path.join(HERE, "..", "raijin12.glb")
TEX_DIR = os.path.join(HERE, "..", "textures")

PART_BODY = 0
PART_DRUM = 1
PART_LED = 2  # led_i is PART_LED + i


def _part_of(o):
    names = [o.name] + ([o.parent.name] if o.parent else [])
    if "drum" in names:
        return PART_DRUM
    if o.name.startswith("led_") and o.name[4:].isdigit():
        return PART_LED + int(o.name.split("_")[1])
    return PART_BODY


def bake_to_single_mesh(col):
    dg = bpy.context.evaluated_depsgraph_get()
    empties = {o.name: o.matrix_world.translation.copy() for o in col.objects if o.type == "EMPTY" and o.name != B.ROOT}
    parts = [o for o in col.objects if o.type == "MESH" and not o.hide_render]
    meshes = []
    for o in parts:
        me = bpy.data.meshes.new_from_object(o.evaluated_get(dg), depsgraph=dg)
        me.transform(o.matrix_world)
        a = me.attributes.new("part", "INT", "FACE")
        a.data.foreach_set("value", [_part_of(o)] * len(me.polygons))
        obj = bpy.data.objects.new(o.name + "_baked", me)
        bpy.context.scene.collection.objects.link(obj)
        meshes.append(obj)
    for o in list(col.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    # free the old names (drum, led_0...) for the split-out pieces
    for me in list(bpy.data.meshes):
        if me.users == 0:
            bpy.data.meshes.remove(me)
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.join()
    out = bpy.context.view_layer.objects.active
    out.name = "body"
    out.data.name = "body"
    bpy.ops.object.material_slot_remove_unused()
    return out, empties


def triangulate(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.triangulate(bm, faces=bm.faces, quad_method="BEAUTY", ngon_method="BEAUTY")
    bm.to_mesh(obj.data)
    bm.free()


def unwrap(obj):
    """UV the textured slots, each filling its own 0-1 square."""
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    for slot in surface_raijin.SLOTS:
        idx = obj.data.materials.find(slot)
        bm = bmesh.from_edit_mesh(obj.data)
        for f in bm.faces:
            f.select_set(f.material_index == idx)
        bmesh.update_edit_mesh(obj.data)
        bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.003, area_weight=0.0, correct_aspect=True, scale_to_bounds=False)
        bpy.ops.uv.pack_islands(rotate=True, rotate_method="AXIS_ALIGNED", shape_method="CONCAVE", margin=0.003)
    bpy.ops.object.mode_set(mode="OBJECT")


def split_parts(obj):
    """Splits the drum and each charge light back out of the joined mesh."""
    out = {}
    part = obj.data.attributes["part"]
    values = [0] * len(obj.data.polygons)
    part.data.foreach_get("value", values)
    for p in sorted(set(values) - {PART_BODY}):
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        layer = bm.faces.layers.int.get("part")
        keep = [f for f in bm.faces if f[layer] != p]
        bmesh.ops.delete(bm, geom=keep, context="FACES")
        name = "drum" if p == PART_DRUM else f"led_{p - PART_LED}"
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        for m in obj.data.materials:
            me.materials.append(m)
        o = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(o)
        assert o.name == name, f"{o.name} should be {name}"
        out[name] = o
        # drop the materials this piece doesn't use, keeping the names
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.material_slot_remove_unused()
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    layer = bm.faces.layers.int.get("part")
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f[layer] != PART_BODY], context="FACES")
    bm.to_mesh(obj.data)
    bm.free()
    return out


def set_origin(o, at):
    o.data.transform(Matrix.Translation(-at))
    o.location = at


def export(path=DEFAULT_OUT, bake=True):
    col = B.build()
    tris = B.triangle_count(col)
    obj, empties = bake_to_single_mesh(col)
    triangulate(obj)
    unwrap(obj)
    if bake:
        surface_raijin.bake(obj, TEX_DIR)
    surface_raijin.final_materials(obj, TEX_DIR)
    pieces = split_parts(obj)
    # the drum turns about its axle, so its origin sits on it
    set_origin(pieces["drum"], Vector((0.0, (B.DRUM_Y[0] + B.DRUM_Y[1]) / 2, B.DRUM_Z)))
    for i, (y, z) in enumerate(B.LEDS):
        set_origin(pieces[f"led_{i}"], Vector((B.LED_X, y, z)))

    root = bpy.data.objects.new("RAIJIN12", None)
    bpy.context.scene.collection.objects.link(root)
    nodes = [obj] + list(pieces.values())
    for name, at in empties.items():
        e = bpy.data.objects.new(name, None)
        e.location = at
        bpy.context.scene.collection.objects.link(e)
        nodes.append(e)
    for o in nodes:
        o.parent = root
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for o in nodes:
        o.select_set(True)
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
        export_attributes=False,
    )
    print("exported", os.path.abspath(path), "triangles", tris,
          "nodes", sorted(o.name for o in nodes),
          "body materials", [m.name for m in obj.data.materials])


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    no_bake = "--no-bake" in args
    args = [a for a in args if a != "--no-bake"]
    export(args[0] if args else DEFAULT_OUT, bake=not no_bake)
