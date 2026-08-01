extends "res://scripts/world/bridge_realistic_ocean_release.gd"


func _ready() -> void:
	# Child _ready() callbacks can run while the RoadMemory root is still adding
	# its procedural children. Delay every ocean add_child() until that setup has
	# completed, rather than attempting to mutate the busy parent immediately.
	set_physics_process(false)
	_rng.randomize()
	_wave_time = float(Time.get_ticks_msec()) * 0.001
	_road = get_parent() as Node3D
	if _road == null:
		push_error("REALISTIC OCEAN ERROR: the bridge scene root is unavailable.")
		return
	_finish_safe_ocean_setup.call_deferred()


func _finish_safe_ocean_setup() -> void:
	# One additional rendered frame protects against other deferred RoadMemory
	# construction passes that run immediately after the scene enters the tree.
	await get_tree().process_frame
	if _road == null or not is_instance_valid(_road):
		return

	_build_ocean_surface()
	_build_surface_mist()
	_build_underwater_fog()
	_remove_legacy_water()
	_enhance_bridge_environment()
	_splash_stream = _build_splash_stream()
	set_physics_process(true)

	print(
		"REALISTIC BRIDGE OCEAN READY: ",
		OCEAN_SIZE,
		" meter wave surface with ",
		OCEAN_SUBDIVISIONS,
		" x ",
		OCEAN_SUBDIVISIONS,
		" displacement grid at Y=",
		WATER_LEVEL,
		" (deferred safe setup with upgraded vehicle splash)"
	)
