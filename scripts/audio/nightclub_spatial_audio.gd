extends Node

var _scene_root: Node3D
var _detail_timer: float = 2.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 7311998
	_start_audio.call_deferred()


func _process(delta: float) -> void:
	if _scene_root == null:
		return
	_detail_timer -= delta
	if _detail_timer > 0.0:
		return
	_detail_timer = _rng.randf_range(4.5, 9.5)
	var positions: Array[Vector3] = [
		Vector3(-13.0, 2.2, 6.0),
		Vector3(0.0, 2.5, -31.0),
		Vector3(12.5, 4.5, -10.0),
		Vector3(-8.0, 1.0, 20.0)
	]
	var selected_position: Vector3 = positions[_rng.randi_range(0, positions.size() - 1)]
	SFXDirector.play_world_cue(
		"impact_metal",
		selected_position,
		0.075,
		_rng.randf_range(0.82, 1.10),
		34.0
	)


func _start_audio() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_scene_root = get_parent() as Node3D
	if _scene_root == null:
		return
	SFXDirector.start_club_ambience()
	set_process(true)
