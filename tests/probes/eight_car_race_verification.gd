extends "res://tests/probes/eight_car_course_survey.gd"
func run() -> void:
	Engine.max_fps = 60
	await select_course("moonlight_junk_heap","quick")
	check(race.cars.size()==8 and race.session.progress.records.size()==8,"eight_grid")
	var ids: Array = []
	for car: CharacterBody3D in race.cars:
		ids.append(race.identities.racers[car.player].portrait_id)
		check(car.get_node("VehicleLamps/TaillightL").light_color.is_equal_approx(car.get_meta("vehicle_colour")),"light_%d"%car.player)
	check(ids.size()==8 and ids.count(0)==1 and ids.count(7)==1,"unique_identities")
	check(race.player_car.ai,"automated_human_slot_only_for_verification")
	save_frame("eight_grid")
	race.session.toggle_pause()
	var paused_time: float = race.race_time
	await settle(10)
	check(is_equal_approx(paused_time,race.race_time),"pause")
	race.session.toggle_pause()
	var wall: Array = []
	var physics: Array = []
	var gpu: Array = []
	var previous: int = Time.get_ticks_usec()
	var frames: int = 0
	var captured: bool = false
	while race.phase in [1,2,5] and frames<20000:
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		if race.phase in [2,5]:
			wall.append((now-previous)/1000.0)
			physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()))
		previous = now
		frames += 1
		if not captured and race.race_time>8.0:
			captured = true
			save_frame("eight_racing")
	check(race.phase==3,"race_results")
	report("classification",race.session.results)
	check(race.session.results.size()==8,"eight_classified")
	var all_finished: bool = true
	var incidents: Array = []
	for car: CharacterBody3D in race.cars:
		all_finished = all_finished and car.finish_time>=0.0
		incidents.append({"player":car.player,"finish":car.finish_time,"crashes":car.crashes,"contacts":car.impacts,"laps":car.laps,"penalty":race.session.progress.records[car.player].penalty})
	report("all_finished",all_finished)
	report("incidents",incidents)
	check(all_finished,"all_eight_finish")
	report("performance",{"wall_ms":summary(wall),"physics_ms":summary(physics),"gpu_ms":summary(gpu)})
	await get_tree().create_timer(1.4).timeout
	save_frame("eight_results")
	check(race.results_panel.get_node("Podium").get_node_or_null("Driver7")!=null,"eighth_result_portrait")
	# The ordinary player slot resumes human control when a new race starts.
	race.player_car.ai = false # Undo only the probe's driving helper.
	race.race_mode = "quick"
	race.rival_count = 3
	race.show_menu()
	check(race.cars.size()==4 and not race.all_cars[7].visible and race.all_cars[7].collision_layer==0,"return_four")
	race.rival_count = 0
	race.show_menu()
	check(race.cars.size()==1,"return_solo")
	race.rival_count = 7
	race.show_menu()
	race.start_race()
	check(race.cars.size()==8 and not race.player_car.ai,"retry_human_seven_ai")
	var raw: Dictionary = race.profile.data.duplicate(true)
	raw.quick_race.rivals = 7
	check(race.profile.validate(raw).quick_race.rivals==7,"saved_seven_rivals")
	check(race.profile.valid_record_key(race.profile.record_key("quick",3,7,2,"moonlight_junk_heap")),"eight_record_key")
	race.race_mode = "tournament"
	race.configure_quick_race()
	check(race.cars.size()==4,"tournament_four_preserved")
