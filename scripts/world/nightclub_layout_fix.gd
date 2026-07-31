extends Node

const RAMP_ANGLE_DEGREES: float = 21.5


func _ready() -> void:
	call_deferred("_repair_balcony_access")


func _repair_balcony_access() -> void:
	var scene_root: Node3D = get_parent() as Node3D
	if scene_root == null:
		return

	_remove_broken_stair_geometry(scene_root)
	_remove_stairway_clutter(scene_root)
	_build_clear_balcony_route(scene_root)


func _remove_broken_stair_geometry(scene_root: Node3D) -> void:
	var children: Array[Node] = scene_root.get_children()
	for child: Node in children:
		var body: StaticBody3D = child as StaticBody3D
		if body == null:
			continue

		var node_name: String = str(body.name)
		if node_name == "BalconyFloor" or node_name.begins_with("BalconyStairs"):
			body.queue_free()
			continue

		var blocks_stairway: bool = (
			node_name.begins_with("RightColumn")
			and body.position.x > 11.0
			and body.position.z > -8.0
			and body.position.z < 6.0
		)
		if blocks_stairway:
			body.queue_free()


func _remove_stairway_clutter(scene_root: Node3D) -> void:
	var visual_nodes: Array[Node] = scene_root.find_children("Debris*", "MeshInstance3D", true, false)
	for node: Node in visual_nodes:
		var debris: MeshInstance3D = node as MeshInstance3D
		if debris == null:
			continue
		var inside_route: bool = (
			debris.position.x > 9.0
			and debris.position.x < 17.0
			and debris.position.z > -9.0
			and debris.position.z < 7.0
		)
		if inside_route:
			debris.queue_free()


func _build_clear_balcony_route(scene_root: Node3D) -> void:
	_create_static_box(
		scene_root,
		"RebuiltBalconyFloor",
		Vector3(12.5, 4.10, -12.0),
		Vector3(9.0, 0.50, 14.0),
		Color("16101d")
	)

	var ramp: StaticBody3D = _create_static_box(
		scene_root,
		"BalconyAccessRamp",
		Vector3(13.0, 2.15, -0.5),
		Vector3(6.2, 0.48, 12.0),
		Color("21152a")
	)
	ramp.rotation_degrees.x = RAMP_ANGLE_DEGREES

	_create_static_box(
		scene_root,
		"BalconyLanding",
		Vector3(13.0, 4.08, -6.4),
		Vector3(6.2, 0.46, 3.0),
		Color("24172d")
	)

	_create_visual_box(
		scene_root,
		"RampLeftEdge",
		Vector3(9.86, 2.55, -0.5),
		Vector3(0.12, 0.22, 12.0),
		Color("9c4dba"),
		RAMP_ANGLE_DEGREES
	)
	_create_visual_box(
		scene_root,
		"RampRightEdge",
		Vector3(16.14, 2.55, -0.5),
		Vector3(0.12, 0.22, 12.0),
		Color("e24a9b"),
		RAMP_ANGLE_DEGREES
	)

	_create_visual_box(
		scene_root,
		"LandingGuideLight",
		Vector3(13.0, 4.39, -6.5),
		Vector3(5.4, 0.05, 1.8),
		Color("6f3d8e")
	)

	_create_static_box(
		scene_root,
		"RelocatedRightSupport",
		Vector3(16.6, 3.0, -1.0),
		Vector3(0.65, 6.0, 0.65),
		Color("211329")
	)


func _create_static_box(
	parent: Node3D,
	node_name: String,
	box_position: Vector3,
	box_size: Vector3,
	color: Color
) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = node_name
	body.position = box_position

	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = box_size
	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = _make_material(color)
	body.add_child(visual)

	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = box_size
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)

	parent.add_child(body)
	return body


func _create_visual_box(
	parent: Node3D,
	node_name: String,
	box_position: Vector3,
	box_size: Vector3,
	color: Color,
	x_rotation_degrees: float = 0.0
) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = box_size
	var material: StandardMaterial3D = _make_material(color)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.55

	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = box_position
	instance.rotation_degrees.x = x_rotation_degrees
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _make_material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	return material
