extends "res://tests/autopilot/probe_base.gd"
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(summer_out_dir)
	await super._ready()
	await settle(4)
	var race: Node3D = get_tree().current_scene.get_node("Race")
	race.profile.read_only = true
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.using_pad = false
	race.controller.device = -1
	var helper: Node = load("res://tests/probes/beach_buggies_live.gd").new()
	race.add_child(helper)
	var failures: Array = []
	var remote_checks: int = 0
	var teleport_checks: int = 0
	var choices: OptionButton = race.menu.get_node("TrackSelect")
	if choices.item_count!=preload("res://scripts/tracks/content_catalog.gd").IDS.size(): failures.append("Course menu/catalogue count mismatch")
	for id: String in ["toys_r_you","toys_r_asleep","rusty_nuts_workshop","moonlight_junk_heap","firefly_bbq","nighttime_noodles","beach_buggies"]:
		var selected: Dictionary = helper.select_course(id)
		if not selected.selected:
			failures.append({"course":id,"select":selected})
			continue
		await settle_physics(5)
		var checks: Dictionary = helper.gate_checks()
		report(id,checks)
		failures.append_array(checks.failures)
		var car: CharacterBody3D = race.player_car
		for gate: Dictionary in race.track.gates:
			var heading: Vector2 = race.track.direction(gate.station)
			var forward: Vector3 = Vector3(heading.x,0,heading.y)
			car.reset_car(gate.station-8.0,0.0)
			race.session.progress.reset(race.all_cars,race.track.total_length)
			var teleport_expected: int = race.track.gates.size() if gate.index==0 else gate.index
			race.session.progress.records[car.player].gate = teleport_expected
			car.gate = teleport_expected
			car.position = gate.position+forward*0.15
			var teleported: Dictionary = race.track.project_3d(car.position,gate.station)
			var teleport_response: Dictionary = race.session.progress.observe(car,Vector2(teleported.station,teleported.distance),0.05,1.0)
			teleport_checks += 1
			if car.gate!=teleport_expected or teleport_response.has("lap"): failures.append({"course":id,"teleport_gate":gate.index})
			var edges: Array[Vector3] = preload("res://scripts/tracks/imported_checkpoint_flags.gd").plane_edges(race.track,gate)
			var normal: Vector3 = Vector3(-heading.y,0,heading.x)
			var reach: float = maxf(absf((edges[0]-gate.position).dot(normal)),absf((edges[1]-gate.position).dot(normal)))+1.0
			for span: int in range(race.track.starts.size()):
				if absf(wrapf(race.track.lengths[span]-gate.station,-race.track.total_length*0.5,race.track.total_length*0.5))<15.0: continue
				var a: Vector3 = race.track.starts[span]
				var b: Vector3 = race.track.ends[span]
				var da: float = (a-gate.position).dot(forward)
				var db: float = (b-gate.position).dot(forward)
				if da*db>=0.0 or absf(da-db)<0.000001: continue
				var point: Vector3 = a.lerp(b,da/(da-db))
				if absf((point-gate.position).dot(normal))<reach: continue
				car.position = point-forward*0.06
				var before: Dictionary = race.track.project_3d(car.position,race.track.lengths[span])
				if not before.supported: continue
				car.station = before.station
				car.state = 0
				race.session.progress.reset(race.all_cars,race.track.total_length)
				var expected: int = race.track.gates.size() if gate.index==0 else gate.index
				race.session.progress.records[car.player].gate = expected
				car.gate = expected
				car.position = point+forward*0.06
				var after: Dictionary = race.track.project_3d(car.position,race.track.lengths[span])
				if not after.supported: continue
				var response: Dictionary = race.session.progress.observe(car,Vector2(after.station,after.distance),0.05,1.0)
				remote_checks += 1
				if car.gate!=expected or response.has("lap"): failures.append({"course":id,"remote_plane_gate":gate.index,"response":response})
				break
		race.show_menu()
	for dialog: Node in race.get_children():
		if dialog is AcceptDialog and dialog.title=="Third-party asset credits":
			var scroll: ScrollContainer = dialog.get_child(0)
			var credits: RichTextLabel = scroll.get_child(0)
			for id: String in ["toys_r_asleep","rusty_nuts_workshop","moonlight_junk_heap","firefly_bbq","nighttime_noodles","beach_buggies"]:
				var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tracks/%s/measurement_manifest.json" % id))
				if not credits.text.contains(manifest.title) or not credits.text.contains(manifest.source_url): failures.append({"missing_credit":id})
			dialog.popup_centered(Vector2i(1040,420))
			await settle(3)
			scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
			await settle(3)
			save_frame("credits_last_course")
			report("credits_scroll",scroll.scroll_vertical)
			if scroll.scroll_vertical<=0: failures.append("Credits do not scroll")
			dialog.hide()
	report("remote_branch_checks",remote_checks)
	report("teleport_checks",teleport_checks)
	report("failures",failures)
	report("passed",failures.is_empty() and remote_checks>0)
	finish()
