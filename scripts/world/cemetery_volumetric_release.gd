extends Node


func _ready() -> void:
	_apply_volumetric_cemetery.call_deferred()


func _apply_volumetric_cemetery() -> void:
	# The base Cemetery, exact-model pass, expansion pass, and eerie-bat pass all
	# adjust lighting during their deferred setup. Run last so the final values
	# are deterministic instead of depending on child-ready ordering.
	for _frame_index: int in range(14):
		await get_tree().process_frame

	var cemetery: Node3D = get_parent() as Node3D
	if cemetery == null:
		return

	var environment_nodes: Array[Node] = cemetery.find_children(
		"*",
		"WorldEnvironment",
		true,
		false
	)
	if environment_nodes.is_empty():
		push_error("CEMETERY FOG ERROR: no WorldEnvironment was found.")
		return

	var world_environment: WorldEnvironment = environment_nodes[0] as WorldEnvironment
	if world_environment == null or world_environment.environment == null:
		push_error("CEMETERY FOG ERROR: the WorldEnvironment has no Environment resource.")
		return

	var environment: Environment = world_environment.environment

	# Preserve the eerie night grade while raising visibility enough to read the
	# path, graves, bats and the hooded woman without flattening the shadows.
	environment.background_energy_multiplier = 0.40
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("34445f")
	environment.ambient_light_energy = 0.46
	environment.fog_enabled = true
	environment.fog_light_color = Color("2b394d")
	environment.fog_light_energy = 0.54
	environment.fog_density = 0.032
	environment.fog_height = 1.05
	environment.fog_height_density = 0.30
	environment.fog_sky_affect = 0.78
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 0.86
	environment.adjustment_contrast = 1.13
	environment.adjustment_saturation = 0.72

	# True volumetric fog. This requires Forward+, which is now enforced in
	# project.godot. The relatively short range keeps froxel detail around the
	# player and lets lantern and moonlight form visible shafts through the mist.
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.024
	environment.volumetric_fog_albedo = Color("a6b2c2")
	environment.volumetric_fog_emission = Color("121a2a")
	environment.volumetric_fog_emission_energy = 0.48
	environment.volumetric_fog_length = 58.0
	environment.volumetric_fog_detail_spread = 2.25
	environment.volumetric_fog_ambient_inject = 0.52
	environment.volumetric_fog_gi_inject = 0.0
	environment.volumetric_fog_anisotropy = 0.34
	environment.volumetric_fog_sky_affect = 0.52
	environment.volumetric_fog_temporal_reprojection_enabled = true
	environment.volumetric_fog_temporal_reprojection_amount = 0.82

	var directional_nodes: Array[Node] = cemetery.find_children(
		"*",
		"DirectionalLight3D",
		true,
		false
	)
	for node: Node in directional_nodes:
		var moonlight: DirectionalLight3D = node as DirectionalLight3D
		if moonlight == null:
			continue
		moonlight.light_energy = 0.72
		moonlight.light_volumetric_fog_energy = 1.25
		moonlight.shadow_enabled = true

	var omni_nodes: Array[Node] = cemetery.find_children("*", "OmniLight3D", true, false)
	for node: Node in omni_nodes:
		var light: OmniLight3D = node as OmniLight3D
		if light == null:
			continue
		var light_name: String = str(light.name)
		if light_name.contains("PhysicalImpactFlash"):
			light.light_volumetric_fog_energy = 0.0
			continue
		if light_name.contains("RiggedGhostWoman"):
			light.light_volumetric_fog_energy = 0.68
			continue
		light.light_energy *= 1.18
		light.omni_range *= 1.06
		light.light_volumetric_fog_energy = 1.10

	var gate_fill: OmniLight3D = cemetery.get_node_or_null(
		"EerieCemeteryFill/GateColdFill"
	) as OmniLight3D
	if gate_fill != null:
		gate_fill.light_energy = 0.90
		gate_fill.light_volumetric_fog_energy = 1.55

	var memorial_fill: OmniLight3D = cemetery.get_node_or_null(
		"EerieCemeteryFill/MemorialBloodFill"
	) as OmniLight3D
	if memorial_fill != null:
		memorial_fill.light_energy = 0.58
		memorial_fill.light_volumetric_fog_energy = 1.25
