// Synthwave night sky: gradient, a giant striped sun on the horizon,
// silhouetted mountains with neon rims, and pixel stars. Colours come from
// the run's palette.
shader_type sky;

uniform vec3 top_color : source_color = vec3(0.07, 0.0, 0.17);
uniform vec3 mid_color : source_color = vec3(0.35, 0.06, 0.43);
uniform vec3 horizon_color : source_color = vec3(1.0, 0.24, 0.5);
uniform vec3 sun_top : source_color = vec3(1.0, 0.88, 0.3);
uniform vec3 sun_bottom : source_color = vec3(1.0, 0.16, 0.54);
uniform vec3 mountain_color : source_color = vec3(0.16, 0.03, 0.22);
uniform vec3 rim_color : source_color = vec3(1.0, 0.2, 0.9);
uniform vec3 ground_color : source_color = vec3(0.04, 0.01, 0.07);
// direction the sun sits in (azimuth in radians, 0 = -Z / north)
uniform float sun_azimuth = 0.0;
uniform float sun_size = 0.34;
uniform float sun_height = 0.1;

float hash(float x) {
	return fract(sin(x * 127.1) * 43758.5453);
}

float ridge(float az, float scale, float seed) {
	float x = az * scale + seed;
	float i = floor(x);
	float f = fract(x);
	float a = hash(i + seed);
	float b = hash(i + 1.0 + seed);
	float h = mix(a, b, f);
	// triangular peaks: angular, low-poly mountains
	return h * (1.0 - abs(f - 0.5) * 0.6);
}

void sky() {
	vec3 d = EYEDIR;
	float y = d.y;
	float az = atan(d.x, -d.z);
	vec3 c;
	if (y > 0.0) {
		float k = pow(clamp(y, 0.0, 1.0), 0.55);
		c = mix(horizon_color, mid_color, smoothstep(0.0, 0.35, k));
		c = mix(c, top_color, smoothstep(0.3, 0.9, k));
	} else {
		c = mix(horizon_color * 0.5, ground_color, clamp(-y * 6.0, 0.0, 1.0));
	}
	// sun
	float daz = az - sun_azimuth;
	daz = mod(daz + PI, 2.0 * PI) - PI;
	vec2 sp = vec2(daz, y - sun_height);
	float r = length(sp) / sun_size;
	float glow = exp(-max(r - 1.0, 0.0) * 3.0) * 0.55;
	c += mix(sun_bottom, sun_top, 0.4) * glow * smoothstep(-0.05, 0.05, y + 0.02);
	if (r < 1.0) {
		float v = clamp((sp.y / sun_size) * 0.5 + 0.5, 0.0, 1.0);
		vec3 sc = mix(sun_bottom, sun_top, v);
		// horizontal cuts that thicken toward the bottom
		float band = fract((1.0 - v) * 9.0);
		float cut = v < 0.55 ? step(band, mix(0.55, 0.05, v / 0.55)) : 0.0;
		c = mix(sc * 1.25, c, cut * 0.92);
	}
	// mountains
	float m1 = 0.02 + ridge(az, 5.0, 3.0) * 0.07;
	float m2 = 0.01 + ridge(az, 9.0, 11.0) * 0.045;
	if (y < m1 && y > -0.02) {
		float edge = smoothstep(0.004, 0.0, m1 - y);
		c = mix(mountain_color, rim_color * 1.4, edge);
		c += rim_color * 0.06 * step(0.5, fract(y * 220.0));
	}
	if (y < m2 && y > -0.02) {
		float edge2 = smoothstep(0.004, 0.0, m2 - y);
		c = mix(mountain_color * 0.6, rim_color, edge2 * 0.8);
	}
	// stars
	if (y > 0.12) {
		vec2 cell = floor(vec2(az * 110.0, y * 110.0));
		float h = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
		float tw = 0.6 + 0.4 * sin(TIME * 3.0 + h * 50.0);
		c += vec3(0.9, 0.85, 1.0) * step(0.9965, h) * smoothstep(0.12, 0.4, y) * tw;
	}
	COLOR = c;
}
