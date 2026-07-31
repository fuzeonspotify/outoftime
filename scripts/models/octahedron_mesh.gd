class_name OctahedronMesh
extends SphereMesh

var _mesh_size: float = 1.0

var size: float:
	set(value):
		_mesh_size = maxf(value, 0.05)
		radius = _mesh_size * 0.5
		height = _mesh_size
		radial_segments = 4
		rings = 2
	get:
		return _mesh_size


func _init() -> void:
	radial_segments = 4
	rings = 2
	radius = 0.5
	height = 1.0
