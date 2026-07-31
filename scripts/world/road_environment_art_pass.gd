extends "res://scripts/world/environment_art_pass.gd"

const EXACT_CAR_PATH_MARKERS: Array[String] = [
	"spectralpontiac",
	"porsche911turbo"
]


func _classify_mesh(mesh_instance: MeshInstance3D) -> String:
	var descriptor: String = str(mesh_instance.get_path()).to_lower()
	for marker: String in EXACT_CAR_PATH_MARKERS:
		if descriptor.contains(marker):
			# Never assign a whole-mesh material_override to the Porsche. A
			# material_override wins over every per-surface paint material.
			return ""
	return super._classify_mesh(mesh_instance)


func _decorate_road_memory() -> void:
	# Keep the bridge fixture detailing, but do not run the retired procedural
	# Pontiac builder inside the exact Porsche hierarchy.
	_add_bridge_fixture_details()


func _upgrade_pontiac_model() -> void:
	# Intentionally disabled. The bridge car is exclusively Porsche911Turbo.
	pass
