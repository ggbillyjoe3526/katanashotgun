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
`psx_retro` and `psx_snap`): FULL snaps vertices and reads `_retro` texel
by texel with no live shine (like the PS1); LIGHT and OFF use the full maps
with per-pixel light. The `_retro` light is drawn by `retro_shade()` in
`surface_dojigiri.py` from an object-space normal bake.
`scripts/katana_model.gd` loads the .glb and sets the materials.

### Rules
- Triangle budget: about 20k, ceiling 30k (now about 13k).
- Our own shapes; no copied designs, logos or text.
- The code-built katana stays the default until the owner approves the
  model (dev menu, F10, LOOK, KATANA MODEL).
- Log every model in `ASSETS.md`.
