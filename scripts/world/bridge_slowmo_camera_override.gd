extends Node

const CENTER_ANGLE_ONE_SECONDS: float = 1.10
const CENTER_ANGLE_TWO_SECONDS: float = 1.08
const CENTER_ANGLE_THREE_SECONDS: float = 1.02

var _road: Node3D
var _physics_director: Node
var _crash_set: Node3D
var _close_camera: Camera3D
var _center_seen: bool = false
var _rail_seen: bool = false
var _sequence_running: bool = false


func _ready() -> void:
	process_priority = 420
	set_process(true)


func _process(_delta: float) -> void:
	if _road == null:
		_road = get_parent() as Node3D
	if _road == null:
		return
	if _physics_director == null:
		_physics_director = _road.get_node_or_null("BridgeCrashPhysicsDirector")
	if _physics_director == null:
		return

	if not _center_seen and bool(_physics_director.get("_center_triggered")):
		_center_seen = true
		_play_center_closeups.call_deferred()
		return
	if not _rail_seen and bool(_physics_director.get("_rail_triggered")):
		_rail_seen = true
		_play_rail_closeups.call_deferred()


func _play_center_closeups() -> void:
	if _sequence_running:
		return
	_crash_set = _find_crash_set()
	if _crash_set == null:
		return
	_sequence_running = true
	_begin_close_camera()
	var target: Vector3 = _crash_set.to_global(Vector3(0.0, 0.86, 0.0))
	_place_camera(target + Vector3(-4.2, 1.25, 3.35), target, 46.0)
	await _wait_real(CENTER_ANGLE_ONE_SECONDS)
	_place_camera(
		target + Vector3(3.45, 1.55, -2.55),
		target + Vector3(0.0, 0.30, -0.4),
		42.0
	)
	await _wait_real(CENTER_ANGLE_TWO_SECONDS)
	_place_camera(target + Vector3(-0.55, 5.05, 1.35), target, 50.0)
	await _wait_real(CENTER_ANGLE_THREE_SECONDS)
	_end_close_camera()
	_sequence_running = false


func _play_rail_closeups() -> void:
	while _sequence_running:
		await get_tree().process_frame
	_crash_set = _find_crash_set()
	if _crash_set == null:
		return
	_sequence_running = true
	_begin_close_camera()
	var target: Vector3 = _crash_set.to_global(Vector3(5.95, 0.78, -14.5))
	_place_camera(target + Vector3(2.9, 0.95, 2.55), target, 43.0)
	await _wait_real(0.48)
	_place_camera(
		target + Vector3(-2.75, 1.30, -1.45),
		target + Vector3(0.5, 0.15, 0.0),
		39.0
	)
	await _wait_real(0.50)
	_place_camera(target + Vector3(1.0, 4.65, 3.0), target, 48.0)
	await _wait_real(0.44)
	_end_close_camera()
	_sequence_running = false


func _find_crash_set() -> Node3D:
	var exact_set: Node3D = _road.get_node_or_null("CenteredBridgeCrashSet") as Node3D
	if exact_set != null:
		return exact_set
	return _road.get_node_or_null("BridgeCrashSet") as Node3D


func _begin_close_camera() -> void:
	_end_close_camera()
	_close_camera = Camera3D.new()
	_close_camera.name = "WreckSlowMotionCloseCamera"
	_close_camera.near = 0.08
	_close_camera.current = true
	_road.add_child(_close_camera)


func _place_camera(position_value: Vector3, target_value: Vector3, fov_value: float) -> void:
	if _close_camera == null or not is_instance_valid(_close_camera):
		return
	_close_camera.global_position = position_value
	_close_camera.look_at(target_value, Vector3.UP)
	_close_camera.fov = fov_value
	_close_camera.current = true


func _end_close_camera() -> void:
	if _road != null:
		var crash_camera: Camera3D = _road.get("_crash_camera") as Camera3D
		if crash_camera != null and is_instance_valid(crash_camera):
			crash_camera.current = true
	if _close_camera != null and is_instance_valid(_close_camera):
		_close_camera.queue_free()
	_close_camera = null


func _wait_real(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _exit_tree() -> void:
	_end_close_camera()
