extends "res://scripts/world/road_memory_final_cut.gd"

const REQUIRED_CAR_NODE_NAME: String = "Porsche911Turbo"
const METALLIC_RED: Color = Color("98141f")
const BODY_MATERIAL_NAMES: Array[String] = [
	"material.005",
	"carpaint",
	"car_paint",
	"bodypaint",
	"body_paint",
	"exteriorpaint",
	"exterior_paint"
]
const LEGACY_CAR_NODE_NAMES: Array[String] = [
	"ModeledPontiacFallback",
	"KenneyCC0Car",
	"ExternalPontiac",
	"ProceduralPontiac"
]


func _ready() -> void:
	super._ready()
	_enforce_exact_car_only.call_deferred()


func _build_car() -> void:
	_remove_existing_bridge_car()

	var prototype: Node3D = StartupPreloader.get_car_prototype()
	if prototype == null:
		push_error("REQUIRED MODEL ERROR: assets/models/cars/porsche_911_turbo.glb did not load. No substitute vehicle will be created.")
		return

	_car = Node3D.new()
	_car.name = "SpectralPontiac"
	_car.position = Vector3(0.0, 0.04, 8.0)
	add_child(_car)

	_real_car_visual = prototype.duplicate() as Node3D
	if _real_car_visual == null:
		_car.queue_free()
		_car = null
		push_error("REQUIRED MODEL ERROR: the Porsche prototype could not be duplicated. No substitute vehicle will be created.")
		return

	_real_car_visual.name = REQUIRED_CAR_NODE_NAME
	_car.add_child(_real_car_visual)
	_normalize_car_model(_real_car_visual)
	# The supplied Porsche faces positive Z. Bridge travel is toward negative Z.
	_real_car_visual.rotation_degrees.y = 180.0
	_paint_car_metallic_red(_real_car_visual)
	_add_car_lighting()
	_add_car_camera()
	_purge_non_porsche_geometry()


func _paint_car_metallic_red(model_root: Node3D) -> void:
	var mesh_nodes: Array[Node] = model_root.find_children("*", "MeshInstance3D", true, false)
	var painted_surfaces: int = 0
	for node: Node in mesh_nodes:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		for surface_index: int in range(mesh_instance.mesh.get_surface_count()):
			var source_material: Material = mesh_instance.get_active_material(surface_index)
			var source_standard: StandardMaterial3D = source_material as StandardMaterial3D
			if source_standard == null or source_standard.emission_enabled:
				continue
			var material_name: String = str(source_standard.resource_name).to_lower()
			var source_color: Color = source_standard.albedo_color
			var known_body_material: bool = BODY_MATERIAL_NAMES.has(material_name)
			var semantic_body_material: bool = (
				material_name.contains("paint")
				or material_name.contains("body")
				or material_name.contains("exterior")
				or material_name.contains("shell")
			)
			var red_dominant_surface: bool = (
				source_color.r > 0.18
				and source_color.r > source_color.g * 2.0
				and source_color.r > source_color.b * 2.0
			)
			if not known_body_material and not semantic_body_material and not red_dominant_surface:
				continue

			var painted_material: StandardMaterial3D = source_standard.duplicate() as StandardMaterial3D
			if painted_material == null:
				continue
			# Keep any supplied texture detail and tint it with the requested paint.
			painted_material.albedo_color = METALLIC_RED
			painted_material.metallic = 0.92
			painted_material.roughness = 0.18
			mesh_instance.set_surface_override_material(surface_index, painted_material)
			painted_surfaces += 1

	if painted_surfaces == 0:
		push_error("PORSCHE PAINT ERROR: no body-paint surface was identified; glass, tires, and lights were left unchanged.")


func _remove_existing_bridge_car() -> void:
	var existing_cars: Array[Node] = find_children("SpectralPontiac", "Node3D", false, false)
	for node: Node in existing_cars:
		var existing_car: Node3D = node as Node3D
		if existing_car == null:
			continue
		existing_car.visible = false
		existing_car.queue_free()


func _enforce_exact_car_only() -> void:
	# Older presentation/model helpers can run several frames after the road scene.
	# Purge them after every likely deferred installation window.
	for _frame_index: int in range(24):
		await get_tree().process_frame
		_purge_non_porsche_geometry()


func _purge_non_porsche_geometry() -> void:
	if _car == null or not is_instance_valid(_car):
		return
	if _real_car_visual == null or not is_instance_valid(_real_car_visual):
		return

	# Remove known retired model roots immediately.
	for legacy_name: String in LEGACY_CAR_NODE_NAMES:
		var legacy_nodes: Array[Node] = _car.find_children(legacy_name, "Node3D", true, false)
		for node: Node in legacy_nodes:
			var legacy_visual: Node3D = node as Node3D
			if legacy_visual == null or legacy_visual == _real_car_visual:
				continue
			legacy_visual.visible = false
			legacy_visual.queue_free()

	# The Porsche is the only hierarchy allowed to contribute car geometry.
	var mesh_nodes: Array[Node] = _car.find_children("*", "MeshInstance3D", true, false)
	for node: Node in mesh_nodes:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance == null:
			continue
		if _real_car_visual == mesh_instance or _real_car_visual.is_ancestor_of(mesh_instance):
			continue
		mesh_instance.visible = false
		mesh_instance.queue_free()

	# Remove any remaining top-level retired visual roots while preserving only
	# the required Porsche, camera, and lights.
	var car_children: Array[Node] = _car.get_children()
	for child: Node in car_children:
		if child == _real_car_visual or child is Camera3D or child is Light3D:
			continue
		var child_3d: Node3D = child as Node3D
		if child_3d == null:
			continue
		child_3d.visible = false
		child_3d.queue_free()
