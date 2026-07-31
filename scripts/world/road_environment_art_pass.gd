extends "res://scripts/world/environment_art_pass.gd"


func _classify_mesh(mesh_instance: MeshInstance3D) -> String:
	var descriptor: String = str(mesh_instance.get_path()).to_lower()
	if descriptor.contains("kenneycc0car"):
		return ""
	return super._classify_mesh(mesh_instance)
