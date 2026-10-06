extends "res://tests/probes/race_quality_ai_verification.gd"
const STORE: Script = preload("res://scripts/profile_store.gd")
const RULES: Script = preload("res://scripts/race/challenge_rules.gd")

func begin_fixture() -> void:
	race.start_race()
	check(race.phase==6 and race.cars.size()==1 and race.session.laps_required==3,"solo_three_laps")
	race.begin_countdown()
	race.session.change_phase(2)

func complete_fixture(elapsed: float) -> void:
	var record: Dictionary = race.session.progress.records[1]
	record.laps = 3
	race.player_car.laps = 3
	race.session.progress.mark_finished(race.player_car,elapsed)
	race.on_racer_finished(race.player_car)
	race.session.classify()
	await settle(20)

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
	check(race.profile.read_only,"sentinel_before_setup")
	race.profile.path = summer_out_dir+"/profile.json"
	race.profile.read_only = false
	race.profile.status = ""
	race.menu_flow.home.get_node("Challenge").pressed.emit()
	race.menu_flow.show_step(3)
	await settle(5)
	check(race.menu.get_node("TrackSelect").disabled==false,"select_any_course")
	check(not race.menu.get_node("QuickRace").visible,"fixed_solo_rules")
	save_frame("challenge_setup")
	begin_fixture()
	var clock: float = race.race_time
	race.paused_race = true
	await settle(10)
	check(race.race_time==clock,"pause_safe_clock")
	race.paused_race = false
	race.on_gate_warning(race.player_car,false)
	await complete_fixture(100.0)
	var key: String = RULES.context_key(race.challenge.context)
	check(race.profile.data.challenges[key].finish and not race.profile.data.challenges[key].clean,"returned_missed_gate_not_clean")
	check(race.profile.data.records.is_empty(),"challenge_does_not_pollute_race_records")
	save_frame("finish_only")
	race.results_action()
	begin_fixture()
	await complete_fixture(race.challenge.target-1.0)
	var record: Dictionary = race.profile.data.challenges[key]
	check(record.finish and record.clean and record.medal,"all_achievements")
	var snapshot: Dictionary = race.profile.data.duplicate(true)
	race.on_results_ready(race.session.results)
	check(snapshot==race.profile.data,"duplicate_result_no_award")
	save_frame("medal_results")
	var loaded: RefCounted = STORE.new()
	loaded.path = race.profile.path
	loaded.load_profile()
	check(loaded.data.challenges==race.profile.data.challenges,"achievements_reload")
	race.profile.data = loaded.data
	race.show_menu()
	race.menu_flow.show_step(3)
	check(race.challenge.summary().contains("MEDAL OK"),"progress_visible_after_reload")
	race.garage.select(race,1)
	check(race.challenge.summary().contains("MEDAL --"),"driver_isolation")
	for invalid: String in ["ai","test","dnf"]:
		begin_fixture()
		var before: Dictionary = race.profile.data.challenges.duplicate(true)
		if invalid=="ai": race.player_car.ai = true
		if invalid=="test": race.stats_test_mode = 1
		if invalid=="dnf": race.session.classify()
		else: await complete_fixture(100.0)
		check(race.profile.data.challenges==before,"reject_"+invalid)
		race.stats_test_mode = 0
		race.player_car.ai = false
		race.show_menu()
	race.garage.select(race,0)
	race.profile.vehicle().stats.speed += 0.25
	race.garage.apply_stats(race)
	check(race.challenge.summary().contains("1 OLD SETS") and race.challenge.summary().contains("MEDAL --"),"upgrade_context_preserves_history")
	race.menu_flow.show_step(3)
	await settle(4)
	save_frame("historic_progress")
	report("failures",failures)
	report("passed",failures.is_empty())
	finish()
