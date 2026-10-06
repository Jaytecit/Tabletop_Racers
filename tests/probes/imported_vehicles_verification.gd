extends "res://tests/probes/race_quality_ai_verification.gd"

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
	check(race.profile.read_only,"read_only")
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.device = -1
	race.controller.using_pad = false
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	app.get_node("Opening").queue_free()
	get_tree().paused = false
	race.get_node("HUD").show()
	race.menu_flow.choose_mode("freestyle")
	check(race.course.select("game_table"),"course")
	while race.course.loading: await get_tree().process_frame
	race.rival_count = 1
	race.race_laps = 1
	for id: String in preload("res://scripts/vehicles/vehicle_catalog.gd").IDS:
		check(race.set_vehicle(id),"class_"+id)
		var car: CharacterBody3D = race.player_car
		check(car.visual.has_node("Model") and race.all_cars[1].visual.has_node("Model"),"models_"+id)
		check(race.garage.preview_car==null,"track_preview_has_no_vehicle_"+id)
		var importer: Script = preload("res://scripts/vehicles/imported_visual.gd")
		var box: AABB = importer.bounds(car.visual.get_node("Model"))
		# Bounds in visual coordinates include the model's alignment and scale.
		box = car.visual.get_node("Model").transform*box
		report("bounds_"+id,{"position":str(box.position),"size":str(box.size)})
		check(absf(box.position.y)<0.001 and box.size.x>0.5 and box.size.x<1.65,"fit_"+id)
		var material: ShaderMaterial = importer.paint_meshes(car.visual)[0].material_override
		check(material.get_shader_parameter("source_texture")!=null,"texture_"+id)
		race.menu_flow.show_step(3)
		await settle(2)
		save_frame(id+"_menu")
		race.start_race()
		race.begin_countdown()
		race.session.countdown = 0.81
		await settle_physics(3)
		car.reset_car(20,0)
		race.session.progress.reset(race.cars,race.track.total_length)
		check(race.phase==2,"racing_"+id)
		var origin: Vector3 = car.position
		Input.action_press("p1_go")
		await settle_physics(35)
		Input.action_release("p1_go")
		check(car.position.distance_to(origin)>0.5 and car.crashes==0,"drive_"+id)
		race.set_physics_process(false)
		for vehicle: CharacterBody3D in race.all_cars: vehicle.set_physics_process(false)
		car.visual.rotation = Vector3.ZERO
		race.camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		var pose: Vector3 = car.global_position
		var forward: Vector3 = Vector3(cos(car.heading),0,sin(car.heading))
		race.camera.global_position = pose+forward*1.8+Vector3.UP*1.1+forward.cross(Vector3.UP)*1.7
		race.camera.look_at(pose+Vector3.UP*0.3)
		await settle(3)
		race.get_node("HUD").hide()
		await settle(2)
		save_frame(id+"_race")
		race.get_node("HUD").show()
		race.show_menu()
		race.set_physics_process(true)
		for vehicle: CharacterBody3D in race.all_cars: vehicle.set_physics_process(true)
	check(race.set_vehicle("buggy"),"switch_back_buggy")
	check(race.player_car.visual.has_node("Model"),"buggy_restored")
	report("failures",failures)
	report("passed",failures.is_empty())
	finish()

