extends "res://tests/probes/race_quality_ai_verification.gd"

func prepare(laps: int = 1) -> void:
	race.race_laps = laps
	race.start_race()
	race.begin_countdown()
	race.session.change_phase(2)
	race.set_physics_process(false)
	for car: CharacterBody3D in race.cars: car.set_physics_process(false)

func advance(distance: float, delta: float = 0.05) -> void:
	var car: CharacterBody3D = race.player_car
	car.station = fposmod(car.station+distance,race.track.total_length)
	car.position = race.track.sample_3d(car.station)
	race.session.tick(delta)
	race.session.observe(car,Vector2(car.station,0.0),delta)

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
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	app.get_node("Opening").queue_free()
	get_tree().paused = false
	race.get_node("HUD").show()
	check(race.profile.read_only,"read_only")
	race.menu_flow.home.get_node("TimeAttack").pressed.emit()
	race.menu_flow.show_step(3)
	await settle(4)
	save_frame("setup")
	prepare()
	check(race.cars.size()==1 and race.session.laps_required==1,"solo_configurable_laps")
	var clock: RefCounted = race.session.time_attack
	clock.reset(0.05,3.0)
	var car: CharacterBody3D = race.player_car
	var gate: float = race.track.definition.start_station+race.track.total_length/race.track.definition.gate_count
	car.station = gate-0.1
	car.position = race.track.sample_3d(car.station)
	race.session.progress.rebase(car)
	advance(0.2,0.1)
	check(clock.last_ordinal==1 and clock.deadline>3.0 and race.phase==2,"interpolated_crossing_beats_expiry")
	var before: float = clock.deadline
	advance(-0.2)
	advance(0.2)
	check(clock.last_ordinal==1 and clock.deadline==before,"recross_no_duplicate_extension")
	check(not clock.checkpoint(3,race.race_time),"out_of_order_extension_rejected")
	var remaining: float = clock.remaining(race.race_time)
	race.paused_race = true
	race.session.tick(5.0)
	check(clock.remaining(race.race_time)==remaining,"pause_freezes_budget")
	race.paused_race = false
	clock.deadline = race.race_time+10.0
	race.session.progress.records[1].missed_deadline = race.race_time
	race.session.tick(0.05)
	check(is_equal_approx(clock.remaining(race.race_time),4.95),"missed_gate_costs_clock_time")
	prepare()
	clock.deadline = 0.05
	race.session.tick(0.1)
	race.session.tick(0.1)
	check(race.phase==3 and clock.expired and not race.session.results[0].finished,"expiry_is_dnf")
	check(race.profile.data.records.is_empty(),"expired_run_no_pb")
	race._physics_process(0.2)
	await settle(20)
	save_frame("expired")
	prepare()
	# A large fixture budget isolates checkpoint sequencing from target tuning.
	clock.deadline = 1000.0
	for step: int in range(20000):
		if race.phase==3: break
		advance(0.4)
	check(race.phase==3 and race.session.results[0].finished and not clock.expired,"ordered_full_lap_finishes")
	check(clock.last_ordinal==race.track.definition.gate_count,"one_bonus_per_gate")
	check(race.profile.data.records.keys().any(func(key: String) -> bool: return key.contains("|time_attack|")),"separate_time_attack_record")
	check(preload("res://scripts/profile_store.gd").validate(race.profile.data).records==race.profile.data.records,"record_validates")
	var reward: int = race.profile.vehicle().points
	race.on_results_ready(race.session.results)
	check(race.profile.vehicle().points==reward,"once_only_reward")
	race.results_action()
	check(clock.last_ordinal==0 and not clock.expired and clock.remaining(0.0)==race.session.time_attack_settings.start,"retry_resets_clock")
	report("failures",failures)
	report("passed",failures.is_empty())
	finish()
