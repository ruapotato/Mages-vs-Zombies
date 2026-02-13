shader_type spatial;

// Terrain shader with biome-based colors and slope detection
// Based on Hamberg terrain system - steep slopes show rock, flat areas show grass
// Biome is calculated from world position using noise

// World seed for biome calculation
uniform int world_seed = 12345;

// Slope thresholds
uniform float slope_rock_start : hint_range(0.0, 1.0) = 0.6;
uniform float slope_rock_full : hint_range(0.0, 1.0) = 0.8;

// Zone radii for biome difficulty
const float SPAWN_VALLEY_RADIUS = 25.0;
const float SAFE_ZONE_RADIUS = 1250.0;
const float MID_ZONE_RADIUS = 2500.0;
const float DANGER_ZONE_RADIUS = 3750.0;
const float EXTREME_ZONE_RADIUS = 5000.0;

// ========== BIOME COLORS (Fantasy bright colors - matching Hamberg) ==========

// Valley biome - BRIGHT BLUE serene meadows
const vec3 VALLEY_GRASS = vec3(0.25, 0.55, 0.95);
const vec3 VALLEY_GRASS_DARK = vec3(0.15, 0.45, 0.85);
const vec3 VALLEY_ROCK = vec3(0.4, 0.42, 0.45);

// Dark Forest biome - DARK TEAL-GREEN bioluminescent
const vec3 FOREST_GRASS = vec3(0.05, 0.25, 0.15);
const vec3 FOREST_GRASS_DARK = vec3(0.02, 0.18, 0.10);
const vec3 FOREST_ROCK = vec3(0.15, 0.2, 0.18);

// Swamp biome - YELLOW-GREEN murky
const vec3 SWAMP_GRASS = vec3(0.6, 0.75, 0.3);
const vec3 SWAMP_GRASS_DARK = vec3(0.5, 0.65, 0.2);
const vec3 SWAMP_ROCK = vec3(0.25, 0.22, 0.18);

// Mountain biome - WHITE snow/ice
const vec3 MOUNTAIN_GRASS = vec3(0.95, 0.97, 1.0);
const vec3 MOUNTAIN_GRASS_DARK = vec3(0.85, 0.90, 0.95);
const vec3 MOUNTAIN_ROCK = vec3(0.6, 0.62, 0.68);

// Desert biome - BRIGHT YELLOW sandy
const vec3 DESERT_SAND = vec3(0.95, 0.85, 0.35);
const vec3 DESERT_SAND_DARK = vec3(0.85, 0.75, 0.25);
const vec3 DESERT_ROCK = vec3(0.7, 0.58, 0.4);

// Wizardland biome - BRIGHT MAGENTA magical
const vec3 WIZARD_GRASS = vec3(0.9, 0.3, 1.0);
const vec3 WIZARD_GRASS_DARK = vec3(0.75, 0.2, 0.85);
const vec3 WIZARD_ROCK = vec3(0.55, 0.35, 0.65);

// Hell biome - BRIGHT RED hellfire
const vec3 HELL_GROUND = vec3(0.9, 0.2, 0.1);
const vec3 HELL_GROUND_DARK = vec3(0.7, 0.1, 0.05);
const vec3 HELL_ROCK = vec3(0.3, 0.12, 0.08);

// Simple hash function for variation
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float hash_seed(vec2 p, float seed) {
	return fract(sin(dot(p + seed, vec2(127.1, 311.7))) * 43758.5453);
}

// Simplex-like noise for color variation
float noise2D(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);

	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));

	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Seeded noise for biome calculation
float noise2D_seeded(vec2 p, float seed) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);

	float a = hash_seed(i, seed);
	float b = hash_seed(i + vec2(1.0, 0.0), seed);
	float c = hash_seed(i + vec2(0.0, 1.0), seed);
	float d = hash_seed(i + vec2(1.0, 1.0), seed);

	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Calculate biome index from world position (matches TerrainBiomeGenerator)
int get_biome_at_position(vec2 world_xz, float seed) {
	float distance = length(world_xz);

	// Force valley near spawn
	if (distance < SPAWN_VALLEY_RADIUS) {
		return 0;
	}

	// Domain warping for organic shapes
	float warp_strength = 200.0;
	float warp_x = (noise2D_seeded(world_xz * 0.002, seed + 200.0) * 2.0 - 1.0) * warp_strength;
	float warp_z = (noise2D_seeded(world_xz * 0.002, seed + 201.0) * 2.0 - 1.0) * warp_strength;

	vec2 warped_pos = world_xz + vec2(warp_x, warp_z);

	// Sample biome noise
	float biome_value = noise2D_seeded(warped_pos * 0.0032, seed + 100.0) * 2.0 - 1.0;
	float scale_value = noise2D_seeded(world_xz * 0.004, seed + 300.0) * 2.0 - 1.0;

	float combined = biome_value + scale_value * 0.3;
	float normalized = (combined + 1.0) * 0.5;

	// Difficulty tier
	int tier = 0;
	if (distance < SAFE_ZONE_RADIUS) tier = 0;
	else if (distance < MID_ZONE_RADIUS) tier = 1;
	else if (distance < DANGER_ZONE_RADIUS) tier = 2;
	else if (distance < EXTREME_ZONE_RADIUS) tier = 3;
	else tier = 4;

	// Select biome
	if (tier == 0) {
		return normalized < 0.5 ? 0 : 1;
	} else if (tier == 1) {
		if (normalized < 0.25) return 0;
		else if (normalized < 0.5) return 1;
		else if (normalized < 0.75) return 2;
		else return 4;
	} else if (tier == 2) {
		if (normalized < 0.15) return 1;
		else if (normalized < 0.3) return 2;
		else if (normalized < 0.5) return 4;
		else if (normalized < 0.7) return 3;
		else if (normalized < 0.9) return 5;
		else return 6;
	} else if (tier == 3) {
		if (normalized < 0.15) return 4;
		else if (normalized < 0.3) return 3;
		else if (normalized < 0.45) return 5;
		else return 6;
	} else {
		if (normalized < 0.15) return 3;
		else if (normalized < 0.25) return 5;
		else return 6;
	}
}

// Get grass colors for biome
void get_biome_colors(int biome, out vec3 grass, out vec3 grass_dark, out vec3 rock) {
	if (biome == 0) { // Valley
		grass = VALLEY_GRASS;
		grass_dark = VALLEY_GRASS_DARK;
		rock = VALLEY_ROCK;
	} else if (biome == 1) { // Dark Forest
		grass = FOREST_GRASS;
		grass_dark = FOREST_GRASS_DARK;
		rock = FOREST_ROCK;
	} else if (biome == 2) { // Swamp
		grass = SWAMP_GRASS;
		grass_dark = SWAMP_GRASS_DARK;
		rock = SWAMP_ROCK;
	} else if (biome == 3) { // Mountain
		grass = MOUNTAIN_GRASS;
		grass_dark = MOUNTAIN_GRASS_DARK;
		rock = MOUNTAIN_ROCK;
	} else if (biome == 4) { // Desert
		grass = DESERT_SAND;
		grass_dark = DESERT_SAND_DARK;
		rock = DESERT_ROCK;
	} else if (biome == 5) { // Wizardland
		grass = WIZARD_GRASS;
		grass_dark = WIZARD_GRASS_DARK;
		rock = WIZARD_ROCK;
	} else { // Hell (6)
		grass = HELL_GROUND;
		grass_dark = HELL_GROUND_DARK;
		rock = HELL_ROCK;
	}
}

void fragment() {
	// World position for noise
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 world_xz = world_pos.xz;

	// Get slope from normal (0 = flat, 1 = vertical)
	float slope = 1.0 - abs(NORMAL.y);

	// Calculate biome from world position
	int biome = get_biome_at_position(world_xz, float(world_seed));

	// Get biome colors
	vec3 grass_color, grass_dark_color, rock_color;
	get_biome_colors(biome, grass_color, grass_dark_color, rock_color);

	// Add noise-based variation to grass
	float grass_noise = noise2D(world_xz * 0.1);
	float detail_noise = noise2D(world_xz * 0.5);

	// Blend between grass variations
	vec3 grass_final = mix(grass_dark_color, grass_color, grass_noise);
	grass_final = mix(grass_final, grass_color * 1.1, detail_noise * 0.3);

	// Add small-scale detail
	float micro_noise = noise2D(world_xz * 2.0);
	grass_final *= 0.9 + micro_noise * 0.2;

	// Rock variation
	float rock_noise = noise2D(world_xz * 0.3);
	vec3 rock_final = rock_color * (0.85 + rock_noise * 0.3);

	// Blend based on slope
	float rock_blend = smoothstep(slope_rock_start, slope_rock_full, slope);

	// Final color
	vec3 final_color = mix(grass_final, rock_final, rock_blend);

	// Slightly darken lower areas (fake ambient occlusion)
	float height_factor = clamp(world_pos.y / 50.0, 0.0, 1.0);
	final_color *= 0.85 + height_factor * 0.15;

	ALBEDO = final_color;

	// Roughness based on surface type
	ROUGHNESS = mix(0.85, 0.95, rock_blend);

	// Subtle specular for wet swamp
	if (biome == 2) {
		ROUGHNESS = mix(0.7, 0.9, rock_blend);
	}
}
