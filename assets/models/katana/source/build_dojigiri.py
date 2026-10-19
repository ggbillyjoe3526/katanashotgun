# Builds the DOJIGIRI katana game mesh in Blender (5.2 LTS).
# Run it in Blender's Scripting tab (or through the Blender MCP). It rebuilds
# the "DOJIGIRI" collection from scratch every time, so tweak a number here and
# run it again rather than editing the mesh by hand.
#
# Axes and size match the code-built katana in scripts/viewmodel.gd: metres,
# origin at the grip, blade up +Z, cutting edge facing -Y. The glTF exporter
# turns that into Godot's +Y up with the edge facing +Z.
#
# Material slots (the game looks them up by name):
#   steel - blade, bridges, bolts
#   grip  - the one-piece hilt (pommel, handle, collar, finger spur)
#   edge  - every glowing part. Colour-neutral; the game tints it and runs
#           effects along it. On the edge rail, UV.x runs 0 (collar) to 1 (tip)
#           and UV.y 0 (cutting edge) to 1 (inner side).
import math

import bmesh
import bpy

COLLECTION = "DOJIGIRI"

# ---------------------------------------------------------------- blade shape
Z_COL = 0.255  # where the blade leaves the collar
Z_BASE = 0.225  # blade root, hidden inside the collar
ZB = 1.075  # start of the angled point
ZT = 1.13  # the point
Y_EDGE = -0.022  # cutting edge line before the curve is added
RAIL = 0.0115  # glow rail width
GAP = 0.0035  # open slot between rail and blade body
BODY_T = 0.0075  # blade thickness at the spine
RAIL_T = 0.0045  # glow rail thickness


def sori(z):
    """The blade's gentle curve towards the spine."""
    s = max(0.0, (z - 0.17) / 0.96)
    return 0.022 * s * s


def spine(z):
    return 0.025 - 0.003 * (z - Z_COL) / (ZT - Z_COL) + sori(z)


def edge(z):
    """The cutting edge: straight (plus curve), then up to the point."""
    if z <= ZB:
        return Y_EDGE + sori(z)
    t = (z - ZB) / (ZT - ZB)
    return (Y_EDGE + sori(ZB)) * (1.0 - t) + spine(ZT) * t


def _offset_curve(d, n=400):
    """The edge line pushed inwards by d, as sorted (z, y) samples."""
    pts = [(edge(z), z) for z in (Z_BASE + (ZT - Z_BASE) * i / n for i in range(n + 1))]
    out = []
    for i, (y, z) in enumerate(pts):
        a = pts[max(i - 1, 0)]
        b = pts[min(i + 1, n)]
        tz, ty = b[1] - a[1], b[0] - a[0]
        ln = math.hypot(tz, ty) or 1.0
        out.append((z - d * ty / ln, y + d * tz / ln))
    out.sort()
    return out


_RAIL_TOP = _offset_curve(RAIL)


def _interp(table, z):
    if z <= table[0][0]:
        return table[0][1]
    for (z0, y0), (z1, y1) in zip(table, table[1:]):
        if z <= z1:
            return y0 + (y1 - y0) * (z - z0) / ((z1 - z0) or 1.0)
    return table[-1][1]


def rail_top(z):
    return min(_interp(_RAIL_TOP, z), spine(z))


def body_low(z):
    return _interp(_RAIL_TOP, z) + GAP


def smoothstep(e0, e1, x):
    t = min(1.0, max(0.0, (x - e0) / (e1 - e0)))
    return t * t * (3.0 - 2.0 * t)


def stations(z0, z1):
    """Length-wise sample points: even along the blade, dense at the point."""
    zs = [z0 + (ZB - z0) * i / 90 for i in range(91)]
    zs += [ZB + (z1 - ZB) * i / 30 for i in range(1, 31)]
    return [z for z in zs if z <= z1 + 1e-9]


def body_ring(z):
    ys, yl = spine(z), body_low(z)
    w = ys - yl
    t = BODY_T * (1.0 - 0.4 * (z - Z_COL) / (ZT - Z_COL))
    tl = 0.4 * t
    yr = yl + 0.45 * w  # ridge: thick above, ground thinner below
    c = min(0.0008, w * 0.1)
    # fuller (groove) between ridge and spine, fading in and out
    dg = 0.0011 * smoothstep(0.30, 0.36, z) * (1.0 - smoothstep(0.86, 0.93, z))
    g0, g1 = yr + 0.12 * w, yr + 0.42 * w
    gw = g1 - g0
    right = [
        (tl / 2, yl), (t / 2, yr),
        (t / 2, g0), (t / 2 - dg, g0 + 0.2 * gw), (t / 2 - dg, g1 - 0.2 * gw), (t / 2, g1),
        (t / 2, ys - c), (t / 2 - c, ys),
    ]
    return right + [(-x, y) for (x, y) in reversed(right)]


def rail_ring(z):
    ye, yt = edge(z), rail_top(z)
    w = max(yt - ye, 0.0)
    yg = ye + 0.45 * w  # edge grind
    c = min(0.0004, w * 0.1)
    right = [(0.0003, ye), (RAIL_T / 2, yg), (RAIL_T / 2, yt - c), (RAIL_T / 2 - c, yt)]
    return right + [(-x, y) for (x, y) in reversed(right)]


# ------------------------------------------------------------ mesh helpers
def _collection():
    col = bpy.data.collections.get(COLLECTION)
    if col is None:
        col = bpy.data.collections.new(COLLECTION)
        bpy.context.scene.collection.children.link(col)
    for o in list(col.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    return col


def _material(name, base, metal, rough, emit=False):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*base, 1.0)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    if emit:
        # colour-neutral: the game supplies the colour
        b.inputs["Emission Color"].default_value = (1.0, 0.36, 0.06, 1.0)
        b.inputs["Emission Strength"].default_value = 5.0
    return m


def _object(col, name, bm, mat, smooth_angle=None):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    col.objects.link(o)
    o.data.materials.append(mat)
    if smooth_angle is not None:
        with bpy.context.temp_override(selected_editable_objects=[o], active_object=o, object=o):
            bpy.ops.object.shade_smooth_by_angle(angle=math.radians(smooth_angle))
    return o


def loft(col, name, zs, ring_fn, mat, uv_fn=None):
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    rings = []
    for z in zs:
        rings.append([bm.verts.new((x, y, z)) for (x, y) in ring_fn(z)])
    n = len(rings[0])
    for a, b in zip(rings, rings[1:]):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    if uv_fn:
        for f in bm.faces:
            for loop in f.loops:
                loop[uv].uv = uv_fn(loop.vert.co)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.dissolve_degenerate(bm, edges=bm.edges, dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _object(col, name, bm, mat, smooth_angle=35)


def prism(pts_yz, thick, x0=None):
    """A flat outline in the side view (y, z), extruded across the blade (x)."""
    bm = bmesh.new()
    xa = -thick / 2 if x0 is None else x0
    f = bm.faces.new([bm.verts.new((xa, y, z)) for (y, z) in pts_yz])
    r = bmesh.ops.extrude_face_region(bm, geom=[f])
    for v in [e for e in r["geom"] if isinstance(e, bmesh.types.BMVert)]:
        v.co.x += thick
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def strip(line, width):
    """A polyline in (y, z) turned into an outline `width` wide."""
    up, dn = [], []
    for i, (y, z) in enumerate(line):
        a = line[max(i - 1, 0)]
        b = line[min(i + 1, len(line) - 1)]
        ty, tz = b[0] - a[0], b[1] - a[1]
        ln = math.hypot(ty, tz)
        ny, nz = -tz / ln, ty / ln
        up.append((y + ny * width / 2, z + nz * width / 2))
        dn.append((y - ny * width / 2, z - nz * width / 2))
    return up + list(reversed(dn))


def cylinder_x(radius, length, sides, y, z, x=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=sides, radius1=radius, radius2=radius, depth=length)
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=_rot_y90())
    bmesh.ops.translate(bm, verts=bm.verts, vec=(x, y, z))
    return bm


def cylinder_z(radius, length, sides, z):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=sides, radius1=radius, radius2=radius, depth=length)
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0.0, 0.0, z))
    return bm


def _rot_y90():
    from mathutils import Matrix
    return Matrix.Rotation(math.pi / 2, 3, "Y")


def cut(target, col, name, bm):
    """Boolean-subtract a hidden cutter from target (kept live until export)."""
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    c = bpy.data.objects.new(name, me)
    col.objects.link(c)
    c.hide_set(True)
    c.hide_render = True
    c.display_type = "WIRE"
    mod = target.modifiers.new(name, "BOOLEAN")
    mod.object = c
    mod.operation = "DIFFERENCE"
    mod.solver = "EXACT"
    return c


def bevel(o, width, segments=2, angle=30):
    b = o.modifiers.new("Bevel", "BEVEL")
    b.width = width
    b.segments = segments
    b.limit_method = "ANGLE"
    b.angle_limit = math.radians(angle)
    b.harden_normals = True
    o.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL").keep_sharp = True


def merge(bms):
    out = bmesh.new()
    for b in bms:
        me = bpy.data.meshes.new("_tmp")
        b.to_mesh(me)
        b.free()
        out.from_mesh(me)
        bpy.data.meshes.remove(me)
    return out


# ------------------------------------------------------------------ hilt
HILT_T = 0.021
HILT = [
    (0.024, -0.180), (0.024, -0.158), (0.021, -0.148), (0.021, 0.140),
    (0.030, 0.152), (0.030, 0.238), (0.006, 0.262),
    (-0.006, 0.262), (-0.020, 0.280), (-0.030, 0.280), (-0.034, 0.262),
    (-0.036, 0.248), (-0.084, 0.270), (-0.101, 0.264), (-0.094, 0.248),
    (-0.074, 0.240), (-0.046, 0.212), (-0.040, 0.192), (-0.033, 0.180), (-0.033, 0.155),
    (-0.021, 0.140), (-0.021, -0.140),
    (-0.030, -0.158), (-0.037, -0.188), (-0.026, -0.186), (-0.016, -0.197), (0.008, -0.197),
]
WINDOWS = [(0.120, 0.052), (0.056, 0.048), (-0.004, 0.044), (-0.058, 0.038), (-0.104, 0.030)]
GLOW_LINE = [(0.018, 0.232), (-0.022, 0.222), (-0.086, 0.258)]
BOLTS = [(0.013, 0.170), (-0.016, 0.170), (0.012, 0.205)]
# recessed side panel on the collar (inset from its outline)
COLLAR_PANEL = [
    (0.024, 0.160), (0.024, 0.234), (0.004, 0.254), (-0.026, 0.254), (-0.028, 0.243),
    (-0.080, 0.262), (-0.090, 0.257), (-0.072, 0.246), (-0.046, 0.218), (-0.038, 0.196),
    (-0.027, 0.183), (-0.027, 0.160),
]


def window(z, length):
    return [(-0.0145, z - length), (-0.0145, z - 0.010), (0.0145, z), (0.0145, z - length + 0.010)]


def build():
    col = _collection()
    steel = _material("steel", (0.03, 0.032, 0.036), 1.0, 0.36)
    grip = _material("grip", (0.022, 0.022, 0.025), 0.35, 0.58)
    glow = _material("edge", (1.0, 1.0, 1.0), 0.0, 0.4, emit=True)

    # blade body
    z_end = next(z for z in stations(Z_BASE, ZT) if body_low(z) >= spine(z) - 0.0012)
    zs = [z for z in stations(Z_BASE, ZT) if z < z_end] + [z_end]
    body = loft(col, "blade_body", zs, body_ring, steel)
    for i, z in enumerate((0.292, 0.311, 0.330)):  # heat vents near the root
        ys = spine(z)
        cut(body, col, f"cut_vent_{i}", prism([(ys - 0.013, z), (ys - 0.013, z + 0.004), (ys - 0.004, z + 0.012), (ys - 0.004, z + 0.008)], 0.02))

    # glow rail
    z0 = Z_COL - 0.01

    def rail_uv(co):
        ye, yt = edge(co.z), rail_top(co.z)
        return ((co.z - z0) / (ZT - z0), (co.y - ye) / (yt - ye) if yt - ye > 1e-5 else 0.0)

    loft(col, "edge_rail", stations(z0, ZT), rail_ring, glow, rail_uv)

    # bridges holding the rail across the slot, each with a pin
    parts = []
    for z in (0.47, 0.70, 0.93):
        y0, y1 = rail_top(z) - 0.0012, body_low(z) + 0.0012
        parts.append(prism([(y0, z - 0.011), (y0, z + 0.003), (y1, z + 0.014), (y1, z)], 0.0064))
        parts.append(cylinder_x(0.0011, 0.0072, 8, (y0 + y1) / 2, z + 0.0015))
    br = _object(col, "bridges", merge(parts), steel, smooth_angle=35)
    bevel(br, 0.0004, 1)

    # one-piece hilt: pommel, handle, collar and finger spur
    hilt = _object(col, "hilt", prism(HILT, HILT_T), grip)
    for i, (z, length) in enumerate(WINDOWS):
        cut(hilt, col, f"cut_window_{i}", prism(window(z, length), 0.04))
    cut(hilt, col, "cut_lanyard", cylinder_x(0.0042, 0.04, 16, 0.006, -0.184))
    for s in (-1, 1):  # both side faces
        xo = s * HILT_T / 2
        depth = 0.0008
        xa = xo - depth if s > 0 else xo - 0.002
        cut(hilt, col, f"cut_panel_{s}", prism(COLLAR_PANEL, depth + 0.002, x0=xa))
        cut(hilt, col, f"cut_glow_groove_{s}", prism(strip(GLOW_LINE, 0.0062), 0.0035 + 0.002, x0=(xo - 0.0035 if s > 0 else xo - 0.002)))
        cut(hilt, col, f"cut_pommel_line_{s}", prism([(-0.040, -0.1515), (0.030, -0.1515), (0.030, -0.1500), (-0.040, -0.1500)], 0.0007 + 0.002, x0=(xo - 0.0007 if s > 0 else xo - 0.002)))
        for j, (y, z) in enumerate(BOLTS):  # counterbores for the bolts
            cut(hilt, col, f"cut_bore_{s}_{j}", cylinder_x(0.0042, 0.002, 16, y, z, x=xo))
    for j in range(6):  # grip notches along the back of the finger spur
        t = 0.18 + j * 0.12
        y, z = -0.046 + (-0.074 + 0.046) * t, 0.212 + (0.240 - 0.212) * t
        cut(hilt, col, f"cut_notch_{j}", prism([(y - 0.0045, z - 0.0035), (y, z + 0.0012), (y + 0.0045, z - 0.0035)], 0.03))
    bevel(hilt, 0.0006, 2)

    # bolts: hex heads sitting in the counterbores, both sides
    bolts = []
    for s in (-1, 1):
        for (y, z) in BOLTS:
            bolts.append(cylinder_x(0.0031, 0.0016, 6, y, z, x=s * (HILT_T / 2 - 0.0003)))
    bo = _object(col, "bolts", merge(bolts), steel)
    bevel(bo, 0.0003, 1)

    # glowing parts on the hilt: the collar line (sits in its groove) and the core
    _object(col, "collar_glow", prism(strip(GLOW_LINE, 0.0042), HILT_T - 0.0045), glow)
    _object(col, "handle_core", cylinder_z(0.0058, 0.29, 6, 0.0), glow, smooth_angle=35)
    # dark bands that split the core into cells
    bands = []
    for (z, length) in WINDOWS:
        for zz in (z - length + 0.006, z - 0.004):
            bands.append(cylinder_z(0.0068, 0.0025, 6, zz))
    _object(col, "core_bands", merge(bands), steel)
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
    print("DOJIGIRI triangles:", triangle_count(c))
