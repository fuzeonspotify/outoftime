extends Node

const OCEAN_SHADER: Shader = preload("res://shaders/bridge_realistic_ocean.gdshader")
const WATER_LEVEL: float = -8.9
const OCEAN_CENTER_Z: float = -610.0
const OCEAN_SIZE: float = 4600.0
const OCEAN_SUBDIVISIONS: int = 220
const WATER_ENTRY_MARGIN: float = 0.34
const MAX_TRACKED_SPLASHES: int = 16

var _road: Node3D
var _ocean_surface: MeshInstance3D
var _ocean_material: ShaderMaterial
var _physical_car: RigidBody3D
var _wave_time: float = 0.0
var _water_entry_times: Dictionary = {}
var _water_entry_speeds: Dictionary = {}
var _splash_serial: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _splash_stream: AudioStreamWAV


func _ready() -> void:
	_rng.randomize()
	_wave_time = float(Time.get_ticks_msec()) * 0.001
	_road = get_parent() as Node3D
	if _road == null:
		push_error("REALISTIC OCEAN ERROR: the bridge scene root is unavailable.")
		return

	_remove_legacy_water.call_deferred()
	_build_ocean_surface()
	_enhance_bridge_environment.call_deferred()
	_build_surface_mist()
	_build_underwater_fog()
	_splash_stream = _build_splash_stream()
	set_physics_process(true)
	print("REALISTIC BRIDGE OCEAN READY: 4.6 km wave surface at Y=", WATER_LEVEL)


func _physics_process(delta: float) -> void:
	_wave_time += delta
	if _physical_car == null or not is_instance_valid(_physical_car):
		var candidate: Node = get_tree().get_first_node_in_group("physical_porsche_wreck")
		_physical_car = candidate as RigidBody3D
	if _physical_car == null or not is_instance_valid(_physical_car):
		return
	_update_physical_car_water(_physical_car, delta)


func get_water_level() -> float:
	return WATER_LEVEL


func get_surface_height(world_position: Vector3) -> float:
	var world_xz: Vector2 = Vector2(world_position.x, world_position.z)
	var height: float = WATER_LEVEL
	height += _sample_wave(world_xz, Vector2(0.82, 0.57), 0.058, 1.12, 0.72)
	height += _sample_wave(world_xz, Vector2(-0.36, 0.93), 0.097, 0.58, 1.05)
	height += _sample_wave(world_xz, Vector2(0.98, -0.18), 0.172, 0.27, 1.52)
	height += _sample_wave(world_xz, Vector2(-0.74, -0.67), 0.285, 0.13, 2.10)
	height += _sample_wave(world_xz, Vector2(0.21, -0.98), 0.510, 0.055, 2.95)
	return height


func has_body_entered_water(body: RigidBody3D) -> bool:
	if body == null or not is_instance_valid(body):
		return false
	return _water_entry_times.has(body.get_instance_id())


func get_body_water_time(body: RigidBody3D) -> float:
	if body == null or not is_instance_valid(body):
		return 0.0
	return float(_water_entry_times.get(body.get_instance_id(), 0.0))


func get_body_entry_speed(body: RigidBody3D) -> float:
	if body == null or not is_instance_valid(body):
		return 0.0
	return float(_water_entry_speeds.get(body.get_instance_id(), 0.0))


func _sample_wave(
	world_xz: Vector2,
	direction: Vector2,
	frequency: float,
	amplitude: float,
	speed: float
) -> float:
	var normalized_direction: Vector2 = direction.normalized()
	var phase: float = world_xz.dot(normalized_direction) * frequency + _wave_time * speed
	return sin(phase) * amplitude


func _remove_legacy_water() -> void:
	if _road == null:
		return
	var legacy_nodes: Array[Node] = _road.find_children("MoonlitWater", "MeshInstance3D", true, false)
	for node: Node in legacy_nodes:
		var legacy_water: MeshInstance3D = node as MeshInstance3D
		if legacy_water == null:
			continue
		legacy_water.visible = false
		legacy_water.queue_free()
	print("REALISTIC BRIDGE OCEAN: removed ", legacy_nodes.size(), " legacy water surface(s).")


func _build_ocean_surface() -> void:
	_ocean_surface = MeshInstance3D.new()
	_ocean_surface.name = "RealisticNightOceanSurface"
	_ocean_surface.position = Vector3(0.0, WATER_LEVEL, OCEAN_CENTER_Z)
	_ocean_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ocean_surface.extra_cull_margin = 12.0
	_ocean_surface.custom_aabb = AABB(
		Vector3(-OCEAN_SIZE * 0.5, -4.5, -OCEAN_SIZE * 0.5),
		Vector3(OCEAN_SIZE, 9.0, OCEAN_SIZE)
	)

	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(OCEAN_SIZE, OCEAN_SIZE)
	plane.subdivide_width = OCEAN_SUBDIVISIONS
	plane.subdivide_depth = OCEAN_SUBDIVISIONS
	_ocean_surface.mesh = plane

	_ocean_material = ShaderMaterial.new()
	_ocean_material.shader = OCEAN_SHADER
	_ocean_surface.material_override = _ocean_material
	_road.add_child(_ocean_surface)


func _enhance_bridge_environment() -> void:
	if _road == null:
		return
	var environment_nodes: Array[Node] = _road.find_children("*", "WorldEnvironment", true, false)
	for node: Node in environment_nodes:
		var world_environment: WorldEnvironment = node as WorldEnvironment
		if world_environment == null or world_environment.environment == null:
			continue
		var environment: Environment = world_environment.environment
		environment.ssr_enabled = true
		environment.ssr_max_steps = 96
		environment.ssr_fade_in = 0.04
		environment.ssr_fade_out = 2.4
		environment.ssr_depth_tolerance = 0.16
		environment.volumetric_fog_enabled = true
		environment.volumetric_fog_length = maxf(environment.volumetric_fog_length, 150.0)
		environment.volumetric_fog_density = maxf(environment.volumetric_fog_density, 0.0045)
		environment.volumetric_fog_albedo = Color("8fa8b8")
		environment.volumetric_fog_emission = Color("071520")
		environment.volumetric_fog_emission_energy = 0.18
		environment.volumetric_fog_anisotropy = 0.52
		environment.volumetric_fog_ambient_inject = 0.42
		environment.volumetric_fog_temporal_reprojection_enabled = true
		environment.volumetric_fog_temporal_reprojection_amount = 0.86
		environment.fog_light_color = environment.fog_light_color.lerp(Color("58758c"), 0.34)
		environment.fog_sky_affect = maxf(environment.fog_sky_affect, 0.62)
		environment.glow_enabled = true
		environment.glow_bloom = maxf(environment.glow_bloom, 0.16)
		print("REALISTIC BRIDGE OCEAN: Forward+ SSR and ocean atmosphere enabled.")
		return
	push_warning("REALISTIC OCEAN WARNING: no WorldEnvironment was found for SSR enhancement.")


func _build_surface_mist() -> void:
	var mist: GPUParticles3D = GPUParticles3D.new()
	mist.name = "OceanSurfaceMist"
	mist.position = Vector3(0.0, WATER_LEVEL + 1.5, OCEAN_CENTER_Z)
	mist.amount = 140
	mist.lifetime = 13.0
	mist.preprocess = 9.0
	mist.randomness = 0.82
	mist.fixed_fps = 20
	mist.local_coords = false
	mist.visibility_aabb = AABB(Vector3(-130.0, -8.0, -860.0), Vector3(260.0, 22.0, 1720.0))

	var process_material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_material.emission_box_extents = Vector3(105.0, 1.2, 790.0)
	process_material.direction = Vector3(0.18, 0.03, -1.0)
	process_material.spread = 18.0
	process_material.initial_velocity_min = 0.22
	process_material.initial_velocity_max = 0.70
	process_material.gravity = Vector3(0.0, 0.016, 0.0)
	process_material.scale_min = 0.72
	process_material.scale_max = 1.65
	process_material.color_ramp = _make_gradient_texture([
		Color(0.46, 0.62, 0.70, 0.0),
		Color(0.46, 0.62, 0.70, 0.055),
		Color(0.36, 0.52, 0.62, 0.040),
		Color(0.30, 0.44, 0.54, 0.0)
	])
	mist.process_material = process_material

	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(10.0, 3.6)
	var mist_material: StandardMaterial3D = StandardMaterial3D.new()
	mist_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mist_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mist_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mist_material.vertex_color_use_as_albedo = true
	mist_material.albedo_color = Color.WHITE
	mist_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	quad.material = mist_material
	mist.draw_pass_1 = quad
	_road.add_child(mist)


func _build_underwater_fog() -> void:
	var underwater_volume: FogVolume = FogVolume.new()
	underwater_volume.name = "OceanUnderwaterFog"
	underwater_volume.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	underwater_volume.size = Vector3(240.0, 26.0, 1660.0)
	underwater_volume.position = Vector3(0.0, WATER_LEVEL - 11.0, OCEAN_CENTER_Z)
	var underwater_material: FogMaterial = FogMaterial.new()
	underwater_material.density = 0.075
	underwater_material.albedo = Color("1a526a")
	underwater_material.emission = Color("00101b")
	underwater_volume.material = underwater_material
	_road.add_child(underwater_volume)

	var surface_volume: FogVolume = FogVolume.new()
	surface_volume.name = "OceanLowMistVolume"
	surface_volume.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	surface_volume.size = Vector3(220.0, 7.0, 1620.0)
	surface_volume.position = Vector3(0.0, WATER_LEVEL + 2.5, OCEAN_CENTER_Z)
	var surface_material: FogMaterial = FogMaterial.new()
	surface_material.density = 0.0075
	surface_material.albedo = Color("90a9b4")
	surface_material.emission = Color("06131b")
	surface_volume.material = surface_material
	_road.add_child(surface_volume)


func _update_physical_car_water(body: RigidBody3D, delta: float) -> void:
	var surface_height: float = get_surface_height(body.global_position)
	var depth: float = surface_height - body.global_position.y
	var body_id: int = body.get_instance_id()

	if depth < -WATER_ENTRY_MARGIN:
		return

	if not _water_entry_times.has(body_id):
		_register_water_entry(body, surface_height)

	var water_time: float = float(_water_entry_times.get(body_id, 0.0)) + delta
	_water_entry_times[body_id] = water_time
	var submersion: float = clampf((depth + WATER_ENTRY_MARGIN) / 2.4, 0.0, 1.0)
	var flood_progress: float = smoothstep(2.7, 10.5, water_time)
	var sealed_buoyancy: float = lerpf(1.16, 0.24, flood_progress)

	var buoyancy_force: Vector3 = Vector3.UP * body.mass * 9.8 * sealed_buoyancy * submersion
	var linear_drag_strength: float = 0.72 + submersion * 2.35
	var drag_force: Vector3 = -body.linear_velocity * body.mass * linear_drag_strength
	var angular_drag: Vector3 = -body.angular_velocity * body.mass * (0.28 + submersion * 0.72)
	body.apply_central_force(buoyancy_force + drag_force)
	body.apply_torque(angular_drag)
	body.sleeping = false

	# A flooded car eventually becomes negatively buoyant and sinks instead of
	# hovering forever at the surface.
	if water_time > 7.0:
		body.apply_central_force(Vector3.DOWN * body.mass * lerpf(0.0, 3.8, flood_progress))


func _register_water_entry(body: RigidBody3D, surface_height: float) -> void:
	var body_id: int = body.get_instance_id()
	var entry_velocity: Vector3 = body.linear_velocity
	var entry_speed: float = entry_velocity.length()
	_water_entry_times[body_id] = 0.0
	_water_entry_speeds[body_id] = entry_speed
	body.set_meta("ocean_entered", true)
	body.set_meta("ocean_entry_speed", entry_speed)

	var resistance_ratio: float = clampf(entry_speed / 34.0, 0.26, 0.62)
	body.apply_central_impulse(-entry_velocity * body.mass * resistance_ratio)
	body.apply_central_impulse(Vector3.UP * body.mass * clampf(1.3 + maxf(-entry_velocity.y, 0.0) * 0.10, 1.3, 3.4))
	body.apply_torque_impulse(Vector3(
		_rng.randf_range(-120.0, 120.0),
		_rng.randf_range(-80.0, 80.0),
		_rng.randf_range(-150.0, 150.0)
	))

	var impact_position: Vector3 = body.global_position
	impact_position.y = surface_height + 0.08
	_spawn_major_splash(impact_position, entry_speed)
	print("PORSCHE OCEAN IMPACT: entered at ", impact_position, " with speed ", entry_speed)


func _spawn_major_splash(world_position: Vector3, entry_speed: float) -> void:
	_splash_serial += 1
	_spawn_water_droplets(world_position, entry_speed)
	_spawn_foam_plume(world_position, entry_speed)
	for ring_index: int in range(3):
		_spawn_expanding_ring(world_position, ring_index, entry_speed)
	_play_splash_audio(world_position, entry_speed)


func _spawn_water_droplets(world_position: Vector3, entry_speed: float) -> void:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.name = "OceanImpactDroplets_%02d" % _splash_serial
	particles.global_position = world_position
	particles.one_shot = true
	particles.amount = int(clampf(150.0 + entry_speed * 4.5, 170.0, 320.0))
	particles.lifetime = 2.8
	particles.explosiveness = 1.0
	particles.randomness = 0.68
	particles.fixed_fps = 45
	particles.local_coords = false
	particles.visibility_aabb = AABB(Vector3(-28.0, -8.0, -28.0), Vector3(56.0, 42.0, 56.0))

	var process_material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_material.emission_sphere_radius = 1.25
	process_material.direction = Vector3.UP
	process_material.spread = 48.0
	process_material.initial_velocity_min = 8.0
	process_material.initial_velocity_max = clampf(12.0 + entry_speed * 0.46, 14.0, 27.0)
	process_material.gravity = Vector3(0.0, -13.5, 0.0)
	process_material.scale_min = 0.55
	process_material.scale_max = 1.65
	process_material.color_ramp = _make_gradient_texture([
		Color(0.72, 0.90, 1.0, 0.94),
		Color(0.42, 0.72, 0.86, 0.82),
		Color(0.20, 0.49, 0.66, 0.38),
		Color(0.12, 0.32, 0.46, 0.0)
	])
	particles.process_material = process_material

	var droplet_mesh: SphereMesh = SphereMesh.new()
	droplet_mesh.radius = 0.055
	droplet_mesh.height = 0.18
	var droplet_material: StandardMaterial3D = StandardMaterial3D.new()
	droplet_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	droplet_material.vertex_color_use_as_albedo = true
	droplet_material.albedo_color = Color.WHITE
	droplet_material.metallic = 0.0
	droplet_material.roughness = 0.10
	droplet_mesh.material = droplet_material
	particles.draw_pass_1 = droplet_mesh
	_road.add_child(particles)
	particles.restart()
	particles.finished.connect(Callable(particles, "queue_free"))


func _spawn_foam_plume(world_position: Vector3, entry_speed: float) -> void:
	var plume: GPUParticles3D = GPUParticles3D.new()
	plume.name = "OceanImpactFoam_%02d" % _splash_serial
	plume.global_position = world_position + Vector3.UP * 0.20
	plume.one_shot = true
	plume.amount = int(clampf(70.0 + entry_speed * 2.0, 80.0, 150.0))
	plume.lifetime = 3.4
	plume.explosiveness = 0.92
	plume.randomness = 0.80
	plume.local_coords = false
	plume.visibility_aabb = AABB(Vector3(-24.0, -6.0, -24.0), Vector3(48.0, 26.0, 48.0))

	var process_material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_material.emission_sphere_radius = 1.6
	process_material.direction = Vector3.UP
	process_material.spread = 62.0
	process_material.initial_velocity_min = 2.8
	process_material.initial_velocity_max = clampf(5.0 + entry_speed * 0.18, 6.0, 12.0)
	process_material.gravity = Vector3(0.0, -2.4, 0.0)
	process_material.scale_min = 0.65
	process_material.scale_max = 1.8
	process_material.color_ramp = _make_gradient_texture([
		Color(0.85, 0.94, 0.96, 0.80),
		Color(0.70, 0.87, 0.91, 0.62),
		Color(0.54, 0.74, 0.81, 0.28),
		Color(0.45, 0.65, 0.72, 0.0)
	])
	plume.process_material = process_material

	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.48, 0.48)
	var foam_material: StandardMaterial3D = StandardMaterial3D.new()
	foam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	foam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	foam_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	foam_material.vertex_color_use_as_albedo = true
	foam_material.albedo_color = Color.WHITE
	quad.material = foam_material
	plume.draw_pass_1 = quad
	_road.add_child(plume)
	plume.restart()
	plume.finished.connect(Callable(plume, "queue_free"))


func _spawn_expanding_ring(world_position: Vector3, ring_index: int, entry_speed: float) -> void:
	var ring: MeshInstance3D = MeshInstance3D.new()
	ring.name = "OceanImpactRing_%02d_%d" % [_splash_serial, ring_index]
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.88
	torus.outer_radius = 1.0
	torus.rings = 72
	torus.ring_segments = 10
	ring.mesh = torus

	var ring_material: StandardMaterial3D = StandardMaterial3D.new()
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.albedo_color = Color(0.68, 0.88, 0.94, 0.52 - float(ring_index) * 0.10)
	ring_material.emission_enabled = true
	ring_material.emission = Color("6da8ba")
	ring_material.emission_energy_multiplier = 0.24
	ring.material_override = ring_material
	_road.add_child(ring)
	ring.global_position = world_position + Vector3.UP * (0.02 + float(ring_index) * 0.025)
	ring.scale = Vector3.ONE * (0.65 + float(ring_index) * 0.22)

	var duration: float = 2.0 + float(ring_index) * 0.46
	var maximum_radius: float = clampf(7.5 + entry_speed * 0.28 + float(ring_index) * 4.0, 10.0, 24.0)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_interval(float(ring_index) * 0.18)
	tween.tween_property(ring, "scale", Vector3.ONE * maximum_radius, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring_material, "albedo_color:a", 0.0, duration).set_trans(Tween.TRANS_QUAD)
	tween.chain().tween_callback(Callable(ring, "queue_free"))


func _play_splash_audio(world_position: Vector3, entry_speed: float) -> void:
	if _splash_stream == null or _road == null:
		return
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.name = "OceanImpactAudio_%02d" % _splash_serial
	player.stream = _splash_stream
	player.global_position = world_position
	player.volume_linear = clampf(0.18 + entry_speed * 0.008, 0.20, 0.48)
	player.pitch_scale = _rng.randf_range(0.82, 0.94)
	player.unit_size = 8.0
	player.max_distance = 95.0
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.bus = "SFX"
	_road.add_child(player)
	player.finished.connect(Callable(player, "queue_free"))
	player.play()


func _build_splash_stream() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 1.45
	var sample_count: int = int(float(sample_rate) * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	var local_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	local_rng.seed = 729104
	for sample_index: int in range(sample_count):
		var time_value: float = float(sample_index) / float(sample_rate)
		var envelope: float = exp(-time_value * 3.4)
		var low_body: float = sin(TAU * (54.0 - time_value * 9.0) * time_value) * exp(-time_value * 5.2)
		var wash_noise: float = local_rng.randf_range(-1.0, 1.0)
		var secondary_noise: float = local_rng.randf_range(-1.0, 1.0) * sin(TAU * 210.0 * time_value)
		var sample_value: float = clampf(
			low_body * 0.54 + wash_noise * envelope * 0.40 + secondary_noise * envelope * 0.13,
			-1.0,
			1.0
		)
		data.encode_s16(sample_index * 2, int(sample_value * 32767.0))

	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream


func _make_gradient_texture(colors: Array[Color]) -> GradientTexture1D:
	var gradient: Gradient = Gradient.new()
	var offsets: PackedFloat32Array = PackedFloat32Array()
	var packed_colors: PackedColorArray = PackedColorArray()
	var denominator: float = float(maxi(1, colors.size() - 1))
	for color_index: int in range(colors.size()):
		offsets.append(float(color_index) / denominator)
		packed_colors.append(colors[color_index])
	gradient.offsets = offsets
	gradient.colors = packed_colors
	var texture: GradientTexture1D = GradientTexture1D.new()
	texture.gradient = gradient
	return texture
