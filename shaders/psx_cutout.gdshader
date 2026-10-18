// Lit alpha-cutout surface (blood decals on the floor). Crisp edges, no blending,
// exactly like PS1-era decals.
shader_type spatial;
render_mode vertex_lighting, cull_disabled, specular_disabled, depth_draw_opaque;

#include "res://shaders/psx_cutout.gdshaderinc"
