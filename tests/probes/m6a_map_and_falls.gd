extends "res://tests/autopilot/probe_base.gd"
var failures: Array[String] = []
func check(label: String, value: bool) -> void:
	if not value: failures.append(label)
func _ready() -> void:
	await super._ready()
	await settle(4)
	var race: Node = get_tree().current_scene.get_node("Race")
	race.profile.path = "user://m6a_map_test.json"
	race.profile.data = race.profile.defaults()
	var map: Control = race.get_node("HUD/RaceMinimap")
	for id: String in ["felt_sprint","card_bridge","game_table","practice_patch"]:
		race.race_mode = "quick"
		race.rival_count = 3
		race.course.select(id)
		race.start_race()
		await settle(3)
		check(id+"_route",map.route==race.track.definition and map.segments.size()==race.track.starts.size())
		check(id+"_cars",race.cars.size()==(1 if id=="practice_patch" else 4))
		for point: Vector3 in race.track.starts:
			check(id+"_fit",Rect2(Vector2(8,8),map.size-Vector2(16,16)).has_point(map.map_position(point)))
		var built: int = map.rebuilds
		race.start_race()
		await settle(3)
		check(id+"_retry_cached",map.rebuilds==built)
		race.paused_race = true
		var position_before: Vector3 = race.player_car.position
		for frame: int in range(10): await get_tree().physics_frame
		check(id+"_pause",race.player_car.position==position_before)
		race.show_menu()
		await settle(2)
		check(id+"_hidden",not map.visible)
	for mode: String in ["trial","cup"]:
		race.race_mode = mode
		race.course.select("felt_sprint")
		race.start_race()
		await settle(3)
		check(mode+"_map",map.visible and map.route==race.track.definition)
		check(mode+"_cars",race.cars.size()==(1 if mode=="trial" else 4))
		if mode=="cup":
			for id: String in ["card_bridge","game_table"]:
				race.course.select(id)
				await settle(2)
				map.rebuild()
				check(id+"_cup_transition",map.route==race.track.definition)
	race.race_mode = "quick"
	race.rival_count = 0
	race.course.select("card_bridge")
	race.start_race()
	race.session.change_phase(2)
	var car: CharacterBody3D = race.player_car
	var spans: Array[float] = []
	for section_index: int in [12,14,16]:
		for sample_index: int in range(race.track.section_ids.size()):
			if race.track.section_ids[sample_index]==section_index:
				spans.append(race.track.lengths[sample_index]+(15.0 if section_index==12 else 1.0))
				break
	check("no_rails",not race.get_node("CourseEnvironment/CardBridge").has_node("GuardRails"))
	var samples: int = 0
	for station: int in range(int(race.track.total_length)):
		var route: Dictionary = race.track.at(float(station))
		if route.layer!=1: continue
		check("raised_width",route.edge=="raised" and is_equal_approx(route.width,3.8))
		for fraction: float in [-0.7,0.0,0.7]:
			var normal: Vector2 = race.track.direction(float(station)).orthogonal()
			var position3: Vector3 = route.position+Vector3(normal.x,0,normal.y)*fraction*route.width*0.5
			var support: Dictionary = car.physical_support(position3)
			check("route_supported_%d" % station,race.track.project_3d(position3,float(station)).supported)
			check("supported_deck_%d" % station,not support.is_empty() and absf(support.position.y-position3.y)<0.08)
			samples += 1
	for station: float in spans:
		for side: float in [-1.0,1.0]:
			car.reset_car(station,0.0)
			race.session.progress.rebase(car)
			race.session.progress.records[1].legal_station = station
			race.session.progress.records[1].gate = int(fposmod(station-race.track.definition.start_station,race.track.total_length)/(race.track.total_length/8.0))+1
			race.session.progress.records[1].distance = fposmod(station-race.track.definition.start_station,race.track.total_length)
			car.gate = race.session.progress.records[1].gate
			var accepted: float = race.session.progress.records[1].distance
			car.heading += side*PI*0.5
			Input.action_press("p1_go")
			for frame: int in range(55):
				await get_tree().physics_frame
				if car.state==2: break
			Input.action_release("p1_go")
			report("exit_%f_%f" % [station,side],{"state":car.state,"ai":car.ai,"phase":race.phase,"speed":car.velocity.length(),"position":str(car.position),"command":car.player_input.read_commands(car)})
			check("drive_off_%f_%f" % [station,side],car.state==2)
			var height: float = car.position.y
			for frame: int in range(30): await get_tree().physics_frame
			check("visible_fall",car.position.y<height-0.3)
			for frame: int in range(140):
				await get_tree().physics_frame
				if car.state==0: break
			check("legal_return",car.state==0 and race.session.progress.records[1].distance<=accepted+0.5 and car.laps==0)
			check("supported_return",race.track.project_3d(car.position,car.station).supported)
			report("return_%f_%f" % [station,side],{"position":str(car.position),"station":car.station,"surface":race.track.project_3d(car.position,car.station),"state":car.state,"accepted":accepted,"distance":race.session.progress.records[1].distance})
	car.reset_car(race.track.gates[6].station,0.0)
	race.camera_driver.reset(race.camera,car)
	for resolution: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		get_tree().root.size = resolution
		await settle(4)
		check("screen_fit",map.get_global_rect().end.x<=race.get_viewport().get_visible_rect().size.x)
		save_frame("bridge_map_%d" % resolution.y)
	report("collision_samples",samples)
	report("failures",failures)
	report("passed",failures.is_empty())
	finish()
