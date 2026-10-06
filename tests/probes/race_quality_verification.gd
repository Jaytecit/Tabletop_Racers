extends "res://tests/probes/race_quality_ai_verification.gd"
# Controlled fixtures supplement the separate full-race reference.
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
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	app.get_node("Opening").queue_free()
	get_tree().paused = false
	race.get_node("HUD").show()
	check(race.profile.read_only,"read_only")
	race.profile.vehicle().stats = preload("res://scripts/vehicles/player_stats.gd").neutral()
	race.garage.apply_stats(race)
	race.race_mode = "quick"
	check(race.course.select("toys_r_you"),"selected")
	await settle(4)
	race.camera_driver.mode = 0
	race.rival_count = 0
	race.race_laps = 3
	await start_at(20.0)
	var player: CharacterBody3D = race.player_car
	var start_position: Vector3 = player.position
	var start_frame: int = Engine.get_physics_frames()
	Input.action_press("p1_go")
	Input.action_press("boost")
	await settle_physics(45)
	Input.action_release("boost")
	Input.action_release("p1_go")
	check(player.position.distance_to(start_position)>1.0 and player.boost<95.0,"real_boost_motion")
	check(race.feedback.emitted.get("boost_start",0)==1,"one_boost_edge")
	report("boost_input",{"before":start_frame,"after":Engine.get_physics_frames(),"used":100.0-player.boost,"distance":player.position.distance_to(start_position)})
	await settle(2)
	save_frame("boost")
	await action("pause_race",2)
	var paused_position: Vector3 = player.position
	var paused_wheel: float = player.visual_motion.roll_angle
	var paused_clock: float = race.feedback.clock
	await settle_physics(10)
	check(race.paused_race and player.position == paused_position and player.visual_motion.roll_angle == paused_wheel and race.feedback.clock == paused_clock,"pause_freezes_motion_and_feedback")
	await action("pause_race",2)
	check(not race.paused_race,"input_resumes")
	await action("reset_car",2)
	check(player.state!=0 and race.feedback.emitted.get("recovery_start",0)==1,"input_recovery_start")
	save_frame("recovery")
	await settle_physics(170)
	check(player.state==0 and race.feedback.emitted.get("recovery_end",0)==1,"recovery_finishes_once")
	await start_at(20.0)
	await action("p1_right",8,false)
	check(absf(player.visual_motion.mounts[2].rotation.y)>0.4 and is_zero_approx(player.visual_motion.mounts[0].rotation.y),"front_only_stationary_steer")
	check(is_zero_approx(player.visual_motion.roll_angle),"stationary_wheels_do_not_roll")
	await close_view("stationary_full_lock")
	Input.action_release("p1_right")
	var before_reverse: Vector3 = player.position
	await action("p1_brake",24)
	var reverse_distance: float = (player.position-before_reverse).dot(Vector3(cos(player.heading),0,sin(player.heading)))
	var reverse_error: float = absf(wrapf(player.visual_motion.roll_angle+reverse_distance/player.visual_motion.radii[0],-PI,PI))
	report("reverse_measurement",{"distance":reverse_distance,"angle":player.visual_motion.roll_angle,"wrapped_error":reverse_error})
	check(reverse_distance<0.0 and reverse_error<0.03,"reverse_signed_roll")
	await close_view("reverse")
	await start_at(20.0)
	player.position.y += 0.8
	player.airborne = true
	player.lift_speed = -1.0
	await settle_physics(30)
	check(not player.airborne and race.feedback.emitted.get("landing",0)==1,"physical_landing_once")
	await settle_physics(20)
	check(race.feedback.emitted.get("landing",0)==1 and player.visual_motion.compression==0.0,"landing_settles_without_ground_spam")
	var enabled_trace: Array = await movement_trace(true)
	var disabled_trace: Array = await movement_trace(false)
	var deviation: float = 0.0
	for i: int in range(enabled_trace.size()):
		deviation = maxf(deviation,enabled_trace[i].position.distance_to(disabled_trace[i].position))
		deviation = maxf(deviation,enabled_trace[i].velocity.distance_to(disabled_trace[i].velocity))
	check(deviation<0.00001,"visual_motion_physics_parity")
	report("physical_max_deviation",deviation)
	player.visual_motion.enabled = true
	await start_at(20.0)
	var count_before: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	for i: int in range(10):
		race.feedback.handle_event(&"impact",player,1.0,player.global_position)
		race.feedback.handle_event(&"impact",player,1.0,player.global_position)
		await settle_physics(16)
	check(race.feedback.emitted.get("impact",0)==10 and race.feedback.suppressed.get("impact",0)==10,"impact_debounce_capacity_fixture")
	await settle_physics(45)
	check(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))==count_before,"effects_do_not_grow_nodes")
	check(race.feedback.shake==0.0 and race.feedback.impact_duck==0.0,"envelopes_return_to_zero")
	race.profile.data.setup.reduced_effects = true
	race.feedback.handle_event(&"impact",player,1.0,player.global_position)
	check(race.feedback.camera_offset()==Vector3.ZERO and player.debris.amount==8,"reduced_effects")
	race.profile.data.setup.reduced_effects = false
	race.feedback.clear()
	race.message_time = 0.0
	race.feedback.post("GATE",3.0,3)
	race.feedback.post("FINAL LAP",1.5,2)
	race.feedback.post("PASS",1.2,0)
	check(race.message=="GATE" and race.feedback.messages.size()==2,"warning_priority")
	race.feedback.post("CAMERA · CHASE",1.5,1,&"camera")
	race.feedback.post("CAMERA · CLOSE CHASE",1.5,1,&"camera")
	check(race.message=="GATE" and race.feedback.messages.size()==3 and race.feedback.messages[1].text=="CAMERA · CLOSE CHASE","queued_camera_notice_current")
	# The finite voice pool cannot steal a warning for lower-priority contacts.
	for voice: AudioStreamPlayer in race.voices: voice.stop()
	for i: int in range(race.voices.size()): race.play_sound("finish")
	race.play_sound("bump")
	var protected_voices: bool = true
	for voice: AudioStreamPlayer in race.voices: protected_voices = protected_voices and voice.stream==race.sounds.finish
	check(protected_voices,"warning_voice_priority")
	report("master_peak_db",AudioServer.get_bus_peak_volume_left_db(0,0))
	var minimum_clearance: float = INF
	for steer: float in [-1.0,0.0,1.0]:
		for i: int in range(4):
			var mount: Node3D = player.visual_motion.mounts[i]
			var yaw: float = steer*player.visual_motion.MAX_STEER if mount.position.x>0 else 0.0
			var inner: float = absf(mount.position.z)-absf(sin(yaw))*player.visual_motion.radii[i]-absf(cos(yaw))*0.075
			minimum_clearance = minf(minimum_clearance,inner-0.16-0.035)
	check(minimum_clearance>0.0,"tyre_body_swept_clearance")
	report("minimum_visual_clearance",minimum_clearance)
	for station: float in [80.0,165.0,306.0]:
		await start_at(station)
		for mode: int in range(3):
			race.camera_driver.mode = mode
			race.camera_driver.reset(race.camera,player)
			await settle(4)
			save_frame("camera_%d_station_%d" % [mode,int(station)])
			check(race.camera.transform.is_finite(),"camera_finite_%d_%d" % [mode,int(station)])
			if mode==2:
				var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
				var sphere: SphereShape3D = SphereShape3D.new()
				sphere.radius = 0.20
				query.shape = sphere
				query.transform = Transform3D(Basis.IDENTITY,race.camera.global_position)
				query.collision_mask = 1
				check(player.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(),"camera_clear_%d" % int(station))
				check(race.camera.projection==Camera3D.PROJECTION_PERSPECTIVE,"close_perspective_%d" % int(station))
	for expected: int in [0,1,2]:
		await action("cycle_camera",2)
		check(race.camera_driver.mode==expected,"camera_input_cycle_%d" % expected)
	check(race.message=="CAMERA · "+race.camera_driver.MODES[2],"active_camera_notice_current")
	race.controls_setup.config_path = summer_out_dir+"/controls.cfg"
	race.controls_setup.save_camera_mode()
	var camera_settings: ConfigFile = ConfigFile.new()
	camera_settings.load(race.controls_setup.config_path)
	check(camera_settings.get_value("camera","mode",-1)==2,"camera_mode_saved")
	for size: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(1600,720)]:
		DisplayServer.window_set_size(size)
		for pixels: bool in [false,true]:
			race.setup_menu.set_pixels(pixels)
			await settle(3)
			save_frame("hud_%dx%d_%s" % [size.x,size.y,str(pixels)])
			for path: String in ["Status","Boost","StandingBack","RaceMinimap"]:
				check(Rect2(Vector2.ZERO,Vector2(1200,800)).encloses(race.get_node("HUD/"+path).get_rect()),"fits_%s_%s_%s" % [path,str(size),str(pixels)])
	var retry_nodes: Array[int] = []
	var phase_connections: int = race.session.phase_changed.get_connections().size()
	for i: int in range(5):
		await action("restart",2)
		check(race.phase==6 and race.feedback.shake==0.0 and race.feedback.messages.is_empty(),"retry_clears_%d" % i)
		await action("start_race",2)
		check(race.phase==1,"retry_countdown_%d" % i)
		check(race.camera_driver.mode==2 and race.camera.projection==Camera3D.PROJECTION_PERSPECTIVE,"retry_retains_close_%d" % i)
		retry_nodes.append(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
		check(race.session.phase_changed.get_connections().size()==phase_connections,"retry_signal_count_%d" % i)
	check(retry_nodes.min()==retry_nodes.max(),"retry_nodes_stable")
	report("retry_node_counts",retry_nodes)
	await action("menu",2)
	check(race.phase==0 and race.profile.read_only,"return_menu_read_only")
	race.setup_menu.open()
	await settle(3)
	save_frame("setup_reduced_effects")
	check(race.setup_menu.panel.get_global_rect().encloses(race.setup_menu.reduced_effects.get_global_rect()),"reduced_setting_visible")
	var store: RefCounted = preload("res://scripts/profile_store.gd").new()
	store.path = summer_out_dir+"/profile.json"
	store.data = race.profile.data.duplicate(true)
	store.data.setup.reduced_effects = true
	check(store.save_profile()==OK,"save_evidence_profile")
	var restored: RefCounted = preload("res://scripts/profile_store.gd").new()
	restored.path = store.path
	restored.load_profile()
	check(restored.data.setup.reduced_effects,"reduced_effects_disk_roundtrip")
	check(not preload("res://scripts/profile_store.gd").validate({"schema_version":8}).setup.reduced_effects,"old_profile_effects_default")
	race.setup_menu.close()
	# Missed-gate deadline uses the real session timeout and recovery transition.
	await start_at(20.0)
	race.session.progress.records[1].missed_deadline = race.race_time+0.03
	await settle_physics(5)
	check(race.session.progress.records[1].penalty==5.0 and player.state!=0,"missed_gate_penalty_recovery_fixture")
	save_frame("missed_gate")
	# Full Time Trial via shared AI commands, labelled development reference.
	race.race_mode = "trial"
	race.race_laps = 1
	await start_at(0.0)
	player.ai = true
	player.ai_driver.rng.seed = 64
	for i: int in range(6000):
		await get_tree().physics_frame
		if race.phase==3: break
	await settle(8)
	check(race.phase==3 and player.finish_time>0.0 and player.laps==1,"full_time_trial_finish")
	check(race.trial.completed and race.trial.result_note.contains("PERSONAL BEST"),"time_trial_pb_feedback")
	check(not race.engine_sound.playing and not race.engine_layer.playing and not race.skid_sound.playing,"finish_stops_loops")
	check(race.banner.get_rect().end.y+8.0<=race.results_panel.get_node("Retry").get_global_rect().position.y,"trial_notice_clears_buttons")
	check(race.banner.get_minimum_size().y<=132.0,"trial_notice_text_fits")
	save_frame("time_trial_results")
	# An expired finishing window classifies remaining racers honestly as DNF.
	race.race_mode = "quick"
	race.rival_count = 3
	await start_at(20.0)
	for car: CharacterBody3D in race.cars: car.set_physics_process(false)
	race.session.progress.mark_finished(player,10.0)
	race.session.change_phase(5)
	race.session.finish_deadline = race.race_time+0.03
	Input.action_press("ui_accept")
	await settle_physics(20)
	check(race.phase==3 and not race.session.results[1].finished,"dnf_classification_fixture")
	check(race.results_panel.get_node("Retry").disabled,"held_accept_does_not_retry")
	var points_before: int = race.profile.vehicle().points
	race.on_results_ready(race.session.results)
	check(race.profile.vehicle().points==points_before,"reward_once")
	Input.action_release("ui_accept")
	await settle_physics(15)
	check(not race.results_panel.get_node("Retry").disabled,"results_release_unlocks_controls")
	await settle(10)
	save_frame("dnf_results")
	for car: CharacterBody3D in race.cars: car.set_physics_process(true)
	await action("menu",2)
	check(race.profile.read_only,"final_profile_read_only")
	report("feedback",race.feedback.diagnostic_state())
	report("failures",failures)
	report("passed",failures.is_empty())
	finish()

func action(name: String, frames: int, release: bool = true) -> void:
	Input.action_press(name)
	await settle_physics(frames)
	if release:
		Input.action_release(name)
		await settle_physics(2)

func start_at(station: float) -> void:
	race.start_race()
	race.begin_countdown()
	race.session.countdown = 0.81
	await settle_physics(3)
	race.player_car.ai = false
	race.player_car.reset_car(station,0.0)
	race.session.progress.rebase(race.player_car)
	race.camera_driver.reset(race.camera,race.player_car)
	await settle_physics(2)

func close_view(title: String) -> void:
	race.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	race.camera.size = 2.8
	race.camera.position = race.player_car.position+Vector3(2,1.8,2)
	race.camera.look_at(race.player_car.position+Vector3.UP*0.35)
	race.set_physics_process(false)
	race.player_car.set_physics_process(false)
	await settle(3)
	save_frame(title)
	race.player_car.set_physics_process(true)
	race.set_physics_process(true)
	race.camera_driver.reset(race.camera,race.player_car)

func movement_trace(enabled: bool) -> Array:
	await start_at(20.0)
	race.player_car.visual_motion.enabled = enabled
	var trace: Array = []
	Input.action_press("p1_go")
	for i: int in range(40):
		await get_tree().physics_frame
		trace.append({"position":race.player_car.position,"velocity":race.player_car.velocity})
	Input.action_release("p1_go")
	return trace
