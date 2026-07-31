extends "res://scripts/bootstrap/startup_preloader.gd"


func _prepare_all() -> void:
	if _preparing or _ready_for_gameplay:
		return
	_update_progress(0.01, "WARMING LOCAL SOUNDTRACK")
	MusicDirector.prepare_music_library()
	while not MusicDirector.is_music_library_ready():
		await get_tree().process_frame
	await super._prepare_all()
