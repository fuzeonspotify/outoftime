extends Node

const CABLE_HIDE_DISTANCE: float = 34.0
const DEFAULT_CAMERA_DISTANCE: float = 7.4

var _bridge_cables: Array[MeshInstance3D] = []
var _car: Node3D


func _ready() -> void:
	SFXDirector.start_pontiac_ambience()
	call_deferred("_configure_bridge_scene")


func _process(_delta: float) -> void:
	if _car == null:
		return

	for cable: MeshInstance3D in _bridge_cables:
		if not is_instance_valid(cable):
			continue
		var distance_from_car: float = absf(cable.global_position.z - _car.global_position.z)
		cable.visible = distance_from_car >= CABLE_HIDE_DISTANCE


func _exit_tree() -> void:
	SFXDirector.stop_environment(0.45)


func _configure_bridge_scene() -> void:
	var scene_root: Node = get_parent()
	if scene_root == null:
		return

	scene_root.set("_camera_distance", DEFAULT_CAMERA_DISTANCE)
	scene_root.set("_camera_target_distance", DEFAULT_CAMERA_DISTANCE)
	_car = scene_root.get_node_or_null("SpectralPontiac") as Node3D
	var camera: Camera3D = scene_root.get_node_or_null("SpectralPontiac/Camera3D") as Camera3D
	if camera != null:
		camera.position.z = DEFAULT_CAMERA_DISTANCE

	var mesh_nodes: Array[Node] = scene_root.find_children("*", "MeshInstance3D", true, false)
	for node: Node in mesh_nodes:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance == null:
			continue

		var box_mesh: BoxMesh = mesh_instance.mesh as BoxMesh
		if box_mesh == null:
			continue

		var box_size: Vector3 = box_mesh.size
		var is_bridge_cable: bool = box_size.x >= 8.0 and box_size.y <= 0.06 and box_size.z <= 0.06
		if not is_bridge_cable:
			continue

		_bridge_cables.append(mesh_instance)
		var source_material: StandardMaterial3D = mesh_instance.material_override as StandardMaterial3D
		if source_material == null:
			continue

		var muted_material: StandardMaterial3D = source_material.duplicate() as StandardMaterial3D
		if muted_material == null:
			continue
		muted_material.albedo_color = Color("25283a")
		muted_material.emission_enabled = false
		muted_material.roughness = 0.78
		muted_material.metallic = 0.05
		mesh_instance.material_override = muted_material
