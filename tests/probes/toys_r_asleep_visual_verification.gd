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
	var helper: Node = load("res://tests/probes/toys_r_asleep_live.gd").new()
	race.add_child(helper)
	report("select",helper.select_course())
	await settle_physics(5)
	inspect_flags(race,"initial")
	helper.overview()
	var overlay: Node3D = race.track.get_node("Generated/RouteDebugOverlay")
	overlay.hide()
	await settle(3)
	save_frame("flags_no_overlay")
	for gate: Dictionary in race.track.gates:
		race.camera.size = 19
		race.camera.position = gate.position+Vector3(0,24,16)
		race.camera.look_at(gate.position)
		await settle(2)
		save_frame("gate_%d" % gate.index)
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
	report("time_trial_back",race.course.select("toys_r_asleep"))
	await settle_physics(5)
	inspect_flags(race,"switched")
	race.race_mode = "trial"
	race.start_race()
	race.player_car.ai = true
	race.begin_countdown()
	for i: int in range(400): await get_tree().physics_frame
	report("time_trial_running",race.race_mode=="trial" and race.phase==2 and race.player_car.station>10.0)
	save_frame("time_trial_driving")
	race.show_menu()
	for dialog: Node in race.get_children():
		if dialog is AcceptDialog and dialog.title=="Third-party asset credits":
			dialog.popup_centered(Vector2i(1040,420))
			await settle(3)
			save_frame("credits")
			dialog.hide()
	report("toys_regression",load("res://tests/probes/toys_alignment_checks.gd").check(load("res://tracks/toys_r_you/definition.tres")))
	helper.select_course("game_table")
	await settle_physics(4)
	procedural_checks(race)
	helper.select_course("practice_patch")
	await settle_physics(4)
	procedural_checks(race)
	report("failures",failures)
	report("passed",failures.is_empty() and _reports.toys_regression.failures.is_empty() and _reports.time_trial_back and _reports.time_trial_running)
	finish()
