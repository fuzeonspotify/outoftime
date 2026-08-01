extends Node

const EXPANSION_CONTAINER_NAME: String = "ExpandedLevelGeometry"
const ROAD_EXTENDED_DISTANCE: float = 1120.0
const ROAD_WRAP_THRESHOLD: float = 680.0
const ROAD_WRAP_AMOUNT: float = 480.0

var _root: Node3D
var _container: Node3D
var _instance_counter: int = 0
var _road_distance_offset: float = 0.0
var _road_guard_active: bool = false
var _road_display_distance: float = 0.0


func _ready() -> void:
	process_priority = -100
	set_process(false)
	_install_expansion.call_deferred()


func _process(_delta: float) -> void:
	if not _road_guard_active or _root == null or not is_instance_valid(_root):
		return
	if bool(_root.get("_sequence_finished")):
		_road_guard_active = false
		set_process(false)
		return

	var current_distance: float = float(_root.get("_distance_travelled"))
	var virtual_distance: float = _road_distance_offset + current_distance
	_road_display_distance = virtual_distance

	if virtual_distance >= ROAD_EXTENDED_DISTANCE:
		_road_display_distance = ROAD_EXTENDED_DISTANCE
		_root.set("_distance_travelled", 760.0)
		_road_guard_active = false
	else:
		if current_distance >= ROAD_WRAP_THRESHOLD:
			_root.set("_distance_travelled", current_distance - ROAD_WRAP_AMOUNT)
			_road_distance_offset += ROAD_WRAP_AMOUNT
			_road_display_distance = _road_distance_offset + current_distance - ROAD_WRAP_AMOUNT

	_refresh_road_distance_label.call_deferred()


func _install_expansion() -> void:
	for _frame_index: int in range(3):
		await get_tree().process_frame

	_root = get_parent() as Node3D
	if _root == null:
		return
	if _root.get_node_or_null(EXPANSION_CONTAINER_NAME) != null:
		return

	_container = Node3D.new()
	_container.name = EXPANSION_CONTAINER_NAME
	_root.add_child(_container)

	match str(_root.name):
		"Cemetery":
			_expand_cemetery()
		"RoadMemory":
			_expand_memory_road()
		"HeavenDescent":
			_expand_false_heaven()
		"RuinedNightclub":
			_expand_nightclub()
		"SkeletonChamber":
			_expand_skeleton_chamber()
		_:
			push_error("No level expansion plan for %s." % _root.name)


func _expand_cemetery() -> void:
	# The original cemetery ended just in front of the player. This adds a full
	# arrival courtyard and side burial gardens, then begins the player farther
	# from the memorial so the prologue has a longer visual build-up.
	_create_static_box(
		"CemeteryArrivalGround",
		Vector3(0.0, -0.30, 47.0),
		Vector3(42.0, 0.60, 38.0),
		"rock_ground"
	)
	_create_visual_box(
		"CemeteryArrivalPath",
		Vector3(0.0, 0.035, 47.0),
		Vector3(4.2, 0.07, 38.0),
		"monastery_stone_floor"
	)
	_create_static_box(
		"CemeteryArrivalFenceLeft",
		Vector3(-19.0, 1.0, 47.0),
		Vector3(0.35, 2.0, 38.0),
		"stone_floor"
	)
	_create_static_box(
		"CemeteryArrivalFenceRight",
		Vector3(19.0, 1.0, 47.0),
		Vector3(0.35, 2.0, 38.0),
		"stone_floor"
	)
	_create_static_box(
		"CemeteryArrivalBackLeft",
		Vector3(-11.0, 1.0, 65.8),
		Vector3(16.0, 2.0, 0.35),
		"stone_floor"
	)
	_create_static_box(
		"CemeteryArrivalBackRight",
		Vector3(11.0, 1.0, 65.8),
		Vector3(16.0, 2.0, 0.35),
		"stone_floor"
	)

	# Open side gardens make the map wider without changing the memorial route.
	_create_static_box(
		"CemeteryWestGarden",
		Vector3(-24.0, -0.28, 48.0),
		Vector3(10.0, 0.56, 28.0),
		"rock_ground"
	)
	_create_static_box(
		"CemeteryEastGarden",
		Vector3(24.0, -0.28, 48.0),
		Vector3(10.0, 0.56, 28.0),
		"rock_ground"
	)
	_create_static_box(
		"CemeteryOuterFenceLeft",
		Vector3(-29.0, 1.0, 48.0),
		Vector3(0.35, 2.0, 28.0),
		"stone_floor"
	)
	_create_static_box(
		"CemeteryOuterFenceRight",
		Vector3(29.0, 1.0, 48.0),
		Vector3(0.35, 2.0, 28.0),
		"stone_floor"
	)

	for lamp_z: float in [34.0, 46.0, 58.0]:
		_place_model("street_lamp_02", Vector3(-3.2, 0.0, lamp_z), Vector3.ZERO, 3.8)
		_place_model("street_lamp_02", Vector3(3.2, 0.0, lamp_z), Vector3(0.0, 180.0, 0.0), 3.8)

	_place_model(
		"painted_wooden_sofa",
		Vector3(-12.0, 0.0, 47.5),
		Vector3(0.0, 55.0, 0.0),
		2.7,
		Vector3(2.4, 1.0, 0.9)
	)
	_place_model(
		"painted_wooden_sofa",
		Vector3(12.0, 0.0, 51.0),
		Vector3(0.0, -120.0, 0.0),
		2.7,
		Vector3(2.4, 1.0, 0.9)
	)
	for planter_position: Vector3 in [
		Vector3(-8.0, 0.0, 39.0),
		Vector3(8.0, 0.0, 42.0),
		Vector3(-22.5, 0.0, 55.0),
		Vector3(22.5, 0.0, 44.0)
	]:
		_place_model(
			"planter_box_01",
			planter_position,
			Vector3(0.0, 90.0, 0.0),
			1.6,
			Vector3(1.5, 0.8, 0.8)
		)
	_place_model("ceramic_vase_01", Vector3(-1.4, 0.0, 63.0), Vector3.ZERO, 0.75)
	_place_model("ceramic_vase_01", Vector3(1.4, 0.0, 63.0), Vector3.ZERO, 0.75)
	_place_model(
		"plastic_monobloc_chair_01",
		Vector3(-24.0, 0.0, 39.0),
		Vector3(0.0, 32.0, 0.0),
		1.15,
		Vector3(0.8, 1.0, 0.8)
	)

	_move_player_to(Vector3(0.0, 0.1, 61.5))


func _expand_memory_road() -> void:
	# Keep the original crash threshold untouched and guard it externally. The
	# physical road now lasts 1,120 distance units before the crash begins.
	_road_guard_active = true
	set_process(true)

	var segments: Array[Node] = _root.find_children("BridgeSegment*", "Node3D", true, false)
	for segment_index: int in range(segments.size()):
		var segment: Node3D = segments[segment_index] as Node3D
		if segment == null:
			continue
		if segment_index % 5 == 1:
			_place_model(
				"utility_box_01",
				Vector3(-6.6, 0.10, -2.0),
				Vector3(0.0, 90.0, 0.0),
				1.35,
				Vector3(1.1, 1.3, 0.8),
				segment
			)
		if segment_index % 7 == 3:
			_place_model(
				"covered_car",
				Vector3(7.2, 0.10, 0.5),
				Vector3(0.0, 180.0, 0.0),
				4.4,
				Vector3(4.2, 1.8, 2.0),
				segment
			)
		if segment_index % 6 == 2:
			_place_model(
				"metal_trash_can",
				Vector3(-6.8, 0.10, 3.0),
				Vector3.ZERO,
				1.25,
				Vector3(0.9, 1.2, 0.9),
				segment
			)


func _expand_false_heaven() -> void:
	# Remove the statue-head props regardless of whether an older scene cache
	# instantiated them before this release script ran.
	var bust_nodes: Array[Node] = _root.find_children("PH_marble_bust_01_*", "Node3D", true, false)
	for bust_node: Node in bust_nodes:
		bust_node.queue_free()

	# Add a long ceremonial arrival court in front of the existing procession.
	_create_static_box(
		"HeavenArrivalGround",
		Vector3(0.0, -0.85, 72.0),
		Vector3(54.0, 1.7, 28.0),
		"marble_01"
	)
	_create_visual_box(
		"HeavenArrivalPath",
		Vector3(0.0, 0.03, 72.0),
		Vector3(10.5, 0.12, 28.0),
		"monastery_stone_floor"
	)
	_create_visual_box(
		"HeavenArrivalWaterLeft",
		Vector3(-8.5, -0.10, 72.0),
		Vector3(2.1, 0.22, 28.0),
		"marble_01"
	)
	_create_visual_box(
		"HeavenArrivalWaterRight",
		Vector3(8.5, -0.10, 72.0),
		Vector3(2.1, 0.22, 28.0),
		"marble_01"
	)
	_create_invisible_boundary(Vector3(-27.5, 4.0, 72.0), Vector3(2.0, 10.0, 30.0))
	_create_invisible_boundary(Vector3(27.5, 4.0, 72.0), Vector3(2.0, 10.0, 30.0))
	_create_invisible_boundary(Vector3(0.0, 4.0, 86.0), Vector3(54.0, 10.0, 2.0))

	for planter_position: Vector3 in [
		Vector3(-14.0, 0.0, 62.0),
		Vector3(14.0, 0.0, 62.0),
		Vector3(-17.0, 0.0, 72.0),
		Vector3(17.0, 0.0, 72.0),
		Vector3(-14.0, 0.0, 82.0),
		Vector3(14.0, 0.0, 82.0)
	]:
		_place_model(
			"planter_box_01",
			planter_position,
			Vector3.ZERO,
			1.8,
			Vector3(1.6, 0.8, 0.9)
		)

	for vase_position: Vector3 in [
		Vector3(-5.8, 0.0, 63.0),
		Vector3(5.8, 0.0, 63.0),
		Vector3(-5.8, 0.0, 81.0),
		Vector3(5.8, 0.0, 81.0)
	]:
		_place_model("ceramic_vase_01", vase_position, Vector3.ZERO, 1.0)

	_move_player_to(Vector3(0.0, 0.2, 80.0))


func _expand_nightclub() -> void:
	# A ruined lobby and two side lounges now sit before the original club room.
	_create_static_box(
		"ClubLobbyFloor",
		Vector3(0.0, -0.35, 52.0),
		Vector3(36.0, 0.70, 36.0),
		"scuffed_cement"
	)
	_create_static_box(
		"ClubWestLoungeFloor",
		Vector3(-24.0, -0.35, 51.0),
		Vector3(12.0, 0.70, 30.0),
		"scuffed_cement"
	)
	_create_static_box(
		"ClubEastLoungeFloor",
		Vector3(24.0, -0.35, 51.0),
		Vector3(12.0, 0.70, 30.0),
		"scuffed_cement"
	)
	_create_static_box("ClubLobbyLeftWallA", Vector3(-18.0, 5.0, 39.0), Vector3(1.0, 10.0, 10.0), "scuffed_cement")
	_create_static_box("ClubLobbyLeftWallB", Vector3(-18.0, 5.0, 63.0), Vector3(1.0, 10.0, 14.0), "scuffed_cement")
	_create_static_box("ClubLobbyRightWallA", Vector3(18.0, 5.0, 39.0), Vector3(1.0, 10.0, 10.0), "scuffed_cement")
	_create_static_box("ClubLobbyRightWallB", Vector3(18.0, 5.0, 63.0), Vector3(1.0, 10.0, 14.0), "scuffed_cement")
	_create_static_box("ClubOuterWestWall", Vector3(-30.0, 5.0, 51.0), Vector3(1.0, 10.0, 30.0), "scuffed_cement")
	_create_static_box("ClubOuterEastWall", Vector3(30.0, 5.0, 51.0), Vector3(1.0, 10.0, 30.0), "scuffed_cement")
	_create_static_box("ClubLobbyFrontLeft", Vector3(-10.5, 5.0, 70.0), Vector3(15.0, 10.0, 1.0), "scuffed_cement")
	_create_static_box("ClubLobbyFrontRight", Vector3(10.5, 5.0, 70.0), Vector3(15.0, 10.0, 1.0), "scuffed_cement")
	_create_static_box("ClubWestLoungeBack", Vector3(-24.0, 5.0, 36.0), Vector3(12.0, 10.0, 1.0), "scuffed_cement")
	_create_static_box("ClubEastLoungeBack", Vector3(24.0, 5.0, 36.0), Vector3(12.0, 10.0, 1.0), "scuffed_cement")
	_create_static_box("ClubWestLoungeFront", Vector3(-24.0, 5.0, 66.0), Vector3(12.0, 10.0, 1.0), "scuffed_cement")
	_create_static_box("ClubEastLoungeFront", Vector3(24.0, 5.0, 66.0), Vector3(12.0, 10.0, 1.0), "scuffed_cement")

	_place_model("sofa_02", Vector3(-25.5, 0.0, 46.0), Vector3(0.0, 90.0, 0.0), 2.8, Vector3(2.5, 1.2, 1.1))
	_place_model("sofa_02", Vector3(25.5, 0.0, 55.0), Vector3(0.0, -90.0, 0.0), 2.8, Vector3(2.5, 1.2, 1.1))
	_place_model("modern_coffee_table_01", Vector3(-22.0, 0.0, 46.0), Vector3.ZERO, 1.6, Vector3(1.5, 0.6, 0.9))
	_place_model("modern_coffee_table_01", Vector3(22.0, 0.0, 55.0), Vector3.ZERO, 1.6, Vector3(1.5, 0.6, 0.9))
	_place_model("television_01", Vector3(-28.5, 0.0, 59.0), Vector3(0.0, 90.0, 0.0), 1.15, Vector3(1.0, 0.9, 0.6))
	_place_model("cassette_player", Vector3(-22.0, 0.60, 46.0), Vector3(0.0, 20.0, 0.0), 0.55)
	_place_model("metal_trash_can", Vector3(16.0, 0.0, 66.0), Vector3.ZERO, 1.25, Vector3(0.9, 1.2, 0.9))
	_place_model("utility_box_01", Vector3(-16.0, 0.0, 66.0), Vector3(0.0, 180.0, 0.0), 1.4, Vector3(1.1, 1.3, 0.8))
	_place_model("plastic_monobloc_chair_01", Vector3(23.0, 0.0, 43.0), Vector3(0.0, -28.0, 0.0), 1.15, Vector3(0.8, 1.0, 0.8))

	_add_omni_light(Vector3(-24.0, 3.2, 49.0), Color("b341ff"), 2.2, 11.0)
	_add_omni_light(Vector3(24.0, 3.2, 52.0), Color("ff397e"), 2.2, 11.0)
	_move_player_to(Vector3(0.0, 0.1, 65.0))


func _expand_skeleton_chamber() -> void:
	# A long entry crypt and two furnished reading alcoves now precede the first
	# journal, increasing travel time while keeping the confrontation intact.
	_create_static_box(
		"ChamberEntryFloor",
		Vector3(0.0, -0.35, 50.0),
		Vector3(38.0, 0.70, 38.0),
		"stone_floor"
	)
	_create_static_box(
		"ChamberWestAlcoveFloor",
		Vector3(-25.0, -0.35, 50.0),
		Vector3(12.0, 0.70, 24.0),
		"stone_floor"
	)
	_create_static_box(
		"ChamberEastAlcoveFloor",
		Vector3(25.0, -0.35, 50.0),
		Vector3(12.0, 0.70, 24.0),
		"stone_floor"
	)
	_create_static_box("ChamberEntryLeftWallA", Vector3(-19.0, 5.0, 36.0), Vector3(1.0, 10.0, 10.0), "stone_floor")
	_create_static_box("ChamberEntryLeftWallB", Vector3(-19.0, 5.0, 63.0), Vector3(1.0, 10.0, 14.0), "stone_floor")
	_create_static_box("ChamberEntryRightWallA", Vector3(19.0, 5.0, 36.0), Vector3(1.0, 10.0, 10.0), "stone_floor")
	_create_static_box("ChamberEntryRightWallB", Vector3(19.0, 5.0, 63.0), Vector3(1.0, 10.0, 14.0), "stone_floor")
	_create_static_box("ChamberOuterWestWall", Vector3(-31.0, 5.0, 50.0), Vector3(1.0, 10.0, 24.0), "stone_floor")
	_create_static_box("ChamberOuterEastWall", Vector3(31.0, 5.0, 50.0), Vector3(1.0, 10.0, 24.0), "stone_floor")
	_create_static_box("ChamberEntryFrontLeft", Vector3(-11.5, 5.0, 69.0), Vector3(15.0, 10.0, 1.0), "stone_floor")
	_create_static_box("ChamberEntryFrontRight", Vector3(11.5, 5.0, 69.0), Vector3(15.0, 10.0, 1.0), "stone_floor")
	_create_static_box("ChamberWestAlcoveBack", Vector3(-25.0, 5.0, 38.0), Vector3(12.0, 10.0, 1.0), "stone_floor")
	_create_static_box("ChamberEastAlcoveBack", Vector3(25.0, 5.0, 38.0), Vector3(12.0, 10.0, 1.0), "stone_floor")
	_create_static_box("ChamberWestAlcoveFront", Vector3(-25.0, 5.0, 62.0), Vector3(12.0, 10.0, 1.0), "stone_floor")
	_create_static_box("ChamberEastAlcoveFront", Vector3(25.0, 5.0, 62.0), Vector3(12.0, 10.0, 1.0), "stone_floor")

	_place_model("sofa_01", Vector3(-26.0, 0.0, 49.0), Vector3(0.0, 90.0, 0.0), 2.7, Vector3(2.4, 1.2, 1.0))
	_place_model("sofa_01", Vector3(26.0, 0.0, 52.0), Vector3(0.0, -90.0, 0.0), 2.7, Vector3(2.4, 1.2, 1.0))
	_place_model("classic_nightstand_01", Vector3(-22.0, 0.0, 49.0), Vector3.ZERO, 1.0, Vector3(0.8, 1.0, 0.8))
	_place_model("classic_nightstand_01", Vector3(22.0, 0.0, 52.0), Vector3.ZERO, 1.0, Vector3(0.8, 1.0, 0.8))
	_place_model("wooden_table_03", Vector3(0.0, 0.0, 45.0), Vector3(0.0, 180.0, 0.0), 2.2, Vector3(2.0, 1.2, 0.9))
	_place_model("side_table_01", Vector3(0.0, 0.0, 59.0), Vector3.ZERO, 1.2, Vector3(1.0, 0.8, 0.8))
	_place_model("wooden_candlestick", Vector3(-22.0, 1.05, 49.0), Vector3.ZERO, 0.45)
	_place_model("wooden_candlestick", Vector3(22.0, 1.05, 52.0), Vector3.ZERO, 0.45)
	_place_model("ceramic_vase_01", Vector3(-4.0, 0.0, 58.0), Vector3.ZERO, 0.8)
	_place_model("ceramic_vase_01", Vector3(4.0, 0.0, 58.0), Vector3.ZERO, 0.8)

	_add_omni_light(Vector3(-24.0, 3.0, 49.0), Color("526ee0"), 1.7, 10.0)
	_add_omni_light(Vector3(24.0, 3.0, 52.0), Color("8c4fc6"), 1.7, 10.0)
	_move_player_to(Vector3(0.0, 0.1, 64.0))


func _move_player_to(target_position: Vector3) -> void:
	var player: CharacterBody3D = _root.get("_player") as CharacterBody3D
	if player == null or not is_instance_valid(player):
		var players: Array[Node] = _root.find_children("*", "CharacterBody3D", true, false)
		if not players.is_empty():
			player = players[0] as CharacterBody3D
	if player == null:
		push_error("LEVEL EXPANSION ERROR: player was not found in %s." % _root.name)
		return
	player.position = target_position
	player.velocity = Vector3.ZERO


func _refresh_road_distance_label() -> void:
	if _root == null or not is_instance_valid(_root):
		return
	var label: Label = _root.get("_distance_label") as Label
	if label != null:
		label.text = "MEMORY DISTANCE  %04d / %04d" % [
			int(round(_road_display_distance)),
			int(ROAD_EXTENDED_DISTANCE)
		]


func _create_static_box(
	node_name: String,
	box_position: Vector3,
	box_size: Vector3,
	material_id: String
) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = node_name
	body.position = box_position

	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = box_size
	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = _required_material(material_id)
	body.add_child(visual)

	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = box_size
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	_container.add_child(body)
	return body


func _create_visual_box(
	node_name: String,
	box_position: Vector3,
	box_size: Vector3,
	material_id: String
) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = box_size
	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.name = node_name
	visual.position = box_position
	visual.mesh = mesh
	visual.material_override = _required_material(material_id)
	_container.add_child(visual)
	return visual


func _create_invisible_boundary(boundary_position: Vector3, boundary_size: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = boundary_position
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = boundary_size
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	_container.add_child(body)


func _place_model(
	asset_id: String,
	local_position: Vector3,
	local_rotation: Vector3,
	target_longest_dimension: float,
	collision_size: Vector3 = Vector3.ZERO,
	parent_override: Node3D = null
) -> Node3D:
	var prototype: Node3D = StartupPreloader.get_environment_prototype(asset_id)
	if prototype == null:
		push_error("REQUIRED EXPANSION MODEL MISSING: %s" % asset_id)
		return null

	var model: Node3D = prototype.duplicate() as Node3D
	if model == null:
		push_error("REQUIRED EXPANSION MODEL COULD NOT DUPLICATE: %s" % asset_id)
		return null

	var parent_node: Node3D = parent_override if parent_override != null else _container
	var anchor: Node3D = Node3D.new()
	_instance_counter += 1
	anchor.name = "PHX_%s_%03d" % [asset_id, _instance_counter]
	anchor.position = local_position
	anchor.rotation_degrees = local_rotation
	parent_node.add_child(anchor)
	anchor.add_child(model)
	_normalize_model(model, target_longest_dimension)

	if collision_size.length_squared() > 0.0001:
		var collision_body: StaticBody3D = StaticBody3D.new()
		collision_body.position.y = collision_size.y * 0.5
		var collision_shape: CollisionShape3D = CollisionShape3D.new()
		var box_shape: BoxShape3D = BoxShape3D.new()
		box_shape.size = collision_size
		collision_shape.shape = box_shape
		collision_body.add_child(collision_shape)
		anchor.add_child(collision_body)
	return anchor


func _normalize_model(model: Node3D, target_longest_dimension: float) -> void:
	var bounds: AABB = _calculate_bounds(model)
	var longest_dimension: float = maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if longest_dimension <= 0.001:
		return
	var scale_factor: float = target_longest_dimension / longest_dimension
	model.scale = Vector3.ONE * scale_factor
	var center: Vector3 = bounds.get_center()
	model.position = Vector3(
		-center.x * scale_factor,
		-bounds.position.y * scale_factor,
		-center.z * scale_factor
	)


func _calculate_bounds(model: Node3D) -> AABB:
	var bounds: AABB = AABB()
	var has_bounds: bool = false
	var mesh_nodes: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
	for node: Node in mesh_nodes:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var relative_transform: Transform3D = model.global_transform.affine_inverse() * mesh_instance.global_transform
		var mesh_bounds: AABB = relative_transform * mesh_instance.get_aabb()
		if not has_bounds:
			bounds = mesh_bounds
			has_bounds = true
		else:
			bounds = bounds.merge(mesh_bounds)
	return bounds


func _required_material(material_id: String) -> StandardMaterial3D:
	var source: StandardMaterial3D = StartupPreloader.get_environment_material(material_id)
	if source == null:
		push_error("REQUIRED EXPANSION MATERIAL MISSING: %s" % material_id)
		return null
	return source.duplicate() as StandardMaterial3D


func _add_omni_light(
	light_position: Vector3,
	light_color: Color,
	energy: float,
	range_value: float
) -> void:
	var light: OmniLight3D = OmniLight3D.new()
	light.position = light_position
	light.light_color = light_color
	light.light_energy = energy
	light.omni_range = range_value
	light.shadow_enabled = true
	_container.add_child(light)
