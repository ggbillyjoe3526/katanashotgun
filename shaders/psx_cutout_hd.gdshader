// psx_cutout for INSANE on Forward+: fogged by the Environment so it sits
// in the same volumetric haze as the floor under it.
shader_type spatial;
render_mode vertex_lighting, cull_disabled, specular_disabled, depth_draw_opaque;

#define PSX_HD
#include "res://shaders/psx_cutout.gdshaderinc"
