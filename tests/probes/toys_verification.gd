extends "res://tests/autopilot/probe_base.gd"
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(summer_out_dir)
	await super._ready()
	await settle(5)
	var race: Node3D = get_tree().current_scene.get_node("Race")
	race.profile.read_only = true
	# Keep live controller use in the user's game out of this disposable probe.
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.using_pad = false
	race.controller.device = -1
	var helper: Node = load("res://tests/probes/toys_live.gd").new()
	race.add_child(helper)
	report("select",helper.select_course())
	await settle_physics(3)
	report("support",helper.support_report())
	report("gates",helper.gate_checks())
	report("generated_children",race.track.get_node("Generated").get_child_count())
	save_frame("menu")
	helper.start_test(2,3)
	var captured: bool = false
	var fps_samples: Array[float] = []
	for frame: int in range(13500):
		await get_tree().physics_frame
		if race.phase==2 and frame%60==0:
			fps_samples.append(Performance.get_monitor(Performance.TIME_FPS))
		if not captured and race.race_time>20:
			captured = true
			save_frame("driving")
			report("performance",helper.performance_report())
		if race.phase==3: break
	var finished: Dictionary = helper.snapshot()
	report("race",finished)
	save_frame("results")
	report("race_complete",race.phase==3 and race.session.results.size()==4)
	# Player throttle and boost through the real input path.
	helper.start_test(1,1)
	helper.player_control()
	for i: int in range(250): await get_tree().physics_frame
	var before: Vector3 = race.player_car.position
	var before_frame: int = Engine.get_physics_frames()
	Input.action_press("p1_go")
	Input.action_press("boost")
	for i: int in range(45): await get_tree().physics_frame
	Input.action_release("boost")
	Input.action_release("p1_go")
	report("input",{"before":str(before),"after":str(race.player_car.position),"before_frame":before_frame,"after_frame":Engine.get_physics_frames(),"moved":race.player_car.position.distance_to(before)>1.0,"boost_used":race.player_car.boost<95.0})
	Input.action_press("reset_car")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("reset_car")
	for i: int in range(210): await get_tree().physics_frame
	report("recovery",{"crashes":race.player_car.crashes,"state":race.player_car.state,"supported":not race.player_car.physical_support(race.player_car.position).is_empty()})
	race.toggle_pause()
	var paused_position: Vector3 = race.player_car.position
	for i: int in range(10): await get_tree().physics_frame
	report("pause",race.paused_race and race.player_car.position.is_equal_approx(paused_position))
	race.toggle_pause()
	report("resume",not race.paused_race)
	report("switch_away",helper.select_course("practice_patch"))
	report("switch_back",helper.select_course())
	await settle(3)
	save_frame("menu_final")
	helper.overview()
	await settle(3)
	save_frame("overview")
	report("fps_samples",fps_samples)
	report("passed",finished.results==4 and _reports.support.failures.is_empty() and _reports.gates.failures.is_empty() and _reports.input.moved and _reports.input.boost_used and _reports.recovery.state==0 and _reports.recovery.supported and _reports.pause and _reports.resume and _reports.switch_back.selected)
	finish()
