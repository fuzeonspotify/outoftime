extends "res://scripts/world/bridge_realistic_ocean.gd"

const WAKE_INTERVAL: float = 0.13
const WAKE_MAX_SECONDS: float = 6.5

var _wake_accumulators: Dictionary = {}
var _entry_directions: Dictionary = {}


func _update_physical_car_water(body: RigidBody3D, delta: float) -> void:
	super._update_physical_car_water(body, delta)
	if body == null or not is_instance_valid(body):
		return
	if not has_body_entered_water(body):
		return

	var body_id: int = body.get_instance_id()
	var water_time: float = get_body_water_time(body)
	if water_time > WAKE_MAX_SECONDS:
		return
	var planar_velocity: Vector3 = Vector3(
		body.linear_velocity.x,
		0.0,
		body.linear_velocity.z
	)
	var planar_speed: float = planar_velocity.length()
	if planar_speed < 1.2:
		return

	var accumulator: float = float(_wake_accumulators.get(body_id, 0.0)) + delta
	if accumulator >= WAKE_INTERVAL:
		accumulator = fmod(accumulator, WAKE_INTERVAL)
		var travel_direction: Vector3 = planar_velocity.normalized()
		var wake_position: Vector3 = body.global_position - travel_direction * 1.45
		wake_position.y = get_surface_height(wake_position) + 0.055
		_spawn_wake_foam_patch(wake_position, travel_direction, planar_speed)
	_wake_accumulators[body_id] = accumulator


func _register_water_entry(body: RigidBody3D, surface_height: float) -> void:
	var body_id: int = body.get_instance_id()
	var entry_velocity: Vector3 = body.linear_velocity
	var entry_speed: float = entry_velocity.length()
	_water_entry_times[body_id] = 0.0
	_water_entry_speeds[body_id] = entry_speed
	_wake_accumulators[body_id] = 0.0
	body.set_meta("ocean_entered", true)
	body.set_meta("ocean_entry_speed", entry_speed)

	var planar_direction: Vector3 = Vector3(
		entry_velocity.x,
		0.0,
		entry_velocity.z
	)
	if planar_direction.length_squared() <= 0.0001:
		planar_direction = -body.global_basis.z
		planar_direction.y = 0.0
	if planar_direction.length_squared() <= 0.0001:
		planar_direction = Vector3(0.0, 0.0, -1.0)
	planar_direction = planar_direction.normalized()
	_entry_directions[body_id] = planar_direction

	# Water removes momentum primarily opposite the actual entry velocity. The
	# upward impulse is tied to vertical entry speed rather than a fixed bounce.
	var resistance_ratio: float = clampf(entry_speed / 42.0, 0.20, 0.50)
	body.apply_central_impulse(-entry_velocity * body.mass * resistance_ratio)
	var downward_speed: float = maxf(-entry_velocity.y, 0.0)
	body.apply_central_impulse(
		Vector3.UP * body.mass * clampf(0.55 + downward_speed * 0.12, 0.55, 2.35)
	)
	var pitch_axis: Vector3 = planar_direction.cross(Vector3.UP).normalized()
	body.apply_torque_impulse(
		pitch_axis * body.mass * clampf(entry_speed * 0.025, 0.28, 1.05)
	)

	var impact_position: Vector3 = body.global_position
	impact_position.y = surface_height + 0.06
	_spawn_realistic_vehicle_splash(impact_position, entry_velocity)
	print(
		"PORSCHE REALISTIC OCEAN IMPACT: entered at ",
		impact_position,
		" with velocity ",
		entry_velocity
	)


func _spawn_major_splash(world_position: Vector3, entry_speed: float) -> void:
	# Compatibility path for any external caller that only knows impact speed.
	_spawn_realistic_vehicle_splash(
		world_position,
		Vector3(0.0, -entry_speed * 0.72, -entry_speed * 0.68)
	)


func _spawn_realistic_vehicle_splash(
	world_position: Vector3,
	entry_velocity: Vector3
) -> void:
	_splash_serial += 1
	var entry_speed: float = entry_velocity.length()
	var planar_direction: Vector3 = Vector3(
		entry_velocity.x,
		0.0,
		entry_velocity.z
	)
	if planar_direction.length_squared() <= 0.0001:
		planar_direction = Vector3(0.0, 0.0, -1.0)
	planar_direction = planar_direction.normalized()
	var lateral: Vector3 = Vector3.UP.cross(planar_direction).normalized()

	_spawn_impact_cavity(world_position, planar_direction, entry_speed)
	_spawn_splash_curtain(
		world_position,
		planar_direction,
		128.0,
		clampf(3.6 + entry_speed * 0.085, 4.3, 7.2),
		clampf(3.0 + entry_speed * 0.075, 3.6, 6.1),
		0
	)
	_spawn_splash_curtain(
		world_position,
		(planar_direction * 0.42 + lateral * 0.90).normalized(),
		78.0,
		clampf(2.8 + entry_speed * 0.060, 3.2, 5.2),
		clampf(2.5 + entry_speed * 0.055, 2.9, 4.7),
		1
	)
	_spawn_splash_curtain(
		world_position,
		(planar_direction * 0.42 - lateral * 0.90).normalized(),
		78.0,
		clampf(2.8 + entry_speed * 0.060, 3.2, 5.2),
		clampf(2.5 + entry_speed * 0.055, 2.9, 4.7),
		2
	)

	_spawn_directional_droplet_emitter(
		world_position,
		(planar_direction * 0.62 + Vector3.UP * 0.78).normalized(),
		int(clampf(145.0 + entry_speed * 3.0, 170.0, 290.0)),
		clampf(10.0 + entry_speed * 0.30, 13.0, 22.0),
		31.0,
		"Bow"
	)
	_spawn_directional_droplet_emitter(
		world_position,
		(lateral * 0.78 + Vector3.UP * 0.62 + planar_direction * 0.20).normalized(),
		int(clampf(90.0 + entry_speed * 1.8, 110.0, 190.0)),
		clampf(8.0 + entry_speed * 0.22, 10.0, 17.0),
		26.0,
		"Port"
	)
	_spawn_directional_droplet_emitter(
		world_position,
		(-lateral * 0.78 + Vector3.UP * 0.62 + planar_direction * 0.20).normalized(),
		int(clampf(90.0 + entry_speed * 1.8, 110.0, 190.0)),
		clampf(8.0 + entry_speed * 0.22, 10.0, 17.0),
		26.0,
		"Starboard"
	)
	_spawn_directional_droplet_emitter(
		world_position,
		(Vector3.UP * 0.94 - planar_direction * 0.18).normalized(),
		int(clampf(70.0 + entry_speed * 1.3, 85.0, 145.0)),
		clampf(7.0 + entry_speed * 0.18, 8.5, 14.0),
		38.0,
		"Vertical"
	)
	_spawn_aerated_whitewater(world_position, planar_direction, entry_speed)

	for ring_index: int in range(4):
		_spawn_irregular_wave_front(
			world_position,
			planar_direction,
			ring_index,
			entry_speed
		)
	_play_splash_audio(world_position, entry_speed)


func _spawn_impact_cavity(
	world_position: Vector3,
	travel_direction: Vector3,
	entry_speed: float
) -> void:
	var cavity: MeshInstance3D = MeshInstance3D.new()
	cavity.name = "OceanImpactCavity_%02d" % _splash_serial
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.025
	disc.radial_segments = 64
	cavity.mesh = disc
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.005, 0.025, 0.040, 0.72)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	cavity.material_override = material
	_road.add_child(cavity)
	cavity.global_position = world_position - Vector3.UP * 0.045
	cavity.rotation.y = atan2(travel_direction.x, travel_direction.z)
	cavity.scale = Vector3(0.75, 1.0, 0.48)

	var size_factor: float = clampf(2.6 + entry_speed * 0.105, 3.4, 6.2)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(
		cavity,
		"scale",
		Vector3(size_factor, 1.0, size_factor * 0.68),
		0.32
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, 1.15).set_delay(0.16)
	tween.chain().tween_callback(Callable(cavity, "queue_free"))

	var crown: MeshInstance3D = MeshInstance3D.new()
	crown.name = "OceanImpactCavityCrown_%02d" % _splash_serial
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.76
	torus.outer_radius = 1.0
	torus.rings = 72
	torus.ring_segments = 12
	crown.mesh = torus
	var crown_material: StandardMaterial3D = StandardMaterial3D.new()
	crown_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	crown_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	crown_material.albedo_color = Color(0.78, 0.92, 0.95, 0.72)
	crown_material.emission_enabled = true
	crown_material.emission = Color("a7d7df")
	crown_material.emission_energy_multiplier = 0.12
	crown.material_override = crown_material
	_road.add_child(crown)
	crown.global_position = world_position + Vector3.UP * 0.025
	crown.rotation.y = cavity.rotation.y
	crown.scale = Vector3(0.72, 0.16, 0.50)
	var crown_tween: Tween = create_tween().set_parallel(true)
	crown_tween.tween_property(
		crown,
		"scale",
		Vector3(size_factor * 1.08, 0.08, size_factor * 0.76),
		0.82
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	crown_tween.tween_property(crown_material, "albedo_color:a", 0.0, 0.96)
	crown_tween.chain().tween_callback(Callable(crown, "queue_free"))


func _spawn_splash_curtain(
	world_position: Vector3,
	curtain_direction: Vector3,
	arc_degrees: float,
	curtain_height: float,
	curtain_radius: float,
	curtain_index: int
) -> void:
	var curtain: MeshInstance3D = MeshInstance3D.new()
	curtain.name = "VehicleSplashCurtain_%02d_%d" % [_splash_serial, curtain_index]
	curtain.mesh = _build_curtain_mesh(
		curtain_direction,
		arc_degrees,
		curtain_height,
		curtain_radius
	)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color(0.72, 0.90, 0.96, 0.88)
	material.emission_enabled = true
	material.emission = Color("79aebe")
	material.emission_energy_multiplier = 0.08
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	curtain.material_override = material
	curtain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_road.add_child(curtain)
	curtain.global_position = world_position
	curtain.scale = Vector3(0.68, 0.52, 0.68)

	var duration: float = 0.92 + float(curtain_index) * 0.10
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(
		curtain,
		"scale",
		Vector3(1.28, 1.08, 1.28),
		duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, duration).set_delay(0.18)
	tween.chain().tween_callback(Callable(curtain, "queue_free"))


func _build_curtain_mesh(
	curtain_direction: Vector3,
	arc_degrees: float,
	curtain_height: float,
	curtain_radius: float
) -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()
	var segments: int = 28
	var direction_2d: Vector2 = Vector2(curtain_direction.x, curtain_direction.z).normalized()
	for segment_index: int in range(segments + 1):
		var progress: float = float(segment_index) / float(segments)
		var angle: float = deg_to_rad(lerpf(-arc_degrees * 0.5, arc_degrees * 0.5, progress))
		var ray: Vector2 = direction_2d.rotated(angle)
		var arch: float = pow(maxf(sin(progress * PI), 0.0), 0.62)
		var lower_radius: float = 0.46 + arch * 0.20
		var upper_radius: float = curtain_radius * (0.70 + arch * 0.30)
		vertices.append(Vector3(ray.x * lower_radius, 0.02, ray.y * lower_radius))
		colors.append(Color(0.82, 0.95, 1.0, 0.74))
		vertices.append(Vector3(
			ray.x * upper_radius,
			0.42 + curtain_height * arch,
			ray.y * upper_radius
		))
		colors.append(Color(0.66, 0.88, 0.95, 0.04 + arch * 0.12))

	for segment_index: int in range(segments):
		var base_index: int = segment_index * 2
		indices.append(base_index)
		indices.append(base_index + 1)
		indices.append(base_index + 2)
		indices.append(base_index + 2)
		indices.append(base_index + 1)
		indices.append(base_index + 3)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _spawn_directional_droplet_emitter(
	world_position: Vector3,
	emission_direction: Vector3,
	particle_count: int,
	maximum_velocity: float,
	spread_degrees: float,
	label: String
) -> void:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.name = "VehicleSplash%s_%02d" % [label, _splash_serial]
	particles.one_shot = true
	particles.amount = particle_count
	particles.lifetime = 2.65
	particles.explosiveness = 1.0
	particles.randomness = 0.58
	particles.fixed_fps = 48
	particles.local_coords = false
	particles.visibility_aabb = AABB(
		Vector3(-34.0, -10.0, -34.0),
		Vector3(68.0, 48.0, 68.0)
	)

	var process_material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_material.emission_sphere_radius = 1.15
	process_material.direction = emission_direction
	process_material.spread = spread_degrees
	process_material.initial_velocity_min = maximum_velocity * 0.46
	process_material.initial_velocity_max = maximum_velocity
	process_material.gravity = Vector3(0.0, -15.8, 0.0)
	process_material.scale_min = 0.52
	process_material.scale_max = 1.72
	process_material.color_ramp = _make_gradient_texture([
		Color(0.80, 0.95, 1.0, 0.98),
		Color(0.55, 0.82, 0.92, 0.88),
		Color(0.28, 0.61, 0.77, 0.48),
		Color(0.15, 0.40, 0.56, 0.0)
	])
	particles.process_material = process_material

	var droplet_mesh: SphereMesh = SphereMesh.new()
	droplet_mesh.radius = 0.042
	droplet_mesh.height = 0.24
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color.WHITE
	material.roughness = 0.08
	droplet_mesh.material = material
	particles.draw_pass_1 = droplet_mesh
	_road.add_child(particles)
	particles.global_position = world_position
	particles.restart()
	particles.finished.connect(Callable(particles, "queue_free"))


func _spawn_aerated_whitewater(
	world_position: Vector3,
	travel_direction: Vector3,
	entry_speed: float
) -> void:
	var foam: GPUParticles3D = GPUParticles3D.new()
	foam.name = "AeratedVehicleWhitewater_%02d" % _splash_serial
	foam.one_shot = true
	foam.amount = int(clampf(190.0 + entry_speed * 3.2, 220.0, 360.0))
	foam.lifetime = 3.6
	foam.explosiveness = 0.94
	foam.randomness = 0.84
	foam.local_coords = false
	foam.visibility_aabb = AABB(
		Vector3(-28.0, -8.0, -28.0),
		Vector3(56.0, 34.0, 56.0)
	)
	var process_material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_material.emission_sphere_radius = 1.85
	process_material.direction = (Vector3.UP * 0.90 + travel_direction * 0.24).normalized()
	process_material.spread = 66.0
	process_material.initial_velocity_min = 2.4
	process_material.initial_velocity_max = clampf(6.8 + entry_speed * 0.16, 7.5, 12.5)
	process_material.gravity = Vector3(0.0, -3.1, 0.0)
	process_material.scale_min = 0.62
	process_material.scale_max = 2.2
	process_material.color_ramp = _make_gradient_texture([
		Color(0.92, 0.97, 0.98, 0.90),
		Color(0.78, 0.91, 0.94, 0.76),
		Color(0.57, 0.77, 0.82, 0.34),
		Color(0.42, 0.64, 0.70, 0.0)
	])
	foam.process_material = process_material

	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.56, 0.56)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color.WHITE
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	quad.material = material
	foam.draw_pass_1 = quad
	_road.add_child(foam)
	foam.global_position = world_position + Vector3.UP * 0.18
	foam.restart()
	foam.finished.connect(Callable(foam, "queue_free"))


func _spawn_irregular_wave_front(
	world_position: Vector3,
	travel_direction: Vector3,
	ring_index: int,
	entry_speed: float
) -> void:
	var ring: MeshInstance3D = MeshInstance3D.new()
	ring.name = "IrregularImpactWave_%02d_%d" % [_splash_serial, ring_index]
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.86
	torus.outer_radius = 1.0
	torus.rings = 88
	torus.ring_segments = 10
	ring.mesh = torus
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(
		0.68,
		0.87,
		0.91,
		0.46 - float(ring_index) * 0.075
	)
	material.emission_enabled = true
	material.emission = Color("6d9fac")
	material.emission_energy_multiplier = 0.10
	ring.material_override = material
	_road.add_child(ring)
	ring.global_position = world_position + Vector3.UP * (0.025 + float(ring_index) * 0.018)
	ring.rotation.y = atan2(travel_direction.x, travel_direction.z) + _rng.randf_range(-0.18, 0.18)
	var start_scale: float = 0.56 + float(ring_index) * 0.20
	ring.scale = Vector3(start_scale, 0.10, start_scale * _rng.randf_range(0.68, 0.88))

	var delay: float = float(ring_index) * 0.16
	var duration: float = 1.9 + float(ring_index) * 0.48
	var maximum_radius: float = clampf(
		7.0 + entry_speed * 0.24 + float(ring_index) * 3.7,
		9.0,
		23.0
	)
	var width_ratio: float = _rng.randf_range(0.66, 0.88)
	var tween: Tween = create_tween()
	tween.tween_interval(delay)
	tween.set_parallel(true)
	tween.tween_property(
		ring,
		"scale",
		Vector3(maximum_radius, 0.035, maximum_radius * width_ratio),
		duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, duration)
	tween.chain().tween_callback(Callable(ring, "queue_free"))


func _spawn_wake_foam_patch(
	world_position: Vector3,
	travel_direction: Vector3,
	planar_speed: float
) -> void:
	var patch: MeshInstance3D = MeshInstance3D.new()
	patch.name = "PorscheWakeFoam"
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.52
	torus.outer_radius = 1.0
	torus.rings = 44
	torus.ring_segments = 8
	patch.mesh = torus
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.76, 0.90, 0.92, 0.34)
	material.emission_enabled = true
	material.emission = Color("7ba4ad")
	material.emission_energy_multiplier = 0.06
	patch.material_override = material
	_road.add_child(patch)
	patch.global_position = world_position
	patch.rotation.y = atan2(travel_direction.x, travel_direction.z) + _rng.randf_range(-0.10, 0.10)
	var length_scale: float = clampf(0.85 + planar_speed * 0.045, 0.95, 1.85)
	patch.scale = Vector3(length_scale, 0.045, _rng.randf_range(0.34, 0.54))

	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(
		patch,
		"scale",
		Vector3(length_scale * 1.65, 0.025, patch.scale.z * 1.45),
		1.55
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, 1.55)
	tween.chain().tween_callback(Callable(patch, "queue_free"))
