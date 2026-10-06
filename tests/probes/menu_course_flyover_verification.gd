extends "res://tests/probes/race_quality_ai_verification.gd"

func _ready() -> void:
	await settle(4)
	var app: Node = get_tree().current_scene
	race = app.get_node("Race")
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.device = -1
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	app.get_node("Opening").queue_free()
	get_tree().paused = false
	race.get_node("HUD").show()
	race.menu.show()
	race.menu_flow.show_step(3)
	for id: String in ["game_table","toys_r_you"]:
		race.course.request_select(id)
		while race.course.loading: await get_tree().process_frame
		await settle(3)
		check(race.track_id==id and race.course.error.is_empty(),id+"_selected")
		var camera: Camera3D = race.menu.get_node("Diorama").get_child(0).get_child(0).get_node("PreviewCamera")
		race.garage.refresh_course_preview(race)
		var start: float = race.track.definition.start_station+minf(18.0,race.track.total_length*0.12)
		check(is_equal_approx(camera.station,start),id+"_reset")
		var section: Dictionary = race.track.at(start)
		var focus: Vector3 = (section.position-camera.centre)*camera.ratio+Vector3.UP*0.12
		if not race.track.definition.imported_surface: focus.y = section.position.y*camera.ratio+0.12
		check(is_equal_approx(camera.position.y-focus.y,camera.size*1.25),id+"_original_height")
		var origin: Vector3 = camera.position
		var zoom: float = camera.size
		save_frame(id+"_start")
		await get_tree().create_timer(2.0).timeout
		check(camera.position.distance_to(origin)>0.03,id+"_moving")
		check(is_equal_approx(camera.size,zoom),id+"_fixed_zoom")
		save_frame(id+"_moving")
		race.menu_flow.show_step(2)
		var stopped: float = camera.station
		await settle(10)
		check(is_equal_approx(camera.station,stopped),id+"_hidden_stops")
		race.menu_flow.show_step(3)
		camera.station = race.track.total_length-0.001
		await get_tree().physics_frame
		await settle(3)
		check(camera.station<1.0,id+"_lap_wrap")
		check(camera.position.is_finite(),id+"_finite")
	check(race.profile.read_only,"read_only")
	report("failures",failures)
	report("passed",failures.is_empty())
	for node: Node in get_tree().root.find_children("*","AudioStreamPlayer",true,false): node.stop()
	await settle(5)
	finish()
