# Builds the hands (build_hands.py) and exports them as hands.glb:
#   ~/bpyenv/bin/python export_hands.py ../hands.glb
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_hands  # noqa: E402


def main(out):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    col = build_hands.build()
    bpy.ops.object.select_all(action="DESELECT")
    for ob in col.objects:
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.modifier_apply(modifier="bevel")
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.quads_convert_to_tris()
        bpy.ops.object.mode_set(mode="OBJECT")
    for ob in col.objects:
        ob.select_set(True)
        print("%s: %d tris" % (ob.name, len(ob.data.polygons)))
    bpy.ops.export_scene.gltf(filepath=os.path.abspath(out), use_selection=True, export_format="GLB", export_apply=True)


if __name__ == "__main__":
    main(sys.argv[-1] if sys.argv[-1].endswith(".glb") else "../hands.glb")
