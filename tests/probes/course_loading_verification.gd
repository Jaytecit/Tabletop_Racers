extends "res://tests/probes/race_quality_verification.gd"
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
	for name: StringName in InputMap.get_actions(): InputMap.action_erase_events(name)
	app.get_node("Opening").queue_free()
	get_tree().paused = false
	race.get_node("HUD").show()
	var target_course: String = OS.get_environment("TABLETOP_VERIFY_COURSE")
	if target_course.is_empty(): target_course = "toys_r_you"
	var timings: Array = []
	for id: String in [target_course,"game_table",target_course,"game_table",target_course]:
		var begin: int = Time.get_ticks_usec()
		check(race.course.select(id),"select_%d" % timings.size())
		await settle(3)
		var sample: Dictionary = race.course.last_load_metrics.duplicate()
		sample["visible_ms"] = (Time.get_ticks_usec()-begin)/1000.0
		sample["memory_mib"] = Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0
		sample["record_signature"] = race.trial.signature
		timings.append(sample)
	# Exercise the menu's asynchronous path, including superseded and cancelled loads.
	race.menu_flow.show_step(3)
	var original_id: String = race.track_id
	race.course.request_select("game_table")
	check(race.course.loading and race.menu.get_node("Start").disabled,"loading_blocks_start")
	race.start_race()
	check(race.phase==0,"cannot_start_loading_course")
	race.course.request_select(target_course)
	for i: int in range(600):
		await get_tree().process_frame
		if not race.course.loading: break
	check(race.track_id==target_course and not race.course.loading,"latest_selection_wins")
	race.course.request_select("game_table")
	race.menu_flow.go_back()
	await settle(5)
	# Assigned-vehicle modes return directly to Character; Freestyle has Vehicle.
	var back_step: int = 2 if race.race_mode=="freestyle" else 1
	check(race.track_id==original_id and not race.course.loading and race.menu_flow.step==back_step,"back_cancels_selection")
	race.menu_flow.show_step(3)
	race.course.request_select("missing_course_fixture")
	check(race.course.error!="" and race.menu.get_node("Start").disabled and race.track_id==original_id,"failed_selection_preserves_course")
	var previous_entry: Resource = race.course.entry
	race.course.cache_entry("game_table",Resource.new())
	race.course.request_select("game_table")
	for frame: int in range(600):
		await get_tree().process_frame
		if not race.course.loading: break
	check(race.course.error!="" and race.course.entry==previous_entry and race.menu.get_node("Start").disabled,"invalid_resource_preserves_course")
	race.course.cached_entries.erase("game_table")
	race.course.request_select("game_table")
	for i: int in range(600):
		await get_tree().process_frame
		if not race.course.loading: break
	check(race.course.error=="" and race.track_id=="game_table" and not race.menu.get_node("Start").disabled,"failure_can_recover")
	check(race.course.cached_entries.size()<=2,"cache_bounded")
	race.course.cached_entries.clear()
	race.course.cache_order.clear()
	var begin: int = Time.get_ticks_usec()
	var frames_before: int = Engine.get_frames_drawn()
	race.course.request_select(target_course)
	await settle(1)
	save_frame("loading")
	for i: int in range(900):
		await get_tree().process_frame
		if not race.course.loading: break
	report("threaded_selection",{"visible_ms":(Time.get_ticks_usec()-begin)/1000.0,"presented_frames":Engine.get_frames_drawn()-frames_before})
	check(not race.course.loading and race.track_id==target_course,"threaded_selection_complete")
	check(Engine.get_frames_drawn()-frames_before>3,"loading_keeps_presenting_frames")
	await settle(4)
	save_frame("ready")
	# Supersede a request after its validation worker has actually started.
	race.course.request_select("game_table")
	for frame: int in range(600):
		await get_tree().process_frame
		if race.course.validation_worker!=null: break
	check(race.course.validation_worker!=null,"validation_worker_started")
	race.course.request_select(target_course)
	for frame: int in range(900):
		await get_tree().process_frame
		if not race.course.loading and race.course.validation_worker==null: break
	check(race.track_id==target_course and not race.course.loading and race.course.validation_worker==null,"inflight_stale_validation_discarded")
	race.course.request_select("game_table")
	for frame: int in range(600):
		await get_tree().process_frame
		if race.course.validation_worker!=null: break
	race.menu_flow.go_back()
	for frame: int in range(900):
		await get_tree().process_frame
		if race.course.validation_worker==null: break
	check(race.track_id==target_course and not race.course.loading and race.course.validation_worker==null,"inflight_validation_back_cancels")
	race.course.request_select("game_table")
	for frame: int in range(600):
		await get_tree().process_frame
		if race.course.validation_worker!=null: break
	race.course.shutdown()
	await settle(3)
	check(race.track_id==target_course and race.course.validation_worker==null and not race.course.loading,"shutdown_drains_worker")
	check(race.profile.read_only,"read_only")
	report("timings",timings)
	report("runtime",Engine.get_version_info())
	report("gpu",RenderingServer.get_video_adapter_name())
	report("failures",failures)
	report("passed",failures.is_empty())
	report("course",target_course)
	for node: Node in get_tree().root.find_children("*","AudioStreamPlayer",true,false): node.stop()
	await settle(5)
	finish()
