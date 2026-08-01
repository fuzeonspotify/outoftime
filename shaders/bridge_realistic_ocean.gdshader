shader_type spatial;
render_mode depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 deep_water_color : source_color = vec3(0.004, 0.018, 0.035);
uniform vec3 mid_water_color : source_color = vec3(0.012, 0.075, 0.115);
uniform vec3 horizon_water_color : source_color = vec3(0.055, 0.135, 0.175);
uniform vec3 foam_color : source_color = vec3(0.72, 0.86, 0.91);
uniform vec3 moon_glint_color : source_color = vec3(0.62, 0.78, 1.0);
uniform vec3 moon_direction = vec3(-0.28, 0.86, 0.42);
uniform float ocean_time = 0.0;
uniform float wave_strength : hint_range(0.0, 2.0, 0.01) = 1.0;
uniform float micro_ripple_strength : hint_range(0.0, 1.0, 0.01) = 0.24;
uniform float foam_strength : hint_range(0.0, 2.0, 0.01) = 0.86;
uniform float horizon_fade_start = 520.0;
uniform float horizon_fade_end = 1420.0;

varying vec3 ocean_world_position;
varying vec3 ocean_world_normal;
varying float ocean_crest;

float hash21(vec2 point) {
	point = fract(point * vec2(123.34, 456.21));
	point += dot(point, point + 45.32);
	return fract(point.x * point.y);
}

float value_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	local = local * local * (3.0 - 2.0 * local);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
}

float fbm(vec2 point) {
	float total = 0.0;
	float amplitude = 0.5;
	mat2 rotation = mat2(vec2(0.80, -0.60), vec2(0.60, 0.80));
	for (int octave = 0; octave < 4; octave++) {
		total += value_noise(point) * amplitude;
		point = rotation * point * 2.03 + vec2(17.2, 9.4);
		amplitude *= 0.5;
	}
	return total;
}

void accumulate_wave(
	vec2 world_xz,
	vec2 direction,
	float frequency,
	float amplitude,
	float speed,
	inout float height,
	inout vec2 slope
) {
	vec2 wave_direction = normalize(direction);
	float phase = dot(world_xz, wave_direction) * frequency + ocean_time * speed;
	float sine_value = sin(phase);
	float cosine_value = cos(phase);
	height += sine_value * amplitude;
	slope += wave_direction * cosine_value * amplitude * frequency;
}

void vertex() {
	vec3 source_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 world_xz = source_world_position.xz;
	float wave_height = 0.0;
	vec2 wave_slope = vec2(0.0);

	accumulate_wave(world_xz, vec2(0.82, 0.57), 0.058, 1.12 * wave_strength, 0.72, wave_height, wave_slope);
	accumulate_wave(world_xz, vec2(-0.36, 0.93), 0.097, 0.58 * wave_strength, 1.05, wave_height, wave_slope);
	accumulate_wave(world_xz, vec2(0.98, -0.18), 0.172, 0.27 * wave_strength, 1.52, wave_height, wave_slope);
	accumulate_wave(world_xz, vec2(-0.74, -0.67), 0.285, 0.13 * wave_strength, 2.10, wave_height, wave_slope);

	VERTEX.y += wave_height;
	vec3 local_normal = normalize(vec3(-wave_slope.x, 1.0, -wave_slope.y));
	NORMAL = local_normal;
	ocean_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	ocean_world_normal = normalize(MODEL_NORMAL_MATRIX * local_normal);
	ocean_crest = clamp(wave_height * 0.42 + length(wave_slope) * 0.34, 0.0, 1.0);
}

void fragment() {
	vec3 world_normal = normalize(ocean_world_normal);
	vec2 micro_uv = ocean_world_position.xz * 0.30;
	float micro_a = fbm(micro_uv + vec2(ocean_time * 0.19, ocean_time * -0.11));
	float micro_b = fbm(micro_uv * 1.77 + vec2(ocean_time * -0.13, ocean_time * 0.21));
	vec2 micro_gradient = vec2(
		micro_a - fbm(micro_uv + vec2(0.035, 0.0)),
		micro_b - fbm(micro_uv + vec2(0.0, 0.035))
	);
	world_normal = normalize(world_normal + vec3(
		micro_gradient.x * micro_ripple_strength,
		0.0,
		micro_gradient.y * micro_ripple_strength
	));
	NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);

	vec3 world_view = normalize(CAMERA_POSITION_WORLD - ocean_world_position);
	float facing = clamp(dot(world_normal, world_view), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 5.0);
	float distance_to_camera = distance(CAMERA_POSITION_WORLD, ocean_world_position);
	float horizon_mix = smoothstep(horizon_fade_start, horizon_fade_end, distance_to_camera);

	float broad_variation = fbm(ocean_world_position.xz * 0.011 + vec2(ocean_time * 0.006, 0.0));
	vec3 body_color = mix(deep_water_color, mid_water_color, 0.24 + broad_variation * 0.28);
	body_color = mix(body_color, horizon_water_color, fresnel * 0.74 + horizon_mix * 0.46);

	vec3 reflected_moon = reflect(-normalize(moon_direction), world_normal);
	float moon_glint = pow(max(dot(reflected_moon, world_view), 0.0), 118.0);
	moon_glint += pow(max(dot(reflected_moon, world_view), 0.0), 24.0) * 0.13;
	moon_glint *= 0.45 + ocean_crest * 0.85;

	float foam_noise = fbm(ocean_world_position.xz * 0.19 + vec2(ocean_time * 0.04, ocean_time * -0.03));
	float crest_foam = smoothstep(0.52, 0.92, ocean_crest + foam_noise * 0.28);
	float broken_foam = smoothstep(0.67, 0.89, foam_noise) * smoothstep(0.23, 0.62, ocean_crest);
	float foam = clamp((crest_foam * 0.72 + broken_foam * 0.55) * foam_strength, 0.0, 0.88);

	ALBEDO = mix(body_color, foam_color, foam);
	METALLIC = 0.0;
	ROUGHNESS = mix(0.22, 0.055, fresnel) + foam * 0.36;
	SPECULAR = 0.96;
	EMISSION = moon_glint_color * moon_glint * 1.55 + foam_color * foam * 0.045;
}
