extends "res://tests/probes/race_quality_verification.gd"

func _ready() -> void:
	var deadline: Timer = Timer.new()
	deadline.one_shot = true
	deadline.wait_time = summer_max_seconds
	deadline.timeout.connect(_on_deadline)
	add_child(deadline)
	deadline.start()
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
	race.menu_flow.choose_mode("freestyle")
	check(race.course.select("toys_r_you"),"selected")
	race.rival_count = 0
	race.race_laps = 3
	race.difficulty = 2
	race.camera_driver.mode = 2
	var start_station: float = 122.0
	var requested_start: String = OS.get_environment("TABLETOP_RAMP_START")
	if requested_start.is_valid_float(): start_station = requested_start.to_float()
	var speed_cap: float = 0.0
	var requested_speed: String = OS.get_environment("TABLETOP_RAMP_SPEED")
	if requested_speed.is_valid_float(): speed_cap = requested_speed.to_float()
	var cases: Array[Dictionary] = []
	for id: String in ["buggy","drift_car","racing_car","monster_truck","speedboat"]:
		race.set_vehicle(id)
		race.profile.vehicle().stats = preload("res://scripts/vehicles/player_stats.gd").neutral()
		race.garage.apply_stats(race)
		for lane: float in [-0.5,0.5]:
			race.start_race()
			race.begin_countdown()
			race.session.countdown = 0.81
			await settle_physics(3)
			var car: CharacterBody3D = race.player_car
			car.ai = true
			car.lane = lane
			car.reset_car(start_station,lane)
			if speed_cap>0.0: car.top_speed = speed_cap/car.tuning.speed_factor(race.track.at(start_station).surface,true)
			car.velocity = Vector3(cos(car.heading),0,sin(car.heading))*10.0
			car.ai_driver.rng.seed = 256
			race.session.progress.reset(race.cars,race.track.total_length)
			# This is a local mid-route approach, not a race from the start line.
			# Seed the next checkpoint consistently so its grace timeout cannot
			# masquerade as a failed physics transition during the longer fixture.
			car.gate = int(floor(fposmod(start_station-race.track.definition.start_station,race.track.total_length)/(race.track.total_length/race.track.definition.gate_count)))+1
			race.session.progress.records[car.player].gate = car.gate
			var contacts: Array[Dictionary] = []
			var captured: bool = false
			for frame: int in range(480 if speed_cap>0.0 else 360):
				await get_tree().physics_frame
				if speed_cap>0.0 and frame==240: save_frame(id+str(lane)+"_slow_slope")
				for index: int in range(car.get_slide_collision_count()):
					if contacts.size()>=24: break
					var contact: KinematicCollision3D = car.get_slide_collision(index)
					if absf(contact.get_normal().y)>0.6: continue
					contacts.append({"station":car.station,"normal":str(contact.get_normal()),"point":str(contact.get_position()),"local_point":str(race.to_local(contact.get_position())),"car_position":str(car.position),"collider":str(contact.get_collider().get_path()),"speed":car.velocity.length()})
					if not captured:
						save_frame(id+str(lane)+"_contact")
						captured = true
			cases.append({"id":id,"lane":lane,"station":car.station,"impacts":car.impacts,"crashes":car.crashes,"contacts":contacts,"start":start_station,"speed_cap":speed_cap,"vertical_velocity":car.velocity.y,"airborne":car.airborne,"lift_speed":car.lift_speed,"penalty":race.session.progress.records[car.player].penalty})
			check(car.station>start_station+(40.0 if speed_cap>0.0 else 23.0) and car.crashes==0 and absf(car.velocity.y)<20.0,"passes_transition_"+id+str(lane))
			check(car.impacts==0,"clears_ramp_lip_"+id+str(lane))
			race.show_menu()
			await settle(3)
	report("cases",cases)
	report("failures",failures)
	report("passed",failures.is_empty())
	finish()
