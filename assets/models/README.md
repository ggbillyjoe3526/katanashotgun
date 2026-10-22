# 3D models

Models made in Blender for the game. Everything else is built in code.
Each model's source is a Python script, so it can be rebuilt exactly.

## DOJIGIRI katana (`katana/`)
- `source/build_dojigiri.py`: builds the model in Blender (collection
  "DOJIGIRI"). Runs in Blender's Scripting tab, or headless.
- `source/surface_dojigiri.py`: the surface detail (brushed steel,
  scratches, heat tint, grip knurl, edge wear), made from Blender procedural
  nodes and baked to images.
- `source/export_dojigiri.py`: build, join into one mesh, triangulate, UV,
  bake and export. Writes `dojigiri.glb` and `textures/`.
- `source/.gdignore` keeps Godot out of the scripts.

### Rebuild
Needs Python 3.13 with the `bpy` module (5.2) and Pillow, or Blender 5.2:

```
python3.13 -m venv ~/bpyenv && ~/bpyenv/bin/pip install "bpy==5.2.*" pillow
cd assets/models/katana/source
~/bpyenv/bin/python export_dojigiri.py ../dojigiri.glb
```

`--no-bake` re-exports the mesh and keeps the textures as they are (fast).
A full bake takes several minutes. Then run `godot --headless --import`.

### Layout
- Metres, origin at the grip, blade along +Z, edge towards -Y in Blender.
  In Godot (glTF is Y up): blade +Y, edge +Z, like the code-built katana.
- One mesh, three surfaces (material names): `steel` (blade and bolts),
  `grip` (the one-piece hilt: pommel, handle, collar, finger spur) and
  `edge` (the glowing edge and the hilt's glow lines).
- `edge` has no texture. Its UVs run along the blade (u from the collar to
  the tip, v across), so colour and effect shaders can use them. In game it
  gets the viewmodel's edge material, which the Rewards looks tint.

### Textures (per textured surface)
| File | Size | Godot import |
|---|---|---|
| `_basecolor` | 2048 | VRAM compressed, mipmaps |
| `_orm` (R AO, G roughness, B metal) | 2048 | VRAM compressed, mipmaps |
| `_normal` (OpenGL, Y up) | 2048 | VRAM compressed as a normal map, mipmaps |
| `_retro` (colour with light and shine painted in) | 256 | lossless, no mipmaps |

`shaders/psx_model.gdshader` follows the RETRO LOOK setting (the globals
`psx_retro` and `psx_snap`): LIGHT and OFF use the full maps with per-pixel
light. Above `psx_retro` 0.5 it reads `_retro` texel by texel with no live
shine (like the PS1); that was the old RETRO LOOK FULL, removed on
2026-10-22, so no setting reaches it now. The `_retro` light is drawn by `retro_shade()` in
`surface_dojigiri.py` from an object-space normal bake.
`scripts/katana_model.gd` loads the .glb and sets the materials.

### Rules
- Triangle budget: about 20k, ceiling 30k (the katana is about 13k).
- Our own shapes; no copied designs, logos or text.
- The model is the game's katana (owner approved, 2026-10-19). The
  code-built blade in `viewmodel.gd` only shows if the model fails to load.
- Log every model in `ASSETS.md`.

## RAIJIN-12 shotgun (`shotgun/`)
Same pipeline, texture set and rules as the katana; the scripts in
`shotgun/source/` reuse `surface_dojigiri.py`'s helpers.
- `source/build_raijin.py`: builds the model (collection "RAIJIN12"). The
  owner's Blender file for it is `raijin12.blend`, kept apart from the
  katana's.
- `source/surface_raijin.py`: paint (red, gunmetal, off-white polymer,
  rubber grip), grime, edge wear, scratches, muzzle soot and the white
  markings, baked to images.
- `source/export_raijin.py`: build, join, triangulate, UV, bake, split the
  moving parts out again and export. Writes `raijin12.glb` and `textures/`.

```
cd assets/models/shotgun/source
~/bpyenv/bin/python export_raijin.py ../raijin12.glb   # add --no-bake to keep the textures
```

### Layout
- Metres, origin where the code-built gun's `spin_pivot` is, barrels along
  +Y, up +Z in Blender. In Godot: barrels along -Z, muzzle at
  (0, 0.05, -0.90) (the code-built gun's is at -0.95).
- Nodes under `RAIJIN12`: `body`, `drum` (origin on its axle, turns about
  Z in Godot), `led_0`..`led_9` (the charge lights), and the empty nodes
  `muzzle` and `arc_point_0`..`arc_point_2` (the idle crackle jumps between
  them, inside the emitter).
- Surfaces: `body` (metal and rubber) and `shell` (off-white polymer) are
  textured; `coil`, `core`, `emitter`, `cell` and `led` glow and take the
  viewmodel's materials, so the Rewards looks tint them and the gun pulses
  them as it fires and recharges.
- `scripts/shotgun_model.gd` loads it; `viewmodel.gd` swaps it in for the
  code-built gun, which only shows if the model fails to load (owner
  approved, 2026-10-19). About 23k triangles.
