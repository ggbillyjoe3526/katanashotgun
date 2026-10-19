# Procedural surface detail for the RAIJIN-12 shotgun, baked to textures.
#
# Two baked texture sets, one per textured material slot, each 2048 px, laid
# out like the katana's (see ../../katana/source/surface_dojigiri.py, whose
# node and image helpers this reuses):
#   raijin_<slot>_basecolor.png  colour (sRGB)
#   raijin_<slot>_orm.png        R occlusion, G roughness, B metallic (linear)
#   raijin_<slot>_normal.png     tangent-space normal map, OpenGL (Y+)
#   raijin_<slot>_retro.png      256 px colour with light and shine painted in
# The glowing slots have no textures: the game draws them.
#
# The detail is driven by object-space position (metres, see build_raijin.py)
# and, on the body, by the face attribute "paint" (black, red, gunmetal,
# rubber). Markings are our own: plus and minus signs, ticks, corner
# brackets and stripes. No text, no logos.
import os
import sys

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "katana", "source"))
import surface_dojigiri as S  # noqa: E402

SIZE = S.SIZE
RETRO_SIZE = S.RETRO_SIZE
SLOTS = ("body", "shell")


# ------------------------------------------------------------ mask helpers
def _band(g, v, a, b, soft=0.0002):
    """1 where a < v < b (soft edges), else 0."""
    return g.math("MULTIPLY", g.map_range(v, a - soft, a), g.map_range(v, b + soft, b))


def _rect(g, y, z, y0, y1, z0, z1):
    return g.math("MULTIPLY", _band(g, y, y0, y1), _band(g, z, z0, z1))


def _union(g, masks):
    out = masks[0]
    for m in masks[1:]:
        out = g.math("MAXIMUM", out, m)
    return out


def _plus(g, y, z, cy, cz, size, t):
    h = size / 2
    return g.math("MAXIMUM", _rect(g, y, z, cy - h, cy + h, cz - t / 2, cz + t / 2), _rect(g, y, z, cy - t / 2, cy + t / 2, cz - h, cz + h))


def _bracket(g, y, z, cy, cz, sy, sz, size, t):
    """An L-shaped corner mark at (cy, cz) opening towards (sy, sz)."""
    a = _rect(g, y, z, min(cy, cy + sy * size), max(cy, cy + sy * size), min(cz, cz + sz * t), max(cz, cz + sz * t))
    b = _rect(g, y, z, min(cy, cy + sy * t), max(cy, cy + sy * t), min(cz, cz + sz * size), max(cz, cz + sz * size))
    return g.math("MAXIMUM", a, b)


def _side_faces(g, geo):
    nx = g.math("ABSOLUTE", g.xyz(geo.outputs["Normal"])[0])
    return g.map_range(nx, 0.85, 0.95)


def _paint_is(g, paint, v):
    return _band(g, paint, v - 0.5, v + 0.5, 0.01)


# ------------------------------------------------------------ channels
def _channels_body(g):
    co = g.node("ShaderNodeTexCoord").outputs["Object"]
    x, y, z = g.xyz(co)
    attr = g.node("ShaderNodeAttribute", attribute_name="paint")
    paint = attr.outputs["Fac"]
    red = _paint_is(g, paint, 1.0)
    metal_p = _paint_is(g, paint, 2.0)
    rubber = _paint_is(g, paint, 3.0)
    edge, geo = S._edge_mask(g, 0.0007, 10.0)
    sidef = _side_faces(g, geo)

    stipple = g.noise(co, 2400.0, 2.0, 0.5)
    grime = g.noise(g.scale(co, (22.0, 22.0, 22.0)), 2.0, 6.0, 0.6)
    chips = g.map_range(g.noise(co, 260.0, 3.0), 0.38, 0.62)
    worn = g.math("MULTIPLY", edge, chips)
    brushed = g.noise(g.scale(co, (40.0, 1400.0, 40.0)), 1.0, 4.0, 0.6)
    # diamond knurl on the sunken grip panels
    pitch = 0.0016
    u = g.math("FRACT", g.math("DIVIDE", g.math("ADD", y, z), pitch))
    v = g.math("FRACT", g.math("DIVIDE", g.math("SUBTRACT", y, z), pitch))
    knurl = g.math("MULTIPLY", g.math("MINIMUM", g.math("ABSOLUTE", g.math("SUBTRACT", u, 0.5)), g.math("ABSOLUTE", g.math("SUBTRACT", v, 0.5))), 2.0)
    grip_panel = g.math("MULTIPLY", g.math("MULTIPLY", rubber, sidef), g.map_range(g.math("ABSOLUTE", x), 0.0212, 0.0203))

    # painted markings (white) on side faces of the black parts
    marks = _union(g, [
        _plus(g, y, z, -0.170, 0.048, 0.016, 0.0028),  # receiver side panel
        _bracket(g, y, z, -0.131, 0.029, 1, 1, 0.008, 0.0014),
        _bracket(g, y, z, -0.004, 0.029, -1, 1, 0.008, 0.0014),
        _bracket(g, y, z, -0.131, 0.091, 1, -1, 0.008, 0.0014),
        _bracket(g, y, z, -0.004, 0.091, -1, -1, 0.008, 0.0014),
        _rect(g, y, z, 0.140, 0.160, 0.0615, 0.0640),  # minus on the receiver nose
        _rect(g, y, z, 0.255, 0.275, -0.0045, -0.0020),  # minus on the housing
        _plus(g, y, z, 0.640, -0.028, 0.012, 0.0024),  # plus on the housing nose
    ])
    ticks = g.math("MULTIPLY", _band(g, z, -0.212, -0.205),
                   g.map_range(g.math("FRACT", g.math("DIVIDE", y, 0.012)), 0.80, 0.82))
    ticks = g.math("MULTIPLY", ticks, _band(g, y, -0.190, -0.030))
    marks = g.math("MAXIMUM", marks, ticks)
    marks = g.math("MULTIPLY", g.math("MULTIPLY", marks, sidef), g.math("SUBTRACT", 1.0, g.math("MAXIMUM", red, metal_p)))
    marks_worn = g.math("MULTIPLY", marks, g.map_range(g.noise(co, 900.0, 2.0), 0.28, 0.40))

    black = g.mix_rgb(g.math("MULTIPLY", grime, 0.35), (0.020, 0.021, 0.024, 1.0), (0.034, 0.032, 0.030, 1.0))
    color = black
    color = g.mix_rgb(red, color, (0.50, 0.030, 0.022, 1.0))
    color = g.mix_rgb(metal_p, color, (0.085, 0.088, 0.095, 1.0))
    color = g.mix_rgb(rubber, color, (0.013, 0.013, 0.015, 1.0))
    color = g.mix_rgb(marks_worn, color, (0.62, 0.63, 0.62, 1.0))
    color = g.mix_rgb(worn, color, (0.30, 0.30, 0.31, 1.0))

    rough = g.math("ADD", 0.48, g.math("MULTIPLY", stipple, 0.14))
    rough = g.mix(red, rough, 0.38)
    rough = g.mix(metal_p, rough, g.math("ADD", 0.26, g.math("MULTIPLY", brushed, 0.12)))
    rough = g.mix(rubber, rough, 0.78)
    rough = g.mix(marks_worn, rough, 0.55)
    rough = g.mix(worn, rough, 0.28)
    rough = g.math("ADD", rough, g.math("MULTIPLY", grime, 0.06))
    metal = g.math("MAXIMUM", metal_p, worn)
    height = g.math("MULTIPLY", stipple, 0.10)
    height = g.math("ADD", height, g.math("MULTIPLY", knurl, grip_panel))
    height = g.math("ADD", height, g.math("MULTIPLY", g.math("MULTIPLY", brushed, metal_p), 0.25))
    height = g.math("ADD", height, g.math("MULTIPLY", marks, 0.05))
    return color, rough, metal, height, 0.00035


def _channels_shell(g):
    co = g.node("ShaderNodeTexCoord").outputs["Object"]
    x, y, z = g.xyz(co)
    edge, geo = S._edge_mask(g, 0.0008, 9.0)
    sidef = _side_faces(g, geo)
    mottle = g.noise(g.scale(co, (60.0, 20.0, 60.0)), 1.0, 4.0, 0.55)
    micro = g.noise(co, 1800.0, 2.0, 0.5)
    grime = g.noise(g.scale(co, (18.0, 18.0, 18.0)), 2.0, 6.0, 0.6)
    scr = g.map_range(g.noise(g.scale(co, (40.0, 700.0, 40.0)), 1.0, 1.0), 0.74, 0.79)
    chips = g.math("MULTIPLY", edge, g.map_range(g.noise(co, 220.0, 3.0), 0.45, 0.66))
    # soot from the muzzle, fading back along the tubes
    soot = g.math("MULTIPLY", g.map_range(y, 0.80, 0.92), 0.55)
    soot = g.math("MULTIPLY", soot, g.map_range(grime, 0.3, 0.7, 0.6, 1.0))

    red_stripe = _union(g, [
        _rect(g, y, z, 0.200, 0.580, 0.1125, 0.1148),
        _rect(g, y, z, 0.620, 0.640, 0.0330, 0.0400),
    ])
    dark = _union(g, [
        _plus(g, y, z, 0.845, 0.045, 0.014, 0.0030),
        _rect(g, y, z, 0.200, 0.215, 0.0640, 0.0700),
        _rect(g, y, z, 0.222, 0.229, 0.0640, 0.0700),
        _bracket(g, y, z, 0.140, 0.034, 1, 1, 0.010, 0.0016),
        _bracket(g, y, z, 0.140, 0.112, 1, -1, 0.010, 0.0016),
    ])
    ticks = g.math("MULTIPLY", _band(g, z, 0.066, 0.073),
                   g.map_range(g.math("FRACT", g.math("DIVIDE", y, 0.03)), 0.93, 0.95))
    ticks = g.math("MULTIPLY", ticks, _band(g, y, 0.650, 0.830))
    dark = g.math("MAXIMUM", dark, ticks)
    keep = g.map_range(g.noise(co, 900.0, 2.0), 0.26, 0.38)
    red_m = g.math("MULTIPLY", g.math("MULTIPLY", red_stripe, sidef), keep)
    dark_m = g.math("MULTIPLY", g.math("MULTIPLY", dark, sidef), keep)

    color = g.mix_rgb(g.math("MULTIPLY", mottle, 0.4), (0.66, 0.67, 0.68, 1.0), (0.60, 0.605, 0.60, 1.0))
    color = g.mix_rgb(g.math("MULTIPLY", grime, 0.18), color, (0.42, 0.41, 0.40, 1.0))
    color = g.mix_rgb(soot, color, (0.10, 0.10, 0.105, 1.0))
    color = g.mix_rgb(red_m, color, (0.55, 0.035, 0.025, 1.0))
    color = g.mix_rgb(dark_m, color, (0.06, 0.062, 0.068, 1.0))
    color = g.mix_rgb(g.math("MULTIPLY", scr, 0.35), color, (0.80, 0.80, 0.80, 1.0))
    color = g.mix_rgb(chips, color, (0.05, 0.05, 0.055, 1.0))
    rough = g.math("ADD", 0.36, g.math("MULTIPLY", mottle, 0.10))
    rough = g.math("ADD", rough, g.math("MULTIPLY", micro, 0.06))
    rough = g.mix(soot, rough, 0.62)
    rough = g.mix(chips, rough, 0.55)
    metal = 0.0
    height = g.math("ADD", g.math("MULTIPLY", micro, 0.08), g.math("MULTIPLY", scr, -0.4))
    height = g.math("ADD", height, g.math("MULTIPLY", g.math("ADD", red_m, dark_m), 0.06))
    height = g.math("ADD", height, g.math("MULTIPLY", chips, -0.5))
    return color, rough, metal, height, 0.00025


CHANNELS = {"body": _channels_body, "shell": _channels_shell}


def _build_bake_material(mat):
    g = S.Graph(mat)
    color, rough, metal, height, bump_dist = CHANNELS[mat.name](g)
    bump = g.node("ShaderNodeBump")
    bump.inputs["Distance"].default_value = bump_dist
    bump.inputs["Strength"].default_value = 1.0
    g._feed(bump.inputs["Height"], height)
    bsdf = g.node("ShaderNodeBsdfPrincipled")
    g._feed(bsdf.inputs["Base Color"], color)
    g._feed(bsdf.inputs["Roughness"], rough)
    g._feed(bsdf.inputs["Metallic"], metal)
    g.link(bump.outputs["Normal"], bsdf.inputs["Normal"])
    emit = g.node("ShaderNodeEmission")
    out = g.node("ShaderNodeOutputMaterial")
    return {"g": g, "bsdf": bsdf, "emit": emit, "out": out, "color": color, "rough": rough, "metal": metal}


def bake(obj, out_dir, samples_ao=32):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.render.bake.margin = 12
    scene.render.bake.use_clear = True
    scene.render.bake.normal_space = "TANGENT"
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    os.makedirs(out_dir, exist_ok=True)
    # anything else in the scene would shade the AO bake (a new file's 2 m
    # default cube encloses the whole gun and turns it black)
    hidden = [o for o in scene.objects if o is not obj and not o.hide_render]
    for o in hidden:
        o.hide_render = True

    built = {m.name: _build_bake_material(m) for m in obj.data.materials if m.name in SLOTS}
    dummy = bpy.data.images.new("_dummy", 8, 8)
    for m in obj.data.materials:
        if m.name not in SLOTS:
            S._target(m, dummy)

    def run(label, kind, channel, colorspace, samples, size=SIZE):
        scene.cycles.samples = samples
        imgs = {}
        for name, b in built.items():
            g = b["g"]
            nt = g.nt
            for link in list(b["out"].inputs["Surface"].links):
                nt.links.remove(link)
            if channel is None:
                g.link(b["bsdf"].outputs[0], b["out"].inputs["Surface"])
            else:
                src = b[channel]
                for link in list(b["emit"].inputs["Color"].links):
                    nt.links.remove(link)
                if isinstance(src, (int, float)):
                    b["emit"].inputs["Color"].default_value = (src, src, src, 1.0)
                else:
                    g.link(src, b["emit"].inputs["Color"])
                g.link(b["emit"].outputs[0], b["out"].inputs["Surface"])
            imgs[name] = S._image(f"{name}_{label}", colorspace, size)
            S._target(bpy.data.materials[name], imgs[name])
        bpy.ops.object.bake(type=kind)
        return imgs

    res = {}
    res["basecolor"] = run("basecolor", "EMIT", "color", "Linear Rec.709", 4)
    res["rough"] = run("rough", "EMIT", "rough", "Non-Color", 4)
    res["metal"] = run("metal", "EMIT", "metal", "Non-Color", 1)
    res["normal"] = run("normal", "NORMAL", None, "Non-Color", 4)
    res["ao"] = run("ao", "AO", None, "Non-Color", samples_ao)
    scene.render.bake.normal_space = "OBJECT"
    res["nobj"] = run("nobj", "NORMAL", None, "Non-Color", 1, RETRO_SIZE * 2)
    scene.render.bake.normal_space = "TANGENT"

    for name in built:
        S._save(res["basecolor"][name], os.path.join(out_dir, f"raijin_{name}_basecolor.png"), srgb=True)
        S._save(res["normal"][name], os.path.join(out_dir, f"raijin_{name}_normal.png"))
        orm = np.stack([S._px(res["ao"][name])[..., 0], S._px(res["rough"][name])[..., 0], S._px(res["metal"][name])[..., 0]], -1)
        S._save_array(orm, os.path.join(out_dir, f"raijin_{name}_orm.png"))
        retro = retro_shade(
            S._px(res["nobj"][name], RETRO_SIZE * 2)[..., :3] * 2.0 - 1.0,
            S._shrink(S._px(res["basecolor"][name])[..., :3], RETRO_SIZE * 2),
            S._shrink(orm, RETRO_SIZE * 2),
            LIFT[name])
        S._save_array(S._shrink(retro, RETRO_SIZE), os.path.join(out_dir, f"raijin_{name}_retro.png"), srgb=True)
    bpy.data.images.remove(dummy)
    for o in hidden:
        o.hide_render = False


# Retro light, in the model's space (barrel +Y, up +Z; sides mirrored to +X):
# a key from above and behind the shooter's shoulder, a cool fill from below,
# and one hard highlight band.
KEY = S._unit((0.55, -0.35, 0.75))
FILL = S._unit((0.3, 0.2, -0.9))
SHINE = S._unit((0.7, -0.35, 0.6))
# how far each slot's colour is lifted for the small texture: the black body
# needs it to keep its edges and marks readable, the light shell does not
LIFT = {"body": 2.2, "shell": 1.0}


def retro_shade(n, base, orm, lift):
    n = n / np.maximum(np.linalg.norm(n, axis=-1, keepdims=True), 1e-6)
    n[..., 0] = np.abs(n[..., 0])
    ao, rough, metal = orm[..., 0:1], orm[..., 1:2], orm[..., 2:3]
    key = np.clip(n @ KEY, 0.0, 1.0)[..., None]
    fill = np.clip(n @ FILL, 0.0, 1.0)[..., None]
    shine = np.power(np.clip(n @ SHINE, 0.0, 1.0)[..., None], 6.0 + 30.0 * (1.0 - rough))
    lifted = np.clip(0.04 * (lift - 1.0) + base * lift, 0.0, 0.9)
    light = 0.38 + 0.7 * key + np.array([0.10, 0.14, 0.22], np.float32) * fill
    spec = shine * (0.25 + 0.75 * metal) * (1.1 - 0.7 * rough) * 0.6
    return (lifted * light + spec) * (0.45 + 0.55 * ao)


def final_materials(obj, tex_dir):
    """Image-based materials matching the baked textures (preview and glTF)."""
    for m in obj.data.materials:
        nt = m.node_tree
        nt.nodes.clear()
        out = nt.nodes.new("ShaderNodeOutputMaterial")
        bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
        nt.links.new(bsdf.outputs[0], out.inputs["Surface"])
        if m.name not in SLOTS:
            blue = (0.35, 0.75, 1.0, 1.0)
            bsdf.inputs["Base Color"].default_value = blue
            bsdf.inputs["Emission Color"].default_value = blue
            bsdf.inputs["Emission Strength"].default_value = 3.0
            continue

        def tex(kind, colorspace):
            n = nt.nodes.new("ShaderNodeTexImage")
            n.image = bpy.data.images.load(os.path.join(tex_dir, f"raijin_{m.name}_{kind}.png"), check_existing=True)
            n.image.colorspace_settings.name = colorspace
            return n

        nt.links.new(tex("basecolor", "sRGB").outputs["Color"], bsdf.inputs["Base Color"])
        orm = tex("orm", "Non-Color")
        sep = nt.nodes.new("ShaderNodeSeparateColor")
        nt.links.new(orm.outputs["Color"], sep.inputs[0])
        nt.links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
        nt.links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(tex("normal", "Non-Color").outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
