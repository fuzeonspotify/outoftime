extends Node

var _canvas: CanvasLayer
var _signal_label: Label
var _scanline_root: Control
var _elapsed_time: float = 0.0


func _ready() -> void:
	_build_overlay.call_deferred()


func _process(delta: float) -> void:
	_elapsed_time += delta
	if _signal_label != null:
		var pulse: float = 0.72 + (sin(_elapsed_time * 1.15) * 0.5 + 0.5) * 0.20
		var signal_modulate: Color = _signal_label.modulate
		signal_modulate.a = pulse
		_signal_label.modulate = signal_modulate
	if _scanline_root != null:
		var scanline_position: Vector2 = _scanline_root.position
		scanline_position.y = fmod(_elapsed_time * 7.0, 12.0) - 12.0
		_scanline_root.position = scanline_position


func _build_overlay() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var player: Node3D = get_parent() as Node3D
	if player == null:
		return

	_canvas = CanvasLayer.new()
	_canvas.name = "MemorySignalOverlay"
	_canvas.layer = 45
	player.add_child(_canvas)

	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(root)

	_build_vignette(root)
	_build_scanlines(root)
	_build_corner_frame(root)
	_build_signal_readout(root)
	set_process(true)


func _build_vignette(root: Control) -> void:
	var vignette: ColorRect = ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader: Shader = Shader.new()
	shader.code = "shader_type canvas_item;\nvoid fragment(){\n vec2 p=UV*2.0-1.0;\n float edge=smoothstep(0.48,1.18,length(p*vec2(0.82,1.0)));\n float pulse=0.015*(sin(TIME*0.65)+1.0);\n COLOR=vec4(0.035,0.008,0.060,(edge*0.33)+pulse);\n}"
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	vignette.material = material
	root.add_child(vignette)


func _build_scanlines(root: Control) -> void:
	_scanline_root = Control.new()
	_scanline_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scanline_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_scanline_root)
	for index: int in range(76):
		var line: ColorRect = ColorRect.new()
		line.anchor_right = 1.0
		line.position = Vector2(0.0, float(index) * 12.0)
		line.offset_right = 0.0
		line.offset_bottom = 1.0
		line.color = Color(0.39, 0.25, 0.55, 0.010 if index % 3 != 0 else 0.018)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_scanline_root.add_child(line)


func _build_corner_frame(root: Control) -> void:
	var bracket_color: Color = Color(0.49, 0.42, 0.76, 0.27)
	_create_corner(root, Vector2(20.0, 20.0), false, false, bracket_color)
	_create_corner(root, Vector2(-20.0, 20.0), true, false, bracket_color)
	_create_corner(root, Vector2(20.0, -20.0), false, true, bracket_color)
	_create_corner(root, Vector2(-20.0, -20.0), true, true, bracket_color)


func _create_corner(
	root: Control,
	offset: Vector2,
	anchor_right_side: bool,
	anchor_bottom_side: bool,
	color: Color
) -> void:
	var corner: Control = Control.new()
	corner.anchor_left = 1.0 if anchor_right_side else 0.0
	corner.anchor_right = corner.anchor_left
	corner.anchor_top = 1.0 if anchor_bottom_side else 0.0
	corner.anchor_bottom = corner.anchor_top
	corner.position = offset
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(corner)

	var horizontal: ColorRect = ColorRect.new()
	horizontal.size = Vector2(46.0, 2.0)
	horizontal.position = Vector2(-46.0 if anchor_right_side else 0.0, -2.0 if anchor_bottom_side else 0.0)
	horizontal.color = color
	corner.add_child(horizontal)

	var vertical: ColorRect = ColorRect.new()
	vertical.size = Vector2(2.0, 46.0)
	vertical.position = Vector2(-2.0 if anchor_right_side else 0.0, -46.0 if anchor_bottom_side else 0.0)
	vertical.color = color
	corner.add_child(vertical)


func _build_signal_readout(root: Control) -> void:
	_signal_label = Label.new()
	_signal_label.anchor_top = 1.0
	_signal_label.anchor_bottom = 1.0
	_signal_label.offset_left = 24.0
	_signal_label.offset_top = -35.0
	_signal_label.offset_right = 440.0
	_signal_label.offset_bottom = -14.0
	_signal_label.text = "%s  //  MEMORY SIGNAL STABLE" % _chapter_code()
	_signal_label.add_theme_font_size_override("font_size", 10)
	_signal_label.add_theme_color_override("font_color", Color("81799b"))
	_signal_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.90))
	_signal_label.add_theme_constant_override("outline_size", 3)
	_signal_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_signal_label)


func _chapter_code() -> String:
	var scene_root: Node = get_tree().current_scene
	var scene_name: String = str(scene_root.name) if scene_root != null else "UNKNOWN"
	match scene_name:
		"Cemetery":
			return "OFT-01"
		"AfterlifeVoid":
			return "OFT-03"
		"RuinedNightclub":
			return "OFT-04"
		"SkeletonChamber":
			return "OFT-05"
		_:
			return "OFT-00"
