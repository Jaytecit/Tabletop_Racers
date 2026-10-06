extends "res://tests/autopilot/probe_base.gd"
var failures: Array[String] = []
var race: Node
var course_id: String = "game_table"

func check(label: String, value: bool) -> void:
	report(label,value)
	if not value: failures.append(label)

func place(car: CharacterBody3D, station: float, lateral: float) -> Vector2:
	car.station = fposmod(station,race.track.total_length)
	var direction: Vector2 = race.track.direction(car.station)
	car.position = race.track.sample_3d(car.station)+Vector3(-direction.y,0,direction.x)*lateral
	var sample: Dictionary = race.track.project_3d(car.position,car.station)
	return Vector2(sample.station,sample.distance)

func fixture(car: CharacterBody3D, boundary: float, lateral: float, gate: int) -> void:
	race.start_race()
	race.session.countdown = 0.8
	race.session.tick(0.05)
	place(car,boundary-0.1,lateral)
	race.session.progress.rebase(car)
	race.session.progress.records[car.player].gate = gate
	race.session.progress.records[car.player].legal_station = car.station
	car.gate = gate

func _ready() -> void:
	await super._ready()
	await settle()
	race = get_tree().current_scene.get_node("Race")
	race.profile.path = "user://lap_crossings_test.json"
	race.race_mode = "quick"
	race.course.select(course_id)
	race.set_physics_process(false)
	race.controller.set_physics_process(false)
	for car: CharacterBody3D in race.cars: car.set_physics_process(false)
	var length: float = race.track.total_length
	var boundary: float = race.track.definition.start_station+length/8.0
	for car: CharacterBody3D in race.cars:
		fixture(car,boundary,3.2,1)
		var hit: Vector2 = place(car,boundary+0.1,3.2)
		check("shoulder_is_supported_%d"%car.player,not car.physical_support(car.position).is_empty())
		race.session.observe(car,hit,0.05)
		check("shoulder_gate_%d"%car.player,car.gate==2 and car.laps==0)
		fixture(car,race.track.definition.start_station,3.2,8)
		hit = place(car,race.track.definition.start_station+0.1,3.2)
		race.session.observe(car,hit,0.05)
		check("shoulder_finish_%d"%car.player,car.laps==1 and car.gate==1)
	fixture(race.player_car,boundary,4.1,1)
	race.session.observe(race.player_car,place(race.player_car,boundary+0.1,4.1),0.05)
	race.session.paused = true
	race.session.tick(10.0)
	check("pause_freezes_gate_grace",race.session.progress.records[1].penalty==0.0)
	race.session.paused = false
	race.session.observe(race.player_car,place(race.player_car,boundary-0.1,0.0),0.5)
	race.session.observe(race.player_car,place(race.player_car,boundary+0.1,0.0),0.05)
	check("return_cancels_deadline",race.player_car.gate==2 and race.session.progress.records[1].missed_deadline<0.0)
	race.session.tick(6.0)
	check("returned_gate_no_penalty",race.session.progress.records[1].penalty==0.0)
	fixture(race.player_car,boundary,4.1,1)
	race.session.observe(race.player_car,place(race.player_car,boundary+0.1,4.1),0.05)
	check("wide_excursion_rejected",race.player_car.gate==1 and race.player_car.laps==0)
	check("grace_keeps_car_drivable",race.player_car.state==0)
	race.session.tick(4.99)
	check("no_early_penalty",race.session.progress.records[1].penalty==0.0)
	race.session.tick(0.01)
	check("penalty_applied",race.session.progress.records[1].penalty==5.0)
	race.session.tick(1.0)
	check("penalty_only_once",race.session.progress.records[1].penalty==5.0)
	check("missed_gate_starts_recovery",race.player_car.state==1 and race.player_car.recovery_target_valid)
	var target: float = race.player_car.safe_station
	check("recovery_behind_missed_gate",fposmod(boundary-target,length)<2.0)
	for frame: int in range(50): race.player_car.recover(0.05)
	check("recovery_awards_no_progress",race.player_car.state==0 and race.player_car.gate==1 and race.player_car.laps==0)
	while fposmod(boundary-race.player_car.station,length)<2.0:
		race.session.observe(race.player_car,place(race.player_car,race.player_car.station+0.2,0.0),0.05)
	check("recross_after_recovery_counts",race.player_car.gate==2 and race.player_car.laps==0)
	fixture(race.player_car,race.track.definition.start_station,4.1,8)
	race.session.observe(race.player_car,place(race.player_car,race.track.definition.start_station+0.1,4.1),0.05)
	race.session.tick(5.0)
	check("missed_finish_returns_without_lap",race.player_car.state==1 and race.player_car.laps==0 and race.player_car.gate==8)
	check("finish_recovery_behind_line",fposmod(race.track.definition.start_station-race.player_car.safe_station,length)<10.0)
	for frame: int in range(50): race.player_car.recover(0.05)
	for frame: int in range(60):
		race.session.observe(race.player_car,place(race.player_car,race.player_car.station+0.2,0.0),0.05)
		if race.player_car.laps==1: break
	check("finish_recross_after_recovery_counts",race.player_car.laps==1 and race.player_car.gate==1)
	fixture(race.player_car,race.track.definition.start_station,3.2,1)
	race.session.observe(race.player_car,place(race.player_car,race.track.definition.start_station+0.1,3.2),0.05)
	check("start_line_without_gates_no_lap",race.player_car.laps==0)
	fixture(race.player_car,boundary,3.2,1)
	race.player_car.position.y += 1.0
	race.session.progress.rebase(race.player_car)
	var wrong_layer: Vector2 = place(race.player_car,boundary+0.1,3.2)
	race.player_car.position.y += 1.0
	race.session.observe(race.player_car,wrong_layer,0.05)
	check("wrong_height_rejected",race.player_car.gate==1)
	fixture(race.player_car,boundary,3.2,1)
	place(race.player_car,boundary+0.1,3.2)
	race.session.progress.rebase(race.player_car)
	race.session.observe(race.player_car,place(race.player_car,boundary-0.1,3.2),0.05)
	check("reverse_shoulder_no_gate",race.player_car.gate==1 and race.player_car.laps==0)
	fixture(race.player_car,boundary,3.2,1)
	race.session.observe(race.player_car,place(race.player_car,boundary+0.1,3.2),0.05)
	race.session.observe(race.player_car,place(race.player_car,boundary-0.1,3.2),0.05)
	race.session.observe(race.player_car,place(race.player_car,boundary+0.1,3.2),0.05)
	check("repeated_gate_no_extra_credit",race.player_car.gate==2 and race.player_car.laps==0)
	race.session.progress.records[1].penalty = 5.0
	race.session.progress.mark_finished(race.player_car,20.0)
	check("finish_includes_penalty",race.player_car.finish_time==25.0)
	race.start_race()
	check("restart_clears_penalty",race.session.progress.records[1].penalty==0.0 and race.session.progress.records[1].missed_deadline<0.0)
	report("failures",failures)
	report("passed",failures.is_empty())
	for suffix: String in ["",".bak",".tmp",".bak.tmp"]: DirAccess.remove_absolute("user://lap_crossings_test.json"+suffix)
	finish()
