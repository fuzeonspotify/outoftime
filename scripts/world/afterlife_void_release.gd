extends "res://scripts/world/afterlife_void.gd"


func _update_checkpoint() -> void:
	var player_z: float = _player.position.z
	if player_z < -112.0:
		_checkpoint_position = Vector3(4.3, 0.5, -111.0)
	elif player_z < -96.0:
		_checkpoint_position = Vector3(0.0, 0.4, -94.0)
	elif player_z < -70.0:
		_checkpoint_position = Vector3(6.4, 7.7, -69.0)
	elif player_z < -46.0:
		_checkpoint_position = Vector3(0.0, 1.5, -44.0)
	elif player_z < -3.0:
		_checkpoint_position = Vector3(0.0, 12.45, -6.0)
	elif player_z < 36.0:
		_checkpoint_position = Vector3(0.0, 1.7, 38.0)


func _create_gravity_anchor(
	anchor_id: String,
	anchor_position: Vector3,
	prompt: String,
	message: String,
	color: Color
) -> void:
	var root: Node3D = Node3D.new()
	root.name = "GravityAnchor_%s" % anchor_id
	root.position = anchor_position
	root.set_meta("rotation_speed", 15.0)
	add_child(root)
	_rotating_nodes.append(root)
	_anchor_visuals[anchor_id] = root

	var core_mesh: SphereMesh = SphereMesh.new()
	core_mesh.radius = 0.75
	core_mesh.height = 1.5
	core_mesh.radial_segments = 4
	core_mesh.rings = 2
	var core: MeshInstance3D = _add_visual_mesh(
		root,
		core_mesh,
		Vector3.ZERO,
		_make_emissive_material(color, 2.1, 0.36)
	)
	core.rotation_degrees = Vector3(0.0, 45.0, 45.0)

	for ring_index: int in range(3):
		var ring_mesh: TorusMesh = TorusMesh.new()
		ring_mesh.inner_radius = 1.15 + float(ring_index) * 0.32
		ring_mesh.outer_radius = ring_mesh.inner_radius + 0.08
		var ring: MeshInstance3D = _add_visual_mesh(
			root,
			ring_mesh,
			Vector3.ZERO,
			_make_emissive_material(color.lightened(0.10), 1.25, 0.45)
		)
		ring.rotation_degrees = Vector3(float(ring_index) * 33.0, 90.0, float(ring_index) * 17.0)

	var interaction: Area3D = _create_interaction(
		"AnchorInteraction_%s" % anchor_id,
		anchor_position - Vector3(0.0, 1.0, 0.0),
		Vector3(4.8, 4.8, 4.8),
		prompt,
		message,
		true
	)
	interaction.connect("activated", Callable(self, "_on_anchor_activated").bind(anchor_id))
