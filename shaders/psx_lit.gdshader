// PS1-style lit surface: per-vertex (Gouraud) lighting, vertex snapping,
// affine texture warping and distance fog. Used for the world, enemies and
// the viewmodel.
shader_type spatial;
render_mode vertex_lighting, cull_back, specular_disabled, diffuse_lambert;

#include "res://shaders/psx_lit.gdshaderinc"
