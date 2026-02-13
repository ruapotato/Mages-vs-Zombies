shader_type sky;

// Dynamic sky shader with day/night cycle, stars, moon, and sun
// Based on Hamberg sky system

// Sky colors (set by DayNightCycle)
uniform vec3 sky_top_color : source_color = vec3(0.3, 0.6, 1.0);
uniform vec3 sky_horizon_color : source_color = vec3(0.6, 0.75, 0.95);
uniform vec3 ground_color : source_color = vec3(0.3, 0.25, 0.2);

// Sun parameters (set by DayNightCycle)
uniform vec3 sun_direction = vec3(0.3, 0.7, -0.5);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.85);
uniform float sun_size : hint_range(0.01, 0.1) = 0.03;
uniform float sun_energy : hint_range(0.0, 2.0) = 1.0;

// Star parameters
uniform float star_brightness : hint_range(0.0, 1.0) = 0.0;
uniform float star_density : hint_range(100.0, 5000.0) = 2000.0;
uniform float star_twinkle_speed : hint_range(0.0, 5.0) = 1.5;

// Moon parameters
uniform vec3 moon_direction = vec3(0.5, 0.5, -0.5);
uniform float moon_phase : hint_range(0.0, 1.0) = 0.5;
uniform float moon_size : hint_range(0.01, 0.2) = 0.06;

// Cloud parameters (set by WeatherManager)
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.0;
uniform float cloud_darkness : hint_range(0.0, 1.0) = 0.0;

// Hash functions for randomness
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

// Simple 2D noise
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

// Generate stars
float stars(vec3 dir, float density, float twinkle_time) {
	// Stable star field based on direction
	vec3 star_coords = dir * density;
	vec3 cell = floor(star_coords);
	vec3 local = fract(star_coords);

	float brightness = 0.0;

	// Check nearby cells for stars
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			for (int z = -1; z <= 1; z++) {
				vec3 neighbor = cell + vec3(float(x), float(y), float(z));
				float star_chance = hash3(neighbor);

				// Only some cells have stars
				if (star_chance > 0.97) {
					// Star position within cell
					vec3 star_pos = neighbor + vec3(
						hash3(neighbor + vec3(1.0, 0.0, 0.0)),
						hash3(neighbor + vec3(0.0, 1.0, 0.0)),
						hash3(neighbor + vec3(0.0, 0.0, 1.0))
					);

					// Distance to star
					float dist = length(star_coords - star_pos);

					// Star brightness with distance falloff
					float star_size = 0.02 + hash3(neighbor + vec3(5.0)) * 0.03;
					float star_b = smoothstep(star_size, 0.0, dist);

					// Twinkle effect
					float twinkle = sin(twinkle_time * (1.0 + hash3(neighbor) * 2.0) + hash3(neighbor) * 6.28);
					twinkle = 0.7 + twinkle * 0.3;

					// Star color temperature variation
					float temp = hash3(neighbor + vec3(10.0));

					brightness += star_b * twinkle;
				}
			}
		}
	}

	return brightness;
}

// Generate moon
vec3 moon(vec3 dir, vec3 moon_dir, float phase, float size) {
	// Distance to moon center
	float moon_dist = length(dir - normalize(moon_dir));

	if (moon_dist > size * 2.0) {
		return vec3(0.0);
	}

	// Moon disc
	float moon_mask = smoothstep(size, size * 0.9, moon_dist);

	if (moon_mask < 0.01) {
		return vec3(0.0);
	}

	// Moon base color
	vec3 moon_color = vec3(0.95, 0.93, 0.88);

	// Surface detail (craters)
	vec2 moon_uv = (dir.xy - moon_dir.xy) / size;
	float crater1 = noise(moon_uv * 10.0);
	float crater2 = noise(moon_uv * 20.0 + vec2(5.3, 2.7));
	float craters = crater1 * 0.3 + crater2 * 0.15;
	moon_color *= 0.85 + craters;

	// Phase shadow (dark side)
	// phase: 0 = new (all dark), 0.5 = full (all lit), 1 = new again
	float phase_angle = phase * 2.0 * 3.14159;
	float shadow_edge = cos(phase_angle);

	// Shadow based on X position on moon face
	vec2 local_pos = (dir.xy - moon_dir.xy) / size;
	float lit = step(shadow_edge, local_pos.x);

	// Soft shadow edge
	float shadow_soft = smoothstep(shadow_edge - 0.1, shadow_edge + 0.1, local_pos.x);

	moon_color *= shadow_soft;

	// Glow around moon
	float glow = smoothstep(size * 1.8, size, moon_dist);
	vec3 glow_color = vec3(0.2, 0.2, 0.25) * glow * (1.0 - moon_mask);

	return moon_color * moon_mask + glow_color;
}

// Simple milky way band
float milky_way(vec3 dir) {
	// Milky way runs along a band
	float band = abs(dir.y + dir.x * 0.3);
	float milky = smoothstep(0.4, 0.0, band);

	// Add noise for structure
	float structure = noise(dir.xz * 20.0);
	structure *= noise(dir.xz * 40.0 + vec2(3.7, 1.2));

	return milky * structure * 0.3;
}

// Simple noise for clouds
float cloud_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);

	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));

	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Fractal brownian motion for clouds
float fbm(vec2 p, int octaves) {
	float value = 0.0;
	float amplitude = 0.5;
	float frequency = 1.0;
	float total_amplitude = 0.0;

	for (int i = 0; i < octaves; i++) {
		value += amplitude * cloud_noise(p * frequency);
		total_amplitude += amplitude;
		amplitude *= 0.5;
		frequency *= 2.0;
	}

	return value / total_amplitude;
}

// Generate clouds
float clouds(vec3 dir) {
	if (dir.y < 0.02) return 0.0;

	float cloud_height = 1.0 / max(dir.y, 0.08);
	vec2 cloud_pos = dir.xz * cloud_height * 1.5;

	// Multiple cloud layers
	vec2 layer1_pos = cloud_pos * 0.5 + vec2(TIME * 0.01, TIME * 0.005);
	float layer1 = fbm(layer1_pos, 4);

	vec2 layer2_pos = cloud_pos * 0.8 + vec2(TIME * 0.015, TIME * 0.008);
	float layer2 = fbm(layer2_pos, 5);

	float cloud_value = layer1 * 0.6 + layer2 * 0.4;

	float cloud_threshold = 1.0 - cloud_coverage * 1.1;
	float result = smoothstep(cloud_threshold, cloud_threshold + 0.25, cloud_value);

	// Fade near horizon
	float horizon_fade = smoothstep(0.02, 0.25, dir.y);
	result *= horizon_fade;

	return clamp(result, 0.0, 1.0);
}

void sky() {
	vec3 dir = EYEDIR;
	vec3 norm_sun_dir = normalize(sun_direction);

	// Simple sky gradient - this MUST show color if shader is working
	float horizon_blend = smoothstep(-0.1, 0.4, dir.y);
	vec3 sky_col = mix(sky_horizon_color, sky_top_color, horizon_blend);

	// Ground (below horizon)
	if (dir.y < 0.0) {
		float ground_blend = smoothstep(0.0, -0.3, dir.y);
		sky_col = mix(sky_horizon_color, ground_color, ground_blend);
	}

	// Sun
	float sun_dist = distance(dir, norm_sun_dir);
	float sun_disc = smoothstep(sun_size, sun_size * 0.5, sun_dist);
	float sun_glow = smoothstep(sun_size * 4.0, sun_size, sun_dist) * 0.3;

	if (norm_sun_dir.y > -0.1) {
		sky_col += sun_color * (sun_disc + sun_glow) * sun_energy;
	}

	// Stars (only at night, above horizon)
	if (star_brightness > 0.01 && dir.y > 0.0) {
		float star_field = stars(dir, star_density, TIME * star_twinkle_speed);

		vec3 star_col = vec3(1.0, 1.0, 1.0);
		float temp_var = hash(dir.xz * 100.0);
		if (temp_var > 0.7) {
			star_col = vec3(0.8, 0.9, 1.0);
		} else if (temp_var < 0.3) {
			star_col = vec3(1.0, 0.95, 0.8);
		}

		float milky = milky_way(dir);
		vec3 milky_color = vec3(0.6, 0.65, 0.8);

		float star_cloud_block = 1.0 - cloud_coverage * 0.9;
		sky_col += (star_col * star_field + milky_color * milky) * star_brightness * star_cloud_block;
	}

	// Moon (at night, above horizon)
	vec3 n_moon_dir = normalize(moon_direction);
	if (star_brightness > 0.01 && n_moon_dir.y > -0.1 && dir.y > 0.0) {
		vec3 moon_col = moon(dir, moon_direction, moon_phase, moon_size);
		float moon_cloud_block = 1.0 - cloud_coverage * 0.7;
		sky_col += moon_col * moon_cloud_block * star_brightness;
	}

	// Clouds (above horizon)
	if (cloud_coverage > 0.01 && dir.y > 0.0) {
		float cloud_value = clouds(dir);

		vec3 cloud_lit_color = vec3(1.0, 1.0, 1.0);
		vec3 cloud_dark_color = vec3(0.4, 0.42, 0.45);
		vec3 cloud_base_color = mix(cloud_lit_color, cloud_dark_color, cloud_darkness);

		float sun_illumination = max(0.0, dot(dir, norm_sun_dir));
		vec3 cloud_col = cloud_base_color * (0.7 + sun_illumination * 0.3);

		float night_factor = 1.0 - clamp(sun_energy, 0.0, 1.0);
		cloud_col = mix(cloud_col, vec3(0.15, 0.17, 0.25), night_factor * 0.7);

		sky_col = mix(sky_col, cloud_col, cloud_value * 0.9);
	}

	COLOR = sky_col;
}
