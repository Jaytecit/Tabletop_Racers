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
	race.controller.using_pad = false
	race.controller.device = -1
	for name: StringName in InputMap.get_actions(): InputMap.action_erase_events(name)
	app.get_node("Opening").queue_free()
	get_tree().paused = false
	race.get_node("HUD").show()
	check(race.course.select("toys_r_you"),"selected")
	race.rival_count = 3
	race.race_mode = "quick"
	var passing: Array = []
	for difficulty: int in [1,2]:
		for rng_seed: int in [128,256,512]:
			race.difficulty = difficulty
			await start_at(400.0)
			for car: CharacterBody3D in race.cars:
				car.set_physics_process(false)
				car.finish_time = 999.0
			var blocker: CharacterBody3D = race.cars[1]
			var racer: CharacterBody3D = race.cars[2]
			blocker.reset_car(24.0,0.0)
			racer.reset_car(20.0,0.0)
			race.session.progress.rebase(racer)
			racer.ai = true
			racer.ai_driver.rng.seed = rng_seed
			racer.set_physics_process(true)
			var sign_changes: int = 0
			var last_side: float = 0.0
			var targets: Array = []
			for frame: int in range(240):
				await get_tree().physics_frame
				var target: float = racer.ai_driver.lateral_target
				if absf(target)>0.25 and racer.station<29.0:
					var side: float = signf(target)
					if last_side!=0.0 and side!=last_side: sign_changes += 1
					last_side = side
				if frame%12==0: targets.append({"station":racer.station,"target":target})
				if racer.station>33.0: break
			var outcome: Dictionary = {"difficulty":difficulty,"seed":rng_seed,"station":racer.station,"impacts":racer.impacts,"recoveries":racer.ai_driver.recoveries,"crashes":racer.crashes,"side_changes":sign_changes,"targets":targets}
			passing.append(outcome)
			check(racer.station>29.0 and racer.crashes==0 and racer.impacts==0 and sign_changes<=1,"pass_%d_%d" % [difficulty,rng_seed])
			race.camera_driver.reset(race.camera,racer)
			race.set_physics_process(false)
			await settle(2)
			save_frame("pass_%d_%d" % [difficulty,rng_seed])
			race.set_physics_process(true)
	# Occupied lane corridor: no safe lateral option, and a stationary loop must
	# eventually request recovery. This fixture tests decisions, not physical motion.
	await start_at(400.0)
	for car: CharacterBody3D in race.cars:
		car.set_physics_process(false)
		car.finish_time = 999.0
	var driver: CharacterBody3D = race.cars[3]
	var narrow_station: float = 0.0
	var narrow_width: float = INF
	for station: int in range(int(race.track.total_length)):
		var width: float = race.track.at(float(station)).width
		if width<narrow_width:
			narrow_width = width
			narrow_station = float(station)
	driver.reset_car(narrow_station,0.0)
	driver.ai_driver.difficulty = 1
	race.cars[0].reset_car(narrow_station+0.8,-1.7)
	race.cars[1].reset_car(narrow_station+0.8,0.0)
	race.cars[2].reset_car(narrow_station+0.8,1.7)
	var initial: Dictionary = driver.ai_driver.read_commands(driver)
	report("blocked_bridge_commands",initial)
	report("blocked_bridge_width",narrow_width)
	report("blocked_bridge_station",narrow_station)
	check(initial.throttle==0.0 and not initial.boost,"blocked_bridge_waits")
	var requests: int = 0
	var unsafe_pass: bool = false
	for frame: int in range(240):
		await get_tree().physics_frame
		var command: Dictionary = driver.ai_driver.read_commands(driver)
		if command.reset_requested: requests += 1
		if absf(driver.ai_driver.lateral_target)>0.01: unsafe_pass = true
	check(requests==1,"stationary_stall_requests_recovery")
	check(not unsafe_pass,"fully_blocked_corridor_does_not_attempt_pass")
	report("passes",passing)
	check(race.profile.read_only,"read_only")
	report("failures",failures)
	report("passed",failures.is_empty())
	for node: Node in get_tree().root.find_children("*","AudioStreamPlayer",true,false): node.stop()
	await settle(5)
	finish()
