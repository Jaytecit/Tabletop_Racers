extends "res://tests/probes/race_quality_verification.gd"
var effect_rows: Array[Dictionary] = []

func _enter_tree() -> void:
	super._enter_tree()
	# The preserved UID sidecar is correct; the editor's generated cache can lose
	# this mapping during script imports. Repair only this disposable process.
	var uid: int = ResourceUID.text_to_id("uid://144hv5b6kwah")
	if ResourceUID.has_id(uid): ResourceUID.set_id(uid,"res://showcase_track.gd")
	else: ResourceUID.add_id(uid,"res://showcase_track.gd")

func check(value: bool, title: String) -> void:
	super.check(value,title)
	var file: FileAccess = FileAccess.open(summer_out_dir.path_join("assertions-progress.json"),FileAccess.WRITE)
	if file!=null: file.store_string(JSON.stringify(_reports,"\t"))

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
	race.menu_flow.choose_mode("freestyle")
	check(race.course.select("toys_r_you"),"selected_bright")
	race.rival_count = 0
	race.race_laps = 9
	race.machine_settings.data.reduced_effects = false
	check(race.profile.read_only,"isolated_profile")
	for id: String in preload("res://scripts/vehicles/vehicle_catalog.gd").IDS:
		check(race.set_vehicle(id),"class_"+id)
		race.profile.vehicle().stats = preload("res://scripts/vehicles/player_stats.gd").neutral()
		race.garage.apply_stats(race)
		await start_at(20.0)
		var car: CharacterBody3D = race.player_car
		var forward: Vector3 = Vector3(cos(car.heading),0,sin(car.heading))
		car.velocity = forward*7.0+Vector3(-forward.z,0,forward.x)*7.0
		Input.action_press("p1_go")
		Input.action_press("p1_right")
		var fx: Node3D = car.effects
		await settle_physics(3)
		var initial_contacts: int = fx.contacts.size()
		var initial_smoke: bool = fx.smoke_strength>0 and fx.tyre_active()
		await settle_physics(7)
		check(fx.diagnostic_state().capacity==96,"normal_capacity_"+id)
		if id!="speedboat":
			check(initial_contacts>0 and initial_smoke,"contact_smoke_"+id)
			check(fx.marks.live>0,"rubber_marks_"+id)
			for hit: Dictionary in fx.contacts:
				check(absf(car.race.to_local(hit.position).y-car.position.y)<0.25,"contact_height_"+id+str(hit.id))
		else:
			check(fx.contacts.is_empty() and fx.marks.live==0 and not car.smoke.emitting,"boat_has_no_tyres")
		await capture_effect("drift_"+id)
		Input.action_release("p1_right")
		Input.action_press("boost")
		await settle_physics(6)
		check(fx.boost_trail.emitting,"boost_exhaust_"+id)
		await capture_effect("boost_"+id)
		Input.action_release("boost")
		Input.action_release("p1_go")
		effect_rows.append({"class":id,"mode":"freestyle","effects":fx.diagnostic_state()})
		# Setting transitions explicitly clear the old larger allocations/marks.
		race.machine_settings.data.reduced_effects = true
		await settle(2)
		check(fx.diagnostic_state().capacity==40 and fx.marks.live==0,"reduced_capacity_"+id)
		race.machine_settings.data.reduced_effects = false
		await settle(2)
		Input.action_press("reset_car")
		await settle_physics(2)
		Input.action_release("reset_car")
		check(car.state!=0 and fx.marks.live==0 and not fx.boost_trail.emitting and fx.contacts.is_empty(),"recovery_clears_"+id)
		await settle_physics(170)
		check(car.state==0,"recovery_done_"+id)
	# Ground-dependent effects immediately stop when airborne or over water.
	check(race.set_vehicle("buggy"),"buggy_edge_cases")
	await start_at(20.0)
	var car: CharacterBody3D = race.player_car
	var fx: Node3D = car.effects
	car.airborne = true
	car.position.y += 0.8
	car.lift_speed = 0.0
	Input.action_press("p1_go")
	Input.action_press("boost")
	await settle_physics(3)
	check(fx.contacts.is_empty() and not car.smoke.emitting and not fx.smoke_right.emitting and fx.marks.previous.is_empty(),"airborne_no_ground_effects")
	await capture_effect("airborne")
	Input.action_release("boost")
	Input.action_release("p1_go")
	await settle_physics(30)
	check(not car.airborne and race.feedback.emitted.get("landing",0)==1,"actual_landing")
	fx.tick(0.06,5.0,8.0,1.0,true,"water",false)
	check(not car.smoke.emitting and not fx.smoke_right.emitting and fx.marks.previous.is_empty() and fx.boost_trail.emitting,"water_no_rubber_or_dust")
	# A temporary wall tests the actual move_and_slide contact/event path.
	await start_at(20.0)
	var wall: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.15,0.7,2)
	shape.shape = box
	wall.add_child(shape)
	race.add_child(wall)
	wall.global_transform = Transform3D(car.global_basis,car.to_global(Vector3(1.2,0.35,0)))
	await settle_physics(2)
	car.velocity = car.global_basis.x*9.0
	Input.action_press("p1_go")
	for i: int in range(15):
		await settle_physics()
		if car.sparks.emitting: break
	Input.action_release("p1_go")
	check(car.impacts>0 and car.sparks.emitting,"physical_impact_sparks")
	check(car.sparks.global_position.distance_to(race.feedback.last_event.position)<0.01,"sparks_at_collision_contact")
	check(car.sparks.direction.dot(-car.global_basis.x)>0.5,"sparks_direction_from_normal")
	await capture_effect("actual_impact")
	wall.queue_free()
	await settle_physics(2)
	await start_at(20.0)
	# The replay is checked frame by frame; effect code cannot alter physics/score.
	var active: Array = await effects_trace(true)
	var inactive: Array = await effects_trace(false)
	var deviation: float = 0.0
	for i: int in range(active.size()):
		deviation = maxf(deviation,active[i].position.distance_to(inactive[i].position))
		deviation = maxf(deviation,active[i].velocity.distance_to(inactive[i].velocity))
		check(active[i].gate==inactive[i].gate and active[i].laps==inactive[i].laps and active[i].boost==inactive[i].boost,"scoring_parity_"+str(i))
	check(deviation<0.00001,"effects_physics_parity")
	report("physics_max_deviation",deviation)
	fx.enabled = true
	await start_at(20.0)
	car.velocity = Vector3(cos(car.heading),0,sin(car.heading))*9.0
	Input.action_press("p1_brake")
	await settle_physics(6)
	check(car.smoke.emitting and fx.marks.live>0,"actual_braking_smoke_and_marks")
	await capture_effect("actual_braking")
	Input.action_release("p1_brake")
	var nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	for run: int in range(3):
		await start_at(20.0)
		for i: int in range(8):
			car.velocity = Vector3(cos(car.heading),0,sin(car.heading))*5.0+Vector3(-sin(car.heading),0,cos(car.heading))*5.0
			await settle_physics(6)
			race.feedback.handle_event(&"impact",car,0.8,car.global_position,Vector3.UP)
			await settle_physics(16)
		check(fx.marks.live<=128 and fx.diagnostic_state().capacity<=96,"repeated_budget_"+str(run))
	check(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))==nodes,"zero_node_growth_repeated_runs")
	car.set_physics_process(false)
	fx.marks.age(8.0)
	check(fx.marks.live==0 and not fx.marks.drawing.visible,"marks_fade_to_zero")
	fx.clear()
	# Pausing freezes all emitters and the strip fade clock.
	car.set_physics_process(true)
	await start_at(20.0)
	Input.action_press("p1_go")
	Input.action_press("boost")
	await settle_physics(8)
	Input.action_release("boost")
	Input.action_release("p1_go")
	await action("pause_race",2)
	var clock: float = fx.marks.clock
	await settle_physics(8)
	var frozen: bool = true
	for emitter: CPUParticles3D in fx.emitters: frozen = frozen and emitter.speed_scale==0
	check(race.paused_race and frozen and clock==fx.marks.clock,"pause_all_effects")
	await action("pause_race",2)
	check(not race.paused_race,"resume_effects")
	# Independent contact strips must never bridge a layer/teleport discontinuity.
	car.set_physics_process(false)
	fx.marks.clear()
	var fixture: Array[Dictionary] = [{"id":0,"position":car.global_position,"normal":Vector3.UP}]
	fx.marks.sample(fixture,1.0,true,0.1,false)
	fixture[0].position += Vector3(0.2,0,0)
	fx.marks.sample(fixture,1.0,true,0.1,false)
	var cursor: int = fx.marks.cursor
	fixture[0].position += Vector3(0.2,1.0,0)
	fx.marks.sample(fixture,1.0,true,0.1,false)
	check(fx.marks.cursor==cursor,"layer_change_does_not_connect")
	fixture[0].position += Vector3(4,0,0)
	fx.marks.sample(fixture,1.0,true,0.1,false)
	check(fx.marks.cursor==cursor,"teleport_does_not_connect")
	var empty_contacts: Array[Dictionary] = []
	fx.marks.sample(empty_contacts,1.0,true,0.1,false)
	check(fx.marks.previous.is_empty(),"lost_wheel_contact_breaks_strip")
	car.set_physics_process(true)
	# Night, banked road and crossing samples use real measured course collision.
	for course_id: String in ["nighttime_noodles","mount_rainier","toys_r_you"]:
		check(race.course.select(course_id),"switch_"+course_id)
		for other: CharacterBody3D in race.all_cars:
			check(other.effects.marks.live==0 and not other.effects.boost_trail.emitting,"switch_clear_"+course_id+str(other.player))
		if course_id=="mount_rainier": check(race.set_vehicle("racing_car"),"road_class")
		for station: float in ([80.0,165.0,306.0] if course_id=="toys_r_you" else [20.0,80.0,160.0]):
			await start_at(station)
			car = race.player_car
			car.velocity = Vector3(cos(car.heading),0,sin(car.heading))*5.0+Vector3(-sin(car.heading),0,cos(car.heading))*5.0
			Input.action_press("p1_go")
			Input.action_press("boost")
			await settle_physics(8)
			Input.action_release("p1_go")
			Input.action_release("boost")
			check(car.state==0 and car.effects.diagnostic_state().capacity<=96,"supported_course_effect_"+course_id+str(station))
			await capture_effect(course_id+"_"+str(int(station)))
			effect_rows.append({"course":course_id,"station":station,"height":car.position.y,"normal":str(car.surface_normal),"effects":car.effects.diagnostic_state()})
	# All four cars can emit together without multiplying their fixed allocations.
	check(race.set_vehicle("buggy"),"stress_class")
	race.rival_count = 3
	for reduced: bool in [false,true]:
		race.machine_settings.data.reduced_effects = reduced
		await settle(3)
		await start_at(20.0)
		for i: int in range(race.cars.size()):
			var other: CharacterBody3D = race.cars[i]
			other.reset_car(20.0+i*3.0,0.0)
			race.session.progress.rebase(other)
			other.ai = true
			other.velocity = Vector3(cos(other.heading),0,sin(other.heading))*5.0+Vector3(-sin(other.heading),0,cos(other.heading))*6.0
		await settle_physics(8)
		var total: int = 0
		var tyre_cars: int = 0
		for other: CharacterBody3D in race.cars:
			total += other.effects.diagnostic_state().capacity
			if other.effects.tyre_active(): tyre_cars += 1
			check(other.effects.marks.live<=(64 if reduced else 128),"stress_marks_"+str(reduced)+str(other.player))
		check(total==(160 if reduced else 384) and tyre_cars==4,"four_simultaneous_"+str(reduced))
		effect_rows.append({"stress_reduced":reduced,"total_particle_capacity":total,"simultaneous_tyre_cars":tyre_cars})
	# Assigned road/tabletop racing and Drift Challenge use the same cosmetic owner.
	for mode_course: Array in [["quick","toys_r_you"],["quick","mount_rainier"],["drift","bazaar"]]:
		race.race_mode = mode_course[0]
		check(race.course.select(mode_course[1]),"permitted_mode_"+mode_course[0]+mode_course[1])
		race.rival_count = 0
		await start_at(20.0)
		car = race.player_car
		Input.action_press("p1_go")
		Input.action_press("boost")
		await settle_physics(16)
		Input.action_release("p1_go")
		Input.action_release("boost")
		check(car.effects.boost_trail.emitting and car.state==0,"mode_effects_"+mode_course[0]+mode_course[1])
		effect_rows.append({"mode":race.race_mode,"course":race.track_id,"class":car.tuning.id})
		await capture_effect("mode_"+mode_course[0]+mode_course[1])
	report("rows",effect_rows)
	report("failures",failures)
	report("passed",failures.is_empty())
	race.show_menu()
	for audio: AudioStreamPlayer in race.find_children("*","AudioStreamPlayer",true,false): audio.stop()
	await settle(3)
	finish()

func capture_effect(title: String) -> void:
	var car: CharacterBody3D = race.player_car
	race.set_physics_process(false)
	car.set_physics_process(false)
	race.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	race.camera.size = 3.8
	race.camera.position = car.position+Vector3(2,2,2)
	race.camera.look_at(car.global_position+car.global_basis*Vector3(-0.3,0.2,0))
	await settle(2)
	save_frame(title)
	if title=="drift_buggy":
		var visibility: Array[bool] = []
		for emitter: CPUParticles3D in car.effects.emitters:
			visibility.append(emitter.visible)
			emitter.hide()
		var mark_visibility: bool = car.effects.marks.drawing.visible
		car.effects.marks.drawing.hide()
		await settle(2)
		save_frame("drift_buggy_no_particles")
		for i: int in range(car.effects.emitters.size()): car.effects.emitters[i].visible = visibility[i]
		car.effects.marks.drawing.visible = mark_visibility
	car.set_physics_process(true)
	race.set_physics_process(true)
	race.camera_driver.reset(race.camera,car)

func effects_trace(value: bool) -> Array:
	await start_at(20.0)
	race.player_car.effects.enabled = value
	var trace: Array = []
	Input.action_press("p1_go")
	Input.action_press("boost")
	for i: int in range(36):
		await settle_physics()
		var car: CharacterBody3D = race.player_car
		trace.append({"position":car.position,"velocity":car.velocity,"gate":car.gate,"laps":car.laps,"boost":car.boost})
	Input.action_release("boost")
	Input.action_release("p1_go")
	return trace
