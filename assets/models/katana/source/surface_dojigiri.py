# Procedural surface detail for the DOJIGIRI katana, baked to textures.
#
# Two baked texture sets, one per textured material slot, each 2048 px:
#   <slot>_basecolor.png  colour (sRGB)
#   <slot>_orm.png        R occlusion, G roughness, B metallic (linear)
#   <slot>_normal.png     tangent-space normal map, OpenGL (Y+), like Godot
#   <slot>_retro.png      256 px colour with light and shine painted in, for
#                         the retro look (PS1 style: the shine lives in the texture)
# The glowing `edge` slot has no textures: the game draws it.
#
# The detail is driven by object-space position (metres; the model's origin is
# the grip), so it lines up with the shapes in build_dojigiri.py.
import os

import bpy
import numpy as np

SIZE = 2048
RETRO_SIZE = 256  # the retro look's small texture (see retro_shade())
SLOTS = ("steel", "grip")


# ------------------------------------------------------------ node helpers
class Graph:
    def __init__(self, mat):
        self.nt = mat.node_tree
        self.nt.nodes.clear()
        self.x = 0

    def node(self, kind, **props):
        n = self.nt.nodes.new(kind)
        n.location = (self.x, 0)
        self.x += 30
        for k, v in props.items():
            setattr(n, k, v)
        return n

    def link(self, out, inp):
        self.nt.links.new(out, inp)

    def math(self, op, a, b=None, clamp=False):
        n = self.node("ShaderNodeMath", operation=op, use_clamp=clamp)
        self._feed(n.inputs[0], a)
        if b is not None:
            self._feed(n.inputs[1], b)
        return n.outputs[0]

    def vmath(self, op, a, b=None):
        n = self.node("ShaderNodeVectorMath", operation=op)
        self._feed(n.inputs[0], a)
        if b is not None:
            self._feed(n.inputs[1], b)
        return n.outputs["Value"] if op in ("DOT_PRODUCT", "LENGTH", "DISTANCE") else n.outputs["Vector"]

    def _feed(self, sock, v):
        if isinstance(v, (int, float)):
            sock.default_value = v
        elif isinstance(v, tuple):
            sock.default_value = v
        else:
            self.link(v, sock)

    def map_range(self, v, a, b, c=0.0, d=1.0):
        n = self.node("ShaderNodeMapRange", clamp=True)
        self._feed(n.inputs["Value"], v)
        n.inputs["From Min"].default_value = a
        n.inputs["From Max"].default_value = b
        n.inputs["To Min"].default_value = c
        n.inputs["To Max"].default_value = d
        return n.outputs["Result"]

    def mix_rgb(self, fac, a, b):
        n = self.node("ShaderNodeMix", data_type="RGBA")
        self._feed(n.inputs[0], fac)
        self._feed(n.inputs[6], a)
        self._feed(n.inputs[7], b)
        return n.outputs[2]

    def mix(self, fac, a, b):
        n = self.node("ShaderNodeMix", data_type="FLOAT")
        self._feed(n.inputs[0], fac)
        self._feed(n.inputs[2], a)
        self._feed(n.inputs[3], b)
        return n.outputs[0]

    def noise(self, vec, scale, detail=2.0, rough=0.5):
        n = self.node("ShaderNodeTexNoise")
        self._feed(n.inputs["Vector"], vec)
        n.inputs["Scale"].default_value = scale
        n.inputs["Detail"].default_value = detail
        n.inputs["Roughness"].default_value = rough
        return n.outputs["Fac"]

    def scale(self, vec, s):
        n = self.node("ShaderNodeVectorMath", operation="MULTIPLY")
        self._feed(n.inputs[0], vec)
        n.inputs[1].default_value = s
        return n.outputs["Vector"]

    def xyz(self, vec):
        n = self.node("ShaderNodeSeparateXYZ")
        self._feed(n.inputs[0], vec)
        return n.outputs["X"], n.outputs["Y"], n.outputs["Z"]

    def ramp(self, v, stops):
        n = self.node("ShaderNodeValToRGB")
        self._feed(n.inputs["Fac"], v)
        el = n.color_ramp.elements
        while len(el) > 1:
            el.remove(el[-1])
        el[0].position, el[0].color = stops[0]
        for pos, col in stops[1:]:
            e = el.new(pos)
            e.color = col
        return n.outputs["Color"]


def _edge_mask(g, radius, gain):
    """1 on worn sharp edges, 0 on flat faces (Cycles bevel trick)."""
    bev = g.node("ShaderNodeBevel")
    bev.inputs["Radius"].default_value = radius
    geo = g.node("ShaderNodeNewGeometry")
    d = g.vmath("DOT_PRODUCT", bev.outputs["Normal"], geo.outputs["Normal"])
    return g.math("MULTIPLY", g.math("SUBTRACT", 1.0, d), gain, clamp=True), geo


def _channels_steel(g):
    co = g.node("ShaderNodeTexCoord").outputs["Object"]
    x, y, z = g.xyz(co)
    edge, geo = _edge_mask(g, 0.0005, 14.0)
    # brushed finish: fine streaks running along the blade
    brushed = g.noise(g.scale(co, (40.0, 1400.0, 6.0)), 1.0, 4.0, 0.6)
    # sparse scratches at a few angles
    scr = g.math("MAXIMUM",
                 g.map_range(g.noise(g.scale(co, (30.0, 900.0, 60.0)), 1.0, 1.0), 0.72, 0.78),
                 g.map_range(g.noise(g.scale(co, (30.0, 120.0, 700.0)), 1.0, 1.0), 0.73, 0.79))
    grime = g.noise(g.scale(co, (30.0, 30.0, 30.0)), 2.0, 6.0, 0.6)
    # heat tint from the glowing rail: blue by the slot, through purple, to straw
    s = g.math("MAXIMUM", g.math("DIVIDE", g.math("SUBTRACT", z, 0.17), 0.96), 0.0)
    sori = g.math("MULTIPLY", g.math("MULTIPLY", s, s), 0.022)
    above = g.math("SUBTRACT", g.math("SUBTRACT", y, sori), -0.0071)
    tint_t = g.map_range(above, 0.0, 0.012)
    base_dark = (0.045, 0.047, 0.052, 1.0)
    tint = g.ramp(tint_t, [
        (0.0, (0.05, 0.07, 0.22, 1.0)),
        (0.35, (0.16, 0.06, 0.20, 1.0)),
        (0.7, (0.30, 0.20, 0.08, 1.0)),
        (1.0, base_dark),
    ])
    blade_zone = g.math("MULTIPLY", g.map_range(z, 0.25, 0.30), g.map_range(z, 1.12, 1.06))
    tint_amt = g.math("MULTIPLY", blade_zone, 0.55)
    color = g.mix_rgb(tint_amt, base_dark, tint)
    color = g.mix_rgb(g.math("MULTIPLY", grime, 0.25), color, (0.03, 0.03, 0.033, 1.0))
    color = g.mix_rgb(g.math("MAXIMUM", edge, g.math("MULTIPLY", scr, 0.6)), color, (0.42, 0.43, 0.45, 1.0))
    rough = g.math("ADD", 0.30, g.math("MULTIPLY", brushed, 0.16))
    rough = g.mix(edge, rough, 0.2)
    rough = g.mix(scr, rough, 0.18)
    rough = g.math("ADD", rough, g.math("MULTIPLY", grime, 0.06))
    metal = 1.0
    height = g.math("ADD", g.math("MULTIPLY", brushed, 0.3), g.math("MULTIPLY", scr, -1.0))
    return color, rough, metal, height, 0.00012


def _channels_grip(g):
    co = g.node("ShaderNodeTexCoord").outputs["Object"]
    x, y, z = g.xyz(co)
    edge, geo = _edge_mask(g, 0.0006, 10.0)
    nx = g.math("ABSOLUTE", g.xyz(geo.outputs["Normal"])[0])
    # diamond knurl on the sunken panels of the handle and pommel
    pitch = 0.0013
    u = g.math("FRACT", g.math("DIVIDE", g.math("ADD", y, z), pitch))
    v = g.math("FRACT", g.math("DIVIDE", g.math("SUBTRACT", y, z), pitch))
    ru = g.math("ABSOLUTE", g.math("SUBTRACT", u, 0.5))
    rv = g.math("ABSOLUTE", g.math("SUBTRACT", v, 0.5))
    knurl = g.math("MULTIPLY", g.math("MINIMUM", ru, rv), 2.0)
    sunken = g.math("MULTIPLY", g.map_range(g.math("ABSOLUTE", x), 0.0101, 0.0099), g.map_range(nx, 0.8, 0.95))
    sunken = g.math("MULTIPLY", sunken, g.map_range(z, 0.137, 0.133))
    # coated finish: fine stipple everywhere, worn back to bare metal on edges
    stipple = g.noise(co, 2600.0, 2.0, 0.5)
    grime = g.noise(g.scale(co, (25.0, 25.0, 25.0)), 2.0, 6.0, 0.6)
    worn = g.math("MULTIPLY", edge, g.map_range(g.noise(co, 300.0, 3.0), 0.35, 0.6))
    color = g.mix_rgb(g.math("MULTIPLY", grime, 0.3), (0.016, 0.016, 0.018, 1.0), (0.03, 0.028, 0.026, 1.0))
    color = g.mix_rgb(g.math("MULTIPLY", sunken, 0.5), color, (0.010, 0.010, 0.011, 1.0))
    color = g.mix_rgb(worn, color, (0.3, 0.3, 0.31, 1.0))
    rough = g.math("ADD", 0.52, g.math("MULTIPLY", stipple, 0.12))
    rough = g.mix(sunken, rough, 0.7)
    rough = g.mix(worn, rough, 0.25)
    metal = g.mix(worn, 0.0, 1.0)
    height = g.math("ADD", g.math("MULTIPLY", knurl, sunken), g.math("MULTIPLY", stipple, 0.08))
    return color, rough, metal, height, 0.00035


CHANNELS = {"steel": _channels_steel, "grip": _channels_grip}


def _build_bake_material(mat):
    """Rebuild `mat` as the procedural surface; returns the sockets per channel."""
    g = Graph(mat)
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


def _image(name, colorspace, size=SIZE):
    img = bpy.data.images.get(name)
    if img:
        bpy.data.images.remove(img)
    img = bpy.data.images.new(name, size, size, alpha=False, float_buffer=True)
    img.colorspace_settings.name = colorspace
    return img


def _target(mat, img):
    nt = mat.node_tree
    n = nt.nodes.get("_bake_target") or nt.nodes.new("ShaderNodeTexImage")
    n.name = "_bake_target"
    n.image = img
    for other in nt.nodes:
        other.select = False
    n.select = True
    nt.nodes.active = n


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

    built = {m.name: _build_bake_material(m) for m in obj.data.materials if m.name in SLOTS}
    # the glow slot is not baked but still needs a target image
    dummy = bpy.data.images.new("_dummy", 8, 8)
    for m in obj.data.materials:
        if m.name not in SLOTS:
            _target(m, dummy)

    results = {}

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
                if isinstance(src, (int, float)):
                    b["emit"].inputs["Color"].default_value = (src, src, src, 1.0)
                    for link in list(b["emit"].inputs["Color"].links):
                        nt.links.remove(link)
                else:
                    g.link(src, b["emit"].inputs["Color"])
                g.link(b["emit"].outputs[0], b["out"].inputs["Surface"])
            imgs[name] = _image(f"{name}_{label}", colorspace, size)
            _target(bpy.data.materials[name], imgs[name])
        bpy.ops.object.bake(type=kind)
        return imgs

    results["basecolor"] = run("basecolor", "EMIT", "color", "Linear Rec.709", 4)
    results["rough"] = run("rough", "EMIT", "rough", "Non-Color", 4)
    results["metal"] = run("metal", "EMIT", "metal", "Non-Color", 1)
    results["normal"] = run("normal", "NORMAL", None, "Non-Color", 4)
    results["ao"] = run("ao", "AO", None, "Non-Color", samples_ao)
    # the retro texture's light is drawn by hand from object-space normals
    # (retro_shade): a Cycles light bake of such dark metal comes out black
    scene.render.bake.normal_space = "OBJECT"
    results["nobj"] = run("nobj", "NORMAL", None, "Non-Color", 1, RETRO_SIZE * 2)
    scene.render.bake.normal_space = "TANGENT"

    for name in built:
        _save(results["basecolor"][name], os.path.join(out_dir, f"dojigiri_{name}_basecolor.png"), srgb=True)
        _save(results["normal"][name], os.path.join(out_dir, f"dojigiri_{name}_normal.png"))
        orm = np.stack([_px(results["ao"][name])[..., 0], _px(results["rough"][name])[..., 0], _px(results["metal"][name])[..., 0]], -1)
        _save_array(orm, os.path.join(out_dir, f"dojigiri_{name}_orm.png"))
        retro = retro_shade(
            _px(results["nobj"][name], RETRO_SIZE * 2)[..., :3] * 2.0 - 1.0,
            _shrink(_px(results["basecolor"][name])[..., :3], RETRO_SIZE * 2),
            _shrink(orm, RETRO_SIZE * 2))
        _save_array(_shrink(retro, RETRO_SIZE), os.path.join(out_dir, f"dojigiri_{name}_retro.png"), srgb=True)
    bpy.data.images.remove(dummy)


def _px(img, size=SIZE):
    a = np.empty(size * size * 4, dtype=np.float32)
    img.pixels.foreach_get(a)
    return a.reshape(size, size, 4)


def _shrink(a, size):
    """Box-filter a square image down to `size` (a whole fraction of it)."""
    f = a.shape[0] // size
    return a.reshape(size, f, size, f, a.shape[2]).mean(axis=(1, 3))


def _unit(v):
    v = np.asarray(v, np.float32)
    return v / np.linalg.norm(v)


# Retro light, in the model's space (blade +Z, edge -Y, flats +-X): a key
# from above the spine, a cool fill from below the edge, and one hard
# highlight band, as a PS1 texture artist would paint it.
KEY = _unit((0.75, 0.35, 0.55))
FILL = _unit((0.4, -0.8, -0.2))
SHINE = _unit((0.85, -0.1, 0.5))


def retro_shade(n, base, orm):
    """Colour with the light painted in (linear). `n` object-space normals,
    `base` linear base colour, `orm` occlusion/roughness/metal, same size.
    The two flat sides mirror (|x|), so either side of the blade reads lit."""
    n = n / np.maximum(np.linalg.norm(n, axis=-1, keepdims=True), 1e-6)
    n[..., 0] = np.abs(n[..., 0])
    ao, rough, metal = orm[..., 0:1], orm[..., 1:2], orm[..., 2:3]
    key = np.clip(n @ KEY, 0.0, 1.0)[..., None]
    fill = np.clip(n @ FILL, 0.0, 1.0)[..., None]
    shine = np.power(np.clip(n @ SHINE, 0.0, 1.0)[..., None], 6.0 + 30.0 * (1.0 - rough))
    # the real colours are near black (dark gunmetal); lift them so the
    # small texture keeps its scratches and worn edges readable
    lifted = 0.05 + base * 2.2
    light = 0.32 + 0.8 * key + np.array([0.12, 0.16, 0.24], np.float32) * fill
    spec = shine * (0.25 + 0.75 * metal) * (1.1 - 0.7 * rough)
    return (lifted * light + spec) * (0.45 + 0.55 * ao)


def _save_array(rgb, path, srgb=False):
    size = rgb.shape[0]
    img = bpy.data.images.new("_out", size, size, alpha=False)
    img.colorspace_settings.name = "Non-Color"
    if srgb:
        rgb = np.where(rgb <= 0.0031308, rgb * 12.92, 1.055 * np.power(np.clip(rgb, 0, None), 1 / 2.4) - 0.055)
    rgba = np.concatenate([np.clip(rgb, 0, 1), np.ones(rgb.shape[:2] + (1,), np.float32)], -1)
    rgba = rgba.astype(np.float32)
    img.pixels.foreach_set(rgba.ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def _save(img, path, srgb=False):
    _save_array(_px(img)[..., :3], path, srgb=srgb)


def final_materials(obj, tex_dir):
    """Image-based materials matching the baked textures (for preview and glTF)."""
    for m in obj.data.materials:
        nt = m.node_tree
        nt.nodes.clear()
        out = nt.nodes.new("ShaderNodeOutputMaterial")
        bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
        nt.links.new(bsdf.outputs[0], out.inputs["Surface"])
        if m.name not in SLOTS:
            bsdf.inputs["Base Color"].default_value = (1.0, 0.36, 0.06, 1.0)
            bsdf.inputs["Emission Color"].default_value = (1.0, 0.36, 0.06, 1.0)
            bsdf.inputs["Emission Strength"].default_value = 4.0
            continue

        def tex(kind, colorspace):
            n = nt.nodes.new("ShaderNodeTexImage")
            n.image = bpy.data.images.load(os.path.join(tex_dir, f"dojigiri_{m.name}_{kind}.png"), check_existing=True)
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
