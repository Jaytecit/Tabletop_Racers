extends "res://tests/autopilot/probe_base.gd"
var runs: Array[Dictionary] = []
var failures: Array[String] = []
var first_run: int = 0
var last_run: int = 8
var course_id: String = "felt_sprint"
var metrics: Dictionary = {}
var race: Node

func record_lap(car: CharacterBody3D, _lap: int) -> void:
	var data: Dictionary = metrics[car.player]
	var duration: float = race.race_time-float(data.clock)
	data.lap_times.append(duration)
	if car.crashes==data.crashes and race.session.progress.records[car.player].penalty==data.penalty:
		data.clean_laps.append(duration)
	data.clock = race.race_time
	data.crashes = car.crashes
	data.penalty = race.session.progress.records[car.player].penalty

func _ready() -> void:
	await super._ready()
	for child: Node in get_children():
		if child is Timer: child.ignore_time_scale = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await settle(4)
	race = get_tree().current_scene.get_node("Race")
	race.profile.path = "user://m6_races_test.json"
	race.profile.data = race.profile.defaults()
	race.profile.read_only = false
	race.race_mode = "quick"
	race.rival_count = 3
	race.race_laps = 3
	race.player_car.ai = true
	if not race.course.select(course_id):
		report("course_error",race.course.error)
		report("requested_course",course_id)
		report("passed",false)
		finish()
		return
	report("course_id",race.track_id)
	race.session.lap_completed.connect(record_lap)
	Engine.time_scale = 16.0
	Engine.physics_ticks_per_second = 960
	Engine.max_physics_steps_per_frame = 64
	report("physics_delta",race.player_car.get_physics_process_delta_time())
	for difficulty: int in range(3):
		for seed_index: int in range(3):
			if difficulty*3+seed_index<first_run or difficulty*3+seed_index>last_run: continue
			race.difficulty = difficulty
			race.race_seed = 2000+seed_index
			metrics.clear()
			for car: CharacterBody3D in race.all_cars:
				metrics[car.player] = {"clock":0.0,"crashes":0,"penalty":0.0,"lap_times":[],"clean_laps":[],"samples":0,"speed_sum":0.0,"boost_frames":0,"line_error_sum":0.0}
			race.start_race()
			for frame: int in range(24000):
				await get_tree().physics_frame
				for car: CharacterBody3D in race.cars:
					if race.phase!=2 or car.state!=0 or car.finish_time>=0.0: continue
					var data: Dictionary = metrics[car.player]
					data.samples += 1
					data.speed_sum += Vector2(car.velocity.x,car.velocity.z).length()/car.top_speed
					data.boost_frames += int(car.boost_was_on)
					data.line_error_sum += absf((Vector2(car.position.x,car.position.z)-race.track.sample(car.station)).dot(race.track.direction(car.station).orthogonal())-car.ai_driver.lateral_target)
				if race.phase==3: break
			var complete: bool = race.phase==3 and race.session.results.size()==4
			var stats: Array = []
			for car: CharacterBody3D in race.cars:
				complete = complete and car.finish_time>=0.0 and car.laps==3
				var data: Dictionary = metrics[car.player]
				stats.append({"player":car.player,"time":car.finish_time,"crashes":car.crashes,"recoveries":car.ai_driver.recoveries,"jumps":car.jumps,"passing_decisions":car.ai_driver.passes,"lap_times":data.lap_times,"clean_laps":data.clean_laps,"speed_utilisation":data.speed_sum/maxi(data.samples,1),"boost_fraction":float(data.boost_frames)/maxi(data.samples,1),"line_error":data.line_error_sum/maxi(data.samples,1)})
			if not complete: failures.append("difficulty%d_seed%d" % [difficulty,race.race_seed])
			runs.append({"difficulty":difficulty,"seed":race.race_seed,"complete":complete,"cars":stats,"phase":race.phase,"paused":race.paused_race,"race_time":race.race_time,"validation_errors":race.track.validation_errors})
			report("runs",runs)
			_write_results(false)
			if seed_index==0 and has_renderer():
				await settle(2)
				save_frame("sprint_difficulty%d_results" % difficulty)
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	race.show_menu()
	for suffix: String in ["",".bak",".tmp",".bak.tmp"]: DirAccess.remove_absolute("user://m6_races_test.json"+suffix)
	report("failures",failures)
	report("passed",failures.is_empty())
	finish()
