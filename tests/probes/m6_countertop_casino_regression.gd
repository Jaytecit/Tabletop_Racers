extends "res://tests/autopilot/probe_base.gd"
var failures: Array[String] = []
func check(label: String, value: bool) -> void:
	if not value: failures.append(label)
func _ready() -> void:
	await super._ready()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await settle(5)
	var race: Node = get_tree().current_scene.get_node("Race")
	race.profile.path = "user://blackjack_pacing_test.json"
	race.profile.data = race.profile.defaults()
	race.race_mode = "quick"
	race.rival_count = 0
	race.course.select("game_table")
	check("new_revision",race.track.definition.revision==5)
	check("preview_identity",race.menu.get_node("CourseMap").texture==race.course.entry.preview)
	race.start_race()
	race.set_physics_process(false)
	race.controller.set_physics_process(false)
	for car: CharacterBody3D in race.all_cars: car.set_physics_process(false)
	var car: CharacterBody3D = race.player_car
	var samples: int = 0
	for station: int in range(int(ceil(race.track.total_length/2.0))):
		var s: float = float(station)*2.0
		var surface: Dictionary = race.track.at(s)
		for lane: float in [-3.6,-2.0,0.0,2.0,3.6]:
			if surface.edge!="shoulder" and absf(lane)>2.0: continue
			var heading: Vector2 = race.track.direction(s)
			var pos: Vector3 = surface.position+Vector3(-heading.y,0,heading.x)*lane
			var support: Dictionary = car.physical_support(pos)
			check("physical_support_%d_%.1f" % [station,lane],not support.is_empty() and absf(support.position.y-pos.y)<0.10)
			if absf(lane)<=2.0:
				var projection: Dictionary = race.track.project_3d(pos,s)
				check("road_corridor_%d_%.1f" % [station,lane],projection.supported)
			samples += 1
	report("support_samples",samples)
	# Incompatible earlier route records must neither replay nor compete.
	race.race_mode = "trial"
	race.race_laps = 1
	race.start_race()
	var key: String = race.trial.key
	race.profile.data.records[key] = {"signature":"0".repeat(64),"total":31.0,"best_lap":31.0,"replay":""}
	race.start_race()
	check("old_record_retired",race.trial.playback.is_empty() and race.trial.summary().contains("changed"))
	race.race_mode = "quick"
	race.show_menu()
	race.set_physics_process(true)
	race.controller.set_physics_process(true)
	for vehicle: CharacterBody3D in race.all_cars: vehicle.set_physics_process(true)
	car.ai = false
	race.start_race()
	await settle(5)
	race.session.countdown = 0.8
	race.session.tick(0.05)
	var before: Vector3 = car.position
	Input.action_press("p1_go")
	for frame: int in range(35): await get_tree().physics_frame
	check("actual_acceleration",Vector2(car.velocity.x,car.velocity.z).length()>3.0 and car.position.distance_to(before)>0.5)
	var heading_before: float = car.heading
	Input.action_press("p1_right")
	for frame: int in range(8): await get_tree().physics_frame
	Input.action_release("p1_right")
	check("actual_steering",absf(car.heading-heading_before)>0.04)
	Input.action_press("boost")
	for frame: int in range(8): await get_tree().physics_frame
	Input.action_release("boost")
	check("actual_boost",car.boost<99.0)
	Input.action_release("p1_go")
	var speed: float = Vector2(car.velocity.x,car.velocity.z).length()
	Input.action_press("p1_brake")
	for frame: int in range(12): await get_tree().physics_frame
	Input.action_release("p1_brake")
	check("actual_braking",Vector2(car.velocity.x,car.velocity.z).length()<speed)
	await settle(2)
	save_frame("actual_drive")
	race.toggle_pause()
	var clock: float = race.race_time
	for frame: int in range(10): await get_tree().physics_frame
	check("pause_stops_clock",race.race_time==clock)
	race.toggle_pause()
	race.show_menu()
	for suffix: String in ["",".bak",".tmp",".bak.tmp"]: DirAccess.remove_absolute(race.profile.path+suffix)
	report("failures",failures)
	report("passed",failures.is_empty())
	finish()

