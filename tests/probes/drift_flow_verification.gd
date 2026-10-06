extends "res://tests/probes/race_quality_ai_verification.gd"
const RULES: Script = preload("res://scripts/race/drift_rules.gd")
const STORE: Script = preload("res://scripts/profile_store.gd")
const CATALOG: Script = preload("res://scripts/tracks/content_catalog.gd")
const STATS: Script = preload("res://scripts/vehicles/player_stats.gd")

func sample(progress: float) -> Dictionary:
	return {"progress":progress,"distance":1.0,"speed":10.0,"forward_speed":8.0,"angle":30.0,"safe":true,"incident":false,"valid_motion":true}

func rule_tests() -> void:
	var rules: RefCounted = RULES.new()
	rules.reset(0.0)
	for index: int in range(1,31): rules.step(0.1,sample(index))
	check(rules.combo>0.0 and rules.score==0.0,"sustained_slip_builds_unbanked_combo")
	var saved: float = rules.combo
	for index: int in range(31,37):
		var straight: Dictionary = sample(index)
		straight.angle = 0.0
		rules.step(0.1,straight)
	check(rules.combo==0.0 and is_equal_approx(rules.score,saved),"straight_exit_banks")
	for invalid: String in ["stationary","spin","reverse","offroad","collision","teleport","old_patch"]:
		rules.reset(100.0 if invalid=="old_patch" else 0.0)
		for index: int in range(1,31):
			var bad: Dictionary = sample(index)
			match invalid:
				"stationary": bad.distance = 0.0; bad.speed = 0.0
				"spin": bad.angle = 85.0
				"reverse": bad.forward_speed = -8.0
				"offroad": bad.safe = false
				"collision": bad.incident = true
				"teleport": bad.valid_motion = false
			rules.step(0.1,bad)
		check(rules.score==0.0 and rules.combo==0.0,"reject_"+invalid)
	rules.reset(0.0)
	for index: int in range(1,31): rules.step(0.1,sample(index))
	var hit: Dictionary = sample(31)
	hit.incident = true
	rules.step(0.1,hit)
	check(rules.combo==0.0 and rules.score==0.0,"collision_loses_pending_combo")

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
	race.machine_settings.read_only = true
	race.profile_directory.read_only = true
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	app.get_node("Opening").queue_free()
	get_tree().paused = false
	race.get_node("HUD").show()
	check(race.profile.read_only,"sentinel_before_setup")
	race.profile.path = summer_out_dir+"/profile.json"
	race.profile.read_only = false
	race.profile.status = ""
	race.profile.data = STORE.defaults()
	race.profile_selected = true
	race.profile_menu.hide()
	race.controls_setup.config_path = summer_out_dir+"/controls.cfg"
	race.show_menu()
	rule_tests()
	var historical: Dictionary = {"driver":0,"course":"topspeed_oval","vehicle":"drift_car","laps":1,"stats":STATS.VERSION+":"+STATS.code(STATS.neutral()),"signature":"a".repeat(64),"score":1234}
	var history_key: String = RULES.CONTEXT.context_key(historical)
	race.profile.data.drift_records[history_key] = historical
	check(race.profile.save_profile()==OK,"save_historical_fixture")
	# Profile activation exercises stale saved mode/course migration.
	var directory: RefCounted = race.profile_directory
	directory.root = summer_out_dir+"/profiles"
	directory.legacy_path = summer_out_dir+"/absent_legacy.json"
	directory.read_only = false
	directory.index = {"schema_version":1,"last_selected":"","entries":[]}
	var created: Dictionary = directory.create_profile("Drifter",0)
	check(created.has("id"),"sandbox_identity")
	if not created.has("id"): report("passed",false); finish(); return
	var stale: RefCounted = STORE.new()
	stale.path = directory.payload_path(created.id)
	stale.load_profile()
	stale.data.mode = "drift"
	stale.data.quick_race.track_id = "topspeed_oval"
	stale.data.drift_records[history_key] = historical
	check(stale.save_profile()==OK,"save_stale_mode")
	check(race.activate_profile(created.id)==OK,"activate_stale_mode")
	await get_tree().process_frame
	while race.course.loading: await get_tree().process_frame
	check(race.track_id=="bazaar" and race.player_car.base_tuning.id=="drift_car","stale_saved_mode_fallback")
	check(race.profile.data.drift_records.has(history_key),"historical_score_preserved")
	race.menu_flow.choose_mode("quick")
	check(race.course.select("topspeed_oval"),"topspeed_ordinary_selection")
	race.menu_flow.home.get_node("Drift").pressed.emit()
	while race.course.loading: await get_tree().process_frame
	race.menu_flow.show_step(3)
	await settle(4)
	check(race.track_id=="bazaar" and race.player_car.base_tuning.id=="drift_car","eligible_course_and_class")
	var selector: OptionButton = race.menu.get_node("TrackSelect")
	for index: int in range(selector.item_count): check(selector.is_item_disabled(index)==(CATALOG.IDS[index]!="bazaar"),"course_eligibility_%d" % index)
	check(CATALOG.validate_entry(race.course.entry,"bazaar","drift_car",false,true).has("entry"),"drift_validation")
	check(not race.course.select("bazaar","drift_car",{"error":"Injected Bazaar load failure"}),"load_failure_rejected")
	race.start_race()
	check(race.phase!=6 and race.course.error.contains("Injected"),"load_failure_blocks_start")
	check(race.course.select("bazaar"),"load_failure_retry")
	race.menu_flow.show_step(3)
	save_frame("setup")
	race.start_race()
	race.begin_countdown()
	race.session.change_phase(2)
	race.paused_race = true
	var elapsed: float = race.drift.elapsed
	await settle(10)
	check(race.drift.elapsed==elapsed,"pause_freezes_duration")
	race.paused_race = false
	race.set_physics_process(false)
	race.player_car.set_physics_process(false)
	# Integration fixtures seed a score at the timer boundary; they do not
	# claim that the physical controller produced this score.
	race.drift.rules.score = 1500.0
	race.drift.elapsed = RULES.DURATION
	race.drift.finish()
	await settle(20)
	check(race.phase==3 and race.session.results[0].finished,"target_win")
	check(race.profile.data.records.is_empty(),"no_time_pb_for_drift")
	check(race.profile.data.drift_records.size()==2 and race.profile.data.drift_records.has(history_key),"score_recorded_and_history_retained")
	var loaded: RefCounted = STORE.new()
	loaded.path = race.profile.path
	loaded.load_profile()
	report("loaded_scores",loaded.data.drift_records)
	report("live_scores",race.profile.data.drift_records)
	check(loaded.data.drift_records==race.profile.data.drift_records,"score_reload")
	var before: Dictionary = race.profile.data.duplicate(true)
	race.drift.finish()
	race.on_results_ready(race.session.results)
	check(before==race.profile.data,"duplicate_result_guard")
	save_frame("score_results")
	race.results_action()
	check(race.phase==6,"retry_preview")
	check(race.track_id=="bazaar" and race.player_car.base_tuning.id=="drift_car","retry_course_and_class")
	race.begin_countdown()
	check(race.drift.rules.score==0.0 and race.drift.rules.combo==0.0 and race.drift.elapsed==0.0,"retry_score_reset")
	race.session.change_phase(2)
	race.drift.elapsed = RULES.DURATION
	race.drift.finish()
	check(not race.session.results[0].finished and race.drift.note.contains("MISSED"),"target_failure")
	# A real 90-second physical run uses ordinary steering commands, without
	# injecting pose, velocity, score or elapsed time. Automated scores never save.
	race.show_menu()
	race.menu_flow.choose_mode("drift")
	race.set_physics_process(true)
	race.player_car.set_physics_process(true)
	race.start_race()
	race.player_car.ai = true
	race.player_car.ai_driver = preload("res://tests/fixtures/drift_input_driver.gd").new()
	race.player_car.ai_driver.difficulty = 2
	race.player_car.ai_driver.reset(race.player_car,42)
	race.begin_countdown()
	race.session.change_phase(2)
	var before_physical: Dictionary = race.profile.data.drift_records.duplicate(true)
	var safe_frames: int = 0
	var slipping_frames: int = 0
	var max_combo: float = 0.0
	var captured: bool = false
	for frame: int in range(6000):
		await get_tree().physics_frame
		if not race.drift.last_sample.is_empty():
			var motion: Dictionary = race.drift.last_sample
			if motion.safe: safe_frames += 1
			if motion.safe and absf(motion.angle)>=12.0 and absf(motion.angle)<=65.0: slipping_frames += 1
			max_combo = maxf(max_combo,race.drift.rules.combo)
		if not captured and race.drift.rules.combo>0.0:
			await settle(2)
			save_frame("physical_drift")
			captured = true
		if race.phase==3: break
	check(race.phase==3 and race.drift.elapsed>=RULES.DURATION,"physical_90_second_completion")
	check(safe_frames>0 and slipping_frames>0 and max_combo>0.0,"physical_asphalt_scoring")
	check(before_physical==race.profile.data.drift_records,"automated_score_not_saved")
	report("physical_run",{"elapsed":race.drift.elapsed,"score":race.drift.rules.score,"max_combo":max_combo,"safe_frames":safe_frames,"slipping_frames":slipping_frames,"crashes":race.player_car.crashes,"recoveries":race.player_car.ai_driver.recoveries,"note":race.drift.note})
	await settle(3)
	save_frame("physical_results")
	# Integration fixture: unsafe position must discard a pending combo via
	# the controller's actual model/support classification, not just rule tests.
	race.player_car.set_physics_process(false)
	race.set_physics_process(false)
	race.session.change_phase(2)
	race.drift.begin()
	race.drift.rules.combo = 100.0
	race.player_car.position += Vector3(500,0,500)
	race.drift.tick(1.0/60.0)
	check(not race.drift.last_sample.safe and race.drift.rules.combo==0.0 and race.drift.rules.score==0.0,"unsafe_shortcut_loses_combo")
	race.drift.resolved = true
	race.show_menu()
	race.menu_flow.choose_mode("quick")
	check(race.player_car.base_tuning.id=="racing_car","standard_assignment_restored")
	for index: int in range(selector.item_count): check(not selector.is_item_disabled(index),"standard_course_unlocked_%d" % index)
	report("failures",failures)
	report("passed",failures.is_empty())
	finish()
