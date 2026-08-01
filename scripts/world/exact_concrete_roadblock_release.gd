extends Node

const BARRIER_COUNT: int = 7
const TARGET_BARRIER_LENGTH: float = 1.88
const MAX_BARRIER_HEIGHT: float = 1.34

var _road: Node3D
var _installed: bool = false


func _ready() -> void:
	set_process(true)


func _process(_delta: float) -> void:
	if _installed:
		set_process(false)
		return
	if _road == null:
		_road = get_parent() as Node3D
	if _road == null:
		return

	var crash_set: Node3D = _road.get_node_or_null("CenteredBridgeCrashSet") as Node3D
	if crash_set == null:
		crash_set = _road.get_node_or_null("BridgeCrashSet") as Node3D
	if crash_set == null:
		return

	_install_exact_roadblocks(crash_set)


func _install_exact_roadblocks(crash_set: Node3D) -> void:
	var test_prototype: Node3D = StartupPreloader.get_roadblock_prototype()
	if test_prototype == null:
		push_error(
			"REQUIRED ROADBLOCK MODEL ERROR: the exact Sketchfab concrete roadblock prototype is unavailable. No substitute barrier was created."
		)
		return
	test_prototype.free()

	var original_barriers: Array[Node] = crash_set.find_children(
		"CenteredRoadblock_*",
		"MeshInstance3D",
		true,
		false
	)
	for node: Node in original_barriers:
		var original_mesh: MeshInstance3D = node as MeshInstance3D
		if original_mesh != null:
			original_mesh.visible = false

	for barrier_index: int in range(BARRIER_COUNT):
		var model: Node3D = StartupPreloader.get_roadblock_prototype()
		if model == null:
			push_error(
				"REQUIRED ROADBLOCK MODEL ERROR: failed to duplicate exact barrier %d." % barrier_index
			)
			return

		var anchor: Node3D = Node3D.new()
		anchor.name = "ExactConcreteRoadblock_%02d" % barrier_index
		anchor.position = Vector3(-6.0 + float(barrier_index) * 2.0, 0.0, 0.0)
		crash_set.add_child(anchor)
		anchor.add_child(model)
		_normalize_roadblock(anchor, model)

		var mesh_nodes: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
		for mesh_node: Node in mesh_nodes:
			var mesh_instance: MeshInstance3D = mesh_node as MeshInstance3D
			if mesh_instance == null:
				continue
			# The working crash-physics director hides every mesh carrying this
			# marker before it spawns the rigid concrete fragments.
			mesh_instance.set_meta("crash_barrier", true)
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	_installed = true
	print("EXACT CONCRETE ROADBLOCK READY: installed 7 scanned Sketchfab barriers.")


func _normalize_roadblock(anchor: Node3D, model: Node3D) -> void:
	model.position = Vector3.ZERO
	model.rotation_degrees = Vector3.ZERO

	var bounds_result: Dictionary = _calculate_bounds(anchor, model)
	if not bool(bounds_result.get("valid", false)):
		push_error("REQUIRED ROADBLOCK MODEL ERROR: the installed scene has no measurable mesh bounds.")
		return

	var bounds: AABB = bounds_result.get("bounds", AABB()) as AABB
	# The row must run across the road on X. Rotate scans authored lengthwise on Z.
	if bounds.size.z > bounds.size.x:
		model.rotation_degrees.y = 90.0
		bounds_result = _calculate_bounds(anchor, model)
		if bool(bounds_result.get("valid", false)):
			bounds = bounds_result.get("bounds", bounds) as AABB

	var horizontal_length: float = maxf(bounds.size.x, bounds.size.z)
	if horizontal_length <= 0.001 or bounds.size.y <= 0.001:
		push_error("REQUIRED ROADBLOCK MODEL ERROR: the installed scan has invalid dimensions.")
		return

	var scale_for_length: float = TARGET_BARRIER_LENGTH / horizontal_length
	var scale_for_height: float = MAX_BARRIER_HEIGHT / bounds.size.y
	var scale_factor: float = minf(scale_for_length, scale_for_height)
	model.scale *= scale_factor

	var center: Vector3 = bounds.get_center()
	model.position = Vector3(
		-center.x * scale_factor,
		-bounds.position.y * scale_factor + 0.02,
		-center.z * scale_factor
	)


func _calculate_bounds(anchor: Node3D, model: Node3D) -> Dictionary:
	var mesh_nodes: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
	var bounds: AABB = AABB()
	var has_bounds: bool = false
	for node: Node in mesh_nodes:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var relative_transform: Transform3D = (
			anchor.global_transform.affine_inverse() * mesh_instance.global_transform
		)
		var mesh_bounds: AABB = relative_transform * mesh_instance.get_aabb()
		if not has_bounds:
			bounds = mesh_bounds
			has_bounds = true
		else:
			bounds = bounds.merge(mesh_bounds)
	return {
		"valid": has_bounds,
		"bounds": bounds
	}
