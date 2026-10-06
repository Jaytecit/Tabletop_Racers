extends "res://tests/autopilot/probe_base.gd"

var race: Node3D
var failures: Array[String] = []
var frame_ms: Array[float] = []
var last_usec: int = 0
var captures: Dictionary = {}
var process_ms: Array[float] = []
var physics_ms: Array[float] = []
var draw_calls: Array[float] = []

func _enter_tree() -> void:
	super._enter_tree()
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_isolate)

func _isolate(node: Node) -> void:
	if node.name=="Track" and node.get_script()==preload("res://showcase_track.gd") and OS.get_environment("TABLETOP_PROFILE_ROUTE")=="1":
		node.set_script(preload("res://tests/fixtures/profiled_track.gd"))
	if node.name == "Race" and node.get("profile") != null:
		node.profile.path = "res://tests/fixtures/race_quality_read_only.json"
	if node.name == "Sequence" and node.get("hardware_input_isolated") != null:
		node.hardware_input_isolated = true

func check(value: bool, title: String) -> void:
	report(title, value)
	if not value: failures.append(title)

func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	if is_instance_valid(race) and race.phase == 2 and not race.paused_race and last_usec > 0:
		frame_ms.append(float(now-last_usec)/1000.0)
		process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
		physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
		draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	last_usec = now

func capture_pose(title: String) -> void:
	if captures.has(title): return
	captures[title] = {"station":race.player_car.station,"height":race.player_car.position.y,
		"phase":race.phase,"camera":race.camera_driver.mode,"frame":Engine.get_physics_frames(),
		"pixelation":race.get_node("Retro").visible}
	save_frame(title)

func select_test_course(course: String) -> bool:
	return race.course.select(course)

func inspect_course() -> void:
	pass

func inspect_after_race() -> void:
	pass

func _ready() -> void:
	await super._ready()
	await settle(4)
	var app: Node = get_tree().current_scene
	race = app.get_node("Race")
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.using_pad = false
	race.controller.device = -1
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	# Skip only the accepted opening in this race baseline; its dedicated probe owns full playback.
	app.get_node("Opening").queue_free()
	get_tree().paused = false
	race.get_node("HUD").show()
	check(race.profile.read_only, "read_only")
	race.profile_selected = true # Authorise only this existing read-only test fixture.
	race.profile.vehicle().stats = preload("res://scripts/vehicles/player_stats.gd").neutral()
	race.garage.apply_stats(race)
	race.race_mode = "quick"
	var load_start: int = Time.get_ticks_msec()
	var course: String = OS.get_environment("TABLETOP_VERIFY_COURSE")
	if course.is_empty(): course = "toys_r_you"
	check(select_test_course(course), "selected")
	var requested_class: String = OS.get_environment("TABLETOP_VERIFY_CLASS")
	if not requested_class.is_empty():
		race.menu_flow.choose_mode("freestyle")
		check(race.set_vehicle(requested_class),"selected_class")
		race.profile.vehicle().stats = preload("res://scripts/vehicles/player_stats.gd").neutral()
		race.garage.apply_stats(race)
	report("vehicle",race.player_car.base_tuning.id)
	report("definition_source_hash",FileAccess.get_sha256(race.player_car.base_tuning.resource_path))
	report("course",course)
	await settle(4)
	report("selection_ms", Time.get_ticks_msec()-load_start)
	await inspect_course()
	if not failures.is_empty():
		report("failures",failures)
		report("passed",false)
		finish()
		return
	race.camera_driver.mode = 0
	race.rival_count = 3
	var requested_rivals: String = OS.get_environment("TABLETOP_VERIFY_RIVALS")
	if requested_rivals.is_valid_int(): race.rival_count = clampi(requested_rivals.to_int(),0,3)
	var requested_build: String = OS.get_environment("TABLETOP_VERIFY_BUILD")
	if requested_build in ["starting","full"]:
		race.stats_test_mode = 1 if requested_build=="starting" else 2
		race.garage.apply_stats(race)
	report("build",requested_build if not requested_build.is_empty() else "neutral")
	race.race_laps = 3
	var requested_laps: String = OS.get_environment("TABLETOP_VERIFY_LAPS")
	if requested_laps.is_valid_int(): race.race_laps = clampi(requested_laps.to_int(),1,9)
	race.difficulty = 2
	race.race_seed = 42
	if OS.get_environment("TABLETOP_VERIFY_MODE")=="tournament":
		race.race_mode = "tournament"
		race.profile.data.tournament = preload("res://scripts/race/tournament_rules.gd").fresh("toybox",race.garage.selected)
	elif OS.get_environment("TABLETOP_VERIFY_MODE") in ["quick","trial","freestyle","elimination","challenge","time_attack","drift"]:
		race.race_mode = OS.get_environment("TABLETOP_VERIFY_MODE")
	race.start_race()
	race.player_car.ai = true
	if race.race_mode=="drift" and OS.get_environment("TABLETOP_DRIFT_INPUT")=="1":
		race.player_car.ai_driver = preload("res://tests/fixtures/drift_input_driver.gd").new()
		race.player_car.ai_driver.difficulty = 2
		race.player_car.ai_driver.reset(race.player_car,42)
		report("deliberate_drift_commands",true)
	for i: int in range(race.cars.size()):
		race.cars[i].ai_driver.rng.seed = [64,128,256,512][i]
	race.begin_countdown()
	if race.track.get("measurements")!=null: race.track.measurements.clear()
	await settle(3)
	capture_pose("grid")
	var stats: Array = []
	for car: CharacterBody3D in race.cars:
		stats.append({"speed":car.top_speed,"acceleration":car.tuning.acceleration,"grip":car.tuning.grip,"boost_drain":car.tuning.boost_drain,"recovery":car.tuning.recovery_speed,"collision_size":str(car.tuning.collision_size),"collision_height":car.tuning.collision_height})
	report("effective_stats",stats)
	report("runtime", {"version":Engine.get_version_info(),"gpu":RenderingServer.get_video_adapter_name(),"viewport":str(get_viewport().get_visible_rect().size),"seeds":[64,128,256,512],"neutral_ai_reference":true})
	var previous_air: bool = false
	var previous_impacts: int = 0
	var previous_laps: int = 0
	var lap_times: Array = []
	var incidents: Array[Dictionary] = []
	var previous_contacts: Dictionary = {}
	var drift_samples: Array[Dictionary] = []
	var drift_counts: Dictionary = {"frames":0,"safe":0,"valid_motion":0,"slip":0,"moving":0,"max_angle":0.0,"max_combo":0.0}
	for frame: int in range(24000):
		await get_tree().physics_frame
		if frame%600==0:
			var progress: FileAccess = FileAccess.open(summer_out_dir.path_join("live_progress.json"),FileAccess.WRITE)
			progress.store_string(JSON.stringify(live_progress(),"  "))
			progress.close()
		for vehicle: CharacterBody3D in race.cars:
			if vehicle.impacts>previous_contacts.get(vehicle.player,0) and incidents.size()<512:
				incidents.append({"player":vehicle.player,"time":race.race_time,"station":vehicle.station,"position":str(vehicle.position),"speed":vehicle.velocity.length(),"heading":vehicle.heading,"lateral_target":vehicle.ai_driver.lateral_target,"impacts":vehicle.impacts,"state":vehicle.state})
			previous_contacts[vehicle.player] = vehicle.impacts
		var car: CharacterBody3D = race.player_car
		if race.race_mode=="drift" and not race.drift.last_sample.is_empty():
			var sample: Dictionary = race.drift.last_sample
			drift_counts.frames += 1
			if sample.safe: drift_counts.safe += 1
			if sample.valid_motion: drift_counts.valid_motion += 1
			if absf(sample.angle)>=12.0 and absf(sample.angle)<=65.0: drift_counts.slip += 1
			if sample.forward_speed>=2.5 and sample.speed>=3.5: drift_counts.moving += 1
			drift_counts.max_angle = maxf(drift_counts.max_angle,absf(sample.angle))
			drift_counts.max_combo = maxf(drift_counts.max_combo,race.drift.rules.combo)
			if frame%60==0: drift_samples.append(sample.duplicate())
		if race.phase == 2:
			if car.station > 20 and car.station < 40: capture_pose("straight")
			if car.station > 80 and car.station < 95: capture_pose("bend")
			if car.position.y > 1.0: capture_pose("bridge")
			if car.station > 300 and car.station < 315: capture_pose("underpass")
			if car.boost_was_on: capture_pose("boost")
			if previous_air and not car.airborne: capture_pose("landing")
			if car.impacts > previous_impacts: capture_pose("impact")
			if car.state != 0: capture_pose("recovery")
			if race.race_mode=="drift" and race.drift.rules.combo>10.0: capture_pose("drift_combo")
			if car.laps != previous_laps:
				lap_times.append(race.race_time)
				if car.laps == 2: capture_pose("final_lap")
		previous_air = car.airborne
		previous_impacts = car.impacts
		previous_laps = car.laps
		if race.phase == 5: capture_pose("finishing")
		if race.phase == 3: break
	await settle(30) # Allow all four staggered podium cards to finish revealing.
	capture_pose("results")
	var cars: Array = []
	for car: CharacterBody3D in race.cars:
		cars.append({"player":car.player,"laps":car.laps,"time":car.finish_time if is_finite(car.finish_time) else -1.0,"impacts":car.impacts,"crashes":car.crashes,"recoveries":car.ai_driver.recoveries,"penalty":race.session.progress.records[car.player].penalty})
	report("cars", cars)
	report("mode",race.race_mode)
	if race.race_mode=="tournament":
		check(race.profile.data.tournament.rounds.size()==1,"tournament_round_committed")
		report("tournament",race.profile.data.tournament)
	report("incidents",incidents)
	report("lap_crossings",lap_times)
	report("captures",captures)
	if race.track.get("measurements")!=null: report("route_inclusive_costs",race.track.measurements)
	frame_ms.sort()
	if not frame_ms.is_empty():
		report("frame_ms",{"count":frame_ms.size(),"p50":frame_ms[int(frame_ms.size()*0.50)],"p95":frame_ms[int(frame_ms.size()*0.95)],"max":frame_ms.back()})
		for metric: Dictionary in [{"name":"process_ms","values":process_ms},{"name":"physics_ms","values":physics_ms},{"name":"draw_calls","values":draw_calls}]:
			metric.values.sort()
			report(metric.name,{"p50":metric.values[int(metric.values.size()*0.50)],"p95":metric.values[int(metric.values.size()*0.95)],"max":metric.values.back()})
	report("nodes",Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	report("memory_mb",Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0)
	report("feedback",race.feedback.diagnostic_state())
	var expected_car: String = OS.get_environment("TABLETOP_EXPECT_CAR_HASH")
	if expected_car.is_empty(): expected_car = race.trial.COSMETIC_CAR_HASH
	report("car_source_hash",FileAccess.get_sha256("res://scripts/vehicles/arcade_car.gd"))
	check(FileAccess.get_sha256("res://scripts/vehicles/arcade_car.gd")==expected_car,"expected_car_revision")
	var expected_track: String = OS.get_environment("TABLETOP_EXPECT_TRACK_HASH")
	if expected_track.is_empty(): expected_track = race.trial.VALIDATED_TRACK_HASH
	report("track_source_hash",FileAccess.get_sha256("res://showcase_track.gd"))
	check(FileAccess.get_sha256("res://showcase_track.gd")==expected_track,"expected_track_revision")
	check(race.phase == 3 and race.session.results.size()==race.cars.size(),"classified_field")
	if race.race_mode=="elimination":
		check(race.session.elimination.eliminated.size()==race.cars.size()-1 and race.session.results[0].finished,"last_survivor")
	elif race.race_mode=="drift":
		report("drift",{"score":race.drift.rules.score,"best_combo":race.drift.rules.best_combo,"elapsed":race.drift.elapsed})
		report("drift_counts",drift_counts)
		report("drift_samples",drift_samples)
		check(race.drift.elapsed>=90.0 and race.drift.rules.score>0.0,"physical_drift_scored")
		check(race.profile.data.drift_records.is_empty(),"automated_drift_not_saved")
	else:
		for car: CharacterBody3D in race.cars:
			check(car.finish_time>0.0 and car.laps==race.session.laps_required,"finished_"+str(car.player))
	if race.race_mode=="challenge": check(race.profile.data.challenges.is_empty(),"automated_run_no_human_achievements")
	if race.race_mode=="time_attack": report("clock",{"remaining":race.session.time_attack.remaining(race.race_time),"extensions":race.session.time_attack.last_ordinal,"expired":race.session.time_attack.expired})
	await inspect_after_race()
	check(race.profile.read_only,"still_read_only")
	report("failures",failures)
	report("passed",failures.is_empty())
	finish()

func live_progress() -> Dictionary:
	var vehicles: Array[Dictionary] = []
	if is_instance_valid(race):
		for vehicle: CharacterBody3D in race.cars:
			vehicles.append({"player":vehicle.player,"station":vehicle.station,"laps":vehicle.laps,"gate":vehicle.gate,"speed":vehicle.velocity.length(),"position":str(vehicle.position),"state":vehicle.state,"crashes":vehicle.crashes,"impacts":vehicle.impacts,"finish_time":vehicle.finish_time,"recoveries":vehicle.ai_driver.recoveries})
	return {"race_time":race.race_time if is_instance_valid(race) else -1,"cars":vehicles}

func _on_deadline() -> void:
	report("deadline_state",live_progress())
	report("_timeout",true)
	finish()
