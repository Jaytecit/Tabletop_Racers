extends "res://tests/probes/race_quality_ai_verification.gd"
var candidate: RefCounted = preload("res://tests/fixtures/bazaar_loading_selection.gd").new()

func _enter_tree() -> void:
	super._enter_tree()
	assert(candidate.prepare() == OK,"Candidate catalogue compilation failed")
	report("candidate_catalogue",candidate.receipt)
	get_tree().node_added.connect(candidate.attach)

func choose_course(id: String) -> void:
	var choice: OptionButton = race.menu.get_node("TrackSelect")
	var index: int = race.course.CATALOG.IDS.find(id)
	choice.select(index)
	choice.item_selected.emit(index)
	for frame: int in range(1200):
		await get_tree().process_frame
		if not race.course.loading: break
	check(race.track_id == id and race.course.error.is_empty() and not race.course.loading,"menu_selected_"+id)
	await settle(3)

func _ready() -> void:
	await settle(4)
	var app: Node = get_tree().current_scene
	race = app.get_node("Race")
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.using_pad = false
	race.controller.device = -1
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	app.get_node("Opening").queue_free()
	get_tree().paused = false
	race.get_node("HUD").show()
	check(race.profile.read_only,"read_only")
	race.menu_flow.choose_mode("quick")
	race.menu_flow.show_step(3)
	await choose_course("bazaar")
	check(race.player_car.base_tuning.id == "racing_car","assigned_racing_car")
	check(race.menu.get_node("CourseInfo").text.contains("ASSIGNED · RACING CAR"),"assigned_label")
	check(race.menu.get_node("CourseMap").texture == race.course.entry.preview,"measured_preview")
	var signature: String = race.trial.signature
	race.trial.refresh_signature()
	check(race.trial.signature == signature,"selection_signature_current")
	save_frame("quick_ready")
	race.rival_count = 3
	race.race_laps = 1
	race.start_race()
	check(race.cars.size() == 4 and race.race_mode == "quick","quick_field")
	race.begin_countdown()
	race.session.change_phase(2)
	var before: Vector3 = race.player_car.position
	Input.action_press("p1_go")
	await settle_physics(30)
	Input.action_release("p1_go")
	check(race.player_car.position.distance_to(before) > 1.0,"quick_player_moves")
	race.toggle_pause()
	before = race.player_car.position
	await settle_physics(4)
	check(race.player_car.position == before,"quick_pause")
	race.toggle_pause()
	race.start_race()
	check(race.phase == race.session.Phase.PREVIEW and race.player_car.laps == 0,"quick_retry")
	race.show_menu()
	race.menu_flow.choose_mode("trial")
	race.menu_flow.show_step(3)
	await choose_course("game_table")
	await choose_course("bazaar")
	check(race.player_car.base_tuning.id == "racing_car","trial_assigned_racing_car")
	signature = race.trial.signature
	race.trial.refresh_signature()
	check(race.trial.signature == signature,"trial_selection_signature_current")
	save_frame("trial_ready")
	race.start_race()
	check(race.cars.size() == 1 and race.race_mode == "trial","trial_solo")
	race.player_car.ai = true
	race.player_car.ai_driver.rng.seed = 64
	race.begin_countdown()
	for frame: int in range(6000):
		await get_tree().physics_frame
		if race.phase == 3: break
	check(race.phase == 3 and race.player_car.laps == 1 and race.player_car.finish_time > 0.0,"trial_valid_finish")
	check(race.player_car.crashes == 0 and race.player_car.ai_driver.recoveries == 0 and race.session.progress.records[1].penalty == 0.0,"trial_clean_finish")
	report("trial",{"time":race.player_car.finish_time,"signature":race.trial.signature,"key":race.trial.key})
	await settle(30)
	save_frame("trial_results")
	race.show_menu()
	race.menu_flow.choose_mode("freestyle")
	check(race.set_vehicle("monster_truck"),"freestyle_truck")
	race.menu_flow.show_step(3)
	await choose_course("game_table")
	await choose_course("bazaar")
	check(race.player_car.base_tuning.id == "monster_truck","freestyle_switch_preserves_vehicle")
	save_frame("freestyle_ready")
	check(race.profile.read_only,"still_read_only")
	check(preload("res://scripts/vehicles/imported_visual.gd").scene_cache.size() <= 2,"vehicle_scene_cache_bounded")
	if candidate.production_registered:
		check(race.course.get_script() == preload("res://scripts/tracks/selected_course.gd"),"production_selector")
		var store: Script = preload("res://scripts/profile_store.gd")
		var saved: RefCounted = store.new()
		saved.path = summer_out_dir.path_join("bazaar_profile.json")
		saved.data = store.defaults()
		saved.data.quick_race.track_id = "bazaar"
		saved.data.quick_race.vehicle_id = "racing_car"
		saved.data.mode = "trial"
		var trial: Dictionary = _reports.trial
		saved.data.records[trial.key] = {"signature":trial.signature,"total":trial.time,"best_lap":trial.time,"replay":""}
		check(saved.save_profile() == OK,"bazaar_profile_saved")
		var reloaded: Dictionary = saved.load_profile()
		check(reloaded.quick_race.track_id == "bazaar" and reloaded.quick_race.vehicle_id == "racing_car" and reloaded.mode == "trial","bazaar_selection_reloaded")
		check(reloaded.records.has(trial.key),"bazaar_record_reloaded")
		report("profile_fixture",saved.path)
	report("failures",failures)
	report("passed",failures.is_empty())
	for node: Node in get_tree().root.find_children("*","AudioStreamPlayer",true,false): node.stop()
	await settle(5)
	finish()
