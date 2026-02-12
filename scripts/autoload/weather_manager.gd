extends Node
## WeatherManager - Manages weather conditions, transitions, and effects
## Handles rain, snow, fog, storms with realistic transitions and time-based patterns

# Weather states enumeration
enum WeatherState {
	CLEAR,
	CLOUDY,
	FOG,
	LIGHT_RAIN,
	RAIN,
	HEAVY_RAIN,
	STORM,
	LIGHT_SNOW,
	SNOW,
	BLIZZARD
}

# Signals for weather events
signal weather_changed(old_state: WeatherState, new_state: WeatherState)
signal weather_transition_started(target_state: WeatherState, duration: float)
signal weather_transition_completed(state: WeatherState)
signal temperature_changed(new_temperature: float)
signal precipitation_intensity_changed(intensity: float)
signal cloud_coverage_changed(coverage: float)

# Current weather state
var current_weather: WeatherState = WeatherState.CLEAR
var target_weather: WeatherState = WeatherState.CLEAR
var is_transitioning: bool = false
var transition_progress: float = 0.0
var transition_duration: float = 5.0

# Weather parameters
var temperature: float = 15.0  # Celsius
var cloud_coverage: float = 0.0  # 0.0 to 1.0
var precipitation_intensity: float = 0.0  # 0.0 to 1.0
var wind_strength: float = 0.0  # 0.0 to 1.0
var visibility: float = 1.0  # 0.0 (no visibility) to 1.0 (full visibility)
var snow_accumulation: float = 0.0  # 0.0 to 1.0

# Cloud rendering parameters
var cloud_darkness: float = 0.0  # 0.0 = white fluffy, 1.0 = dark storm clouds
var target_cloud_coverage: float = 0.0
var target_cloud_darkness: float = 0.0

# Fog parameters
var fog_density: float = 0.0
var target_fog_density: float = 0.0

# Configuration
@export var enable_automatic_transitions: bool = true
@export var min_weather_duration: float = 300.0  # 5 minutes
@export var max_weather_duration: float = 900.0  # 15 minutes
@export var base_temperature: float = 15.0  # Base temperature in Celsius
@export var temperature_variation: float = 10.0  # Temperature can vary +/- this amount

# Timers
var weather_duration_timer: float = 0.0
var next_weather_change: float = 300.0

# Time of day influence (set by DayNightCycle)
var current_hour: float = 12.0  # 0-24
var is_night: bool = false

# Biome modifiers
var current_biome: String = "plains"
var biome_temperature_modifier: float = 0.0
var biome_weather_weights: Dictionary = {}

# Ground snow coverage
var ground_snow_coverage: float = 0.0
var snow_accumulation_rate: float = 0.03  # Rate snow builds up per second
var snow_melt_rate: float = 0.015  # How fast snow melts
var max_snow_coverage: float = 1.0

# References
var world_environment: WorldEnvironment
var sky_material: ShaderMaterial
var terrain_material: ShaderMaterial
var sun_light: DirectionalLight3D

# Particle systems (created at runtime)
var rain_particles: GPUParticles3D
var snow_particles: GPUParticles3D
var player_ref: Node3D

# Weather state properties
const WEATHER_PROPERTIES := {
	WeatherState.CLEAR: {
		"name": "Clear",
		"cloud_coverage": 0.0,
		"cloud_darkness": 0.0,
		"precipitation": 0.0,
		"visibility": 1.0,
		"wind": 0.1,
		"fog": 0.0,
		"requires_cold": false
	},
	WeatherState.CLOUDY: {
		"name": "Cloudy",
		"cloud_coverage": 0.7,
		"cloud_darkness": 0.1,
		"precipitation": 0.0,
		"visibility": 0.9,
		"wind": 0.2,
		"fog": 0.0,
		"requires_cold": false
	},
	WeatherState.FOG: {
		"name": "Fog",
		"cloud_coverage": 0.9,
		"cloud_darkness": 0.1,
		"precipitation": 0.0,
		"visibility": 0.3,
		"wind": 0.05,
		"fog": 1.0,
		"requires_cold": false
	},
	WeatherState.LIGHT_RAIN: {
		"name": "Light Rain",
		"cloud_coverage": 0.8,
		"cloud_darkness": 0.3,
		"precipitation": 0.3,
		"visibility": 0.8,
		"wind": 0.3,
		"fog": 0.3,
		"requires_cold": false
	},
	WeatherState.RAIN: {
		"name": "Rain",
		"cloud_coverage": 0.9,
		"cloud_darkness": 0.5,
		"precipitation": 0.6,
		"visibility": 0.7,
		"wind": 0.4,
		"fog": 0.5,
		"requires_cold": false
	},
	WeatherState.HEAVY_RAIN: {
		"name": "Heavy Rain",
		"cloud_coverage": 1.0,
		"cloud_darkness": 0.7,
		"precipitation": 0.9,
		"visibility": 0.5,
		"wind": 0.6,
		"fog": 0.7,
		"requires_cold": false
	},
	WeatherState.STORM: {
		"name": "Storm",
		"cloud_coverage": 1.0,
		"cloud_darkness": 0.9,
		"precipitation": 1.0,
		"visibility": 0.4,
		"wind": 0.9,
		"fog": 0.6,
		"requires_cold": false
	},
	WeatherState.LIGHT_SNOW: {
		"name": "Light Snow",
		"cloud_coverage": 0.8,
		"cloud_darkness": 0.1,
		"precipitation": 0.3,
		"visibility": 0.8,
		"wind": 0.2,
		"fog": 0.2,
		"requires_cold": true
	},
	WeatherState.SNOW: {
		"name": "Snow",
		"cloud_coverage": 0.9,
		"cloud_darkness": 0.2,
		"precipitation": 0.6,
		"visibility": 0.6,
		"wind": 0.4,
		"fog": 0.4,
		"requires_cold": true
	},
	WeatherState.BLIZZARD: {
		"name": "Blizzard",
		"cloud_coverage": 1.0,
		"cloud_darkness": 0.3,
		"precipitation": 1.0,
		"visibility": 0.2,
		"wind": 1.0,
		"fog": 0.9,
		"requires_cold": true
	}
}

# Weather transition probabilities (influenced by current weather)
const WEATHER_TRANSITIONS := {
	WeatherState.CLEAR: {
		WeatherState.CLEAR: 0.6,
		WeatherState.CLOUDY: 0.3,
		WeatherState.FOG: 0.1
	},
	WeatherState.CLOUDY: {
		WeatherState.CLEAR: 0.3,
		WeatherState.CLOUDY: 0.3,
		WeatherState.LIGHT_RAIN: 0.2,
		WeatherState.FOG: 0.1,
		WeatherState.LIGHT_SNOW: 0.1  # If cold enough
	},
	WeatherState.FOG: {
		WeatherState.FOG: 0.4,
		WeatherState.CLOUDY: 0.3,
		WeatherState.CLEAR: 0.2,
		WeatherState.LIGHT_RAIN: 0.1
	},
	WeatherState.LIGHT_RAIN: {
		WeatherState.LIGHT_RAIN: 0.3,
		WeatherState.RAIN: 0.3,
		WeatherState.CLOUDY: 0.3,
		WeatherState.CLEAR: 0.1
	},
	WeatherState.RAIN: {
		WeatherState.RAIN: 0.3,
		WeatherState.HEAVY_RAIN: 0.2,
		WeatherState.LIGHT_RAIN: 0.3,
		WeatherState.STORM: 0.1,
		WeatherState.CLOUDY: 0.1
	},
	WeatherState.HEAVY_RAIN: {
		WeatherState.HEAVY_RAIN: 0.2,
		WeatherState.STORM: 0.3,
		WeatherState.RAIN: 0.4,
		WeatherState.CLOUDY: 0.1
	},
	WeatherState.STORM: {
		WeatherState.STORM: 0.2,
		WeatherState.HEAVY_RAIN: 0.5,
		WeatherState.RAIN: 0.3
	},
	WeatherState.LIGHT_SNOW: {
		WeatherState.LIGHT_SNOW: 0.3,
		WeatherState.SNOW: 0.2,
		WeatherState.CLOUDY: 0.3,
		WeatherState.CLEAR: 0.2
	},
	WeatherState.SNOW: {
		WeatherState.SNOW: 0.3,
		WeatherState.BLIZZARD: 0.2,
		WeatherState.LIGHT_SNOW: 0.3,
		WeatherState.CLOUDY: 0.2
	},
	WeatherState.BLIZZARD: {
		WeatherState.BLIZZARD: 0.2,
		WeatherState.SNOW: 0.5,
		WeatherState.LIGHT_SNOW: 0.3
	}
}


func _ready() -> void:
	# Initialize with clear weather
	set_weather_immediate(WeatherState.CLEAR)
	_update_temperature()
	_schedule_next_weather_change()

	# Find scene nodes
	call_deferred("_find_scene_nodes")
	call_deferred("_create_particle_systems")

	print("[WeatherManager] Initialized with ", get_weather_name(current_weather))


func _process(delta: float) -> void:
	# Handle weather transitions
	if is_transitioning:
		_process_weather_transition(delta)
	else:
		# Smoothly transition parameters even when not changing weather state
		cloud_coverage = lerpf(cloud_coverage, target_cloud_coverage, delta * 0.3)
		cloud_darkness = lerpf(cloud_darkness, target_cloud_darkness, delta * 0.3)
		fog_density = lerpf(fog_density, target_fog_density, delta * 0.3)

	# Handle automatic weather changes
	if enable_automatic_transitions:
		weather_duration_timer += delta
		if weather_duration_timer >= next_weather_change:
			_trigger_automatic_weather_change()

	# Update visuals
	_update_sky_shader()
	_update_environment()
	_update_particles()
	_update_ground_snow(delta)

	# Follow player
	_follow_player()


func _find_scene_nodes() -> void:
	# Find WorldEnvironment and sun
	var parent = get_parent()
	if parent:
		for child in parent.get_children():
			if child is DirectionalLight3D and not sun_light:
				sun_light = child
			if child is WorldEnvironment and not world_environment:
				world_environment = child

	# Get sky shader material
	if world_environment and world_environment.environment:
		var env = world_environment.environment
		if env.sky and env.sky.sky_material is ShaderMaterial:
			sky_material = env.sky.sky_material
			print("[WeatherManager] Found sky shader material")

	# Find terrain material from TerrainWorld
	if parent and parent.has_method("get") and parent.get("terrain_material"):
		var mat = parent.get("terrain_material")
		if mat is ShaderMaterial:
			terrain_material = mat
			print("[WeatherManager] Found terrain shader material")


func _create_particle_systems() -> void:
	# Create rain particle system
	rain_particles = GPUParticles3D.new()
	rain_particles.name = "RainParticles"
	rain_particles.emitting = false
	rain_particles.amount = 2000
	rain_particles.lifetime = 1.5
	rain_particles.visibility_aabb = AABB(Vector3(-30, -20, -30), Vector3(60, 40, 60))
	rain_particles.process_material = _create_rain_material()
	rain_particles.draw_pass_1 = _create_rain_mesh()
	add_child(rain_particles)

	# Create snow particle system
	snow_particles = GPUParticles3D.new()
	snow_particles.name = "SnowParticles"
	snow_particles.emitting = false
	snow_particles.amount = 2000
	snow_particles.lifetime = 8.0
	snow_particles.preprocess = 6.0
	snow_particles.visibility_aabb = AABB(Vector3(-40, -50, -40), Vector3(80, 70, 80))
	snow_particles.process_material = _create_snow_material()
	snow_particles.draw_pass_1 = _create_snow_mesh()
	add_child(snow_particles)

	print("[WeatherManager] Created particle systems")


func _create_rain_material() -> ParticleProcessMaterial:
	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(0.1, -1, 0.05)
	mat.spread = 3.0
	mat.initial_velocity_min = 35.0
	mat.initial_velocity_max = 50.0
	mat.gravity = Vector3(0, -30, 0)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(20, 2, 20)
	mat.color = Color(0.8, 0.85, 0.95, 0.8)
	return mat


func _create_rain_mesh() -> QuadMesh:
	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.03, 0.6)

	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.85, 0.9, 1.0, 0.7)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.vertex_color_use_as_albedo = true
	mesh.material = mat
	return mesh


func _create_snow_material() -> ParticleProcessMaterial:
	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 30.0
	mat.initial_velocity_min = 8.0
	mat.initial_velocity_max = 12.0
	mat.gravity = Vector3(0, -8.0, 0)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(30, 3, 30)
	mat.color = Color(1.0, 1.0, 1.0, 1.0)
	mat.turbulence_enabled = true
	mat.turbulence_noise_strength = 1.5
	mat.turbulence_noise_speed_random = 0.4
	mat.turbulence_noise_scale = 2.0
	mat.scale_min = 0.7
	mat.scale_max = 1.5
	return mat


func _create_snow_mesh() -> QuadMesh:
	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.12, 0.12)

	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 1.0, 1.0, 0.9)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = true
	mesh.material = mat
	return mesh


## Set weather immediately without transition
func set_weather_immediate(new_weather: WeatherState) -> void:
	var old_weather = current_weather
	current_weather = new_weather
	target_weather = new_weather
	is_transitioning = false
	transition_progress = 1.0

	_apply_weather_properties(new_weather, 1.0)

	if old_weather != new_weather:
		weather_changed.emit(old_weather, new_weather)
		weather_transition_completed.emit(new_weather)
		print("[WeatherManager] Weather set to: ", get_weather_name(new_weather))


## Transition to new weather state over time
func transition_to_weather(new_weather: WeatherState, duration: float = 5.0) -> void:
	if new_weather == current_weather:
		return

	# Check if weather is valid for current temperature
	if not _is_weather_valid_for_temperature(new_weather):
		print("[WeatherManager] Weather ", get_weather_name(new_weather), " invalid for temperature ", temperature, "C")
		return

	target_weather = new_weather
	transition_duration = duration
	transition_progress = 0.0
	is_transitioning = true

	weather_transition_started.emit(new_weather, duration)
	print("[WeatherManager] Transitioning from ", get_weather_name(current_weather), " to ", get_weather_name(new_weather))


## Process weather transition
func _process_weather_transition(delta: float) -> void:
	transition_progress += delta / transition_duration

	if transition_progress >= 1.0:
		transition_progress = 1.0
		is_transitioning = false
		var old_weather = current_weather
		current_weather = target_weather
		weather_changed.emit(old_weather, current_weather)
		weather_transition_completed.emit(current_weather)
		print("[WeatherManager] Transition completed to: ", get_weather_name(current_weather))

	# Blend between current and target weather properties
	_apply_weather_blend(transition_progress)


## Apply blended weather properties during transition
func _apply_weather_blend(blend_factor: float) -> void:
	var current_props = WEATHER_PROPERTIES[current_weather]
	var target_props = WEATHER_PROPERTIES[target_weather]

	target_cloud_coverage = lerp(current_props["cloud_coverage"], target_props["cloud_coverage"], blend_factor)
	target_cloud_darkness = lerp(current_props["cloud_darkness"], target_props["cloud_darkness"], blend_factor)
	precipitation_intensity = lerp(current_props["precipitation"], target_props["precipitation"], blend_factor)
	visibility = lerp(current_props["visibility"], target_props["visibility"], blend_factor)
	wind_strength = lerp(current_props["wind"], target_props["wind"], blend_factor)
	target_fog_density = lerp(current_props["fog"], target_props["fog"], blend_factor)

	cloud_coverage = lerpf(cloud_coverage, target_cloud_coverage, 0.3)
	cloud_darkness = lerpf(cloud_darkness, target_cloud_darkness, 0.3)
	fog_density = lerpf(fog_density, target_fog_density, 0.3)

	cloud_coverage_changed.emit(cloud_coverage)
	precipitation_intensity_changed.emit(precipitation_intensity)


## Apply weather properties immediately
func _apply_weather_properties(weather: WeatherState, intensity: float = 1.0) -> void:
	var props = WEATHER_PROPERTIES[weather]

	target_cloud_coverage = props["cloud_coverage"] * intensity
	target_cloud_darkness = props["cloud_darkness"] * intensity
	precipitation_intensity = props["precipitation"] * intensity
	visibility = lerp(1.0, props["visibility"], intensity)
	wind_strength = props["wind"] * intensity
	target_fog_density = props["fog"] * intensity

	# Apply immediately
	cloud_coverage = target_cloud_coverage
	cloud_darkness = target_cloud_darkness
	fog_density = target_fog_density

	cloud_coverage_changed.emit(cloud_coverage)
	precipitation_intensity_changed.emit(precipitation_intensity)


## Check if weather is valid for current temperature
func _is_weather_valid_for_temperature(weather: WeatherState) -> bool:
	var props = WEATHER_PROPERTIES[weather]

	# Snow requires cold temperature (below 2C)
	if props["requires_cold"]:
		return temperature < 2.0

	# Rain requires warm temperature (above 0C)
	if weather in [WeatherState.LIGHT_RAIN, WeatherState.RAIN, WeatherState.HEAVY_RAIN, WeatherState.STORM]:
		return temperature > 0.0

	return true


## Trigger automatic weather change based on probabilities
func _trigger_automatic_weather_change() -> void:
	var new_weather = _select_next_weather()

	if new_weather != current_weather:
		var duration = randf_range(3.0, 8.0)
		transition_to_weather(new_weather, duration)

	_schedule_next_weather_change()


## Select next weather based on transition probabilities and time of day
func _select_next_weather() -> WeatherState:
	var transitions = WEATHER_TRANSITIONS[current_weather].duplicate()

	# Apply time-of-day modifiers
	_apply_time_of_day_modifiers(transitions)

	# Apply biome modifiers
	_apply_biome_modifiers(transitions)

	# Filter out invalid weather states for current temperature
	var valid_transitions := {}
	for weather in transitions:
		if _is_weather_valid_for_temperature(weather):
			valid_transitions[weather] = transitions[weather]

	# Normalize probabilities
	var total_weight = 0.0
	for weight in valid_transitions.values():
		total_weight += weight

	if total_weight == 0.0:
		return current_weather

	# Select weather based on weighted probability
	var rand_value = randf() * total_weight
	var accumulated_weight = 0.0

	for weather in valid_transitions:
		accumulated_weight += valid_transitions[weather]
		if rand_value <= accumulated_weight:
			return weather

	return current_weather


## Apply time-of-day modifiers to weather probabilities
func _apply_time_of_day_modifiers(transitions: Dictionary) -> void:
	# Morning (6-10): Fog more likely
	if current_hour >= 6.0 and current_hour < 10.0:
		if WeatherState.FOG in transitions:
			transitions[WeatherState.FOG] *= 2.0

	# Afternoon (14-18): Storms more likely
	if current_hour >= 14.0 and current_hour < 18.0:
		if WeatherState.STORM in transitions:
			transitions[WeatherState.STORM] *= 1.5
		if WeatherState.HEAVY_RAIN in transitions:
			transitions[WeatherState.HEAVY_RAIN] *= 1.3

	# Night (20-6): Clear weather more likely
	if is_night:
		if WeatherState.CLEAR in transitions:
			transitions[WeatherState.CLEAR] *= 1.5
		# Reduce storm probability at night
		if WeatherState.STORM in transitions:
			transitions[WeatherState.STORM] *= 0.5


## Apply biome modifiers to weather probabilities
func _apply_biome_modifiers(transitions: Dictionary) -> void:
	if biome_weather_weights.is_empty():
		return

	for weather in transitions:
		var weather_name = get_weather_name(weather).to_lower().replace(" ", "_")
		if weather_name in biome_weather_weights:
			transitions[weather] *= biome_weather_weights[weather_name]


## Schedule next weather change
func _schedule_next_weather_change() -> void:
	weather_duration_timer = 0.0
	next_weather_change = randf_range(min_weather_duration, max_weather_duration)


## Update temperature based on time of day and season
func _update_temperature() -> void:
	var old_temp = temperature

	# Base temperature varies by time of day
	var time_modifier = 0.0
	if current_hour >= 6.0 and current_hour < 12.0:
		# Morning: warming up
		time_modifier = -5.0 + (current_hour - 6.0) * 1.5
	elif current_hour >= 12.0 and current_hour < 18.0:
		# Afternoon: warmest
		time_modifier = 4.0 - (current_hour - 12.0) * 0.5
	elif current_hour >= 18.0 and current_hour < 22.0:
		# Evening: cooling down
		time_modifier = 1.0 - (current_hour - 18.0) * 1.5
	else:
		# Night: coldest
		time_modifier = -5.0

	# Apply biome modifier
	temperature = base_temperature + time_modifier + biome_temperature_modifier

	# Weather affects temperature
	match current_weather:
		WeatherState.CLEAR:
			temperature += 2.0
		WeatherState.CLOUDY:
			temperature -= 1.0
		WeatherState.FOG:
			temperature -= 2.0
		WeatherState.STORM:
			temperature -= 3.0
		WeatherState.LIGHT_SNOW, WeatherState.SNOW, WeatherState.BLIZZARD:
			temperature -= 5.0

	if abs(temperature - old_temp) > 0.1:
		temperature_changed.emit(temperature)


## Update snow accumulation
func _update_ground_snow(delta: float) -> void:
	# Snow accumulates during snow weather
	if current_weather in [WeatherState.LIGHT_SNOW, WeatherState.SNOW, WeatherState.BLIZZARD]:
		var accumulation_rate_mult = 1.0 + (precipitation_intensity - 0.3) * 0.5
		ground_snow_coverage = min(1.0, ground_snow_coverage + snow_accumulation_rate * accumulation_rate_mult * delta)
	else:
		# Snow melts when temperature is above freezing
		if temperature > 0.0:
			var melt_rate = snow_melt_rate * (temperature / 10.0)
			ground_snow_coverage = max(0.0, ground_snow_coverage - melt_rate * delta)

	# Update terrain shader
	if terrain_material:
		terrain_material.set_shader_parameter("snow_coverage", ground_snow_coverage)


func _update_sky_shader() -> void:
	if not sky_material:
		return

	# Set cloud parameters
	sky_material.set_shader_parameter("cloud_coverage", cloud_coverage)
	sky_material.set_shader_parameter("cloud_darkness", cloud_darkness)


func _update_environment() -> void:
	if not world_environment or not world_environment.environment:
		return

	var env = world_environment.environment

	# Fog for weather
	if fog_density > 0.01:
		env.fog_enabled = true
		env.fog_density = fog_density * 0.02
		env.fog_light_energy = 1.0 - cloud_darkness * 0.5
		# Fog color based on time of day
		var base_fog_color = Color(0.7, 0.75, 0.8)
		if is_night:
			base_fog_color = Color(0.15, 0.15, 0.2)
		env.fog_light_color = base_fog_color
	else:
		env.fog_enabled = false


func _update_particles() -> void:
	var is_raining = current_weather in [WeatherState.LIGHT_RAIN, WeatherState.RAIN, WeatherState.HEAVY_RAIN, WeatherState.STORM]
	var is_snowing = current_weather in [WeatherState.LIGHT_SNOW, WeatherState.SNOW, WeatherState.BLIZZARD]

	# Rain particles
	rain_particles.emitting = is_raining and precipitation_intensity > 0.05
	if rain_particles.emitting:
		var rain_amount = int(2000 + precipitation_intensity * 6000)
		rain_particles.amount = rain_amount
		var mat = rain_particles.process_material as ParticleProcessMaterial
		if mat:
			mat.initial_velocity_min = 35.0 + precipitation_intensity * 25.0
			mat.initial_velocity_max = 50.0 + precipitation_intensity * 30.0
			var wind_str = precipitation_intensity * 0.3
			mat.direction = Vector3(wind_str, -1, wind_str * 0.5).normalized()

	# Snow particles
	snow_particles.emitting = is_snowing and precipitation_intensity > 0.05
	if snow_particles.emitting:
		var snow_amount = int(2000 + precipitation_intensity * 5000)
		snow_particles.amount = snow_amount
		var mat = snow_particles.process_material as ParticleProcessMaterial
		if mat:
			mat.turbulence_noise_strength = 1.5 + precipitation_intensity * 2.0
			mat.gravity = Vector3(precipitation_intensity * 3.0, -8.0 - precipitation_intensity * 4.0, precipitation_intensity * 2.0)


func _follow_player() -> void:
	if not is_instance_valid(player_ref):
		var players = get_tree().get_nodes_in_group("local_player")
		player_ref = players[0] if players.size() > 0 else null

	if player_ref:
		var pos = player_ref.global_position
		rain_particles.global_position = Vector3(pos.x, pos.y + 20, pos.z)
		snow_particles.global_position = Vector3(pos.x, pos.y + 15, pos.z)


## Set time of day (called by DayNightCycle)
func set_time_of_day(hour: float, night: bool) -> void:
	current_hour = hour
	is_night = night
	_update_temperature()


## Set current biome
func set_biome(biome_name: String, temp_modifier: float = 0.0, weather_weights: Dictionary = {}) -> void:
	current_biome = biome_name
	biome_temperature_modifier = temp_modifier
	biome_weather_weights = weather_weights
	_update_temperature()
	print("[WeatherManager] Biome set to: ", biome_name, " (temp modifier: ", temp_modifier, "C)")


## Get weather state name
func get_weather_name(weather: WeatherState) -> String:
	return WEATHER_PROPERTIES[weather]["name"]


## Get current weather name
func get_current_weather_name() -> String:
	return get_weather_name(current_weather)


## Check if it's currently precipitating
func is_precipitating() -> bool:
	return precipitation_intensity > 0.01


## Check if it's currently snowing
func is_snowing() -> bool:
	return current_weather in [WeatherState.LIGHT_SNOW, WeatherState.SNOW, WeatherState.BLIZZARD]


## Check if it's currently raining
func is_raining() -> bool:
	return current_weather in [WeatherState.LIGHT_RAIN, WeatherState.RAIN, WeatherState.HEAVY_RAIN, WeatherState.STORM]


## Get visibility modifier (for rendering distance)
func get_visibility_modifier() -> float:
	return visibility


## Get movement speed modifier (wind and precipitation slow movement)
func get_movement_speed_modifier() -> float:
	var modifier = 1.0
	modifier -= wind_strength * 0.1
	modifier -= precipitation_intensity * 0.05
	return clamp(modifier, 0.7, 1.0)


## Save weather state for multiplayer sync
func get_weather_state() -> Dictionary:
	return {
		"current_weather": current_weather,
		"target_weather": target_weather,
		"is_transitioning": is_transitioning,
		"transition_progress": transition_progress,
		"temperature": temperature,
		"cloud_coverage": cloud_coverage,
		"precipitation_intensity": precipitation_intensity,
		"wind_strength": wind_strength,
		"visibility": visibility,
		"snow_accumulation": ground_snow_coverage
	}


## Load weather state for multiplayer sync
func set_weather_state(state: Dictionary) -> void:
	current_weather = state.get("current_weather", WeatherState.CLEAR)
	target_weather = state.get("target_weather", WeatherState.CLEAR)
	is_transitioning = state.get("is_transitioning", false)
	transition_progress = state.get("transition_progress", 0.0)
	temperature = state.get("temperature", 15.0)
	cloud_coverage = state.get("cloud_coverage", 0.0)
	precipitation_intensity = state.get("precipitation_intensity", 0.0)
	wind_strength = state.get("wind_strength", 0.0)
	visibility = state.get("visibility", 1.0)
	ground_snow_coverage = state.get("snow_accumulation", 0.0)
