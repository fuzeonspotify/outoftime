extends "res://scripts/world/road_memory.gd"

var _train_transition_started: bool = false


func _show_memory_end(failed: bool = false) -> void:
	if _sequence_finished:
		return
	_sequence_finished = true
	SFXDirector.play_transition()

	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 80
	add_child(canvas)

	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.002, 0.02, 0.0)
	canvas.add_child(dim)

	var crossing_flash: ColorRect = ColorRect.new()
	crossing_flash.anchor_left = 0.0
	crossing_flash.anchor_right = 1.0
	crossing_flash.anchor_top = 0.48
	crossing_flash.anchor_bottom = 0.52
	crossing_flash.color = Color(0.86, 0.18, 0.58, 0.0)
	canvas.add_child(crossing_flash)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(center)

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(650.0, 390.0)
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.018, 0.008, 0.035, 0.96)
	panel_style.border_color = Color("b83f91")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(6)
	panel_style.content_margin_left = 42.0
	panel_style.content_margin_right = 42.0
	panel_style.content_margin_top = 34.0
	panel_style.content_margin_bottom = 34.0
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var stack: VBoxContainer = VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 16)
	panel.add_child(stack)

	var eyebrow: Label = _make_transition_label("MEMORY CROSSING  //  NO TRACK ON ANY MAP", 13, Color("cb8bff"))
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(eyebrow)

	var heading_text: String = "THE TRAIN CAME BACK FOR YOU" if failed else "THE ROAD ENDS AT A CROSSING"
	var heading: Label = _make_transition_label(heading_text, 31, Color("fff3fb"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(heading)

	var note_text: String = "The failed memory resets, but the midnight train still opens its doors." if failed else "A black passenger train cuts across the water. Every window contains a version of you that never got off."
	var note: Label = _make_transition_label(note_text, 17, Color("c8becf"))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(560.0, 82.0)
	stack.add_child(note)

	var warning: Label = _make_transition_label("HEADPHONES RECOMMENDED  •  A / D SHIFT  •  SPACE VAULT", 12, Color("ef78bd"))
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(warning)

	var continue_button: Button = Button.new()
	continue_button.text = "BOARD THE MEMORY TRAIN"
	continue_button.custom_minimum_size = Vector2(340.0, 56.0)
	continue_button.add_theme_font_size_override("font_size", 17)
	continue_button.pressed.connect(_continue_to_city)
	stack.add_child(continue_button)

	var return_button: Button = Button.new()
	return_button.text = "RETURN TO TITLE"
	return_button.custom_minimum_size = Vector2(340.0, 46.0)
	return_button.pressed.connect(_return_to_title)
	stack.add_child(return_button)

	continue_button.grab_focus()
	var reveal: Tween = create_tween().set_parallel(true)
	reveal.tween_property(dim, "color:a", 0.92, 0.75)
	reveal.tween_property(panel, "modulate:a", 1.0, 0.75).from(0.0)
	reveal.tween_property(crossing_flash, "color:a", 0.38, 0.28)
	await reveal.finished
	var flash_fade: Tween = create_tween()
	flash_fade.tween_property(crossing_flash, "color:a", 0.0, 1.1)


func _continue_to_city() -> void:
	if _train_transition_started:
		return
	_train_transition_started = true
	SFXDirector.play_transition()
	SFXDirector.stop_environment(1.2)
	var fade: ColorRect = ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0.0, 0.0, 0.0, 0.0)
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 120
	add_child(canvas)
	canvas.add_child(fade)
	var fade_tween: Tween = create_tween()
	fade_tween.tween_property(fade, "color:a", 1.0, 1.0)
	await fade_tween.finished
	var train_scene: PackedScene = StartupPreloader.get_preloaded_scene(CITY_SCENE_PATH)
	if train_scene != null:
		get_tree().change_scene_to_packed(train_scene)
	else:
		get_tree().change_scene_to_file(CITY_SCENE_PATH)


func _make_transition_label(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.94))
	label.add_theme_constant_override("outline_size", 6)
	return label
