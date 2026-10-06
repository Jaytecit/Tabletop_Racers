extends "res://tests/probes/race_quality_ai_verification.gd"
const STORE: Script = preload("res://scripts/profile_store.gd")
const TOUR: Script = preload("res://scripts/race/tournament_rules.gd")

func wait_course() -> void:
	while race.course.loading: await get_tree().process_frame
	await settle(4)
	check(race.course.error=="","course_ready_"+race.track_id)

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
	# All actual persistence stays in this disposable evidence directory.
	race.profile.path = summer_out_dir+"/profile.json"
	race.profile.read_only = false
	race.profile.status = ""
	race.profile.data.cup = preload("res://scripts/race/cup_rules.gd").fresh()
	var retained_cup: Dictionary = race.profile.data.cup.duplicate(true)
	race.garage.select(race,2)
	race.menu_flow.home.get_node("Tournament").pressed.emit()
	await wait_course()
	race.menu_flow.show_step(3)
	await settle(4)
	check(race.menu.get_node("TournamentSeries").visible and race.menu.get_node("TrackSelect").disabled,"series_controls")
	check(not race.menu.get_node("QuickRace").visible,"fixed_rules_visible")
	save_frame("series_setup")
	# Session classification fixtures prove the full results/save/next-round path.
	# They are not claimed as physical driving evidence.
	for index: int in range(3):
		race.start_race()
		check(race.phase==6 and race.cars.size()==4 and race.session.laps_required==3,"round_setup_%d" % index)
		for car: CharacterBody3D in race.cars: check(car.ai_driver.difficulty==1,"normal_%d_%d" % [index,car.player])
		race.begin_countdown()
		race.session.change_phase(2)
		for car: CharacterBody3D in race.cars:
			var record: Dictionary = race.session.progress.records[car.player]
			record.laps = 3
			car.laps = 3
			race.session.progress.mark_finished(car,100.0+car.player)
		race.session.classify()
		await settle(20)
		check(race.profile.data.tournament.rounds.size()==index+1,"scored_%d" % index)
		var before: Dictionary = race.profile.data.duplicate(true)
		race.on_results_ready(race.session.results)
		check(race.profile.data==before,"duplicate_results_%d" % index)
		var loaded: RefCounted = STORE.new()
		loaded.path = race.profile.path
		loaded.load_profile()
		check(loaded.data.tournament==race.profile.data.tournament,"disk_resume_%d" % index)
		check(loaded.data.cup==retained_cup,"legacy_cup_preserved_%d" % index)
		check(race.results_panel.get_node("Retry").text==("NEW SERIES" if index==2 else "NEXT ROUND"),"result_action_%d" % index)
		save_frame("round_%d_results" % (index+1))
		if index<2:
			race.profile.data = loaded.data
			race.results_panel.get_node("Retry").pressed.emit()
			await wait_course()
			check(race.menu_flow.step==3 and race.track_id==TOUR.SERIES[0].courses[index+1],"next_round_%d" % index)
			check(race.tournament.selector.disabled and race.tournament.abandon.visible,"resume_controls_%d" % index)
			if index==0:
				race.menu_flow.choose_mode("quick")
				race.garage.select(race,0)
				race.menu_flow.choose_mode("tournament")
				await wait_course()
				check(race.garage.selected==2,"resumed_driver_restored")
				race.menu_flow.show_step(3)
	check(race.profile.data.tournament_wins==1 and race.profile.data.cup_wins==1,"single_series_reward")
	check(race.profile.data.tournament.awarded,"award_persisted")
	race.results_panel.get_node("Retry").pressed.emit()
	await wait_course()
	check(race.profile.data.tournament.is_empty() and not race.tournament.selector.disabled,"new_series")
	race.tournament.selector.select(2)
	race.tournament.selector.item_selected.emit(2)
	await wait_course()
	check(race.track_id=="mount_rainier" and race.player_car.base_tuning.id=="racing_car","road_assignment")
	race.start_race()
	race.show_menu()
	race.menu_flow.show_step(3)
	check(race.tournament.abandon.visible,"abandon_available")
	race.tournament.abandon.pressed.emit()
	await wait_course()
	check(race.profile.data.tournament.is_empty(),"abandoned")
	race.menu_flow.choose_mode("quick")
	check(not race.menu.get_node("TrackSelect").disabled,"quick_course_unlocked")
	for card: Button in race.garage.cards: check(not card.disabled,"driver_unlocked_"+str(card.get_index()))
	report("failures",failures)
	report("passed",failures.is_empty())
	finish()
