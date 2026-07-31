extends Node

var _copy_updated: bool = false


func _process(_delta: float) -> void:
	if _copy_updated:
		return

	var scene_root: Node = get_parent()
	if scene_root == null:
		return

	var button_updated: bool = false
	var note_updated: bool = false
	var buttons: Array[Node] = scene_root.find_children("*", "Button", true, false)
	for node: Node in buttons:
		var button: Button = node as Button
		if button == null:
			continue
		if button.text == "ENTER THE CITY":
			button.text = "ENTER THE VOID"
			button_updated = true
		elif button.text == "ENTER THE VOID":
			button_updated = true

	var labels: Array[Node] = scene_root.find_children("*", "Label", true, false)
	for node: Node in labels:
		var label: Label = node as Label
		if label == null:
			continue
		if label.text.contains("opens into a city that should not exist"):
			label.text = "The memory road ends where gravity has been torn apart."
			note_updated = true
		elif label.text.contains("gravity has been torn apart"):
			note_updated = true

	if button_updated and note_updated:
		_copy_updated = true
		set_process(false)
