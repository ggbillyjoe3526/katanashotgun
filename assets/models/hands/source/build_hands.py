# Builds the player's two armoured cyber hands in Blender (5.2 LTS), each
# holding its weapon: the left hand on the DOJIGIRI's handle, the right on the
# RAIJIN-12's grip with the index finger on the trigger. Run it in Blender's
# Scripting tab or headless; it rebuilds the "HANDS" collection every time.
#
# Each hand is built in the space of the weapon model it holds (see the
# weapons' build scripts): metres, Blender axes, so the game parents it to the
# weapon model and it follows every swing and recoil.
#
# Material slots (the game looks them up by name):
#   armor - the plates (fingers, back of the hand, forearm)
#   joint - the dark under-suit between plates (palm, knuckles, cuff)
#   glow  - the light lines; the game tints them with the weapon's trim
import math

import bmesh
import bpy
from mathutils import Matrix, Vector

COLLECTION = "HANDS"
SLOTS = ("armor", "joint", "glow")

# finger size (all four the same width; the arcs set their length)
FW = 0.0195  # width along the bar
FT = 0.0205  # thickness
FGAP = 0.0028
CLEAR = 0.0025  # gap between finger and bar
# the arc each phalanx covers around the bar (degrees), from the knuckle
PHALANX_DEG = (88.0, 72.0, 52.0)
KNUCKLE_DEG = 52.0
FINGER_SCALE = (1.0, 1.05, 1.0, 0.85)  # index..little
PALM_T = 0.026
WRIST_Y = -0.072  # how far behind the bar the wrist starts
ARM_LEN = 0.36
ARM_W0 = (0.056, 0.05)  # forearm (across, deep) at the wrist
ARM_W1 = (0.078, 0.07)  # at the far end
UV_TILE = 0.08
# the game holds the DOJIGIRI at this size (KATANA_MODEL_SCALE in
# scripts/viewmodel.gd) and the left hand is a child of the katana model, so
# the hand is built around the handle at that size and then shrunk by it:
# fingers and forearm come out the same size as the right hand's
KATANA_IN_HAND = 1.5


def _box(bm, a, b, out, w, t, mat, grow=0.0):
    """A plate from a to b, `t` thick along `out` and `w` wide across."""
    d = (b - a)
    ln = d.length
    if ln < 1e-6:
        return
    d /= ln
    out = (out - d * out.dot(d)).normalized()
    side = d.cross(out).normalized()
    a = a - d * grow
    b = b + d * grow
    vs = []
    for p in (a, b):
        for s in (-1, 1):
            for o in (-1, 1):
                vs.append(bm.verts.new(p + side * (s * w / 2) + out * (o * t / 2)))
    # verts: [a--, a-+, a+-, a++, b--, b-+, b+-, b++]
    faces = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (1, 5, 7, 3), (0, 2, 6, 4)]
    for f in faces:
        face = bm.faces.new([vs[i] for i in f])
        face.material_index = mat


def _taper(bm, a, b, out, w0, w1, mat):
    """A box from a to b whose section grows from w0 to w1 (across, deep)."""
    d = (b - a).normalized()
    out = (out - d * out.dot(d)).normalized()
    side = d.cross(out).normalized()
    vs = []
    for p, (w, t) in ((a, w0), (b, w1)):
        for s in (-1, 1):
            for o in (-1, 1):
                vs.append(bm.verts.new(p + side * (s * w / 2) + out * (o * t / 2)))
    faces = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (1, 5, 7, 3), (0, 2, 6, 4)]
    for f in faces:
        bm.faces.new([vs[i] for i in f]).material_index = mat


def _ell(ax, ay, deg, z, push=0.0):
    a = math.radians(deg)
    rx = ax + CLEAR + FT / 2 + push
    ry = ay + CLEAR + FT / 2 + push
    return Vector((rx * math.cos(a), ry * math.sin(a), z))


def _ell_out(deg):
    a = math.radians(deg)
    return Vector((math.cos(a), math.sin(a), 0.0))


def fist(bm, ax, ay, z_top, fingers=(0, 1, 2, 3), arm_dir=(0.0, -1.0, -0.6)):
    """A right hand gripping a bar along Z with half sizes ax (palm side, +X)
    and ay (knuckles toward +Y). Finger 0 (index) sits at z_top."""
    A, J, G = 0, 1, 2
    zs = [z_top - FW / 2 - k * (FW + FGAP) for k in range(4)]
    z_bot = zs[3] - FW / 2
    for k in fingers:
        z = zs[k]
        sc = FINGER_SCALE[k]
        deg = KNUCKLE_DEG
        pts = [_ell(ax, ay, deg, z, 0.004)]
        for ph in PHALANX_DEG:
            deg += ph * sc
            pts.append(_ell(ax, ay, deg, z))
        for i in range(3):
            mid = (pts[i] + pts[i + 1]) / 2
            out = Vector((mid.x / (ax + 0.02) ** 2, mid.y / (ay + 0.02) ** 2, 0)).normalized()
            _box(bm, pts[i], pts[i + 1], out, FW, FT if i < 2 else FT * 0.9, A if i != 1 else A, 0.0035)
            # dark joint under each plate seam
            _box(bm, pts[i], pts[i] + (pts[i + 1] - pts[i]) * 0.2, out, FW * 0.86, FT * 0.82, J, 0.004)
    # knuckle guard across the knuckles
    k0 = _ell(ax, ay, KNUCKLE_DEG, 0, 0.012)
    _box(bm, Vector((k0.x, k0.y, z_top + 0.004)), Vector((k0.x, k0.y, z_bot - 0.002)), _ell_out(KNUCKLE_DEG), 0.026, 0.016, A)
    # palm and back of the hand (from the knuckles back to the wrist)
    px = ax + CLEAR + PALM_T / 2
    k_y = k0.y - 0.004
    _box(bm, Vector((px, k_y, (z_top + z_bot) / 2)), Vector((px, WRIST_Y, (z_top + z_bot) / 2)), Vector((0, 0, 1)), PALM_T, z_top - z_bot + 0.006, J)
    back = Vector((px + PALM_T / 2 + 0.004, 0, 0))
    _box(bm, Vector((back.x, k_y + 0.002, (z_top + z_bot) / 2)), Vector((back.x, WRIST_Y + 0.008, (z_top + z_bot) / 2)), Vector((0, 0, 1)), 0.01, z_top - z_bot + 0.002, A)
    _box(bm, Vector((back.x + 0.0055, k_y - 0.01, (z_top + z_bot) / 2)), Vector((back.x + 0.0055, WRIST_Y + 0.02, (z_top + z_bot) / 2)), Vector((0, 0, 1)), 0.0015, 0.006, G)
    # thumb over the index finger
    ry = ay + CLEAR + FT
    t0 = Vector((px + 0.004, WRIST_Y * 0.45, z_top - 0.012))
    t1 = Vector((px - 0.002, ry * 0.55, z_top + 0.006))
    t2 = Vector((ax * 0.15, ry + 0.012, z_top + 0.004))
    t3 = Vector((-ax * 0.95, ry + 0.006, z_top - 0.004))
    for a, b, w, t in ((t0, t1, 0.026, 0.024), (t1, t2, 0.022, 0.021), (t2, t3, 0.02, 0.019)):
        _box(bm, a, b, Vector((0, 0, 1)), w, t, A, 0.003)
    # wrist cuff and forearm
    wrist = Vector((px, WRIST_Y, (z_top + z_bot) / 2))
    d = Vector(arm_dir).normalized()
    _taper(bm, wrist - d * 0.004, wrist + d * 0.03, Vector((1, 0, 0)), (0.05, 0.044), (0.054, 0.048), J)
    a0 = wrist + d * 0.026
    a1 = a0 + d * ARM_LEN
    _taper(bm, a0, a1, Vector((1, 0, 0)), ARM_W0, ARM_W1, A)
    # a raised plate and a glow line along the outside of the forearm
    o = Vector((1, 0, 0))
    o = (o - d * o.dot(d)).normalized()
    _box(bm, a0 + d * 0.03 + o * 0.03, a1 - d * 0.03 + o * 0.039, o, 0.04, 0.008, A)
    _box(bm, a0 + d * 0.05 + o * 0.035, a1 - d * 0.05 + o * 0.044, o, 0.004, 0.003, G)
    return zs


def trigger_finger(bm, ax, ay, z, tip):
    """The index finger laid along the side of the gun to the trigger `tip`
    (in the hand's own space)."""
    k = _ell(ax, ay, KNUCKLE_DEG - 10, z, 0.004)
    p1 = Vector((k.x * 0.6, tip.y - 0.008, z))
    _box(bm, k, p1, Vector((1, 0, 0.3)), FW, FT, 0, 0.003)
    _box(bm, p1, tip, Vector((0, 1, 0)), FW * 0.95, FT * 0.9, 0, 0.003)


def _mats():
    out = []
    for name in SLOTS:
        m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
        m.diffuse_color = {"armor": (0.2, 0.21, 0.24, 1), "joint": (0.04, 0.04, 0.05, 1), "glow": (0.3, 0.9, 1, 1)}[name]
        out.append(m)
    return out


def _box_uv(bm):
    """Box-projected UVs, UV_TILE metres per texture repeat: the game lays its
    panel texture over the plates with them."""
    uv = bm.loops.layers.uv.verify()
    for f in bm.faces:
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        u, v = [i for i in range(3) if i != ax]
        for lp in f.loops:
            co = lp.vert.co
            lp[uv].uv = (co[u] / UV_TILE, co[v] / UV_TILE)


def _object(col, name, bm, mat, mirror_y=False):
    if mirror_y:
        bmesh.ops.transform(bm, matrix=Matrix.Scale(-1, 4, Vector((0, 1, 0))), verts=bm.verts)
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
    bmesh.ops.transform(bm, matrix=mat, verts=bm.verts)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    _box_uv(bm)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for m in _mats():
        me.materials.append(m)
    ob = bpy.data.objects.new(name, me)
    col.objects.link(ob)
    bev = ob.modifiers.new("bevel", "BEVEL")
    bev.width = 0.0016
    bev.segments = 1
    bev.limit_method = "ANGLE"
    return ob


def build():
    col = bpy.data.collections.get(COLLECTION)
    if col:
        for ob in list(col.objects):
            bpy.data.objects.remove(ob, do_unlink=True)
    else:
        col = bpy.data.collections.new(COLLECTION)
        bpy.context.scene.collection.children.link(col)
    # left hand on the katana handle: the knuckles face the edge (-Y), the
    # forearm leaves from the spine side towards the pommel
    k = KATANA_IN_HAND
    bm = bmesh.new()
    fist(bm, 0.0105 * k, 0.021 * k, 0.128 * k, arm_dir=(0.0, -1.0, -0.75))
    _object(col, "hand_katana", bm, Matrix.Scale(1.0 / k, 4), mirror_y=True)
    # right hand on the shotgun's raked grip, index finger on the trigger
    rake = math.radians(15.5)
    m = Matrix.Translation((0.0, -0.021, -0.085)) @ Matrix.Rotation(-rake, 4, "X")
    bm = bmesh.new()
    ax, ay = 0.022, 0.034
    zs = fist(bm, ax, ay, 0.062, fingers=(1, 2, 3), arm_dir=(0.0, -1.0, -0.35))
    tip = m.inverted() @ Vector((0.0, 0.062, -0.05))
    tip.x = 0.0
    trigger_finger(bm, ax, ay, zs[0], Vector((ax * 0.3 + 0.004, tip.y, zs[0] - 0.004)))
    _object(col, "hand_shotgun", bm, m)
    return col


if __name__ == "__main__":
    build()
