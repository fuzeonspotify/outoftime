extends Node


func _ready() -> void:
	_apply_alignment.call_deferred()


func _apply_alignment() -> void:
	var scene_root: Node = get_parent()
	if scene_root == null:
		return

	var labels: Array[Node] = scene_root.find_children("*", "Label3D", true, false)
	for node: Node in labels:
		var label: Label3D = node as Label3D
		if label != null and label.text.contains("RAN OUT OF TIME"):
			label.rotation_degrees = Vector3.ZERO
