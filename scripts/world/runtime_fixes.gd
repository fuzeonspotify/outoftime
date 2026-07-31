extends Node


func _ready() -> void:
	call_deferred("_apply_runtime_fixes")


func _apply_runtime_fixes() -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return

	var labels: Array[Node] = parent_node.find_children("*", "Label3D", true, false)
	for node: Node in labels:
		var label: Label3D = node as Label3D
		if label != null and label.text.contains("RAN OUT OF TIME"):
			label.rotation_degrees = Vector3.ZERO
