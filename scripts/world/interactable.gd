extends Area3D

signal activated(player: Node)

@export var prompt_text: String = "Inspect"
@export var interaction_title: String = ""
@export var interaction_context: String = "HOLD TO INTERACT"
@export_multiline var interaction_message: String = "Something about this place feels familiar."
@export var one_shot: bool = false
@export var music_cue: String = ""
@export_range(0.0, 2.0, 0.05) var hold_duration: float = 0.42
@export_range(1.0, 12.0, 0.25) var message_duration: float = 5.0
@export var show_world_marker: bool = true
@export var marker_height: float = 2.35
@export var marker_color: Color = Color("bb62d9")

var _used: bool = false
var _nearby_player: Node
var _marker_root: Node3D
var _marker_material: StandardMaterial3D
var _marker_ring: MeshInstance3D
var _marker_base_height: float = 2.35
var _elapsed_time: float = 0.0


func _ready() -> void:
	monitoring = true
	monitorable = true
	collision_layer = 2
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_world_marker()
	set_process(true)


func _process(delta: float) -> void:
	_elapsed_time += delta
	if _marker_root == null or not show_world_marker or _used:
		return

	var nearby: bool = is_instance_valid(_nearby_player)
	var pulse_speed: float = 3.8 if nearby else 1.7
	var pulse_amount: float = 0.08 if nearby else 0.035
	var pulse: float = 1.0 + sin(_elapsed_time * pulse_speed) * pulse_amount
	_marker_root.scale = Vector3.ONE * pulse
	_marker_root.position.y = _marker_base_height + sin(_elapsed_time * 1.8) * 0.08
	if _marker_ring != null:
		_marker_ring.rotate_y(delta * (1.9 if nearby else 0.75))
	if _marker_material != null:
		var target_alpha: float = 0.95 if nearby else 0.48
		var current_color: Color = _marker_material.albedo_color
		_marker_material.albedo_color = Color(
			marker_color.r,
			marker_color.g,
			marker_color.b,
			move_toward(current_color.a, target_alpha, delta * 2.8)
		)
		_marker_material.emission_energy_multiplier = 2.4 if nearby else 1.15


func interact(player: Node) -> void:
	if one_shot and _used:
		return

	_used = true
	SFXDirector.play_interaction()
	if player.has_method("show_interaction_message"):
		player.call(
			"show_interaction_message",
			interaction_message,
			message_duration,
			_resolved_title()
		)
	if not music_cue.is_empty():
		MusicDirector.play_cue(music_cue, 1.8)
	activated.emit(player)

	if one_shot:
		monitoring = false
		monitorable = false
		collision_layer = 0
		if _marker_root != null:
			_marker_root.visible = false
		if player.has_method("clear_interaction_target"):
			player.call("clear_interaction_target", self)


func refresh_release_presentation() -> void:
	_marker_base_height = marker_height
	if _marker_root != null:
		_marker_root.position.y = marker_height
		_marker_root.visible = show_world_marker and not _used
	if _marker_material != null:
		_marker_material.albedo_color = Color(marker_color.r, marker_color.g, marker_color.b, 0.48)
		_marker_material.emission = marker_color

	if is_instance_valid(_nearby_player) and _nearby_player.has_method("set_interaction_target"):
		_nearby_player.call(
			"set_interaction_target",
			self,
			prompt_text,
			_resolved_title(),
			interaction_context,
			hold_duration
		)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player") or (one_shot and _used):
		return
	_nearby_player = body
	if body.has_method("set_interaction_target"):
		body.call(
			"set_interaction_target",
			self,
			prompt_text,
			_resolved_title(),
			interaction_context,
			hold_duration
		)


func _on_body_exited(body: Node) -> void:
	if body != _nearby_player:
		return
	_nearby_player = null
	if body.has_method("clear_interaction_target"):
		body.call("clear_interaction_target", self)


func _resolved_title() -> String:
	if not interaction_title.strip_edges().is_empty():
		return interaction_title.strip_edges()
	if not prompt_text.strip_edges().is_empty():
		return prompt_text.strip_edges().to_upper()
	return "MEMORY ECHO"


func _build_world_marker() -> void:
	_marker_base_height = marker_height
	_marker_root = Node3D.new()
	_marker_root.name = "InteractionMarker"
	_marker_root.position = Vector3(0.0, marker_height, 0.0)
	_marker_root.visible = show_world_marker and not _used
	add_child(_marker_root)

	_marker_material = StandardMaterial3D.new()
	_marker_material.albedo_color = Color(marker_color.r, marker_color.g, marker_color.b, 0.48)
	_marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker_material.emission_enabled = true
	_marker_material.emission = marker_color
	_marker_material.emission_energy_multiplier = 1.15

	var diamond_mesh: SphereMesh = SphereMesh.new()
	diamond_mesh.radius = 0.17
	diamond_mesh.height = 0.34
	diamond_mesh.radial_segments = 4
	diamond_mesh.rings = 2
	var diamond: MeshInstance3D = MeshInstance3D.new()
	diamond.name = "MarkerDiamond"
	diamond.mesh = diamond_mesh
	diamond.rotation_degrees = Vector3(0.0, 45.0, 45.0)
	diamond.material_override = _marker_material
	_marker_root.add_child(diamond)

	var ring_mesh: TorusMesh = TorusMesh.new()
	ring_mesh.inner_radius = 0.28
	ring_mesh.outer_radius = 0.32
	_marker_ring = MeshInstance3D.new()
	_marker_ring.name = "MarkerRing"
	_marker_ring.mesh = ring_mesh
	_marker_ring.rotation_degrees.x = 90.0
	_marker_ring.material_override = _marker_material
	_marker_root.add_child(_marker_ring)

	var beam_mesh: BoxMesh = BoxMesh.new()
	beam_mesh.size = Vector3(0.025, 0.68, 0.025)
	var beam: MeshInstance3D = MeshInstance3D.new()
	beam.name = "MarkerBeam"
	beam.mesh = beam_mesh
	beam.position.y = -0.48
	beam.material_override = _marker_material
	_marker_root.add_child(beam)
