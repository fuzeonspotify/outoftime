extends Control

var _menu: VBoxContainer
var _story_panel: VBoxContainer
var _status_label: Label


func _ready() -> void:
	_build_interface()
	MusicDirector.cue_missing.connect(_on_cue_missing)
	MusicDirector.cue_started.connect(_on_cue_started)


func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = Color("080b14")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var vignette := ColorRect.new()
	vignette.color = Color(0.02, 0.02, 0.04, 0.35)
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_menu = VBoxContainer.new()
	_menu.alignment = BoxContainer.ALIGNMENT_CENTER
	_menu.add_theme_constant_override("separation", 18)
	center.add_child(_menu)

	var title := Label.new()
	title.text = "OUT OF TIME"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	_menu.add_child(title)

	var tagline := Label.new()
	tagline.text = "YOU WERE NEVER THE FIRST"
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.modulate = Color("aeb6ca")
	tagline.add_theme_font_size_override("font_size", 20)
	_menu.add_child(tagline)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(1, 18)
	_menu.add_child(spacer)

	var start_button := Button.new()
	start_button.text = "BEGIN"
	start_button.custom_minimum_size = Vector2(320, 54)
	start_button.pressed.connect(_begin_prologue)
	_menu.add_child(start_button)

	var soundtrack_button := Button.new()
	soundtrack_button.text = "SOUNDTRACK PLAN"
	soundtrack_button.custom_minimum_size = Vector2(320, 46)
	soundtrack_button.pressed.connect(_show_soundtrack_plan)
	_menu.add_child(soundtrack_button)

	var quit_button := Button.new()
	quit_button.text = "QUIT"
	quit_button.custom_minimum_size = Vector2(320, 46)
	quit_button.pressed.connect(get_tree().quit)
	_menu.add_child(quit_button)

	_status_label = Label.new()
	_status_label.text = "Prototype ready — local song files are optional for now."
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.modulate = Color("758098")
	_status_label.add_theme_font_size_override("font_size", 14)
	_menu.add_child(_status_label)

	_story_panel = VBoxContainer.new()
	_story_panel.visible = false
	_story_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	_story_panel.add_theme_constant_override("separation", 20)
	center.add_child(_story_panel)


func _begin_prologue() -> void:
	_menu.visible = false
	_clear_story_panel()
	_story_panel.visible = true

	var chapter := Label.new()
	chapter.text = "PROLOGUE"
	chapter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chapter.add_theme_font_size_override("font_size", 22)
	chapter.modulate = Color("99a5bc")
	_story_panel.add_child(chapter)

	var heading := Label.new()
	heading.text = "A skeleton wakes beneath a dead sky."
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 36)
	_story_panel.add_child(heading)

	var body := Label.new()
	body.text = "He remembers no name — only a woman, a red Pontiac,\nand the feeling that he is already too late."
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("font_size", 20)
	body.modulate = Color("c4cada")
	_story_panel.add_child(body)

	var note := Label.new()
	note.text = "This screen is the working foundation for the first playable cemetery scene."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.modulate = Color("747f97")
	_story_panel.add_child(note)

	_add_back_button()
	MusicDirector.play_cue("okay_intro", 1.5)


func _show_soundtrack_plan() -> void:
	_menu.visible = false
	_clear_story_panel()
	_story_panel.visible = true

	var heading := Label.new()
	heading.text = "THE FIVE-ACT SOUNDTRACK"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 34)
	_story_panel.add_child(heading)

	var sequence := Label.new()
	sequence.text = "OKAY  —  THE MASK\n\nPONTIAC  —  THE FALSE LOVE\n\nROCKSTAR  —  THE RUSH\n\nCIRCLES  —  THE REVEAL\n\nOUT OF TIME  —  THE DEATH"
	sequence.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sequence.add_theme_font_size_override("font_size", 21)
	sequence.modulate = Color("c8cede")
	_story_panel.add_child(sequence)

	_add_back_button()


func _add_back_button() -> void:
	var back_button := Button.new()
	back_button.text = "BACK"
	back_button.custom_minimum_size = Vector2(260, 46)
	back_button.pressed.connect(_return_to_menu)
	_story_panel.add_child(back_button)


func _clear_story_panel() -> void:
	for child in _story_panel.get_children():
		child.queue_free()


func _return_to_menu() -> void:
	MusicDirector.stop_music(0.6)
	_story_panel.visible = false
	_menu.visible = true
	_status_label.text = "Prototype ready — local song files are optional for now."


func _on_cue_missing(cue_id: String, expected_path: String) -> void:
	_status_label.text = "Audio placeholder active: %s" % cue_id
	print("Add the local master at: %s" % expected_path)


func _on_cue_started(cue_id: String) -> void:
	_status_label.text = "Now playing: %s" % cue_id
