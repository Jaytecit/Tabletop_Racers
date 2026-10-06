extends RefCounted
# Reuse the validated atomic store for machine preferences, never person rewards.
const STORE: Script = preload("res://scripts/profile_store.gd")
var path: String = "user://machine_settings.json"
var read_only: bool = false
var data: Dictionary = STORE.defaults().setup

func load_settings(legacy: Dictionary) -> void:
	var store: RefCounted = STORE.new()
	store.path = path
	store.load_profile()
	if FileAccess.file_exists(path):
		data = store.data.setup.duplicate(true)
		read_only = read_only or store.read_only or store.status.begins_with("Unreadable")
	else:
		data = legacy.duplicate(true)
		if not read_only: save_settings()

func save_settings() -> Error:
	if read_only: return ERR_UNAVAILABLE
	var store: RefCounted = STORE.new()
	store.path = path
	store.data.setup = data
	return store.save_profile()
