extends "res://tests/probes/race_quality_verification.gd"
# One course per disposable instance. Controlled placements test camera clearance;
# the separate full-race probe tests driving and checkpoint traversal.
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
	race.controller.using_pad = false
	race.controller.device = -1
	for name: StringName in InputMap.get_actions(): InputMap.action_erase_events(name)
	app.get_node("Opening").queue_free()
	get_tree().paused = false
	race.get_node("HUD").show()
	race.controls_setup.config_path = summer_out_dir+"/controls.cfg"
	var course: String = OS.get_environment("TABLETOP_VERIFY_COURSE")
	if course.is_empty(): course = "toys_r_you"
	check(race.profile.read_only,"read_only")
	check(race.course.select(course),"selected")
	await settle(4)
	race.rival_count = 0
	race.race_mode = "quick"
	race.start_race()
	race.begin_countdown()
	race.session.countdown = 0.81
	await settle_physics(3)
	race.set_physics_process(false)
	for car: CharacterBody3D in race.cars: car.set_physics_process(false)
	var blocked: Array = []
	var samples: Array = []
	for index: int in range(48):
		var station: float = race.track.total_length*float(index)/48.0
		race.player_car.reset_car(station,0.0)
		for backwards: bool in [false,true]:
			if backwards: race.player_car.heading += PI
			race.camera_driver.mode = 2
			race.camera_driver.reset(race.camera,race.player_car)
			await settle_physics(2)
			var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
			var sphere: SphereShape3D = SphereShape3D.new()
			sphere.radius = 0.20
			query.shape = sphere
			query.transform = Transform3D(Basis.IDENTITY,race.camera.global_position)
			query.collision_mask = 1
			var collisions: Array = race.get_world_3d().direct_space_state.intersect_shape(query,4)
			var sample: Dictionary = {"station":station,"backwards":backwards,"camera":str(race.camera.global_position),"car":str(race.player_car.global_position),"finite":race.camera.transform.is_finite()}
			samples.append(sample)
			if not collisions.is_empty():
				sample["collider"] = str(collisions[0].collider.get_path())
				blocked.append(sample)
				await settle(2)
				save_frame("blocked_%d_%s" % [index,str(backwards)])
			elif index%8==0 and not backwards:
				await settle(2)
				save_frame("close_%d" % index)
	check(blocked.is_empty(),"close_volume_clear_all_samples")
	report("blocked_samples",blocked)
	report("camera_samples",samples)
	check(samples.all(func(item: Dictionary) -> bool: return item.finite),"camera_all_finite")
	# Warm repeat switching must clear all per-race pools and preserve the profile.
	race.set_physics_process(true)
	for car: CharacterBody3D in race.cars: car.set_physics_process(true)
	var switches: Array = []
	var baseline_nodes: int = -1
	var connections: int = race.session.phase_changed.get_connections().size()
	for cycle: int in range(5):
		var away: String = "game_table" if course!="game_table" else "toys_r_you"
		check(race.course.select(away),"switch_away_%d" % cycle)
		await settle(3)
		var started: int = Time.get_ticks_msec()
		check(race.course.select(course),"switch_back_%d" % cycle)
		await settle(5)
		var nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		if baseline_nodes<0: baseline_nodes = nodes
		check(nodes==baseline_nodes,"switch_nodes_%d" % cycle)
		check(race.profile.read_only and race.feedback.messages.is_empty() and race.feedback.shake==0.0,"switch_cleanup_%d" % cycle)
		check(race.session.phase_changed.get_connections().size()==connections,"switch_signals_%d" % cycle)
		switches.append({"cycle":cycle,"visible_ms":Time.get_ticks_msec()-started,"nodes":nodes,"memory_mib":Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0})
		race.start_race()
		race.begin_countdown()
		await settle_physics(3)
		check(race.camera_driver.mode==2,"switch_retains_camera_%d" % cycle)
	race.show_menu()
	report("switches",switches)
	report("course",course)
	report("failures",failures)
	report("passed",failures.is_empty())
	finish()
