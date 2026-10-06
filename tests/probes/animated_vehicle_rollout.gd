extends "res://tests/probes/race_quality_ai_verification.gd"
const FACTORY: Script = preload("res://scripts/vehicles/imported_visual.gd")

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
	race.menu_flow.choose_mode("freestyle")
	check(race.course.select("game_table"),"course")
	while race.course.loading: await get_tree().process_frame
	race.rival_count = 3
	race.race_laps = 1
	for id: String in preload("res://scripts/vehicles/vehicle_catalog.gd").IDS:
		check(race.set_vehicle(id),"class_"+id)
		race.garage.select(race,0)
		var car: CharacterBody3D = race.player_car
		var material: ShaderMaterial = FACTORY.paint_meshes(car.visual)[0].material_override
		check(material.get_shader_parameter("source_texture")!=null,"texture_"+id)
		for slot: int in range(4):
			var colour: Color = FACTORY.paint_meshes(race.all_cars[slot].visual)[0].material_override.get_shader_parameter("player_colour")
			check(colour==race.garage.COLORS[slot],"colour_%s_%d"%[id,slot])
		check(race.garage.preview_car==null,"track_preview_has_no_vehicle_"+id)
		race.garage.select(race,3)
		check(FACTORY.paint_meshes(car.visual)[0].material_override.get_shader_parameter("player_colour")==race.garage.COLORS[3],"driver_change_"+id)
		race.garage.select(race,0)
		race.profile.data.gold_livery = true
		race.garage.select(race,0)
		check(FACTORY.paint_meshes(car.visual)[0].material_override.get_shader_parameter("player_colour")==Color("e7ba52"),"gold_"+id)
		race.profile.data.gold_livery = false
		race.garage.select(race,0)
		race.profile.vehicle().paint = "chrome"
		race.garage.select(race,0)
		check(is_equal_approx(float(FACTORY.paint_meshes(car.visual)[0].material_override.get_shader_parameter("paint_metallic")),0.9),"chrome_"+id)
		race.profile.vehicle().paint = "stock"
		race.garage.select(race,0)
		check(is_zero_approx(float(FACTORY.paint_meshes(car.visual)[0].material_override.get_shader_parameter("paint_metallic"))),"stock_restored_"+id)
		race.start_race()
		race.begin_countdown()
		race.session.countdown = 0.81
		await settle_physics(3)
		car.reset_car(20,0)
		race.session.progress.reset(race.cars,race.track.total_length)
		for vehicle: CharacterBody3D in race.all_cars:
			if vehicle==car: continue
			vehicle.set_physics_process(false)
			vehicle.position.y += 50.0
		var origin: Vector3 = car.position
		Input.action_press("p1_go")
		await settle_physics(35)
		Input.action_release("p1_go")
		check(car.position.distance_to(origin)>0.5 and car.crashes==0,"forward_"+id)
		check(car.wheels.size()==(0 if id=="speedboat" else 4),"wheel_count_"+id)
		if id!="speedboat": check(absf(car.visual_motion.roll_angle)>0.1,"spin_"+id)
		else: check(car.visual.get_node_or_null("Propeller")==null,"jet_boat")
		car.reset_car(20,0)
		Input.action_press("p1_brake")
		await settle_physics(100)
		Input.action_release("p1_brake")
		check(car.velocity.dot(Vector3(cos(car.heading),0,sin(car.heading)))<0,"reverse_"+id)
		var angle: float = car.visual_motion.roll_angle
		await settle_physics(3)
		if id!="speedboat": check(wrapf(car.visual_motion.roll_angle-angle,-PI,PI)>0.001,"reverse_spin_"+id)
		car.velocity = Vector3.ZERO
		Input.action_press("p1_left")
		await settle_physics(5)
		Input.action_release("p1_left")
		for mount: Node3D in car.wheels:
			check(absf(mount.rotation.y)>0.1 if mount.position.x>0 else absf(mount.rotation.y)<0.001,"steer_%s_%s"%[id,mount.name])
		race.set_physics_process(false)
		for vehicle: CharacterBody3D in race.all_cars: vehicle.set_physics_process(false)
		race.get_node("HUD").hide()
		race.get_node("Retro").hide()
		var base: Vector3 = car.position
		for slot: int in range(4):
			var vehicle: CharacterBody3D = race.all_cars[slot]
			vehicle.position = base+Vector3(0,0,(slot-1.5)*1.6)
			vehicle.rotation = Vector3.ZERO
			vehicle.visual.rotation = Vector3.ZERO
			vehicle.visual_motion.reset()
			for emitter: CPUParticles3D in [vehicle.smoke,vehicle.sparks,vehicle.debris]: emitter.hide()
		race.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		race.camera.size = 7.2
		race.camera.global_position = base+Vector3(4.5,3.4,5.5)
		race.camera.look_at(base+Vector3.UP*0.3)
		await settle(3)
		save_frame(id+"_four_colours")
		if id!="speedboat":
			for pose: int in range(4):
				for mount: Node3D in car.wheels:
					mount.rotation.y = float(mount.get_meta("max_steer")) if mount.position.x>0 else 0.0
					mount.get_node("Roll").rotation.z = pose*PI*0.5
				if pose==3:
					race.camera.global_position = car.global_position+Vector3(-1.8,0.65,-1.8)
				else: race.camera.global_position = car.global_position+Vector3(1.8,0.8,1.8)
				race.camera.size = 2.1 if id!="monster_truck" else 2.8
				race.camera.look_at(car.global_position+Vector3.UP*(0.3 if id!="monster_truck" else 0.5))
				await settle(3)
				save_frame(id+"_wheel_%d"%pose)
		race.get_node("HUD").show()
		race.show_menu()
		race.set_physics_process(true)
		for vehicle: CharacterBody3D in race.all_cars: vehicle.set_physics_process(true)
	check(race.set_vehicle("buggy"),"switch_back")
	check(race.player_car.wheels.size()==4,"buggy_restored")
	check(race.profile.read_only,"still_read_only")
	while race.course.loading: await get_tree().process_frame
	for node: Node in app.find_children("*","AudioStreamPlayer",true,false): node.stop()
	await settle(6)
	report("course_idle_at_exit",not race.course.loading)
	report("failures",failures)
	report("passed",failures.is_empty())
	finish()
