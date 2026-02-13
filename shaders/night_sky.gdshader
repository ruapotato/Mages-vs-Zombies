shader_type sky;

// Dynamic sky shader with day/night cycle, stars, moon, and sun
// Based on Hamberg sky system

// Sky colors (set by DayNightCycle)
uniform vec3 sky_top_color : source_color = vec3(0.3, 0.6, 1.0);
uniform vec3 sky_horizon_color : source_color = vec3(0.6, 0.75, 0.95);
uniform vec3 ground_color : source_color = vec3(0.3, 0.25, 0.2);

// Sun parameters
uniform vec3 sun_direction = vec3(0.3, 0.7, -0.5);
uniform float sun_size : hint_range(0.01, 0.1) = 0.03;

// Star parameters
uniform float star_brightness : hint_range(0.0, 1.0) = 0.0;
uniform float star_density : hint_range(100.0, 5000.0) = 2000.0;
uniform float star_twinkle_speed : hint_range(0.0, 5.0) = 1.5;

// Moon parameters
uniform vec3 moon_direction = vec3(0.5, 0.5, -0.5);
uniform float moon_phase : hint_range(0.0, 1.0) = 0.5;
uniform float moon_size : hint_range(0.01, 0.2) = 0.06;

// Time for animation
uniform float time : hint_range(0.0, 10000.0) = 0.0;

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

// Generate sun
vec3 sun(vec3 dir, vec3 sun_dir, float size) {
	vec3 normalized_sun_dir = normalize(sun_dir);

	// Only render sun if it's above horizon
	if (normalized_sun_dir.y < -0.1) {
		return vec3(0.0);
	}

	// Distance to sun center
	float sun_dist = length(dir - normalized_sun_dir);

	// Sun disc - bright white center
	float sun_disc = smoothstep(size, size * 0.8, sun_dist);
	vec3 sun_color = vec3(1.0, 0.98, 0.9) * sun_disc * 2.0;

	// Sun glow - soft orange/yellow halo
	float glow_inner = smoothstep(size * 4.0, size, sun_dist);
	float glow_outer = smoothstep(size * 8.0, size * 2.0, sun_dist);
	vec3 glow_color = vec3(1.0, 0.9, 0.6) * glow_inner * 0.5;
	glow_color += vec3(1.0, 0.8, 0.5) * glow_outer * 0.2;

	return sun_color + glow_color;
}

void sky() {
	vec3 dir = normalize(EYEDIR);

	// Height in sky (0 at horizon, 1 at zenith, negative below horizon)
	float height = dir.y;

	vec3 final_color;

	if (height > 0.0) {
		// Above horizon - blend sky colors
		float horizon_blend = smoothstep(0.0, 0.4, height);
		final_color = mix(sky_horizon_color, sky_top_color, horizon_blend);

		// Add stars at night
		if (star_brightness > 0.01) {
			float star_field = stars(dir, star_density, time * star_twinkle_speed);

			// Star color variation (slight blue/yellow tints)
			vec3 star_color = vec3(1.0, 1.0, 1.0);
			float temp_var = hash(dir.xz * 100.0);
			if (temp_var > 0.7) {
				star_color = vec3(0.8, 0.9, 1.0); // Blue-ish
			} else if (temp_var < 0.3) {
				star_color = vec3(1.0, 0.95, 0.8); // Yellow-ish
			}

			// Add milky way
			float milky = milky_way(dir);
			vec3 milky_color = vec3(0.6, 0.65, 0.8);

			// Combine stars and milky way
			final_color += star_color * star_field * star_brightness;
			final_color += milky_color * milky * star_brightness;
		}

		// Add moon (visible at night)
		vec3 moon_color = moon(dir, moon_direction, moon_phase, moon_size);
		final_color += moon_color * star_brightness;

		// Add sun (visible during day - inverse of star_brightness)
		float sun_brightness = 1.0 - star_brightness;
		if (sun_brightness > 0.01) {
			vec3 sun_color = sun(dir, sun_direction, sun_size);
			final_color += sun_color * sun_brightness;
		}

	} else {
		// Below horizon - ground color
		float ground_blend = smoothstep(0.0, -0.2, height);
		final_color = mix(sky_horizon_color, ground_color, ground_blend);
	}

	COLOR = final_color;
}
