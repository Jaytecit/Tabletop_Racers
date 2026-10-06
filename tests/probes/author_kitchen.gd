extends SceneTree
func _initialize() -> void:
	load("res://scripts/tracks/kitchen_art.gd").build_all()
	quit()
