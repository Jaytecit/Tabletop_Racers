extends "res://tests/probes/race_quality_ai_verification.gd"
# Exercise a staged entry without publishing it in the production catalogue.
var helper: Node

func select_test_course(course: String) -> bool:
	var entry: Resource = load("res://tracks/%s/entry.tres" % course)
	var catalog: Script = preload("res://scripts/tracks/content_catalog.gd")
	var vehicle: String = catalog.assigned_vehicle(course)
	var freestyle: bool = race.race_mode == "freestyle"
	if freestyle: vehicle = race.player_car.base_tuning.id
	var staged: Dictionary = catalog.validate_entry(entry,course,vehicle,freestyle)
	return race.course.select(course,vehicle,staged)

func make_live_helper() -> Node:
	return preload("res://tests/probes/topspeed_oval_live.gd").new()

func inspect_course() -> void:
	helper = make_live_helper()
	race.add_child(helper)
	await settle_physics(4)
	var support: Dictionary = helper.support_report()
	report("authored_support",support)
	check(support.failures.is_empty(),"authored_surface_support")
	var gates: Dictionary = preload("res://tests/probes/measured_gate_cases.gd").run(race)
	report("gate_cases",gates)
	check(gates.failures.is_empty(),"ordered_gate_cases")
	var inspector: Node = preload("res://tests/probes/toys_flags_verification.gd").new()
	inspector.inspect_flags(race,"staged")
	report("flags",inspector._reports)
	report("flag_failures",inspector.failures)
	check(inspector.failures.is_empty(),"flags_clear_supported_and_on_plane")
	inspector.free()
	race.show_menu()
	race.get_node("HUD").hide()
	for car: Node3D in race.all_cars: car.hide()
	race.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	race.camera.far = 400
	for gate: Dictionary in race.track.gates:
		race.camera.size = 17
		race.camera.position = gate.position+Vector3(0,22,10)
		race.camera.look_at(gate.position)
		await settle(2)
		save_frame("gate_%d" % gate.index)
	race.camera.size = 62
	race.camera.position = Vector3(0,120,0)
	race.camera.rotation_degrees = Vector3(-90,0,0)
	await settle(3)
	save_frame("overview")
	helper.race_view()

func inspect_after_race() -> void:
	for car: CharacterBody3D in race.cars:
		check(car.crashes==0 and car.ai_driver.recoveries==0 and race.session.progress.records[car.player].penalty==0.0,"clean_race_"+str(car.player))
	race.rival_count = 0
	race.start_race()
	race.begin_countdown()
	race.session.change_phase(2)
	race.player_car.ai = false
	var before: Vector3 = race.player_car.position
	Input.action_press("p1_go")
	Input.action_press("boost")
	await settle_physics(45)
	Input.action_release("boost")
	Input.action_release("p1_go")
	check(race.player_car.position.distance_to(before)>1.0 and race.player_car.boost<95.0,"real_throttle_boost")
	race.toggle_pause()
	var paused: Vector3 = race.player_car.position
	await settle_physics(5)
	check(race.paused_race and race.player_car.position==paused,"pause_freezes_motion")
	race.toggle_pause()
	Input.action_press("reset_car")
	await settle_physics(2)
	Input.action_release("reset_car")
	await settle_physics(200)
	check(race.player_car.crashes==1 and race.player_car.state==0 and not race.player_car.physical_support(race.player_car.position).is_empty(),"reset_restores_support")
	race.camera_driver.mode = 2
	race.camera_driver.reset(race.camera,race.player_car)
	await settle(4)
	save_frame("close_camera_recovery")
	var course: String = race.track_id
	var vehicle: String = race.player_car.base_tuning.id
	check(race.course.select("game_table"),"switch_to_procedural")
	check(select_test_course(course),"switch_back_staged")
	await settle(4)
	check(race.track_id==course and race.track.validation_errors.is_empty(),"switch_back_valid")
	check(race.player_car.base_tuning.id==vehicle,"switch_back_vehicle_preserved")
	# Course switching restarts menu music. Release its MP3 playback before the
	# disposable tree shuts down, matching the numerical verification probes.
	for node: Node in get_tree().root.find_children("*","AudioStreamPlayer",true,false): node.stop()
	await settle(5)
