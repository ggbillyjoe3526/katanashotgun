// psx_lit for the INSANE preset on the Forward+ renderer: the same surface,
// but fogged by the Environment (so volumetric fog reaches it). Picked by
// Psx.lit() when Graphics.advanced().
shader_type spatial;
render_mode vertex_lighting, cull_back, diffuse_lambert;

#define PSX_HD
#include "res://shaders/psx_lit.gdshaderinc"
