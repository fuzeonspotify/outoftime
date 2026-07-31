extends Node

signal library_ready
signal pack_ready(pack_id: String)


func _ready() -> void:
	library_ready.emit.call_deferred()


func is_ready() -> bool:
	return true


func get_stream(_cue_id: String) -> AudioStream:
	return null
