extends "res://scripts/world/kenney_level_expansion.gd"


func _start_expansion() -> void:
	_root = get_parent() as Node3D
	if _root == null:
		return
	if _root.get_node_or_null("KenneyLevelModels") != null:
		return

	await get_tree().process_frame
	_ensure_cache_directories()
	if not _all_assets_cached():
		return

	_model_container = Node3D.new()
	_model_container.name = "KenneyLevelModels"
	_root.add_child(_model_container)
	_build_scene_expansion(str(_root.name))


func _load_prototype(source_id: String, file_name: String) -> Node3D:
	var cache_key: String = "%s/%s" % [source_id, file_name]
	if _prototype_cache.has(cache_key):
		return _prototype_cache[cache_key] as Node3D

	var startup_prototype: Node3D = StartupPreloader.get_level_prototype(source_id, file_name)
	if startup_prototype != null:
		_prototype_cache[cache_key] = startup_prototype
		return startup_prototype

	return super._load_prototype(source_id, file_name)
