shader_type sky;

void sky() {
	// Dead simple - just output blue sky based on direction
	vec3 dir = EYEDIR;

	// Blue gradient from horizon to zenith
	float t = clamp(dir.y, 0.0, 1.0);
	vec3 horizon = vec3(0.6, 0.8, 1.0);
	vec3 zenith = vec3(0.2, 0.4, 0.9);

	COLOR = mix(horizon, zenith, t);
}
