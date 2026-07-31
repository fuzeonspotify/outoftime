extends Node

const UI_STYLE: Script = preload("res://scripts/ui/ui_style.gd")

var _scan_timer: float = 0.0
var _styled_controls: Dictionary = {}


func _ready() -> void:
	set_process(true)
	_apply_release_copy.call_deferred()


func _process(delta: float) -> void:
	_scan_timer -= delta
	if _scan_timer > 0.0:
		return
	_scan_timer = 0.35
	_apply_release_copy()


func _apply_release_copy() -> void:
	var scene_root: Node = get_parent()
	if scene_root == null:
		return

	var labels: Array[Node] = scene_root.find_children("*", "Label", true, false)
	for node: Node in labels:
		var label: Label = node as Label
		if label == null:
			continue
		if label.text.contains("opens into a city that should not exist"):
			label.text = "The memory road ends where gravity has been torn apart."
		elif label.text == "PONTIAC  //  MEMORY BRIDGE":
			label.text = "CHAPTER II  //  THE MEMORY BRIDGE"
		elif label.text.contains("DODGE THE DEAD"):
			label.text = "A / D  STEER    •    MOUSE WHEEL  CAMERA    •    AVOID FAILED MEMORIES"
		_style_label(label)

	var buttons: Array[Node] = scene_root.find_children("*", "Button", true, false)
	for node: Node in buttons:
		var button: Button = node as Button
		if button == null:
			continue
		if button.text == "ENTER THE CITY":
			button.text = "ENTER THE VOID"
		var is_primary: bool = button.text == "ENTER THE VOID"
		UI_STYLE.apply_button(button, is_primary)


func _style_label(label: Label) -> void:
	var instance_id: int = label.get_instance_id()
	if _styled_controls.has(instance_id):
		return
	var text_value: String = label.text.strip_edges()
	if text_value.begins_with("CHAPTER II"):
		UI_STYLE.apply_label(label, 22, UI_STYLE.COLOR_TEXT, 5)
	elif text_value.begins_with("MEMORY DISTANCE"):
		UI_STYLE.apply_label(label, 15, UI_STYLE.COLOR_ACCENT_COOL, 3)
	elif text_value.begins_with("MEMORY INTEGRITY"):
		UI_STYLE.apply_label(label, 15, UI_STYLE.COLOR_ACCENT, 3)
	elif text_value.contains("STEER"):
		UI_STYLE.apply_label(label, 13, UI_STYLE.COLOR_TEXT_MUTED, 3)
	elif label.get_theme_font_size("font_size") >= 28:
		UI_STYLE.apply_label(label, label.get_theme_font_size("font_size"), UI_STYLE.COLOR_TEXT, 6)
	else:
		UI_STYLE.apply_label(label, maxi(15, label.get_theme_font_size("font_size")), UI_STYLE.COLOR_TEXT_MUTED, 3)
	_styled_controls[instance_id] = true
