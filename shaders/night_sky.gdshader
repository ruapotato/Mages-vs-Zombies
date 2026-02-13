shader_type sky;

// Sky colors (set by DayNightCycle)
uniform vec3 sky_top_color : source_color = vec3(0.3, 0.5, 0.9);
uniform vec3 sky_horizon_color : source_color = vec3(0.55, 0.7, 0.9);
uniform vec3 ground_color : source_color = vec3(0.2, 0.2, 0.2);

// Sun parameters (set by DayNightCycle)
uniform vec3 sun_direction = vec3(0.3, 0.7, -0.5);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.8);
uniform float sun_size : hint_range(0.01, 0.2) = 0.05;
uniform float sun_energy : hint_range(0.0, 2.0) = 1.2;

// Star parameters
uniform float star_brightness : hint_range(0.0, 1.0) = 0.0;

// Moon parameters
uniform vec3 moon_direction = vec3(0.5, 0.3, -0.8);
uniform float moon_size : hint_range(0.01, 0.2) = 0.045;
uniform float moon_phase : hint_range(0.0, 1.0) = 0.5;

// Cloud parameters
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.0;

// Simple hash
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

// Simple noise
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// FBM for clouds
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.0;
		a *= 0.5;
	}
	return v;
}

// Stars
float stars(vec3 dir) {
	vec3 p = dir * 300.0;
	vec3 cell = floor(p);
	float star = 0.0;

	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			for (int z = -1; z <= 1; z++) {
				vec3 c = cell + vec3(float(x), float(y), float(z));
				float h = hash3(c);
				if (h > 0.97) {
					vec3 star_pos = c + vec3(hash3(c + vec3(1.0)), hash3(c + vec3(2.0)), hash3(c + vec3(3.0)));
					float d = length(p - star_pos);
					float twinkle = 0.7 + 0.3 * sin(TIME * (2.0 + h * 3.0) + h * 6.28);
					star += smoothstep(0.05, 0.0, d) * twinkle;
				}
			}
		}
	}
	return star;
}

// Moon with phase
vec3 render_moon(vec3 dir, vec3 moon_dir, float size, float phase) {
	float dist = length(dir - moon_dir);
	if (dist > size * 2.0) return vec3(0.0);

	float disc = smoothstep(size, size * 0.9, dist);
	if (disc < 0.01) return vec3(0.0);

	vec3 col = vec3(0.95, 0.93, 0.88);

	// Craters
	vec2 uv = (dir.xy - moon_dir.xy) / size;
	float craters = noise(uv * 10.0) * 0.3 + noise(uv * 20.0) * 0.15;
	col *= 0.85 + craters;

	// Phase shadow
	float phase_angle = phase * 6.28318;
	float shadow_edge = cos(phase_angle);
	float lit = smoothstep(shadow_edge - 0.1, shadow_edge + 0.1, uv.x);
	if (phase >= 0.5) lit = 1.0 - lit;
	col *= lit;

	// Glow
	float glow = smoothstep(size * 1.8, size, dist) * 0.3;

	return col * disc + vec3(0.9, 0.88, 0.85) * glow * (1.0 - disc);
}

// Clouds
float clouds(vec3 dir) {
	if (dir.y < 0.02 || cloud_coverage < 0.01) return 0.0;

	float h = 1.0 / max(dir.y, 0.08);
	vec2 uv = dir.xz * h * 1.5;
	uv += vec2(TIME * 0.01, TIME * 0.005);

	float c = fbm(uv * 0.5);
	float threshold = 1.0 - cloud_coverage * 1.1;
	return smoothstep(threshold, threshold + 0.25, c) * smoothstep(0.02, 0.25, dir.y);
}

void sky() {
	vec3 dir = EYEDIR;
	vec3 sun_dir = normalize(sun_direction);

	// Sky gradient
	float h = smoothstep(-0.1, 0.4, dir.y);
	vec3 col = mix(sky_horizon_color, sky_top_color, h);

	// Ground
	if (dir.y < 0.0) {
		col = mix(sky_horizon_color, ground_color, smoothstep(0.0, -0.3, dir.y));
	}

	// Sun
	float sun_dist = distance(dir, sun_dir);
	float sun_disc = smoothstep(sun_size, sun_size * 0.5, sun_dist);
	float sun_glow = smoothstep(sun_size * 4.0, sun_size, sun_dist) * 0.3;
	if (sun_dir.y > -0.1) {
		col += sun_color * (sun_disc + sun_glow) * sun_energy;
	}

	// Stars (at night)
	if (star_brightness > 0.01 && dir.y > 0.0) {
		col += vec3(1.0) * stars(dir) * star_brightness;
	}

	// Moon (at night)
	vec3 moon_dir = normalize(moon_direction);
	if (star_brightness > 0.01 && moon_dir.y > -0.1 && dir.y > 0.0) {
		col += render_moon(dir, moon_dir, moon_size, moon_phase) * star_brightness;
	}

	// Clouds
	float cloud_val = clouds(dir);
	if (cloud_val > 0.0) {
		vec3 cloud_col = vec3(1.0) * (0.7 + max(0.0, dot(dir, sun_dir)) * 0.3);
		float night = 1.0 - clamp(sun_energy, 0.0, 1.0);
		cloud_col = mix(cloud_col, vec3(0.15, 0.17, 0.25), night * 0.7);
		col = mix(col, cloud_col, cloud_val * 0.9);
	}

	COLOR = col;
}
