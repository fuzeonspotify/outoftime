extends Node

const UI_STYLE: Script = preload("res://scripts/ui/ui_style.gd")

var _applied_backplates: Dictionary = {}


func _ready() -> void:
	_apply_when_ready.call_deferred()


func _apply_when_ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_apply_release_styles()


func _apply_release_styles() -> void:
	var scene_root: Node = get_parent()
	if scene_root == null:
		return

	var buttons: Array[Node] = scene_root.find_children("*", "Button", true, false)
	for node: Node in buttons:
		var button: Button = node as Button
		if button == null or button.has_meta("release_styled"):
			continue
		var is_primary: bool = (
			button.text.contains("ENTER")
			or button.text.contains("BEGIN")
			or button.text.contains("CONTINUE")
		)
		UI_STYLE.apply_button(button, is_primary)

	var labels: Array[Node] = scene_root.find_children("*", "Label", true, false)
	for node: Node in labels:
		var label: Label = node as Label
		if label == null or label.has_meta("release_styled"):
			continue
		_style_label_for_context(label)

	var rich_labels: Array[Node] = scene_root.find_children("*", "RichTextLabel", true, false)
	for node: Node in rich_labels:
		var rich_label: RichTextLabel = node as RichTextLabel
		if rich_label == null or rich_label.has_meta("release_styled"):
			continue
		UI_STYLE.apply_rich_text(rich_label, 17, UI_STYLE.COLOR_TEXT)

	var progress_bars: Array[Node] = scene_root.find_children("*", "ProgressBar", true, false)
	for node: Node in progress_bars:
		var progress_bar: ProgressBar = node as ProgressBar
		if progress_bar != null and not progress_bar.has_meta("release_styled"):
			UI_STYLE.apply_progress(progress_bar)

	var label_3d_nodes: Array[Node] = scene_root.find_children("*", "Label3D", true, false)
	for node: Node in label_3d_nodes:
		var label_3d: Label3D = node as Label3D
		if label_3d == null:
			continue
		label_3d.outline_size = maxi(label_3d.outline_size, 6)
		label_3d.modulate = label_3d.modulate.lightened(0.06)


func _style_label_for_context(label: Label) -> void:
	var clean_text: String = label.text.strip_edges()
	if clean_text.is_empty():
		UI_STYLE.apply_label(label, 15, UI_STYLE.COLOR_TEXT_MUTED, 2)
		return

	var is_chapter_heading: bool = clean_text.contains("//") or clean_text.begins_with("CHAPTER")
	var is_status: bool = (
		clean_text.begins_with("MEMORY ")
		or clean_text.begins_with("JOURNALS")
		or clean_text.begins_with("BREAKERS")
		or clean_text.begins_with("STABILITY")
		or clean_text.begins_with("OBJECTIVE")
	)
	var is_large_heading: bool = label.get_theme_font_size("font_size") >= 28

	if is_large_heading:
		UI_STYLE.apply_label(label, label.get_theme_font_size("font_size"), UI_STYLE.COLOR_TEXT, 6)
	elif is_chapter_heading:
		UI_STYLE.apply_label(label, 15, UI_STYLE.COLOR_ACCENT_COOL, 4)
	elif is_status:
		UI_STYLE.apply_label(label, 15, UI_STYLE.COLOR_TEXT, 3)
		_add_status_backplate(label)
	else:
		UI_STYLE.apply_label(label, maxi(15, label.get_theme_font_size("font_size")), UI_STYLE.COLOR_TEXT_MUTED, 3)


func _add_status_backplate(label: Label) -> void:
	var instance_id: int = label.get_instance_id()
	if _applied_backplates.has(instance_id):
		return
	var parent_node: Node = label.get_parent()
	if parent_node == null or not (parent_node is CanvasLayer or parent_node is Control):
		return

	var panel: PanelContainer = PanelContainer.new()
	panel.name = "%sReleaseBackplate" % str(label.name)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.anchor_left = label.anchor_left
	panel.anchor_top = label.anchor_top
	panel.anchor_right = label.anchor_right
	panel.anchor_bottom = label.anchor_bottom
	panel.offset_left = label.offset_left - 12.0
	panel.offset_top = label.offset_top - 7.0
	panel.offset_right = label.offset_right + 12.0
	panel.offset_bottom = label.offset_bottom + 7.0
	UI_STYLE.apply_panel(panel, true)
	parent_node.add_child(panel)
	parent_node.move_child(panel, label.get_index())
	_applied_backplates[instance_id] = true
