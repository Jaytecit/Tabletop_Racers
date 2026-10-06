extends "res://tests/autopilot/probe_base.gd"
func _ready() -> void:
	await super._ready()
	await settle(20)
	var app: Node = get_tree().current_scene
	var race: Node = app.get_node("Race")
	report("app_booted",app.scene_file_path=="res://scenes/app.tscn")
	report("vehicle_scenes",[race.cars[0].scene_file_path,race.cars[1].scene_file_path,race.cars[2].scene_file_path,race.cars[3].scene_file_path])
	report("tuning",[race.cars[0].top_speed,race.cars[1].top_speed,race.cars[2].top_speed,race.cars[3].top_speed])
	save_frame("00_menu")
	# Use the same buggy physics and command interface, with its existing AI driving.
	race.player_car.ai = true
	await press("start_race")
	var last_lap: int = 0
	for i: int in range(13000):
		await get_tree().physics_frame
		if race.player_car.laps>last_lap:
			last_lap = race.player_car.laps
			save_frame("lap_%d" % last_lap)
		if race.phase==3: break
	report("state",race.diagnostic_state())
	report("results",race.session.results.duplicate(true))
	report("passed",race.phase==3 and race.player_car.laps==3 and race.session.results.size()==4)
	await settle()
	save_frame("01_results")
	race.start_race()
	await get_tree().physics_frame
	report("retry_clean",race.phase==1 and race.race_time==0.0 and race.player_car.laps==0 and race.session.results.is_empty())
	finish()
