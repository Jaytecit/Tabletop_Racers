extends "res://tests/probes/race_quality_ai_verification.gd"
# First asynchronous selection and warm repeats; no prior load of the target.
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
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	app.get_node("Opening").queue_free()
	get_tree().paused = false
	race.get_node("HUD").show()
	race.menu_flow.show_step(3)
	var target: String = OS.get_environment("TABLETOP_VERIFY_COURSE")
	if target.is_empty(): target = "mount_rainier"
	var samples: Array[Dictionary] = []
	for id: String in [target,"game_table",target,"game_table",target]:
		var gaps: Array[float] = []
		var begun: int = Time.get_ticks_usec()
		var previous: int = begun
		var frames: int = Engine.get_frames_drawn()
		race.course.request_select(id)
		while race.course.loading:
			await get_tree().process_frame
			var now: int = Time.get_ticks_usec()
			gaps.append((now-previous)/1000.0)
			previous = now
		var ready_frame: int = Engine.get_frames_drawn()
		while Engine.get_frames_drawn()<ready_frame+3:
			await get_tree().process_frame
			var now: int = Time.get_ticks_usec()
			gaps.append((now-previous)/1000.0)
			previous = now
		gaps.sort()
		var sample: Dictionary = race.course.last_load_metrics.duplicate()
		sample.merge({"visible_ms":(Time.get_ticks_usec()-begun)/1000.0,"presented_frames":Engine.get_frames_drawn()-frames,"max_process_gap_ms":gaps.back(),"p95_process_gap_ms":gaps[int(gaps.size()*0.95)],"memory_mib":Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0})
		sample["ready_to_present_ms"] = sample.visible_ms-sample.request_to_ready_ms
		samples.append(sample)
		check(race.track_id==id and race.course.error.is_empty() and not race.menu.get_node("Start").disabled,"ready_%d" % samples.size())
		check(Engine.get_frames_drawn()-frames>3,"responsive_%d" % samples.size())
	check(race.profile.read_only,"read_only")
	report("samples",samples)
	report("failures",failures)
	report("passed",failures.is_empty())
	save_frame("ready")
	for node: Node in get_tree().root.find_children("*","AudioStreamPlayer",true,false): node.stop()
	await settle(5)
	finish()
