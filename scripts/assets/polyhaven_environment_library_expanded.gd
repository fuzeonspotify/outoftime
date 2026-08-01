extends "res://scripts/assets/polyhaven_environment_library_release.gd"


func _init() -> void:
	# Older Poly Haven assets use case-sensitive API identifiers. The game-facing
	# IDs stay lowercase and fall back to the official legacy slug when required.
	_legacy_api_ids["sofa_01"] = "Sofa_01"
	_legacy_api_ids["classic_nightstand_01"] = "ClassicNightstand_01"
	_legacy_api_ids["wooden_table_03"] = "WoodenTable_03"
	_legacy_api_ids["television_01"] = "Television_01"

	# The ground-level marble busts are no longer part of False Heaven.
	_required_model_ids.erase("marble_bust_01")

	var expanded_model_ids: Array[String] = [
		"planter_box_01",
		"painted_wooden_sofa",
		"ceramic_vase_01",
		"covered_car",
		"utility_box_01",
		"metal_trash_can",
		"sofa_02",
		"modern_coffee_table_01",
		"television_01",
		"cassette_player",
		"sofa_01",
		"classic_nightstand_01",
		"wooden_table_03",
		"wooden_candlestick",
		"side_table_01",
		"plastic_monobloc_chair_01"
	]
	for asset_id: String in expanded_model_ids:
		if not _required_model_ids.has(asset_id):
			_required_model_ids.append(asset_id)
