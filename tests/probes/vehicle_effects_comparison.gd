extends "res://tests/probes/race_quality_verification.gd"
# Identical inputs/camera/seed for before and after. Fixtures are cosmetic evidence,
# the boost/brake/drift sequences still run the real car physics and input path.
func _enter_tree() -> void:
	super._enter_tree()
	var uid: int = ResourceUID.text_to_id("uid://144hv5b6kwah")
	if ResourceUID.has_id(uid): ResourceUID.set_id(uid,"res://showcase_track.gd")
	else: ResourceUID.add_id(uid,"res://showcase_track.gd")

func _ready() -> void:
	var deadline: Timer = Timer.new()
	deadline.one_shot = true
	deadline.wait_time = summer_max_seconds
	deadline.timeout.connect(_on_deadline)
	add_child(deadline)
	deadline.start()
	await settle(4)
	Engine.max_fps = 60
	var app: Node = get_tree().current_scene
	race = app.get_node("Race")
	race.profile.read_only = true
	race.profile_selected = true
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.using_pad = false
	race.controller.device = -1
	for name: StringName in InputMap.get_actions(): InputMap.action_erase_events(name)
	app.get_node("Opening").queue_free()
	get_tree().paused = false
	race.race_mode = "quick"
	var course_id: String = OS.get_environment("EFFECTS_COURSE")
	if course_id.is_empty(): course_id = "toys_r_you"
	check(race.course.select(course_id),"selected")
	race.machine_settings.data.reduced_effects = OS.get_environment("EFFECTS_REDUCED")=="1"
	race.setup_menu.set_pixels(true)
	race.rival_count = 3
	race.race_laps = 9
	race.difficulty = 2
	race.race_seed = 42
	race.profile.vehicle().stats = preload("res://scripts/vehicles/player_stats.gd").neutral()
	race.garage.apply_stats(race)
	for kind: String in ["drift","brake","boost","impact","dirt"]:
		await start_at(20.0)
		var car: CharacterBody3D = race.player_car
		if kind=="dirt":
			# Actual imported supported terrain beyond the legal asphalt boundary.
			car.reset_car(20.0,race.track.at(20.0).width*0.5+0.7)
			car.position.y = car.physical_support(car.position).get("position",car.position).y
			race.session.progress.rebase(car)
		var forward: Vector3 = Vector3(cos(car.heading),0,sin(car.heading))
		car.velocity = forward*7.0
		if kind=="drift": car.velocity += Vector3(-forward.z,0,forward.x)*4.0
		Input.action_press("p1_brake" if kind=="brake" else "p1_go")
		if kind=="drift": Input.action_press("p1_right")
		if kind=="boost": Input.action_press("boost")
		var begin: Vector3 = car.position
		# Lock the accepted overhead camera to the fixture's start for comparisons.
		race.set_physics_process(false)
		race.camera_driver.reset(race.camera,car)
		race.camera_driver.tick(race.camera,car,1.0)
		for i: int in range(12):
			for other: CharacterBody3D in race.cars: other.set_physics_process(true)
			if kind=="impact" and i==2:
				race.feedback.handle_event(&"impact",car,0.9,car.global_position+car.global_basis*Vector3(0.4,0.15,0))
			await settle_physics(3)
			for other: CharacterBody3D in race.cars: other.set_physics_process(false)
			await settle()
			save_frame("%s_%02d"%[kind,i])
		Input.action_release("p1_go")
		Input.action_release("p1_brake")
		Input.action_release("p1_right")
		Input.action_release("boost")
		report(kind+"_motion",{"travel":car.position.distance_to(begin),"airborne":car.airborne,"state":car.state,"station":car.station,"height":car.position.y})
		race.set_physics_process(true)
		for other: CharacterBody3D in race.cars: other.set_physics_process(true)
	# Four independently seeded AI cars exercise the same real scene and rendering.
	await start_at(20.0)
	for i: int in range(race.cars.size()):
		race.cars[i].ai = true
		race.cars[i].ai_driver.rng.seed = [64,128,256,512][i]
	await settle_physics(120)
	frame_ms.clear()
	process_ms.clear()
	physics_ms.clear()
	draw_calls.clear()
	await settle_physics(600)
	frame_ms.sort()
	process_ms.sort()
	draw_calls.sort()
	report("performance",{"gpu":RenderingServer.get_video_adapter_name(),"version":Engine.get_version_info(),"renderer":RenderingServer.get_current_rendering_method(),"samples":frame_ms.size(),"median_frame_ms":frame_ms[int(frame_ms.size()*0.5)],"p95_frame_ms":frame_ms[int(frame_ms.size()*0.95)],"p95_process_ms":process_ms[int(process_ms.size()*0.95)],"median_draw_calls":draw_calls[int(draw_calls.size()*0.5)],"reduced":race.machine_settings.data.reduced_effects,"course":course_id,"viewport":str(get_viewport().get_visible_rect().size),"pixelation":race.get_node("Retro").visible})
	report("failures",failures)
	report("passed",failures.is_empty())
	race.show_menu()
	for audio: AudioStreamPlayer in race.find_children("*","AudioStreamPlayer",true,false): audio.stop()
	await settle(3)
	finish()
