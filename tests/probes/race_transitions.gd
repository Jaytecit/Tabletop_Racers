extends "res://tests/autopilot/probe_base.gd"
func _ready() -> void:
	await super._ready()
	await settle()
	var app: Node = get_tree().current_scene
	var race: Node = app.get_node("Race")
	await press("start_race")
	await press("pause_race")
	report("pause_input",race.paused_race)
	await press("restart")
	report("restart_input",race.phase==1 and not race.paused_race and race.player_car.laps==0)
	await press("menu")
	report("menu_input",race.phase==0 and race.menu.visible and race.session.results.is_empty())
	race.return_to_2d()
	for i: int in range(4): await get_tree().process_frame
	report("fallback_2d",get_tree().current_scene.scene_file_path=="res://main.tscn")
	var error: Error = get_tree().change_scene_to_file("res://scenes/app.tscn")
	for i: int in range(4): await get_tree().process_frame
	report("returned_to_3d",error==OK and get_tree().current_scene.get_node("Race").phase==0)
	# Hold restart across frames: one reset, then the countdown advances.
	race = get_tree().current_scene.get_node("Race")
	Input.action_press("restart")
	for i: int in range(12): await get_tree().physics_frame
	Input.action_release("restart")
	report("held_restart_no_repeat",race.countdown<3.7)
	report("passed",_reports.pause_input and _reports.restart_input and _reports.menu_input and _reports.fallback_2d and _reports.returned_to_3d and _reports.held_restart_no_repeat)
	finish()
