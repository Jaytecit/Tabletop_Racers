extends "res://tests/autopilot/probe_base.gd"
var failures: Array[String] = []
var race: Node
func check(label: String, value: bool) -> void:
	if not value: failures.append(label)
func place(station: float, lane: float = 0.0) -> void:
	var car: CharacterBody3D = race.player_car
	car.station = fposmod(station,race.track.total_length)
	var direction: Vector2 = race.track.direction(car.station)
	car.position = race.track.sample_3d(car.station)+Vector3(-direction.y,0,direction.x)*lane
	car.heading = direction.angle()
	car.rotation.y = -car.heading
	car.velocity = Vector3.ZERO
	car.previous_ground = car.position.y
	car.airborne = false
	car.state = 0
	race.camera_driver.reset(race.camera,car)
func _ready() -> void:
	await super._ready()
	for child: Node in get_children():
		if child is Timer: child.ignore_time_scale = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await settle(5)
	race = get_tree().current_scene.get_node("Race")
	race.profile.path = "user://m6_bridge_test.json"
	race.profile.data = race.profile.defaults()
	race.race_mode = "quick"
	race.rival_count = 3
	race.race_laps = 3
	race.course.select("game_table")
	race.show_menu()
	await settle(3)
	var menu: OptionButton = race.menu.get_node("TrackSelect")
	menu.grab_focus()
	await key(KEY_ENTER,50)
	await key(KEY_DOWN,50)
	await key(KEY_DOWN,50)
	await key(KEY_DOWN,50)
	await key(KEY_ENTER,50)
	check("keyboard_course_selection",race.track_id=="card_bridge")
	check("saved_selection",race.profile.data.quick_race.track_id=="card_bridge")
	check("matching_preview",race.menu.get_node("CourseMap").texture==race.course.entry.preview)
	await settle(4)
	var car: CharacterBody3D = race.player_car
	race.start_race()
	race.set_physics_process(false)
	race.controller.set_physics_process(false)
	for vehicle: CharacterBody3D in race.all_cars: vehicle.set_physics_process(false)
	var samples: int = 0
	var upper: float = -1.0
	var lower: float = -1.0
	for station: int in range(int(race.track.total_length)):
		for lane_fraction: float in [-1.0,0.0,1.0]:
			var lane: float = lane_fraction*minf(2.0,race.track.at(float(station)).width*0.5-0.5)
			place(float(station),lane)
			var projection: Dictionary = race.track.project_3d(car.position,car.station)
			var support: Dictionary = car.physical_support(car.position)
			check("projection_%d_%.1f" % [station,lane],projection.supported and projection.layer==race.track.at(float(station)).layer)
			check("continuous_collision_%d_%.1f" % [station,lane],not support.is_empty() and absf(support.position.y-car.position.y)<0.08)
			samples += 1
		var point: Vector3 = race.track.sample_3d(float(station))
		if Vector2(point.x,point.z).length()<3.0:
			if point.y>3.0: upper = float(station)
			else: lower = float(station)
	check("crossing_both_layers",upper>=0.0 and lower>=0.0)
	for station: float in [lower,upper]:
		place(station)
		var projection: Dictionary = race.track.project_3d(car.position)
		check("broad_projection_layer",projection.layer==(1 if station==upper else 0))
		race.camera_driver.tick(race.camera,car,1.0)
		await settle(3)
		save_frame("bridge_upper" if station==upper else "bridge_lower")
		car.safe_station = station
		car.safe_position = car.position
		race.session.progress.rebase(car)
		var laps: int = car.laps
		car.crash(false)
		for frame: int in range(220):
			car.recover(1.0/60.0)
			if car.state==0: break
		check("recovery_layer",car.state==0 and absf(car.position.y-race.track.at(car.station).position.y)<0.18 and car.laps==laps)
	report("collision_samples",samples)
	report("crossing_stations",{"lower":lower,"upper":upper})
	race.set_physics_process(true)
	race.controller.set_physics_process(true)
	for vehicle: CharacterBody3D in race.all_cars: vehicle.set_physics_process(true)
	car.ai = true
	race.difficulty = 1
	race.race_seed = 2000
	Engine.time_scale = 8.0
	Engine.physics_ticks_per_second = 480
	Engine.max_physics_steps_per_frame = 32
	race.start_race()
	var seen_upper: bool = false
	var seen_lower: bool = false
	for frame: int in range(18000):
		await get_tree().physics_frame
		if car.state==0:
			var layer: int = race.track.at(car.station).layer
			seen_upper = seen_upper or (layer==1 and car.position.y>3.0)
			seen_lower = seen_lower or (layer==0 and car.position.y<0.1)
		if race.phase==3: break
	check("three_lap_race",race.phase==3 and race.session.results.size()==4 and seen_upper and seen_lower)
	for vehicle: CharacterBody3D in race.cars: check("car_finished_%d" % vehicle.player,vehicle.finish_time>=0 and vehicle.laps==3)
	report("race_state",race.diagnostic_state())
	report("lap_seconds",car.finish_time/3.0)
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	await settle(2)
	save_frame("bridge_results")
	race.show_menu()
	check("return_menu",race.phase==0)
	for suffix: String in ["",".bak",".tmp",".bak.tmp"]: DirAccess.remove_absolute(race.profile.path+suffix)
	report("failures",failures)
	report("passed",failures.is_empty())
	finish()
