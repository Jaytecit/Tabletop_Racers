extends "res://tests/probes/race_quality_ai_verification.gd"
# Isolated promotional footage: actual AI driving, production cameras and physics.
func _process(_delta: float) -> void:
	pass

func _ready() -> void:
	await super_ready()
	var app: Node = get_tree().current_scene
	race = app.get_node("Race")
	check(race.profile.read_only,"read_only_fixture")
	race.profile_directory.read_only = true
	race.machine_settings.read_only = true
	race.profile_selected = true
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.using_pad = false
	race.controller.device = -1
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	app.get_node("Opening").queue_free()
	get_tree().paused = false
	get_tree().root.content_scale_size = Vector2i(1920,1080)
	race.menu_flow.choose_mode("freestyle")
	var course_id: String = OS.get_environment("PROMO_COURSE")
	check(preload("res://scripts/race/race_lighting.gd").time_for(course_id)=="DAY","daytime_only")
	check(race.course.select(course_id),"course_selected")
	if not failures.is_empty():
		report("passed",false)
		finish()
		return
	race.rival_count = 1
	if not OS.get_environment("PROMO_RIVALS").is_empty(): race.rival_count = OS.get_environment("PROMO_RIVALS").to_int()
	race.race_laps = 9
	race.difficulty = 2
	race.race_seed = 6106
	var shots: Array[Dictionary] = []
	var rejected: Array[Dictionary] = []
	var views: Array[int] = [0,1,2]
	if not OS.get_environment("PROMO_VIEW").is_empty(): views = [OS.get_environment("PROMO_VIEW").to_int()]
	for vehicle: String in OS.get_environment("PROMO_VEHICLES").split(","):
		check(vehicle!="speedboat","land_vehicle_"+vehicle)
		race.show_menu()
		check(race.set_vehicle(vehicle),"vehicle_"+vehicle)
		race.profile.vehicle().stats = preload("res://scripts/vehicles/player_stats.gd").neutral()
		race.garage.apply_stats(race)
		race.start_race()
		race.player_car.ai = true
		race.begin_countdown()
		race.session.countdown = 0.81
		await settle_physics(120)
		race.get_node("HUD").hide()
		for view: int in views:
			var fraction: float = [0.08,0.38,0.68][view]
			if not OS.get_environment("PROMO_FRACTION").is_empty(): fraction = OS.get_environment("PROMO_FRACTION").to_float()
			if view==2 and not OS.get_environment("PROMO_CLOSE_FRACTION").is_empty(): fraction = OS.get_environment("PROMO_CLOSE_FRACTION").to_float()
			var name: String = "%s_%s_%s"%[course_id,vehicle,["chase","overhead","close_chase"][view]]
			var accepted: bool = false
			for attempt: int in range(6):
				var section: float = fposmod(fraction+attempt*0.13,0.94)
				for index: int in range(race.cars.size()):
					var car: CharacterBody3D = race.cars[index]
					car.reset_car(race.track.total_length*section-float(index)*6.0,0.0)
					car.ai = true
					car.effects.clear()
				race.feedback.clear()
				race.camera_driver.mode = view
				race.camera_driver.reset(race.camera,race.player_car)
				await settle_physics(90)
				var folder: String = summer_out_dir+"/"+name+"_take%d"%(attempt+1)
				DirAccess.make_dir_recursive_absolute(folder)
				var begin_position: Vector3 = race.player_car.position
				var shot: Dictionary = {"name":name,"folder":folder.get_file(),"course":course_id,"vehicle":vehicle,"camera":race.camera_driver.MODES[view],"route_fraction":section,"start_station":race.player_car.station,"start_position":str(begin_position),"start_time":race.race_time,"start_frame":Engine.get_process_frames(),"states":{},"frames":120,"clean":true,"visible_vehicles":race.cars.size(),"time_of_day":"DAY"}
				for frame: int in range(120):
					await RenderingServer.frame_post_draw
					var image: Image = get_viewport().get_texture().get_image()
					if image.save_jpg(folder+"/frame_%03d.jpg"%frame,0.96)!=OK: failures.append("save_"+name)
					var state_key: String = str(race.player_car.state)
					shot.states[state_key] = int(shot.states.get(state_key,0))+1
					for car: CharacterBody3D in race.cars:
						if car.state!=0 or car.crashes!=0 or car.impacts!=0: shot.clean = false
				shot["end_frame"] = Engine.get_process_frames()
				shot["end_station"] = race.player_car.station
				shot["end_time"] = race.race_time
				shot["end_position"] = str(race.player_car.position)
				shot["motion_distance"] = race.player_car.position.distance_to(begin_position)
				if not shot.clean:
					rejected.append(shot)
					report("rejected_takes",rejected)
					continue
				check(shot.motion_distance>1.0,"motion_"+name)
				check(shot.end_time-shot.start_time>3.8,"duration_"+name)
				check(race.profile.read_only,"read_only_"+name)
				shots.append(shot)
				report("shots",shots)
				accepted = true
				break
			check(accepted,"clean_take_"+name)
	report("failures",failures)
	report("passed",failures.is_empty() and shots.size()==views.size()*OS.get_environment("PROMO_VEHICLES").split(",").size())
	finish()

func super_ready() -> void:
	DirAccess.make_dir_recursive_absolute(summer_out_dir)
	var deadline: Timer = Timer.new()
	deadline.one_shot = true
	deadline.wait_time = summer_max_seconds
	deadline.timeout.connect(_on_deadline)
	add_child(deadline)
	deadline.start()
	await settle(5)
