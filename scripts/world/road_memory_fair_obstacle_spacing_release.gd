extends "res://scripts/world/road_memory_destructible_obstacles_final_release.gd"

const FAIR_LANE_POSITIONS: Array[float] = [-2.3, 0.0, 2.3]
const STARTING_CAR_Z: float = 8.0
const INITIAL_CLEAR_DISTANCE: float = 34.0
const MIN_CLUSTER_GAP_START: float = 18.0
const MIN_CLUSTER_GAP_MAX_SPEED: float = 23.0
const CLUSTER_CHANCE_START: float = 0.62
const CLUSTER_CHANCE_MAX: float = 0.76
const DOUBLE_BLOCK_CHANCE_START: float = 0.22
const DOUBLE_BLOCK_CHANCE_MAX: float = 0.36
const CLUSTER_LOCAL_Z_LIMIT: float = 3.25
const DOUBLE_BLOCK_Z_OFFSET: float = 0.38

var _fair_has_previous_cluster: bool = false
var _fair_last_cluster_world_z: float = 0.0
var _fair_last_safe_lane_index: int = 1
var _fair_last_cluster_was_double: bool = false
var _fair_cluster_count: int = 0
var _fair_spacing_skip_count: int = 0


func _ready() -> void:
	super._ready()
	print(
		"FAIR ROAD OBSTACLES READY: speed-aware spacing, protected escape lanes, and no impossible lane walls."
	)


func _seed_segment_obstacles(segment: Node3D) -> void:
	if segment == null or not is_instance_valid(segment):
		return

	var segment_name: String = str(segment.name)
	_segment_obstacles[segment_name] = []

	var difficulty: float = clampf(_distance_travelled / MEMORY_DISTANCE, 0.0, 1.0)
	var cluster_chance: float = lerpf(
		CLUSTER_CHANCE_START,
		CLUSTER_CHANCE_MAX,
		difficulty
	)
	if _rng.randf() > cluster_chance:
		return

	var cluster_local_z: float = _rng.randf_range(
		-CLUSTER_LOCAL_Z_LIMIT,
		CLUSTER_LOCAL_Z_LIMIT
	)
	var cluster_world_z: float = segment.global_position.z + cluster_local_z

	# Give the player time to read the road when the level begins. The car starts
	# at Z=8 and travels toward negative Z, so larger Z values are too close.
	if _distance_travelled < 1.0 and cluster_world_z > (
		STARTING_CAR_Z - INITIAL_CLEAR_DISTANCE
	):
		return

	# The required spacing grows with speed. At 42 units per second, the Porsche
	# travels roughly 16.7 meters while crossing from one outside lane to the
	# other, so the late-game minimum is deliberately larger than that distance.
	var required_gap: float = lerpf(
		MIN_CLUSTER_GAP_START,
		MIN_CLUSTER_GAP_MAX_SPEED,
		difficulty
	)
	if _fair_has_previous_cluster:
		var forward_gap: float = _fair_last_cluster_world_z - cluster_world_z
		if forward_gap < required_gap:
			_fair_spacing_skip_count += 1
			return

	var double_block_chance: float = lerpf(
		DOUBLE_BLOCK_CHANCE_START,
		DOUBLE_BLOCK_CHANCE_MAX,
		difficulty
	)
	var use_double_block: bool = (
		_rng.randf() < double_block_chance
		and not _fair_last_cluster_was_double
	)

	var obstacle_entries: Array = []
	if use_double_block:
		var safe_lane_index: int = _choose_reachable_safe_lane()
		for lane_index: int in range(FAIR_LANE_POSITIONS.size()):
			if lane_index == safe_lane_index:
				continue
			var z_offset: float = (
				-DOUBLE_BLOCK_Z_OFFSET
				if lane_index < safe_lane_index
				else DOUBLE_BLOCK_Z_OFFSET
			)
			_append_fair_obstacle(
				segment,
				obstacle_entries,
				lane_index,
				cluster_local_z + z_offset
			)
		_fair_last_safe_lane_index = safe_lane_index
	else:
		var occupied_lane_index: int = _rng.randi_range(
			0,
			FAIR_LANE_POSITIONS.size() - 1
		)
		_append_fair_obstacle(
			segment,
			obstacle_entries,
			occupied_lane_index,
			cluster_local_z
		)

	_segment_obstacles[segment_name] = obstacle_entries
	_fair_has_previous_cluster = true
	_fair_last_cluster_world_z = cluster_world_z
	_fair_last_cluster_was_double = use_double_block
	_fair_cluster_count += 1


func _choose_reachable_safe_lane() -> int:
	var candidates: Array[int] = []
	for lane_index: int in range(FAIR_LANE_POSITIONS.size()):
		if absi(lane_index - _fair_last_safe_lane_index) <= 1:
			candidates.append(lane_index)
	if candidates.is_empty():
		return _fair_last_safe_lane_index
	return candidates[_rng.randi_range(0, candidates.size() - 1)]


func _append_fair_obstacle(
	segment: Node3D,
	entries: Array,
	lane_index: int,
	local_z: float
) -> void:
	var lane_x: float = FAIR_LANE_POSITIONS[lane_index]
	var obstacle_type: String = (
		"barrier"
		if _rng.randf() < 0.66
		else "skeleton"
	)
	var obstacle: Node3D = _create_obstacle(
		obstacle_type,
		lane_x,
		local_z
	)
	if obstacle == null:
		return

	segment.add_child(obstacle)
	entries.append({
		"node": obstacle,
		"lane_x": lane_x,
		"local_z": local_z,
		"hit": false,
		"type": obstacle_type
	})
