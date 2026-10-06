extends "res://tests/autopilot/probe_base.gd"
# Run one course/resolution per process without --fixed-fps. The runner's
# frame ceiling expires early at this machine's uncapped rendering rate.
var courses: Array[String] = ["felt_sprint","card_bridge","game_table"]
var resolutions: Array[Vector2i] = [Vector2i(1280,720),Vector2i(1920,1080)]
func _init() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--course="): courses.assign([argument.trim_prefix("--course=")])
		if argument=="--720p": resolutions.assign([Vector2i(1280,720)])
		if argument=="--1080p": resolutions.assign([Vector2i(1920,1080)])
func _ready() -> void:
	await super._ready()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await settle(5)
	var race: Node = get_tree().current_scene.get_node("Race")
	race.profile.path = "user://m6a_performance_test.json"
	race.profile.data = race.profile.defaults()
	race.race_mode = "quick"
	race.rival_count = 3
	race.player_car.ai = true
	race.difficulty = 2
	var runs: Array = []
	for resolution: Vector2i in resolutions:
		get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		get_tree().root.size = resolution
		for course_id: String in courses:
			race.course.select(course_id)
			race.start_race()
			while race.phase!=2: await get_tree().physics_frame
			var samples: Array[float] = []
			var map_samples: Array[float] = []
			var map: Control = race.get_node("HUD/RaceMinimap")
			var peak_speed: float = 0.0
			var active_frames: int = 0
			for fraction: float in [0.05,0.66,0.88]:
				var station: float = race.track.total_length*fraction
				for car: CharacterBody3D in race.cars:
					car.position = race.track.sample_3d(station)+Vector3.UP*0.32
					car.station = station
					car.heading = race.track.direction(station).angle()
					var tangent: Vector2 = race.track.direction(station)
					car.velocity = Vector3(tangent.x,0,tangent.y)*car.top_speed
					race.session.progress.rebase(car)
					station -= 2.0
				race.camera_driver.reset(race.camera,race.player_car)
				for warmup: int in range(30): await get_tree().physics_frame
				var last: int = Time.get_ticks_usec()
				var started: int = last
				while Time.get_ticks_usec()-started<2000000:
					await settle(1)
					var now: int = Time.get_ticks_usec()
					samples.append(float(now-last)/1000.0)
					last = now
					active_frames += int(race.phase==2)
					peak_speed = maxf(peak_speed,race.player_car.velocity.length())
					var begin: int = Time.get_ticks_usec()
					map._process(0.0)
					map_samples.append(float(Time.get_ticks_usec()-begin)/1000.0)
				if fraction==0.66: save_frame(course_id+"_"+str(resolution.y)+"p")
			samples.sort()
			map_samples.sort()
			var actual_size: Vector2i = get_viewport().get_texture().get_image().get_size()
			runs.append({"course":course_id,"resolution":str(actual_size),"normal_time_scale":Engine.time_scale==1.0,"active_frames":active_frames,"peak_speed":peak_speed,"sample_count":samples.size(),"p95_ms":samples[int(samples.size()*0.95)],"p99_ms":samples[int(samples.size()*0.99)],"minimap_process_p99_ms":map_samples[int(map_samples.size()*0.99)],"passed":active_frames==samples.size() and peak_speed>6.0 and actual_size==resolution and samples[int(samples.size()*0.95)]<=16.7 and samples[int(samples.size()*0.99)]<=25.0})
			report("runs",runs)
			_write_results(false)
	report("gpu",RenderingServer.get_video_adapter_name())
	report("cpu",OS.get_processor_name())
	var passed: bool = true
	for run: Dictionary in runs: passed = passed and run.passed
	report("passed",passed)
	for suffix: String in ["",".bak",".tmp",".bak.tmp"]: DirAccess.remove_absolute("user://m6a_performance_test.json"+suffix)
	finish()
