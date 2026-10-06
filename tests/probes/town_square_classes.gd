extends "res://tests/probes/town_square_verification.gd"

func _ready() -> void:
	await settle(4)
	var app: Node = get_tree().current_scene
	race = app.get_node("Race")
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.device = -1
	race.controller.using_pad = false
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	app.get_node("Opening").queue_free()
	get_tree().paused = false
	race.get_node("HUD").show()
	check(race.profile.read_only,"read_only")
	race.profile_selected = true
	check(select_test_course("town_square"),"selected")
	var runs: Array[Dictionary] = []
	for vehicle: String in ["buggy","monster_truck","racing_car","drift_car","speedboat"]:
		race.menu_flow.choose_mode("freestyle")
		check(race.set_vehicle(vehicle),"selected_"+vehicle)
		race.profile.vehicle().stats = preload("res://scripts/vehicles/player_stats.gd").neutral()
		race.garage.apply_stats(race)
		race.rival_count = 0
		race.race_laps = 1
		race.difficulty = 2
		race.start_race()
		check(race.cars.size()==1 and race.player_car.base_tuning.id==vehicle,"class_"+vehicle)
		race.player_car.ai = true
		race.player_car.ai_driver.rng.seed = 64
		race.begin_countdown()
		for frame: int in range(6000):
			await get_tree().physics_frame
			if frame%600==0:
				var progress: FileAccess = FileAccess.open(summer_out_dir.path_join("class_progress.json"),FileAccess.WRITE)
				progress.store_string(JSON.stringify({"vehicle":vehicle,"race_time":race.race_time,"cars":live_progress().cars},"\t"))
				progress.close()
			if race.phase==3: break
		var car: CharacterBody3D = race.player_car
		var penalty: float = race.session.progress.records[1].penalty
		check(race.phase==3 and car.laps==1 and car.finish_time>0.0,"finish_"+vehicle)
		check(car.crashes==0 and car.ai_driver.recoveries==0 and penalty==0.0,"clean_"+vehicle)
		runs.append({"vehicle":vehicle,"time":car.finish_time,"crashes":car.crashes,"recoveries":car.ai_driver.recoveries,"penalty":penalty})
		await settle(30)
		save_frame(vehicle+"_results")
		race.show_menu()
	check(race.profile.read_only,"still_read_only")
	report("runs",runs)
	report("failures",failures)
	report("passed",failures.is_empty())
	for node: Node in get_tree().root.find_children("*","AudioStreamPlayer",true,false): node.stop()
	await settle(5)
	finish()
