extends "res://scripts/world/road_memory_final_cut.gd"

const REQUIRED_CAR_NODE_NAME: String = "Porsche911Turbo"
const METALLIC_RED: Color = Color("d0182b")
const BODY_MATERIAL_NAMES: Array[String] = [
	"material.005",
	"material_005",
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
	var primary_body_mesh: MeshInstance3D
	var largest_surface_count: int = -1

	# In this Porsche GLB the main shell is surface 0 of the mesh containing
	# all nine vehicle materials. Find that mesh structurally instead of relying
	# only on an importer-generated material class or name.
	for node: Node in mesh_nodes:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var surface_count: int = mesh_instance.mesh.get_surface_count()
		if surface_count > largest_surface_count:
			largest_surface_count = surface_count
			primary_body_mesh = mesh_instance

	var painted_surfaces: int = 0
	if primary_body_mesh != null and largest_surface_count > 0:
		if _apply_metallic_red(primary_body_mesh, 0):
			painted_surfaces += 1

	# Also cover body surfaces by material semantics in case a later textured GLB
	# splits the shell into multiple surfaces.
	for node: Node in mesh_nodes:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		for surface_index: int in range(mesh_instance.mesh.get_surface_count()):
			if mesh_instance == primary_body_mesh and surface_index == 0:
				continue
			var source_material: Material = mesh_instance.get_active_material(surface_index)
			var source_base: BaseMaterial3D = source_material as BaseMaterial3D
			if source_base == null or source_base.emission_enabled:
				continue
			var material_name: String = str(source_material.resource_name).to_lower()
			var source_color: Color = source_base.albedo_color
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
			if _apply_metallic_red(mesh_instance, surface_index):
				painted_surfaces += 1

	if painted_surfaces == 0:
		push_error("PORSCHE PAINT ERROR: the main shell surface could not be overridden.")


func _apply_metallic_red(mesh_instance: MeshInstance3D, surface_index: int) -> bool:
	var source_material: Material = mesh_instance.get_active_material(surface_index)
	var painted_material: BaseMaterial3D
	if source_material != null:
		painted_material = source_material.duplicate() as BaseMaterial3D
	if painted_material == null:
		painted_material = StandardMaterial3D.new()

	painted_material.albedo_color = METALLIC_RED
	painted_material.metallic = 1.0
	painted_material.roughness = 0.16
	mesh_instance.set_surface_override_material(surface_index, painted_material)
	return true


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
