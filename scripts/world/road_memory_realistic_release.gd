extends "res://scripts/world/road_memory_runtime.gd"


func _tint_car_model(model_root: Node3D) -> void:
	super._tint_car_model(model_root)
	var mesh_nodes: Array[Node] = model_root.find_children("*", "MeshInstance3D", true, false)
	for node: Node in mesh_nodes:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var node_descriptor: String = str(mesh_instance.get_path()).to_lower()
		if _is_branding_descriptor(node_descriptor):
			mesh_instance.visible = false
			continue
		for surface_index: int in range(mesh_instance.mesh.get_surface_count()):
			var source_material: Material = mesh_instance.get_active_material(surface_index)
			if source_material == null:
				continue
			var material_descriptor: String = str(source_material.resource_name).to_lower()
			if not _is_branding_descriptor(material_descriptor):
				continue
			var hidden_material: StandardMaterial3D = StandardMaterial3D.new()
			hidden_material.albedo_color = Color(0.0, 0.0, 0.0, 0.0)
			hidden_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mesh_instance.set_surface_override_material(surface_index, hidden_material)


func _is_branding_descriptor(descriptor: String) -> bool:
	return (
		descriptor.contains("khronos")
		or descriptor.contains("gltf")
		or descriptor.contains("logo")
		or descriptor.contains("license")
	)
