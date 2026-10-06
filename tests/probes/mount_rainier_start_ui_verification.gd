extends "res://tests/probes/toys_flags_verification.gd"
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(summer_out_dir)
	_start_ms = Time.get_ticks_msec()
	await settle(5)
	var race: Node3D = get_tree().current_scene.get_node("Race")
	race.profile.read_only = true
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.device = -1
	race.controller.using_pad = false
	var helper: Node = load("res://tests/probes/mount_rainier_live.gd").new()
	race.add_child(helper)
	report("select",helper.select_course())
	await settle_physics(5)
	inspect_flags(race,"aligned")
	report("support",helper.support_report())
	report("gates",helper.gate_checks())
	var measurement: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/baselines/content/mount_rainier/start_alignment/measurement.json"))
	var expected: Vector3 = Vector3(measurement.game_position[0],measurement.game_position[1],measurement.game_position[2])
	report("timing_plane",{"error":race.track.gates[0].position.distance_to(expected),"revision":race.track.definition.revision,"station":race.track.definition.start_station})
	helper.overview()
	var gate: Dictionary = race.track.gates[0]
	race.camera.size = 19
	race.camera.position = gate.position+Vector3(0,24,16)
	race.camera.look_at(gate.position)
	await settle(3)
	save_frame("aligned_finish")
	for cue: Dictionary in race.track.gates:
		race.camera.position = cue.position+Vector3(0,24,16)
		race.camera.look_at(cue.position)
		await settle(2)
		save_frame("gate_%d" % cue.index)
	helper.race_view()
	race.show_menu()
	await settle(3)
	save_frame("menu")
	var info: Label = race.menu.get_node("CourseInfo")
	report("menu_layout",{"minimum":str(info.get_minimum_size()),"size":str(info.size),"end":info.get_rect().end.y,"mode_y":race.menu.get_node("Mode").position.y})
	report("menu_spacing",info.get_rect().end.y<race.menu.get_node("Mode").position.y and info.get_minimum_size().y<=info.size.y)
	report("licence",not "CUP" in race.menu.get_node("DriverProfile/Stats").text)
	race.start_race()
	report("grid",absf(wrapf(race.player_car.station-race.track.definition.start_station,-race.track.total_length/2,race.track.total_length/2))<0.01)
	race.begin_countdown()
	race.set_physics_process(false)
	for car: CharacterBody3D in race.all_cars: car.set_physics_process(false)
	var stages: Array = []
	for value: float in [3.8,2.8,1.8]:
		race.session.countdown = value
		race.start_lights.update(race)
		stages.append(race.start_lights.stage)
		await settle(3)
		save_frame("red_%d" % race.start_lights.stage)
	report("red_sequence",stages==[1,2,3] and not race.banner.visible and race.start_lights.position.y==20 and race.get_node("HUD").visible)
	race.toggle_pause()
	await settle(3)
	save_frame("paused_lights")
	report("pause_hides_lights",not race.start_lights.visible)
	race.toggle_pause()
	race.session.countdown = 0.81
	race.session.tick(1.0/60.0)
	race.start_lights.update(race)
	await settle(3)
	save_frame("green_start")
	report("green_start",race.phase==2 and race.start_lights.stage==4 and race.start_lights.visible and race.banner.text=="")
	race.message = ""
	race.message_time = 0.0
	race.player_car.state = 3
	race._physics_process(1.0/60.0)
	await settle(3)
	save_frame("recovery_without_panel")
	report("no_recovery_panel",not race.banner.visible and race.banner.text=="")
	race.session.race_time = 1.0
	race.start_lights.update(race)
	report("green_expires",not race.start_lights.visible)
	race.show_menu()
	report("menu_hides_lights",not race.start_lights.visible)
	report("failures",failures)
	report("passed",_reports.select.selected and failures.is_empty() and _reports.support.failures.is_empty() and _reports.gates.failures.is_empty() and _reports.timing_plane.error<0.001 and _reports.grid and _reports.menu_spacing and _reports.licence and _reports.red_sequence and _reports.pause_hides_lights and _reports.green_start and _reports.no_recovery_panel and _reports.green_expires and _reports.menu_hides_lights)
	finish()
