extends "res://tests/probes/race_quality_ai_verification.gd"

func advance(car: CharacterBody3D, distance: float) -> void:
	car.station = fposmod(car.station+distance,race.track.total_length)
	car.position = race.track.sample_3d(car.station)
	race.session.tick(0.05)
	race.session.observe(car,Vector2(car.station,0.0),0.05)

func drive_to_lap(car: CharacterBody3D, lap: int) -> void:
	for step: int in range(20000):
		if car.laps>=lap or race.phase==3: return
		advance(car,0.4)
	check(false,"lap_fixture_deadline")

func prepare() -> void:
	race.start_race()
	race.begin_countdown()
	race.session.change_phase(2)
	race.set_physics_process(false)
	for car: CharacterBody3D in race.cars: car.set_physics_process(false)

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
	race.menu_flow.home.get_node("Elimination").pressed.emit()
	race.rival_count = 3
	race.menu_flow.show_step(3)
	await settle(4)
	save_frame("setup")
	prepare()
	check(race.session.laps_required==4 and race.cars.size()==4,"four_car_four_lap_field")
	# Route sampling exercises the real ordered checkpoint/lap observer, not
	# direct lap signals. Body collision is deliberately out of scope here.
	var leader: CharacterBody3D = race.all_cars[1]
	for id: int in range(1,5): race.session.progress.records[id].distance = 1.0 if id==1 else 10.0+id
	drive_to_lap(leader,1)
	check(race.session.elimination.eliminated.is_empty(),"first_lap_safe")
	drive_to_lap(leader,2)
	check(race.session.elimination.eliminated==[1],"last_player_out")
	check(race.phase==5 and race.results_panel.visible and race.session.results.is_empty(),"immediate_player_result_ai_continues")
	check(not race.player_car.visible and race.player_car.collision_layer==0,"eliminated_body_removed")
	check(not race.rewards_awarded and race.profile.data.records.is_empty(),"no_early_rewards_or_pb")
	var before: float = race.race_time
	race.paused_race = true
	race.session.tick(5.0)
	check(race.race_time==before,"pause_ai_completion")
	race.paused_race = false
	race._physics_process(0.2)
	await settle(20)
	save_frame("player_eliminated")
	check(not race.results_panel.get_node("Retry").disabled,"retry_available_while_ai_racing")
	drive_to_lap(leader,3)
	check(race.session.elimination.eliminated.size()==2,"second_cut")
	drive_to_lap(leader,4)
	await settle(20)
	check(race.phase==3 and race.session.results[0].player==2 and race.session.results[0].finished,"ai_only_completion")
	check(race.session.results[-1].player==1 and not race.session.results[-1].finished,"final_player_rank")
	save_frame("ai_winner")
	race.results_action()
	check(race.phase==6 and race.session.elimination.eliminated.is_empty(),"retry_clears_eliminations")
	for car: CharacterBody3D in race.cars: check(car.visible and car.is_physics_processing() and car.finish_time<0.0,"retry_restores_"+str(car.player))
	prepare()
	for id: int in range(1,5): race.session.progress.records[id].distance = 10.0
	race.session.elimination.lap_completed(race.player_car,2)
	check(race.session.elimination.eliminated==[4],"deterministic_equal_progress")
	race.session.elimination.lap_completed(race.player_car,2)
	check(race.session.elimination.eliminated==[4],"same_leader_lap_once")
	race.show_menu()
	race.rival_count = 1
	prepare()
	check(race.session.laps_required==2 and race.cars.size()==2,"two_car_two_lap_field")
	drive_to_lap(race.player_car,2)
	check(race.phase==3 and race.session.results[0].player==1,"human_winner_pipeline")
	check(race.profile.data.records.keys().any(func(key: String) -> bool: return key.contains("|elimination|")),"isolated_elimination_pb")
	var points: int = race.profile.vehicle().points
	race.on_results_ready(race.session.results)
	check(race.profile.vehicle().points==points,"duplicate_reward_guard")
	check(preload("res://scripts/profile_store.gd").validate(race.profile.data).records==race.profile.data.records,"elimination_record_validation")
	report("failures",failures)
	report("passed",failures.is_empty())
	finish()
