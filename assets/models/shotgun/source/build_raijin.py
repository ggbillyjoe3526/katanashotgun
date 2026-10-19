# Builds the RAIJIN-12 arc shotgun game mesh in Blender (5.2 LTS).
# Run it in Blender's Scripting tab (or through the Blender MCP), or headless.
# It rebuilds the "RAIJIN12" collection from scratch every time, so tweak a
# number here and run it again rather than editing the mesh by hand.
#
# Axes and size match the code-built shotgun in scripts/viewmodel.gd: metres,
# origin at the code-built gun's pivot (the hand sits just below it on the
# grip), barrel forward along Blender +Y, up +Z. The glTF exporter turns that
# into Godot's barrel -Z, up +Y.
#
# Side outlines are drawn in (y, z) and extruded across the gun (x).
# Parts the game moves or drives stay separate objects:
#   drum         - square, turns 90 degrees about the barrel axis after each
#                  blast (one glowing cell per face)
#   arc_point_N  - empties on the muzzle ring; the idle crackle jumps
#                  between them (3)
#   muzzle       - empty where the blast and flash start
#   led_N        - the 10 charge lights, shown by cell count
#
# Material slots (the game looks them up by name):
#   body    - everything dark: receiver, frame, grip, housings, drum, plus the
#             red parts and the gunmetal drum, told apart by the face
#             attribute "paint" (PAINT_*), so they share one texture set
#   shell   - the light twin-tube shroud
#   coil, core, emitter, cell, led - the glowing parts, each driven by the
#             game on its own (the coil fins, the core between them, the ring
#             in the muzzle, the drum's cells, the charge lights)
import math

import bmesh
import bpy
from mathutils import Matrix

COLLECTION = "RAIJIN12"
ROOT = "RAIJIN12_root"
BORE_Z = 0.05  # barrel axis height (the code-built muzzle sits here)
MUZZLE_Y = 0.90

PAINT_BLACK = 0.0
PAINT_RED = 1.0
PAINT_METAL = 2.0
PAINT_RUBBER = 3.0

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
RECEIVER_BOLTS = [(-0.190, 0.015), (-0.190, 0.080), (0.110, 0.012)]

# twin-tube shroud (light): flat fronts, the upper tube a little longer
UPPER_TUBE = [(0.090, 0.080), (0.920, 0.080), (0.920, 0.124), (0.090, 0.124)]
LOWER_TUBE = [(0.130, 0.024), (0.900, 0.024), (0.900, 0.078), (0.130, 0.078)]
TUBE_W = 0.096
SEAM_Y = 0.60  # panel break across both tubes

# under-barrel housing (dark) that holds the coil fins, with a chamfered nose
UNDER = [
    (0.219, -0.062), (0.700, -0.062), (0.770, -0.030), (0.790, 0.026),
    (0.219, 0.026),
]
UNDER_W = 0.068
FINS_Y = (0.300, 0.365, 0.430, 0.495)
FIN_T = 0.030
# square drum of power cells under the receiver front
DRUM_Y = (0.105, 0.215)
DRUM_Z = -0.030
DRUM_R = 0.050  # centre to corner
CRADLE = [(0.100, -0.010), (0.240, -0.010), (0.240, 0.030), (0.100, 0.030)]
CRADLE_W = 0.060

# grip and the open frame that loops back to the rear of the receiver
GRIP = [
    (-0.040, -0.020), (0.035, -0.020), (0.030, -0.050), (-0.015, -0.200), (-0.020, -0.215),
    (-0.090, -0.215), (-0.090, -0.190), (-0.048, -0.040),
]
GRIP_W = 0.044
# sunken grip panel on both sides (textured for grip)
GRIP_PANEL = [(-0.0456, -0.060), (0.019, -0.060), (-0.017, -0.180), (-0.079, -0.180)]
FRAME = [
    # bottom bar from the grip foot back, a 45-degree strut up, and a short
    # stock block behind the receiver; the inside leaves an open loop
    (-0.020, -0.188), (-0.020, -0.215), (-0.200, -0.215), (-0.300, -0.115),
    (-0.300, 0.020), (-0.275, 0.050), (-0.235, 0.050), (-0.235, -0.020),
    (-0.262, -0.050), (-0.262, -0.105), (-0.190, -0.188),
]
FRAME_W = 0.038
# curved like a normal trigger: the finger face is hollow and the tip points forward
TRIGGER = [(0.050, -0.020), (0.066, -0.020), (0.063, -0.045), (0.076, -0.075), (0.066, -0.077), (0.051, -0.047)]
TRIGGER_W = 0.010

LEDS = [(-0.112 + (i % 5) * 0.022, 0.071 - (i // 5) * 0.022) for i in range(10)]
LED_X = -RECEIVER_W / 2 - 0.0005  # outer face of the LED plate (left side)


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
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    b = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(b.outputs[0], out.inputs["Surface"])
    b.inputs["Base Color"].default_value = (*base, 1.0)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    if emit:
        # preview colour only: the game tints glowing parts itself
        b.inputs["Emission Color"].default_value = (*emit, 1.0)
        b.inputs["Emission Strength"].default_value = 1.5
    if name == "body":
        # preview: the paint attribute picks black, red, gunmetal or rubber
        attr = nt.nodes.new("ShaderNodeAttribute")
        attr.attribute_name = "paint"
        scale = nt.nodes.new("ShaderNodeMath")
        scale.operation = "MULTIPLY"
        scale.inputs[1].default_value = 0.25
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.interpolation = "CONSTANT"
        el = ramp.color_ramp.elements
        el[0].position, el[0].color = 0.0, (0.02, 0.021, 0.024, 1.0)
        el[1].position, el[1].color = 0.2, (0.75, 0.04, 0.03, 1.0)
        el.new(0.45).color = (0.30, 0.31, 0.33, 1.0)
        el.new(0.7).color = (0.012, 0.012, 0.014, 1.0)
        nt.links.new(attr.outputs["Fac"], scale.inputs[0])
        nt.links.new(scale.outputs[0], ramp.inputs["Fac"])
        nt.links.new(ramp.outputs["Color"], b.inputs["Base Color"])
    return m


def _paint(me, value):
    a = me.attributes.get("paint") or me.attributes.new("paint", "FLOAT", "FACE")
    a.data.foreach_set("value", [value] * len(me.polygons))


def _object(col, root, name, bm, mat, paint=PAINT_BLACK):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    _paint(me, paint)
    o = bpy.data.objects.new(name, me)
    col.objects.link(o)
    o.parent = root
    o.data.materials.append(mat)
    o["paint"] = paint
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


def side(pts_yz, depth, w, s):
    """A cutter `depth` deep into the side face at x = s * w / 2."""
    return prism(pts_yz, depth + 0.004, x0=w / 2 - depth if s > 0 else -w / 2 - 0.004)


def rect(y0, y1, z0, z1):
    return [(y0, z0), (y1, z0), (y1, z1), (y0, z1)]


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


def cylinder_x(radius, x0, x1, sides, y, z):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=sides, radius1=radius, radius2=radius, depth=x1 - x0)
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "Y"))
    bmesh.ops.translate(bm, verts=bm.verts, vec=((x0 + x1) / 2, y, z))
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
    """Boolean-subtract a hidden cutter from target (kept live until export).
    The cutter carries the target's paint, so the new faces match it."""
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    _paint(me, target.get("paint", PAINT_BLACK))
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


def counterbores(target, col, root, name, pts, w):
    for s in (-1, 1):
        for j, (y, z) in enumerate(pts):
            x0 = w / 2 - 0.0015 if s > 0 else -w / 2 - 0.004
            cut(target, col, root, f"{name}_{s}_{j}", cylinder_x(0.0044, x0, x0 + 0.0055, 16, y, z))


def hex_bolts(col, root, name, pts, w, mat):
    """Hex bolt heads sitting in the counterbores, both sides."""
    parts = []
    for s in (-1, 1):
        x0 = w / 2 - 0.0028 if s > 0 else -w / 2 + 0.0012
        for (y, z) in pts:
            parts.append(cylinder_x(0.0032, x0, x0 + 0.0016, 6, y, z))
    o = _object(col, root, name, merge(parts), mat, PAINT_METAL)
    bevel(o, 0.0003, 1)
    return o


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
    blue = (0.35, 0.75, 1.0)
    coil = _material("coil", blue, 0.0, 0.4, emit=blue)
    core = _material("core", blue, 0.0, 0.4, emit=blue)
    emitter = _material("emitter", blue, 0.0, 0.4, emit=blue)
    cell = _material("cell", blue, 0.0, 0.4, emit=blue)
    led = _material("led", blue, 0.0, 0.4, emit=blue)

    # ---- receiver
    rec = _object(col, root, "receiver", prism(RECEIVER, RECEIVER_W), body)
    for s in (-1, 1):
        cut(rec, col, root, f"cut_side_panel_{s}", side(SIDE_PANEL, 0.002, RECEIVER_W, s))
        # cooling vents in the side panel, ahead of the charge lights
        for k in range(6):
            y = -0.004 + k * 0.016
            cut(rec, col, root, f"cut_vent_rec_{s}_{k}", side([(y, 0.022), (y + 0.006, 0.022), (y + 0.022, 0.082), (y + 0.016, 0.082)], 0.006, RECEIVER_W, s))
        # seam between the upper and lower receiver, above the panel
        cut(rec, col, root, f"cut_seam_rec_{s}", side(rect(-0.228, 0.150, 0.1045, 0.1060), 0.0008, RECEIVER_W, s))
    counterbores(rec, col, root, "cut_bore_rec", RECEIVER_BOLTS, RECEIVER_W - 0.004)
    # recessed plate on the rear face
    cut(rec, col, root, "cut_rear_plate", box(0.0, -0.235, 0.045, 0.072, 0.004, 0.090))
    bevel(rec, 0.004, 3)
    hex_bolts(col, root, "receiver_bolts", RECEIVER_BOLTS, RECEIVER_W - 0.004, body)

    plate = _object(col, root, "led_plate", prism(LED_PLATE, 0.003, x0=LED_X), body)
    for i, (y, z) in enumerate(LEDS):
        cut(plate, col, root, f"cut_led_{i}", box(LED_X, y, z, 0.0032, 0.0145, 0.0145))
    bevel(plate, 0.0008, 2)

    top = _object(col, root, "top_cover", prism(TOP_COVER, TOP_COVER_W), body)
    # rail grooves across the top
    for k in range(7):
        y = -0.098 + k * 0.026
        cut(top, col, root, f"cut_rail_{k}", box(0.0, y, 0.146, TOP_COVER_W + 0.01, 0.006, 0.004))
    bevel(top, 0.003, 3)

    sight = _object(col, root, "rear_sight", prism(SIGHT, SIGHT_W), body, PAINT_RED)
    # the notch floor sits above the front slope's foot (z 0.132): level with
    # it, the cut left overlapping faces there
    cut(sight, col, root, "cut_sight_notch", box(0.0, -0.18, 0.143, 0.014, 0.1, 0.016))
    for k in range(3):
        cut(sight, col, root, f"cut_sight_rib_{k}", box(0.0, -0.216, 0.112 + k * 0.009, SIGHT_W + 0.01, 0.004, 0.0025))
    bevel(sight, 0.002, 2)

    # ---- shroud
    up = _object(col, root, "shroud_upper", prism(UPPER_TUBE, TUBE_W), shell)
    lo = _object(col, root, "shroud_lower", prism(LOWER_TUBE, TUBE_W), shell)
    for t in (up, lo):
        cut(t, col, root, f"cut_seam_{t.name}", box(0, SEAM_Y, BORE_Z + 0.04, TUBE_W + 0.02, 0.004, 0.2))
    # two long flutes along the top
    for sx in (-1, 1):
        for (y0, y1) in ((0.20, 0.585), (0.615, 0.90)):
            cut(up, col, root, f"cut_flute_{sx}_{y0}", box(sx * 0.022, (y0 + y1) / 2, 0.124, 0.008, y1 - y0, 0.004))
    # small heat slots near the front of the upper tube
    for s in (-1, 1):
        for k in range(5):
            y = 0.790 + k * 0.022
            cut(up, col, root, f"cut_heat_{s}_{k}", side(rect(y, y + 0.012, 0.094, 0.110), 0.004, TUBE_W, s))
    # the bore: a square-framed recess in the lower tube's front, with a
    # glowing emitter ring set back inside it (no prongs: a clean muzzle)
    cut(lo, col, root, "cut_bore_frame", box(0.0, 0.900, BORE_Z, 0.074, 0.006, 0.040))
    cut(lo, col, root, "cut_bore", cylinder_y(0.026, 0.80, 0.95, 6, BORE_Z, spin=math.pi / 6))
    bevel(up, 0.006, 3)
    bevel(lo, 0.006, 3)

    ring = _object(col, root, "emitter_ring", cylinder_y(0.0255, 0.852, 0.860, 6, BORE_Z, spin=math.pi / 6), emitter)
    cut(ring, col, root, "cut_ring_hole", cylinder_y(0.017, 0.84, 0.87, 6, BORE_Z, spin=math.pi / 6))
    # a dark back plate behind the ring, so the bore doesn't look hollow
    _object(col, root, "bore_back", cylinder_y(0.026, 0.846, 0.852, 6, BORE_Z, spin=math.pi / 6), body, PAINT_METAL)
    for i in range(3):
        a = math.pi / 2 + i * math.tau / 3
        ap = bpy.data.objects.new(f"arc_point_{i}", None)
        ap.empty_display_size = 0.006
        ap.parent = root
        ap.location = (math.cos(a) * 0.021, 0.862, BORE_Z + math.sin(a) * 0.021)
        col.objects.link(ap)

    # ---- under-barrel housing, coil fins and core
    und = _object(col, root, "under_housing", prism(UNDER, UNDER_W), body)
    groove = rect(FINS_Y[0], FINS_Y[-1] + FIN_T, -0.034, -0.010)
    for s in (-1, 1):
        cut(und, col, root, f"cut_core_groove_{s}", side(groove, 0.004, UNDER_W, s))
        # cooling vents ahead of the fins: slanted slots
        for k in range(6):
            y = 0.565 + k * 0.022
            cut(und, col, root, f"cut_vent_under_{s}_{k}", side([(y, -0.046), (y + 0.007, -0.046), (y + 0.015, -0.008), (y + 0.008, -0.008)], 0.004, UNDER_W, s))
    housing_bolts = [(0.240, -0.045), (0.725, 0.008)]
    counterbores(und, col, root, "cut_bore_und", housing_bolts, UNDER_W)
    bevel(und, 0.004, 3)
    hex_bolts(col, root, "housing_bolts", housing_bolts, UNDER_W, body)

    fins = [prism(rect(y, y + FIN_T, -0.070, 0.030), UNDER_W + 0.014) for y in FINS_Y]
    fo = _object(col, root, "coil_fins", merge(fins), coil)
    bevel(fo, 0.005, 3)
    _object(col, root, "core", prism(groove, UNDER_W - 0.005), core)

    # ---- drum: a square block, a glowing cell set into a window on each face
    drum = _object(col, root, "drum", cylinder_y(DRUM_R, DRUM_Y[0], DRUM_Y[1], 4, 0.0, spin=math.pi / 4), body, PAINT_METAL)
    drum.location = (0.0, 0.0, DRUM_Z)
    face = DRUM_R * math.cos(math.pi / 4)
    ylen = DRUM_Y[1] - DRUM_Y[0] - 0.024
    yc = (DRUM_Y[0] + DRUM_Y[1]) / 2
    wins = [box(face, yc, 0.0, 0.006, ylen + 0.004, 0.044), box(-face, yc, 0.0, 0.006, ylen + 0.004, 0.044),
            box(0.0, yc, face, 0.044, ylen + 0.004, 0.006), box(0.0, yc, -face, 0.044, ylen + 0.004, 0.006)]
    for i, w in enumerate(wins):
        cut(drum, col, root, f"cut_drum_window_{i}", w).parent = drum
    # end hubs on the axle
    hubs = [cylinder_y(0.014, DRUM_Y[0] - 0.003, DRUM_Y[0] + 0.001, 8, 0.0), cylinder_y(0.014, DRUM_Y[1] - 0.001, DRUM_Y[1] + 0.003, 8, 0.0)]
    hub = _object(col, root, "drum_hubs", merge(hubs), body, PAINT_METAL)
    hub.parent = drum
    bevel(drum, 0.004, 3)
    bevel(hub, 0.001, 1)
    inset = face - 0.0028
    cells = [box(inset, yc, 0.0, 0.002, ylen, 0.040), box(-inset, yc, 0.0, 0.002, ylen, 0.040),
             box(0.0, yc, inset, 0.040, ylen, 0.002), box(0.0, yc, -inset, 0.040, ylen, 0.002)]
    dc = _object(col, root, "drum_cells", merge(cells), cell)
    dc.parent = drum
    # cradle: holds the drum against the receiver and the shroud, no gap
    cradle = _object(col, root, "drum_cradle", prism(CRADLE, CRADLE_W), body)
    cradle_bolts = [(0.230, 0.012)]
    counterbores(cradle, col, root, "cut_bore_cradle", cradle_bolts, CRADLE_W)
    bevel(cradle, 0.003, 3)
    hex_bolts(col, root, "cradle_bolts", cradle_bolts, CRADLE_W, body)

    # ---- grip, frame and trigger
    grip = _object(col, root, "grip", prism(GRIP, GRIP_W), body, PAINT_RUBBER)
    for s in (-1, 1):
        cut(grip, col, root, f"cut_grip_panel_{s}", side(GRIP_PANEL, 0.0015, GRIP_W, s))
    # finger grooves along the front
    for k, t in enumerate((0.22, 0.47, 0.72)):
        y = 0.030 + (-0.015 - 0.030) * t
        z = -0.050 + (-0.200 + 0.050) * t
        cut(grip, col, root, f"cut_finger_{k}", cylinder_x(0.013, -0.04, 0.04, 16, y + 0.0105, z + 0.003))
    bevel(grip, 0.004, 3)
    frame = _object(col, root, "frame", prism(FRAME, FRAME_W), body)
    # lightening slot through the stock block
    cut(frame, col, root, "cut_stock_slot", prism([(-0.288, -0.095), (-0.274, -0.095), (-0.274, -0.030), (-0.288, -0.022)], FRAME_W + 0.01))
    # butt pad groove
    cut(frame, col, root, "cut_butt_groove", box(0.0, -0.300, -0.045, FRAME_W + 0.01, 0.004, 0.004))
    bevel(frame, 0.003, 3)
    trig = _object(col, root, "trigger", prism(TRIGGER, TRIGGER_W), body, PAINT_RED)
    bevel(trig, 0.0015, 2)
    _object(col, root, "frame_accent", prism(rect(-0.185, -0.100, -0.204, -0.196), FRAME_W + 0.002), body, PAINT_RED)

    mz = bpy.data.objects.new("muzzle", None)
    mz.empty_display_size = 0.03
    mz.parent = root
    mz.location = (0.0, MUZZLE_Y, BORE_Z)
    col.objects.link(mz)

    # charge lights in their holes in the plate (2 rows of 5)
    for i, (y, z) in enumerate(LEDS):
        o = _object(col, root, f"led_{i}", box(0.0, 0.0, 0.0, 0.002, 0.012, 0.012), led)
        o.location = (LED_X + 0.0005, y, z)
        bevel(o, 0.0006, 1)
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
