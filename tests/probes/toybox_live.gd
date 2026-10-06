extends Node
# Isolated profile for interactive runtime verification; no owner save writes.
func _ready() -> void:
	var app: Node = load("res://scenes/app.tscn").instantiate()
	var race: Node = app.get_node("Race")
	race.profile.path = "user://toybox_live_verify.json"
	race.profile.read_only = true
	add_child.call_deferred(app)
	await get_tree().process_frame
	race.profile.read_only = true
	race.controller.set_physics_process(false)
	race.controller.set_process_input(false)
	race.controller.device = -1
	race.controller.using_pad = false
	race.race_mode = "quick"
	race.rival_count = 0
	race.course.select("toybox_trestle")
	race.show_menu()
