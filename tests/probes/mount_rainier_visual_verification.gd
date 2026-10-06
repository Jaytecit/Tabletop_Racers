extends "res://tests/probes/toys_flags_verification.gd"
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(summer_out_dir)
	# Invoke the probe base; the Toys-only _ready() is deliberately not used.
	_start_ms = Time.get_ticks_msec()
	await settle(5)
	var race: Node3D = get_tree().current_scene.get_node("Race")
	race.profile.read_only = true
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.using_pad = false
	race.controller.device = -1
	var helper: Node = load("res://tests/probes/mount_rainier_live.gd").new()
	race.add_child(helper)
	var select_start: int = Time.get_ticks_msec()
	report("select",helper.select_course())
	report("selection_load_ms",Time.get_ticks_msec()-select_start)
	await settle_physics(5)
	inspect_flags(race,"initial")
	helper.overview()
	# Review overlay exists only in this disposable instance; shipping stays disabled.
	var overlay: Node3D = load("res://scripts/tracks/route_debug_overlay.gd").new()
	overlay.name = "RouteDebugOverlay"
	race.track.get_node("Generated").add_child(overlay)
	overlay.hide()
	await settle(3)
	save_frame("flags_no_overlay")
	for gate: Dictionary in race.track.gates:
		race.camera.size = 19
		race.camera.position = gate.position+Vector3(0,24,16)
		race.camera.look_at(gate.position)
		await settle(2)
		save_frame("gate_%d" % gate.index)
	overlay.draw_route(race.track)
	overlay.show()
	helper.overview()
	await settle(3)
	save_frame("xray_overview")
	for mesh: MeshInstance3D in overlay.get_children():
		mesh.material_override.no_depth_test = false
	await settle(3)
	save_frame("depth_overview")
	for section: int in range(race.track.definition.sections.size()):
		var station: float = race.track.lengths[section*24+12]
		var p: Vector3 = race.track.sample_3d(station)
		race.camera.size = 20
		race.camera.position = p+Vector3(0,55,0)
		race.camera.rotation_degrees = Vector3(-90,0,0)
		await settle(2)
		save_frame("section_%03d" % section)
	race.track.rebuild_art()
	await settle_physics(5)
	inspect_flags(race,"rebuilt")
	report("time_trial_select",helper.select_course("practice_patch"))
	race.race_mode = "trial"
	report("time_trial_back",race.course.select("mount_rainier"))
	await settle_physics(5)
	inspect_flags(race,"switched")
	race.race_mode = "trial"
	race.start_race()
	race.player_car.ai = true
	race.begin_countdown()
	for i: int in range(400): await get_tree().physics_frame
	report("time_trial_running",race.race_mode=="trial" and race.phase==2 and race.player_car.station>10.0)
	report("performance",helper.performance_report())
	report("fps",Performance.get_monitor(Performance.TIME_FPS))
	report("render_cpu_ms",Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
	save_frame("time_trial_driving")
	# Real player actions in the isolated instance, with hardware input disabled.
	helper.start_test(1,1)
	helper.player_control()
	for i: int in range(250): await get_tree().physics_frame
	var before: Vector3 = race.player_car.position
	Input.action_press("p1_go")
	Input.action_press("boost")
	for i: int in range(45): await get_tree().physics_frame
	Input.action_release("boost")
	Input.action_release("p1_go")
	report("input",{"moved":race.player_car.position.distance_to(before)>1.0,"boost_used":race.player_car.boost<95.0})
	Input.action_press("reset_car")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("reset_car")
	for i: int in range(210): await get_tree().physics_frame
	report("recovery",{"state":race.player_car.state,"supported":not race.player_car.physical_support(race.player_car.position).is_empty()})
	race.toggle_pause()
	var paused_position: Vector3 = race.player_car.position
	for i: int in range(10): await get_tree().physics_frame
	report("pause",race.paused_race and race.player_car.position.is_equal_approx(paused_position))
	race.toggle_pause()
	report("resume",not race.paused_race)
	race.show_menu()
	for dialog: Node in race.get_children():
		if dialog is AcceptDialog and dialog.title=="Third-party asset credits":
			dialog.popup_centered(Vector2i(1040,420))
			await settle(3)
			save_frame("credits")
			dialog.hide()
	report("failures",failures)
	report("passed",failures.is_empty() and _reports.time_trial_back and _reports.time_trial_running and _reports.input.moved and _reports.input.boost_used and _reports.recovery.state==0 and _reports.recovery.supported and _reports.pause and _reports.resume)
	finish()
