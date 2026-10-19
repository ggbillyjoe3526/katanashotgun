# Builds the RAIJIN-12 arc shotgun in Blender (5.2 LTS). BLOCKOUT stage:
# big shapes only, for the owner to approve before any detail goes in.
# Run it in Blender's Scripting tab (or through the Blender MCP), or headless.
# It rebuilds the "RAIJIN12" collection from scratch every time, so tweak a
# number here and run it again rather than editing the mesh by hand.
#
# Axes and size match the code-built shotgun in scripts/viewmodel.gd: metres,
# origin at the hand on the grip, barrel forward along Blender +Y, up +Z. The
# glTF exporter turns that into Godot's barrel -Z, up +Y.
#
# Side outlines are drawn in (y, z) and extruded across the gun (x).
# Parts the game moves or drives stay separate objects:
#   drum         - square, turns 90 degrees about the barrel axis after each
#                  blast (one glowing cell per face)
#   arc_point_N  - empties on the muzzle ring; the idle crackle jumps
#                  between them (3)
#   muzzle       - empty where the blast and flash start
#   led_N        - the 10 charge lights, shown by cell count
import math

import bmesh
import bpy
from mathutils import Matrix

COLLECTION = "RAIJIN12"
ROOT = "RAIJIN12_root"
BORE_Z = 0.05  # barrel axis height (the code-built muzzle sits here)
MUZZLE_Y = 0.90

# ------------------------------------------------------------ side outlines
# receiver: black, blocky, with a raked front and a stepped rear
RECEIVER = [
    (-0.235, -0.020), (0.120, -0.020), (0.165, 0.010), (0.165, 0.100), (0.125, 0.128),
    (-0.140, 0.128), (-0.160, 0.112), (-0.235, 0.112),
]
RECEIVER_W = 0.104
# sunken side panel; the charge lights sit on a plate inside it
SIDE_PANEL = [(-0.205, 0.000), (0.100, 0.000), (0.135, 0.025), (0.135, 0.095), (-0.205, 0.095)]
LED_PLATE = [(-0.125, 0.035), (-0.010, 0.035), (-0.010, 0.085), (-0.125, 0.085)]
# raised top cover, narrower, faceted front and back
TOP_COVER = [
    (-0.140, 0.120), (0.105, 0.120), (0.085, 0.146), (-0.120, 0.146),
]
TOP_COVER_W = 0.076
# red rear sight block: low and wide
SIGHT = [(-0.215, 0.105), (-0.150, 0.105), (-0.150, 0.132), (-0.158, 0.140), (-0.215, 0.140)]
SIGHT_W = 0.062

# twin-tube shroud (light): upper tube runs further than the lower one and
# both fronts are cut at a slant
UPPER_TUBE = [(0.090, 0.080), (0.905, 0.080), (0.935, 0.098), (0.920, 0.124), (0.090, 0.124)]
LOWER_TUBE = [(0.130, 0.024), (0.880, 0.024), (0.895, 0.040), (0.880, 0.078), (0.130, 0.078)]
TUBE_W = 0.096
SEAM_Y = 0.60  # panel break across both tubes

# under-barrel housing (dark) that holds the coil fins, with a chamfered nose
UNDER = [
    (0.230, -0.062), (0.700, -0.062), (0.770, -0.030), (0.790, 0.026),
    (0.230, 0.026),
]
UNDER_W = 0.068
FINS_Y = (0.300, 0.365, 0.430, 0.495)
FIN_T = 0.030
# square drum of power cells under the receiver front
DRUM_Y = (0.105, 0.215)
DRUM_Z = -0.030
DRUM_R = 0.050  # centre to corner

# grip and the open frame that loops back to the rear of the receiver
GRIP = [
    (-0.040, -0.020), (0.035, -0.020), (0.030, -0.050), (-0.015, -0.200), (-0.020, -0.215),
    (-0.090, -0.215), (-0.090, -0.190), (-0.048, -0.040),
]
GRIP_W = 0.044
FRAME = [
    # bottom bar from the grip foot back, a 45-degree strut up, and a short
    # stock block behind the receiver; the inside leaves an open loop
    (-0.020, -0.188), (-0.020, -0.215), (-0.200, -0.215), (-0.300, -0.115),
    (-0.300, 0.020), (-0.275, 0.050), (-0.235, 0.050), (-0.235, -0.020),
    (-0.262, -0.050), (-0.262, -0.105), (-0.190, -0.188),
]
FRAME_W = 0.038
TRIGGER = [(0.050, -0.020), (0.070, -0.020), (0.072, -0.045), (0.060, -0.075), (0.050, -0.075), (0.058, -0.045)]
TRIGGER_W = 0.010

LEDS = [(-0.112 + (i % 5) * 0.022, 0.071 - (i // 5) * 0.022) for i in range(10)]


# ------------------------------------------------------------ mesh helpers
def _collection():
    col = bpy.data.collections.get(COLLECTION)
    if col is None:
        col = bpy.data.collections.new(COLLECTION)
        bpy.context.scene.collection.children.link(col)
    for o in list(col.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    return col


def _material(name, base, metal, rough, emit=None):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*base, 1.0)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    if emit:
        # preview colour only: the game tints glowing parts itself
        b.inputs["Emission Color"].default_value = (*emit, 1.0)
        b.inputs["Emission Strength"].default_value = 1.5
    return m


def _object(col, root, name, bm, mat, smooth_angle=None):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    col.objects.link(o)
    o.parent = root
    o.data.materials.append(mat)
    if smooth_angle is not None:
        with bpy.context.temp_override(selected_editable_objects=[o], active_object=o, object=o):
            bpy.ops.object.shade_smooth_by_angle(angle=math.radians(smooth_angle))
    return o


def prism(pts_yz, thick, x0=None):
    """A flat outline in the side view (y, z), extruded across the gun (x)."""
    bm = bmesh.new()
    xa = -thick / 2 if x0 is None else x0
    f = bm.faces.new([bm.verts.new((xa, y, z)) for (y, z) in pts_yz])
    r = bmesh.ops.extrude_face_region(bm, geom=[f])
    for v in [e for e in r["geom"] if isinstance(e, bmesh.types.BMVert)]:
        v.co.x += thick
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def box(cx, cy, cz, sx, sy, sz):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(sx, sy, sz), verts=bm.verts)
    bmesh.ops.translate(bm, vec=(cx, cy, cz), verts=bm.verts)
    return bm


def cylinder_y(radius, y0, y1, sides, z, x=0.0, spin=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=sides, radius1=radius, radius2=radius, depth=y1 - y0)
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(spin, 3, "Z"))
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "X"))
    bmesh.ops.translate(bm, verts=bm.verts, vec=(x, (y0 + y1) / 2, z))
    return bm


def merge(bms):
    out = bmesh.new()
    for b in bms:
        me = bpy.data.meshes.new("_tmp")
        b.to_mesh(me)
        b.free()
        out.from_mesh(me)
        bpy.data.meshes.remove(me)
    return out


def bevel(o, width, segments=2, angle=30):
    b = o.modifiers.new("Bevel", "BEVEL")
    b.width = width
    b.segments = segments
    b.limit_method = "ANGLE"
    b.angle_limit = math.radians(angle)
    b.harden_normals = True
    o.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL").keep_sharp = True


def cut(target, col, root, name, bm):
    """Boolean-subtract a hidden cutter from target (kept live until export)."""
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    c = bpy.data.objects.new(name, me)
    col.objects.link(c)
    c.parent = root
    c.hide_set(True)
    c.hide_render = True
    c.display_type = "WIRE"
    mod = target.modifiers.new(name, "BOOLEAN")
    mod.object = c
    mod.operation = "DIFFERENCE"
    mod.solver = "EXACT"
    return c


# ------------------------------------------------------------------ build
def build(offset=(0.0, 0.0, 0.0)):
    col = _collection()
    old = bpy.data.objects.get(ROOT)
    if old:
        bpy.data.objects.remove(old, do_unlink=True)
    root = bpy.data.objects.new(ROOT, None)
    root.empty_display_size = 0.05
    root.location = offset
    col.objects.link(root)

    body = _material("body", (0.02, 0.021, 0.024), 0.0, 0.55)
    shell = _material("shell", (0.72, 0.73, 0.75), 0.1, 0.35)
    accent = _material("accent", (0.75, 0.04, 0.03), 0.1, 0.4)
    metal = _material("metal", (0.30, 0.31, 0.33), 1.0, 0.32)
    glow = _material("glow", (0.35, 0.75, 1.0), 0.0, 0.4, emit=(0.35, 0.75, 1.0))

    rec = _object(col, root, "receiver", prism(RECEIVER, RECEIVER_W), body)
    for s in (-1, 1):
        xo = s * RECEIVER_W / 2
        cut(rec, col, root, f"cut_side_panel_{s}", prism(SIDE_PANEL, 0.004, x0=(xo - 0.002 if s > 0 else xo - 0.002)))
    # cooling vents in the side panel, ahead of the charge lights
    for s in (-1, 1):
        for k in range(6):
            y = 0.010 + k * 0.017
            cut(rec, col, root, f"cut_vent_rec_{s}_{k}", prism([(y, 0.022), (y + 0.006, 0.022), (y + 0.006, 0.082), (y, 0.082)], 0.01, x0=s * RECEIVER_W / 2 - 0.006))
    bevel(rec, 0.004, 2)
    plate = _object(col, root, "led_plate", prism(LED_PLATE, 0.003, x0=-RECEIVER_W / 2 - 0.0005), body)
    bevel(plate, 0.001, 1)
    top = _object(col, root, "top_cover", prism(TOP_COVER, TOP_COVER_W), body)
    bevel(top, 0.003, 2)
    sight = _object(col, root, "rear_sight", prism(SIGHT, SIGHT_W), accent)
    bevel(sight, 0.002, 1)

    up = _object(col, root, "shroud_upper", prism(UPPER_TUBE, TUBE_W), shell)
    lo = _object(col, root, "shroud_lower", prism(LOWER_TUBE, TUBE_W), shell)
    for t in (up, lo):
        cut(t, col, root, f"cut_seam_{t.name}", box(0, SEAM_Y, BORE_Z + 0.04, TUBE_W + 0.02, 0.004, 0.2))
        bevel(t, 0.006, 3)
    # the bore: the lower tube is open at the front, with a glowing emitter
    # ring set back inside it (no prongs: the owner wants a clean muzzle)
    cut(lo, col, root, "cut_bore", cylinder_y(0.026, 0.80, 0.95, 6, BORE_Z, spin=math.pi / 6))

    und = _object(col, root, "under_housing", prism(UNDER, UNDER_W), body)
    bevel(und, 0.004, 2)
    # capacitor coils: glowing fins that wrap round the housing
    fins = [prism([(y, -0.070), (y + FIN_T, -0.070), (y + FIN_T, 0.030), (y, 0.030)], UNDER_W + 0.014) for y in FINS_Y]
    fo = _object(col, root, "coil_fins", merge(fins), glow)
    bevel(fo, 0.005, 2)
    # the core: glows in a groove along both sides, seen between the fins
    groove = [(FINS_Y[0], -0.034), (FINS_Y[-1] + FIN_T, -0.034), (FINS_Y[-1] + FIN_T, -0.010), (FINS_Y[0], -0.010)]
    for s in (-1, 1):
        cut(und, col, root, f"cut_core_groove_{s}", prism(groove, 0.008, x0=s * UNDER_W / 2 - 0.004))
    _object(col, root, "core", prism(groove, UNDER_W - 0.005), glow)
    # cooling vents ahead of the fins: slanted slots on both sides
    for s in (-1, 1):
        for k in range(6):
            y = 0.565 + k * 0.022
            cut(und, col, root, f"cut_vent_under_{s}_{k}", prism([(y, -0.046), (y + 0.007, -0.046), (y + 0.015, -0.008), (y + 0.008, -0.008)], 0.008, x0=s * UNDER_W / 2 - 0.004))

    # drum: a square block with a glowing cell set into each face
    drum = _object(col, root, "drum", cylinder_y(DRUM_R, DRUM_Y[0], DRUM_Y[1], 4, 0.0, spin=math.pi / 4), metal)
    drum.location = (0.0, 0.0, DRUM_Z)
    bevel(drum, 0.003, 1)
    face = DRUM_R * math.cos(math.pi / 4)
    ylen = DRUM_Y[1] - DRUM_Y[0] - 0.024
    yc = (DRUM_Y[0] + DRUM_Y[1]) / 2
    cells = [box(face, yc, 0.0, 0.004, ylen, 0.040), box(-face, yc, 0.0, 0.004, ylen, 0.040),
             box(0.0, yc, face, 0.040, ylen, 0.004), box(0.0, yc, -face, 0.040, ylen, 0.004)]
    dc = _object(col, root, "drum_cells", merge(cells), glow)
    dc.parent = drum

    grip = _object(col, root, "grip", prism(GRIP, GRIP_W), body)
    bevel(grip, 0.004, 2)
    frame = _object(col, root, "frame", prism(FRAME, FRAME_W), body)
    bevel(frame, 0.003, 2)
    trig = _object(col, root, "trigger", prism(TRIGGER, TRIGGER_W), accent)
    bevel(trig, 0.0015, 1)
    # red accent block on the frame (own take on the hazard band)
    _object(col, root, "frame_accent", prism([(-0.185, -0.204), (-0.100, -0.204), (-0.100, -0.196), (-0.185, -0.196)], FRAME_W + 0.002), accent)

    ring = _object(col, root, "emitter_ring", cylinder_y(0.0255, 0.852, 0.860, 6, BORE_Z, spin=math.pi / 6), glow)
    cut(ring, col, root, "cut_ring_hole", cylinder_y(0.017, 0.84, 0.87, 6, BORE_Z, spin=math.pi / 6))
    for i in range(3):
        a = math.pi / 2 + i * math.tau / 3
        ap = bpy.data.objects.new(f"arc_point_{i}", None)
        ap.empty_display_size = 0.006
        ap.parent = root
        ap.location = (math.cos(a) * 0.021, 0.862, BORE_Z + math.sin(a) * 0.021)
        col.objects.link(ap)

    mz = bpy.data.objects.new("muzzle", None)
    mz.empty_display_size = 0.03
    mz.parent = root
    mz.location = (0.0, MUZZLE_Y, BORE_Z)
    col.objects.link(mz)

    # charge lights on the left side of the receiver (2 rows of 5)
    for i, (y, z) in enumerate(LEDS):
        _object(col, root, f"led_{i}", box(-RECEIVER_W / 2 - 0.002, y, z, 0.004, 0.012, 0.012), glow)
    return col


def triangle_count(col):
    dg = bpy.context.evaluated_depsgraph_get()
    total = 0
    for o in col.objects:
        if o.type != "MESH" or o.hide_render:
            continue
        me = o.evaluated_get(dg).to_mesh()
        me.calc_loop_triangles()
        total += len(me.loop_triangles)
        o.evaluated_get(dg).to_mesh_clear()
    return total


if __name__ == "__main__":
    c = build()
    print("RAIJIN-12 triangles:", triangle_count(c))
