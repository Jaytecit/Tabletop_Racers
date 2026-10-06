extends "res://tests/probes/race_quality_verification.gd"
const VEHICLES: Script = preload("res://scripts/vehicles/vehicle_catalog.gd")
const STORE: Script = preload("res://scripts/profile_store.gd")

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
	race.race_laps = 1
	var rows: Array[Dictionary] = []
	var classes: Array[String] = VEHICLES.IDS.duplicate()
	if OS.get_environment("TABLETOP_VERIFY_LAYOUT_ONLY")=="1": classes.clear()
	for id: String in classes:
		check(race.set_vehicle(id),"class_"+id)
		if id!="buggy" and id!="speedboat": check_wheel_clearance(race.player_car,id)
		if id=="speedboat":
			var envelope: AABB = AABB(Vector3(-0.82,-0.05,-0.38),Vector3(1.64,0.66,0.76)).grow(0.025)
			var external: Array[String] = []
			for mesh: MeshInstance3D in race.player_car.visual.find_children("*","MeshInstance3D",true,false):
				var relative: Transform3D = race.player_car.visual.global_transform.affine_inverse()*mesh.global_transform
				if not envelope.encloses(relative*mesh.get_aabb()): external.append(str(mesh.name))
			report("outside_collision_speedboat",external)
			check(external.is_empty(),"collision_envelope_speedboat")
		race.profile.vehicle().stats = preload("res://scripts/vehicles/player_stats.gd").neutral()
		race.garage.apply_stats(race)
		race.start_race()
		race.begin_countdown()
		race.session.countdown = 0.81
		await settle_physics(3)
		var car: CharacterBody3D = race.player_car
		car.reset_car(20,0)
		race.session.progress.reset(race.cars,race.track.total_length)
		var origin: Vector3 = car.position
		Input.action_press("p1_go")
		Input.action_press("boost")
		await settle_physics(60)
		Input.action_release("p1_go")
		Input.action_release("boost")
		check(car.boost<80.0,"boost_"+id)
		check(car.position.distance_to(origin)>2.0 and car.crashes==0,"forward_"+id)
		if id=="speedboat": check(car.visual.get_node_or_null("Propeller")==null and car.wheels.is_empty(),"jet_boat_propulsion")
		else: check(absf(car.visual_motion.roll_angle)>0.01 and car.wheels.size()==4,"wheel_motion_"+id)
		var moving_position: Vector3 = car.position
		race.toggle_pause()
		await settle_physics(10)
		check(car.position==moving_position,"pause_"+id)
		race.toggle_pause()
		Input.action_press("p1_brake")
		await settle_physics(100)
		Input.action_release("p1_brake")
		var forward: Vector3 = Vector3(cos(car.heading),0,sin(car.heading))
		check(car.velocity.dot(forward)<-0.2,"reverse_"+id)
		car.velocity = Vector3.ZERO
		Input.action_press("p1_left")
		await settle_physics(8)
		if id!="speedboat": check(absf(car.visual_motion.mounts[2].rotation.y)>0.1,"stationary_steer_"+id)
		else: check(car.visual.get_node_or_null("Propeller")==null,"jet_boat_has_no_propeller")
		Input.action_release("p1_left")
		race.set_physics_process(false)
		car.set_physics_process(false)
		race.camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		race.camera.position = car.position+Vector3(2,1.2,2.4)
		race.camera.look_at(race.to_global(car.position+Vector3.UP*0.30))
		await settle(4)
		save_frame(id)
		rows.append({"id":id,"position":str(car.position),"speed":car.top_speed,"grip":car.tuning.grip,"collision":str(car.get_node("Collision").shape.size),"visual_nodes":car.visual.get_child_count()})
		race.set_physics_process(true)
		car.set_physics_process(true)
		Input.action_press("reset_car")
		await settle_physics(2)
		Input.action_release("reset_car")
		await settle_physics(180)
		check(car.state==0 and car.recovery_target_valid,"recovery_"+id)
		await check_water_rules(car,id)
		race.show_menu()
		await settle(4)
	# Every class and mode has an independent key, while schema-9 buggy data survives.
	race.set_vehicle("drift_car")
	race.menu_flow.choose_mode("quick")
	check(race.player_car.base_tuning.id=="buggy","standard_assignment")
	race.menu_flow.choose_mode("freestyle")
	check(race.player_car.base_tuning.id=="drift_car","freestyle_selection_retained")
	race.menu_flow.show_step(2)
	await settle(4)
	save_frame("freestyle_garage")
	race.menu_flow.show_step(0)
	await settle(4)
	save_frame("mode_menu")
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(1600,720)]:
		DisplayServer.window_set_size(dimensions)
		for page: int in range(4):
			if page==3:
				race.difficulty = 3
				race.rival_count = 3
				race.refresh_mode()
			race.menu_flow.show_step(page)
			await settle(3)
			var buttons: Array[Control] = []
			for node: Node in race.menu.find_children("*","BaseButton",true,false):
				if node.is_visible_in_tree(): buttons.append(node)
			for i: int in range(buttons.size()):
				check(race.menu.get_global_rect().encloses(buttons[i].get_global_rect()),"button_bounds_%s_%d_%s" % [str(dimensions),page,str(buttons[i].name)])
				for j: int in range(i+1,buttons.size()):
					check(not buttons[i].get_global_rect().intersects(buttons[j].get_global_rect()),"button_spacing_%s_%d_%s_%s" % [str(dimensions),page,str(buttons[i].name),str(buttons[j].name)])
			if page in [2,3]: save_frame("menu_%dx%d_%d" % [dimensions.x,dimensions.y,page])
	var keys: Array[String] = []
	var sample: Dictionary = {"signature":"a".repeat(64),"total":100.0,"best_lap":50.0,"replay":""}
	var profile: RefCounted = STORE.new()
	profile.path = summer_out_dir.path_join("classes_profile.json")
	profile.data.freestyle_vehicle = "speedboat"
	for id: String in VEHICLES.IDS:
		var key: String = STORE.record_key("freestyle",2,3,2,"toys_r_you","",id)
		check(key not in keys and STORE.valid_record_key(key),"record_key_"+id)
		keys.append(key)
		profile.data.records[key] = sample.duplicate()
		profile.data.vehicles[id].points = VEHICLES.IDS.find(id)+1
	profile.preserve_legacy(keys[0],sample)
	check(profile.save_profile()==OK,"class_profile_saved")
	var reloaded: Dictionary = profile.load_profile()
	check(reloaded.freestyle_vehicle=="speedboat","freestyle_choice_reload")
	check(reloaded.records.size()==5 and reloaded.legacy_records[keys[0]].size()==1,"class_records_reload")
	for id: String in VEHICLES.IDS: check(reloaded.vehicles[id].points==VEHICLES.IDS.find(id)+1,"progression_"+id)
	var old: Dictionary = STORE.defaults()
	old.schema_version = 9
	old.vehicles = {"buggy":old.vehicles.buggy}
	old.vehicles.buggy.points = 47
	check(STORE.validate(old).vehicles.buggy.points==47 and STORE.validate(old).vehicles.size()==5,"schema9_migration")
	check(race.profile.read_only,"read_only")
	report("classes",rows)
	report("failures",failures)
	report("passed",failures.is_empty())
	for node: Node in app.find_children("*","AudioStreamPlayer",true,false): node.stop()
	await settle(5)
	finish()

func check_wheel_clearance(car: CharacterBody3D, id: String) -> void:
	# Conservative swept tyre boxes against every body mesh, through both steering
	# locks and the maximum cosmetic pitch/lean/compression. No visual judgement
	# substitutes for these envelope checks; keep the intersecting names in evidence.
	var intersections: Array[String] = []
	var outside_collision: Array[String] = []
	var collision: AABB = AABB(Vector3(-car.tuning.collision_size.x*0.5,-0.05,-car.tuning.collision_size.z*0.5),Vector3(car.tuning.collision_size.x,car.tuning.collision_height+car.tuning.collision_size.y*0.5+0.05,car.tuning.collision_size.z)).grow(0.025)
	for steer: float in [-0.45,0.0,0.45]:
		for pitch: float in [-0.04,0.0,0.04]:
			for lean: float in [-0.06,0.0,0.06]:
				var response: Transform3D = Transform3D(Basis.from_euler(Vector3(lean,0,pitch)),Vector3(0,-0.035,0))
				for mount: Node3D in car.wheels:
					var tire: MeshInstance3D = mount.get_node("Roll/Tire")
					var steering: Transform3D = Transform3D(Basis(Vector3.UP,steer if mount.position.x>0 else 0.0),mount.position)
					var tire_box: AABB = steering*tire.transform*tire.get_aabb()
					if not collision.encloses(tire_box) and str(mount.name) not in outside_collision: outside_collision.append(str(mount.name))
					for part: Node3D in car.visual.get_children():
						if not part is MeshInstance3D or part.name=="WaterAssist": continue
						var body_box: AABB = response*part.transform*part.get_aabb()
						if not collision.encloses(body_box) and str(part.name) not in outside_collision: outside_collision.append(str(part.name))
						if tire_box.intersects(body_box):
							var pair: String = str(mount.name)+"/"+str(part.name)
							if pair not in intersections: intersections.append(pair)
	report("wheel_intersections_"+id,intersections)
	report("outside_collision_"+id,outside_collision)
	check(outside_collision.is_empty(),"collision_envelope_"+id)
	check(intersections.is_empty(),"swept_wheel_clearance_"+id)

func check_water_rules(car: CharacterBody3D, id: String) -> void:
	# Controlled surface fixture on unchanged measured geometry. This proves the
	# controller rules, not the appearance or extraction of a future water course.
	var original: Resource = race.track.definition
	var original_anchors: Array[Dictionary] = race.track.anchors
	race.track.definition = original.duplicate(true)
	for section: Resource in race.track.definition.sections: section.surface = "water"
	race.track.anchors = original_anchors.duplicate(true)
	for anchor: Dictionary in race.track.anchors: anchor.surface = "water"
	car.reset_car(20,0)
	race.session.progress.reset(race.cars,race.track.total_length)
	Input.action_press("p1_go")
	Input.action_press("boost")
	await settle_physics(60)
	Input.action_release("boost")
	Input.action_release("p1_go")
	check(car.state==0 and car.position.y>=-0.01 and car.velocity.length()>2.0,"water_motion_"+id)
	check(car.velocity.length()<=car.top_speed*1.35*(1.0 if id=="speedboat" else 0.55)+0.01,"water_speed_limit_"+id)
	if id=="speedboat": check(not car.visual.get_node("LandAssist").visible,"water_skids_hidden")
	else: check(car.visual.get_node("WaterAssist").visible,"water_float_visible_"+id)
	car.crash(false)
	await settle_physics(190)
	check(car.state==0 and car.recovery_target_valid,"water_recovery_"+id)
	car.position += Vector3(500,0,500)
	await settle_physics(2)
	check(car.state!=0,"water_missing_support_rejected_"+id)
	car.reset_car(20,0)
	race.session.progress.reset(race.cars,race.track.total_length)
	race.race_mode = "quick"
	await settle_physics(2)
	check((car.state==0)==(id=="speedboat"),"standard_water_permission_"+id)
	race.race_mode = "freestyle"
	race.track.definition = original
	race.track.anchors = original_anchors
	car.reset_car(20,0)
