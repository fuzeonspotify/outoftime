extends "res://scripts/ui/main.gd"

var _startup_overlay: Control
var _startup_panel: PanelContainer
var _startup_status: Label
var _startup_detail: Label
var _startup_progress: ProgressBar
var _startup_percent: Label
var _startup_finished: bool = false


func _ready() -> void:
	super._ready()
	_rewrite_story_copy()
	_build_startup_overlay()
	_begin_button.disabled = true
	StartupPreloader.progress_changed.connect(_on_startup_progress_changed)
	StartupPreloader.preload_completed.connect(_on_startup_preload_completed)
	_on_startup_progress_changed(StartupPreloader.get_progress(), StartupPreloader.get_status())
	if StartupPreloader.is_ready():
		_on_startup_preload_completed(StartupPreloader.used_fallbacks())


func _begin_game() -> void:
	if not StartupPreloader.is_ready():
		return
	super._begin_game()


func _rewrite_story_copy() -> void:
	var labels: Array[Node] = find_children("*", "Label", true, false)
	for node: Node in labels:
		var label: Label = node as Label
		if label == null:
			continue
		match label.text:
			"Follow a familiar woman through a cemetery, a fractured memory,\na gravityless void, and the rooms that remember how you died.":
				label.text = "Follow a familiar woman through a cemetery, a fractured road,\na fatal crash, and a Heaven that changes when you walk away."
			"CEMETERY  •  MEMORY BRIDGE  •  VOID  •  RUINED CLUB  •  CHAMBER":
				label.text = "CEMETERY  •  MEMORY ROAD  •  FALSE HEAVEN  •  RUINED CLUB  •  CHAMBER"
			"WASD\nMove\n\nSHIFT\nSprint\n\nSPACE\nJump\n\nE\nHold to interact\n\nESC\nPause":
				label.text = "WASD\nMove / survive\n\nSHIFT\nSprint\n\nSPACE\nJump\n\nE\nHold to interact\n\nESC\nPause"


func _build_startup_overlay() -> void:
	_startup_overlay = Control.new()
	_startup_overlay.name = "StartupPreparation"
	_startup_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_startup_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_startup_overlay)

	var background: ColorRect = ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.012, 0.006, 0.025, 0.985)
	_startup_overlay.add_child(background)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_startup_overlay.add_child(center)

	_startup_panel = PanelContainer.new()
	_startup_panel.custom_minimum_size = Vector2(640.0, 310.0)
	_startup_panel.add_theme_stylebox_override(
		"panel",
		UI_STYLE.make_signal_panel_style(
			Color(0.025, 0.013, 0.048, 0.98),
			UI_STYLE.COLOR_ACCENT_COOL,
			28.0
		)
	)
	center.add_child(_startup_panel)

	var stack: VBoxContainer = VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 18)
	_startup_panel.add_child(stack)

	var eyebrow: Label = UI_STYLE.make_label("OUT OF TIME  //  MEMORY ARCHIVE", 13, UI_STYLE.COLOR_ACCENT_COOL)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(eyebrow)

	var heading: Label = UI_STYLE.make_label("PREPARING THE DESCENT", 34, UI_STYLE.COLOR_TEXT)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(heading)

	_startup_status = UI_STYLE.make_label("OPENING MEMORY ARCHIVE", 17, UI_STYLE.COLOR_TEXT_MUTED)
	_startup_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_startup_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_startup_status.custom_minimum_size = Vector2(560.0, 38.0)
	stack.add_child(_startup_status)

	_startup_progress = ProgressBar.new()
	_startup_progress.custom_minimum_size = Vector2(560.0, 12.0)
	_startup_progress.min_value = 0.0
	_startup_progress.max_value = 100.0
	_startup_progress.show_percentage = false
	UI_STYLE.apply_progress(_startup_progress)
	stack.add_child(_startup_progress)

	_startup_percent = UI_STYLE.make_label("0%", 13, UI_STYLE.COLOR_ACCENT)
	_startup_percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(_startup_percent)

	_startup_detail = UI_STYLE.make_label(
		"Warming the soundtrack, chapter scenes, character scans, environment assets, and realistic bridge vehicle keeps the crash and gate finale uninterrupted.",
		12,
		UI_STYLE.COLOR_TEXT_DIM
	)
	_startup_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_startup_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_startup_detail.custom_minimum_size = Vector2(560.0, 46.0)
	stack.add_child(_startup_detail)


func _on_startup_progress_changed(progress: float, status: String) -> void:
	if _startup_finished or _startup_progress == null:
		return
	var percent: int = int(round(clampf(progress, 0.0, 1.0) * 100.0))
	_startup_progress.value = float(percent)
	_startup_percent.text = "%d%%" % percent
	_startup_status.text = status


func _on_startup_preload_completed(used_fallbacks: bool) -> void:
	if _startup_finished:
		return
	_startup_finished = true
	_startup_progress.value = 100.0
	_startup_percent.text = "100%"
	_startup_status.text = "MEMORY ARCHIVE READY"
	if used_fallbacks:
		_startup_detail.text = "Some optional online assets were unavailable. Procedural character, vehicle, audio, or environment fallbacks are active."
	else:
		_startup_detail.text = "Soundtrack, chapter scenes, character models, realistic vehicle, and environments are warmed for uninterrupted play."

	await get_tree().create_timer(0.65).timeout
	var fade_tween: Tween = create_tween()
	fade_tween.tween_property(_startup_overlay, "modulate:a", 0.0, 0.55)
	await fade_tween.finished
	_startup_overlay.queue_free()
	_startup_overlay = null
	_begin_button.disabled = false
	_begin_button.grab_focus()
