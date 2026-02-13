shader_type spatial;

// Terrain shader with biome-based colors and slope detection
// Biome is calculated from world position using noise that matches GDScript FastNoiseLite

// World seed for biome calculation
uniform int world_seed = 12345;

// Slope thresholds
uniform float slope_rock_start : hint_range(0.0, 1.0) = 0.6;
uniform float slope_rock_full : hint_range(0.0, 1.0) = 0.8;

// Zone radii for biome difficulty - MUST match terrain_biome_generator.gd
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

// ========== NOISE FUNCTIONS ==========
// These approximate FastNoiseLite Simplex Smooth with FBM

// Permutation table for gradient noise
vec3 mod289(vec3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4 mod289(vec4 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4 permute(vec4 x) { return mod289(((x * 34.0) + 1.0) * x); }
vec4 taylorInvSqrt(vec4 r) { return 1.79284291400159 - 0.85373472095314 * r; }

// Simplex 2D noise - close approximation to FastNoiseLite TYPE_SIMPLEX_SMOOTH
float simplex2D(vec2 v) {
	const vec4 C = vec4(0.211324865405187, 0.366025403784439,
					   -0.577350269189626, 0.024390243902439);
	vec2 i = floor(v + dot(v, C.yy));
	vec2 x0 = v - i + dot(i, C.xx);
	vec2 i1;
	i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
	vec4 x12 = x0.xyxy + C.xxzz;
	x12.xy -= i1;
	i = mod289(vec3(i, 0.0)).xy;
	vec3 p = permute(permute(i.y + vec3(0.0, i1.y, 1.0)) + i.x + vec3(0.0, i1.x, 1.0));
	vec3 m = max(0.5 - vec3(dot(x0, x0), dot(x12.xy, x12.xy), dot(x12.zw, x12.zw)), 0.0);
	m = m * m;
	m = m * m;
	vec3 x = 2.0 * fract(p * C.www) - 1.0;
	vec3 h = abs(x) - 0.5;
	vec3 ox = floor(x + 0.5);
	vec3 a0 = x - ox;
	m *= 1.79284291400159 - 0.85373472095314 * (a0 * a0 + h * h);
	vec3 g;
	g.x = a0.x * x0.x + h.x * x0.y;
	g.yz = a0.yz * x12.xz + h.yz * x12.yw;
	return 130.0 * dot(m, g);
}

// FBM (Fractal Brownian Motion) - matches FastNoiseLite FBM with 3 octaves
float fbm3(vec2 p, float seed) {
	float value = 0.0;
	float amplitude = 1.0;
	float frequency = 1.0;
	float lacunarity = 2.0;
	float gain = 0.5;

	for (int i = 0; i < 3; i++) {
		value += amplitude * simplex2D(p * frequency + seed);
		amplitude *= gain;
		frequency *= lacunarity;
	}
	return value;
}

// Simple hash for color variation
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// 2D noise for color variation
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

// ========== BIOME CALCULATION - Matches terrain_biome_generator.gd exactly ==========

int get_biome_at_position(vec2 world_xz, float seed) {
	float distance = length(world_xz);

	// Force valley near spawn - MUST match GDScript
	if (distance < SPAWN_VALLEY_RADIUS) {
		return 0;
	}

	// Domain warping for organic shapes - matches biome_warp_x/z in GDScript
	// GDScript uses frequency 0.002, TYPE_PERLIN, 2 octaves
	float warp_strength = 200.0;
	float warp_freq = 0.002;
	float warp_x = simplex2D(world_xz * warp_freq + seed + 200.0) * warp_strength;
	float warp_z = simplex2D(world_xz * warp_freq + seed + 201.0) * warp_strength;

	vec2 warped_pos = world_xz + vec2(warp_x, warp_z);

	// Sample biome noise - matches biome_noise in GDScript
	// GDScript uses frequency 0.0032, TYPE_SIMPLEX_SMOOTH, FBM 3 octaves
	float biome_freq = 0.0032;
	float biome_value = fbm3(warped_pos * biome_freq, seed + 100.0);

	// Sample scale noise - matches biome_scale_noise in GDScript
	// GDScript uses frequency 0.004, TYPE_SIMPLEX, 2 octaves
	float scale_freq = 0.004;
	float scale_value = simplex2D(world_xz * scale_freq + seed + 300.0);

	// Combine - GDScript does: combined_value = biome_value + (scale_value * 0.3)
	float combined = biome_value + scale_value * 0.3;

	// Normalize to 0-1 range - GDScript does: (combined_value + 1.0) * 0.5
	float normalized = (combined + 1.0) * 0.5;
	normalized = clamp(normalized, 0.0, 1.0);

	// Determine difficulty tier based on distance - MUST match GDScript exactly
	int tier = 0;
	if (distance < SAFE_ZONE_RADIUS) {
		tier = 0;
	} else if (distance < MID_ZONE_RADIUS) {
		tier = 1;
	} else if (distance < DANGER_ZONE_RADIUS) {
		tier = 2;
	} else if (distance < EXTREME_ZONE_RADIUS) {
		tier = 3;
	} else {
		tier = 4;
	}

	// Select biome based on noise value and difficulty tier
	// MUST match the exact thresholds in terrain_biome_generator.gd _get_biome_index()
	if (tier == 0) {
		// Safe zone - valley and forest only
		if (normalized < 0.5) return 0;  // valley
		else return 1;  // forest
	} else if (tier == 1) {
		// Mid zone - more variety
		if (normalized < 0.25) return 0;      // valley
		else if (normalized < 0.5) return 1;  // forest
		else if (normalized < 0.75) return 2; // swamp
		else return 4;                         // desert
	} else if (tier == 2) {
		// Danger zone - mountains and wizardland appear
		if (normalized < 0.15) return 1;      // forest
		else if (normalized < 0.3) return 2;  // swamp
		else if (normalized < 0.5) return 4;  // desert
		else if (normalized < 0.7) return 3;  // mountain
		else if (normalized < 0.9) return 5;  // wizardland
		else return 6;                         // hell
	} else if (tier == 3) {
		// Extreme zone - heavy hell presence
		if (normalized < 0.15) return 4;      // desert
		else if (normalized < 0.3) return 3;  // mountain
		else if (normalized < 0.45) return 5; // wizardland
		else return 6;                         // hell
	} else {
		// Beyond extreme - mostly pure hell
		if (normalized < 0.15) return 3;      // mountain
		else if (normalized < 0.25) return 5; // wizardland
		else return 6;                         // hell
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
