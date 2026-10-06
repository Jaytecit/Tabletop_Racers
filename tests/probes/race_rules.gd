extends "res://tests/autopilot/probe_base.gd"
var failures: Array[String] = []
var race: Node
func check(name: String, value: bool) -> void:
	report(name,value)
	if not value: failures.append(name)

func advance_car(car: CharacterBody3D, amount: float, delta: float = 0.05) -> void:
	car.station = fposmod(car.station+amount,race.track.total_length)
	car.position = race.track.sample_3d(car.station)
	race.session.observe(car,Vector2(car.station,0.0),delta)

func prepare() -> void:
	race.start_race()
	race.session.countdown = 0.8
	race.session.tick(0.05)

func _ready() -> void:
	await super._ready()
	await settle()
	var app: Node = get_tree().current_scene
	race = app.get_node("Race") if app.has_node("Race") else app
	race.profile.path = "user://race_rules_test.json"
	race.race_mode = "quick"
	race.rival_count = 3
	race.race_laps = 3
	race.course.select("game_table")
	race.show_menu()
	# Fixtures drive legal physical route samples into the real session, without retuning.
	race.set_physics_process(false)
	race.controller.set_physics_process(false)
	for car: CharacterBody3D in race.cars: car.set_physics_process(false)
	var initial_nodes: int = race.get_child_count()
	prepare()
	var car: CharacterBody3D = race.player_car
	var length: float = race.track.total_length
	var gate_station: float = length/8.0+1.0
	# Large route jump and large world-position jump cannot credit a checkpoint.
	car.station = gate_station+0.01
	var point: Vector2 = race.track.sample(car.station)
	car.position = Vector3(point.x,0.0,point.y)
	race.session.observe(car,Vector2(car.station,0.0),0.05)
	check("teleport_rejected",car.gate==1 and car.laps==0)
	# Keep moving legally after skipping gate 1; the later gates cannot complete a lap.
	for i: int in range(int(length/0.4)):
		advance_car(car,0.4)
		if car.station<1.0: break
	check("skipped_gate_rejected",car.laps==0)
	prepare()
	while car.station<gate_station+0.1: advance_car(car,0.2)
	check("forward_gate_accepted",car.gate==2)
	var gate_before: int = car.gate
	for i: int in range(5): advance_car(car,-0.2)
	check("reversed_gate_rejected",car.gate==gate_before and car.laps==0)
	prepare()
	car.station = gate_station-0.05
	point = race.track.sample(car.station)
	car.position = Vector3(point.x,0.0,point.y)
	race.session.progress.rebase(car)
	car.state = 3
	advance_car(car,0.1)
	check("recovery_no_credit",car.gate==1 and car.laps==0)
	car.state = 0
	# Rankings use race-owned records even if vehicle counters are overwritten.
	car.distance = 999999.0
	check("vehicle_cannot_award_progress",race.rank_of(car)==1 and race.session.progress.records[1].distance<length)
	# Pause during a countdown freezes timers, effects and all sound voices.
	prepare()
	race.session.change_phase(1)
	race.session.countdown = 2.0
	race.player_car.smoke.emitting = true
	race.play_sound("crash")
	race.toggle_pause()
	var time_before: float = race.race_time
	race.session.tick(5.0)
	check("pause_freezes_session",race.race_time==time_before and race.countdown==2.0)
	check("pause_freezes_effects",car.smoke.speed_scale==0.0 and race.voices[0].stream_paused)
	race.start_race()
	check("restart_from_pause_clean",not race.paused_race and car.smoke.speed_scale==1.0 and not race.voices[0].stream_paused)
	# Each cycle completes a three-lap four-car race and then dirties transient state.
	var cycles: int = 0
	for cycle: int in range(10):
		prepare()
		for step: int in range(int(length*3.0/0.4)+20):
			race.session.tick(0.05)
			for vehicle: CharacterBody3D in race.cars:
				if vehicle.finish_time<0.0: advance_car(vehicle,0.4)
			if race.phase==3: break
		var valid: bool = race.phase==3 and race.session.results.size()==4
		for row: Dictionary in race.session.results:
			valid = valid and row.finished and row.laps==3 and row.time>=0.0
		check("cycle_%d_finishes" % cycle,valid)
		if valid: cycles += 1
		car.boost_was_on = true
		car.collision_cooldown = 9.0
		car.debris.emitting = true
		car.ring.visible = true
		if cycle==9:
			await settle()
			save_frame("00_results")
		race.show_menu()
		var clean: bool = race.phase==0 and race.race_time==0.0 and race.session.results.is_empty()
		for vehicle: CharacterBody3D in race.cars:
			clean = clean and vehicle.laps==0 and vehicle.gate==1 and vehicle.finish_time<0.0
			clean = clean and vehicle.state==0 and vehicle.velocity==Vector3.ZERO
			clean = clean and not vehicle.boost_was_on and vehicle.collision_cooldown==0.0
			clean = clean and not vehicle.debris.emitting and not vehicle.ring.visible
		for voice: AudioStreamPlayer in race.voices: clean = clean and not voice.playing and not voice.stream_paused
		check("cycle_%d_cleanup" % cycle,clean and race.get_child_count()==initial_nodes)
	var results_banner: String = race.banner.text
	race.toggle_pause()
	check("menu_pause_ignored",race.phase==0 and not race.paused_race and race.banner.text==results_banner)
	report("completed_cycles",cycles)
	# All exact progress/time ties must have unique ranks ordered by stable racer ID.
	for id: int in race.session.progress.records:
		race.session.progress.records[id].distance = 0.0
	check("progress_tie_order",race.session.progress.ordered_ids()==[1,2,3,4])
	for id: int in race.session.progress.records:
		race.session.progress.records[id].finish_time = 12.0
	check("finish_tie_order",race.session.progress.ordered_ids()==[1,2,3,4])
	# Player finish leaves rivals racing; the bounded window classifies unfinished cars.
	prepare()
	for step: int in range(int(length*3.0/0.4)+10):
		race.session.tick(0.05)
		advance_car(car,0.4)
		if race.phase==5: break
	check("rivals_continue",race.phase==5 and race.cars[1].finish_time<0.0)
	race.toggle_pause()
	var deadline: float = race.session.finish_deadline
	race.session.tick(30.0)
	check("finishing_pause_freezes_deadline",race.phase==5 and race.session.finish_deadline==deadline)
	race.toggle_pause()
	race.session.tick(20.1)
	check("timeout_classifies_all",race.phase==3 and race.session.results.size()==4)
	check("timeout_marks_dnf",race.session.results[0].finished and not race.session.results[1].finished)
	await settle()
	save_frame("01_timeout_results")
	race.show_menu()
	# Timers and reset must also be clean when leaving an active recovery.
	prepare()
	car.crash(true)
	race.toggle_pause()
	race.start_race()
	check("recovery_restart_clean",car.state==0 and car.lift_speed==0.0 and not car.airborne and not race.paused_race)
	report("failures",failures)
	report("passed",failures.is_empty())
	finish()
