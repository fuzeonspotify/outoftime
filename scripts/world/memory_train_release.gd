extends "res://scripts/world/memory_train.gd"


func _set_section(stage: int) -> void:
	for child: Node in _section_root.get_children():
		child.queue_free()
	# Keep the outside-night references alive between train-car changes. Invalid
	# car-window references are removed by the release scrolling pass below.
	match stage:
		STAGE_PASSENGER:
			_build_passenger_car()
		STAGE_SWITCH:
			_build_switch_car()
		STAGE_ROOF:
			_build_roof_section()
		STAGE_ENGINE, STAGE_FINALE:
			_build_engine_car()


func _update_scrolling_details(delta: float) -> void:
	_section_scroll += _train_speed * delta
	var active_details: Array[Node3D] = []
	for detail: Node3D in _scrolling_details:
		if not is_instance_valid(detail):
			continue
		active_details.append(detail)
		var speed_scale: float = float(
			detail.get_meta("scenery_speed", detail.get_meta("scroll_speed", 1.0))
		)
		detail.position.z += _train_speed * speed_scale * delta
		if detail.position.z > 36.0:
			detail.position.z -= 92.0
	_scrolling_details = active_details


func _start_engine_gate() -> void:
	var gate_sequence: Array[int] = [0, 2, 1]
	_required_lane = gate_sequence[_engine_gate_index]
	_required_lane_timer = 3.4
	var lane_names: Array[String] = [
		"LEFT PRESSURE BANK",
		"CENTER MEMORY CORE",
		"RIGHT BRAKE BANK"
	]
	_objective_label.text = "ALIGN: %s" % lane_names[_required_lane]
	_train_audio.call("play_memory_pulse")
	_pulse_lane_beacon(_required_lane)
