extends Node


func _ready() -> void:
	_apply_when_ready.call_deferred()


func _apply_when_ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var scene_root: Node = get_parent()
	if scene_root == null:
		return

	var areas: Array[Node] = scene_root.find_children("*", "Area3D", true, false)
	for node: Node in areas:
		var area: Area3D = node as Area3D
		if area == null or not area.has_method("interact"):
			continue
		_configure_interaction(area)


func _configure_interaction(area: Area3D) -> void:
	var interaction_name: String = str(area.name)
	var prompt_text: String = str(area.get("prompt_text"))
	var title: String = _title_from_prompt(prompt_text)
	var context: String = "HOLD TO INTERACT"
	var hold_duration: float = 0.42
	var marker_height: float = 2.35
	var marker_color: Color = Color("bb62d9")
	var replacement_message: String = ""
	var suppress_message: bool = false

	if interaction_name == "MemorialInteraction":
		title = "THE MEMORIAL"
		context = "EXAMINE"
		hold_duration = 0.65
		marker_height = 3.5
		marker_color = Color("d46b87")
		area.set("prompt_text", "Examine the memorial")
		replacement_message = "A fresh red flower rests beneath names erased by weather and time. You remember leaving it here. That memory cannot belong to you."
	elif interaction_name == "WomanInteraction":
		title = "THE WOMAN AT THE GATE"
		context = "SPEAK"
		hold_duration = 0.55
		marker_height = 3.0
		marker_color = Color("9d8de0")
		suppress_message = true
	elif interaction_name.begins_with("AnchorInteraction_"):
		title = "GRAVITY ANCHOR"
		context = "STABILIZE"
		hold_duration = 0.85
		marker_height = 3.0
		marker_color = Color("9c6cff")
	elif interaction_name.begins_with("Breaker_"):
		title = "POWER BREAKER"
		context = "RESTORE POWER"
		hold_duration = 0.78
		marker_height = 2.8
		marker_color = Color("ef5aaa")
		if interaction_name == "Breaker_bar":
			replacement_message = "Power returns to the shelves. In every bottle's reflection, you are smiling beside someone different."
		elif interaction_name == "Breaker_stage":
			replacement_message = "The speakers wake without a song. The crowd mouths lyrics you have not written yet."
		else:
			replacement_message = "From the balcony, every dancer wears your skull beneath someone else's clothes."
	elif interaction_name == "BackstageExit":
		title = "BENEATH THE STAGE"
		context = "DESCEND"
		hold_duration = 0.90
		marker_height = 3.0
		marker_color = Color("d04e9b")
		replacement_message = "The woman is gone. Beneath the stage, a stairwell exhales air colder than the void."
	elif interaction_name.begins_with("Journal_"):
		title = "RECOVERED JOURNAL"
		context = "READ"
		hold_duration = 0.58
		marker_height = 2.4
		marker_color = Color("7f96df")
	elif interaction_name == "ConfrontWoman":
		title = "THE WOMAN"
		context = "CONFRONT"
		hold_duration = 0.72
		marker_height = 3.0
		marker_color = Color("bc6fa4")
		suppress_message = true
	elif interaction_name == "NightclubEntrance":
		title = "THE THRESHOLD"
		context = "CROSS OVER"
		hold_duration = 0.95
		marker_height = 4.2
		marker_color = Color("ed5eb4")
	elif interaction_name.contains("Exit") or interaction_name.contains("Entrance"):
		title = "THE WAY FORWARD"
		context = "ENTER"
		hold_duration = 0.80
		marker_color = Color("d85aa6")

	area.set("interaction_title", title)
	area.set("interaction_context", context)
	area.set("hold_duration", hold_duration)
	area.set("marker_height", marker_height)
	area.set("marker_color", marker_color)
	area.set("suppress_message", suppress_message)
	if not replacement_message.is_empty():
		area.set("interaction_message", replacement_message)
	if area.has_method("refresh_release_presentation"):
		area.call("refresh_release_presentation")


func _title_from_prompt(prompt_text: String) -> String:
	var cleaned: String = prompt_text.strip_edges()
	if cleaned.is_empty():
		return "MEMORY ECHO"
	return cleaned.to_upper()
