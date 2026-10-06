extends "res://tests/probes/race_quality_ai_verification.gd"
const STORE: Script = preload("res://scripts/profile_store.gd")
const ROADMAP: Script = preload("res://scripts/race/challenge_roadmap.gd")

func start_fixture() -> void:
	race.start_race()
	race.begin_countdown()
	race.session.change_phase(2)
	race.player_car.ai = false
	for car: CharacterBody3D in race.all_cars: car.set_physics_process(false)

func complete_fixture() -> void:
	if race.race_mode=="drift":
		race.drift.elapsed = 90.0
		race.drift.rules.score = race.roadmap.run_target
		race.drift.finish()
	else:
		var progress: Dictionary = race.session.progress.records[1]
		progress.laps = race.session.laps_required
		race.session.progress.mark_finished(race.player_car,race.roadmap.run_target if race.race_mode=="challenge" else 1.0)
		race.session.classify()

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
	race.profile.path = summer_out_dir+"/profile.json"
	race.profile.data = STORE.defaults()
	race.profile.read_only = false
	race.profile.status = ""
	race.machine_settings.read_only = true
	race.profile_directory.read_only = true
	race.profile_selected = true
	race.profile_menu.hide()
	race.controls_setup.config_path = summer_out_dir+"/controls.cfg"
	race.show_menu()
	race.set_physics_process(false)
	for car: CharacterBody3D in race.all_cars: car.set_physics_process(false)
	for mode: String in ROADMAP.MODES:
		race.menu_flow.choose_mode(mode)
		while race.course.loading: await get_tree().process_frame
		if mode!="drift": check(race.course.select("game_table"),mode+"_course")
		race.menu_flow.show_step(3)
		check(race.roadmap.completed()==0,mode+"_new_track_progress")
		check(race.roadmap.row.visible and race.roadmap.row.get_child(1).disabled,mode+"_locked_stages")
		var base_clock: Dictionary = preload("res://scripts/race/time_attack_rules.gd").settings(race.course.entry)
		for tier: int in range(5):
			check(race.roadmap.stage()==tier,mode+"_next_%d" % tier)
			race.roadmap.choices[race.roadmap.key()] = 4
			check(race.roadmap.stage()==tier,mode+"_locked_override_rejected_%d" % tier)
			race.roadmap.choices.erase(race.roadmap.key())
			start_fixture()
			if mode=="drift": check(race.roadmap.run_target==ROADMAP.DRIFT[tier],"drift_target_%d" % tier)
			if mode=="challenge": check(is_equal_approx(race.challenge.target,race.roadmap.run_target),"challenge_target_%d" % tier)
			if mode=="time_attack": check(is_equal_approx(race.session.time_attack.deadline,base_clock.start*ROADMAP.FACTORS[tier]) and is_equal_approx(race.session.time_attack.extension,base_clock.extension*ROADMAP.FACTORS[tier]),"clock_scale_%d" % tier)
			# Invalid runs never unlock the next stage.
			race.player_car.ai = true
			check(race.roadmap.award().contains("UNRANKED") and race.roadmap.completed()==tier,mode+"_ai_guard_%d" % tier)
			race.player_car.ai = false
			race.developer.run_experimental = true
			race.roadmap.resolved = false
			check(race.roadmap.award().contains("UNRANKED") and race.roadmap.completed()==tier,mode+"_experimental_guard_%d" % tier)
			race.developer.run_experimental = false
			race.roadmap.resolved = false
			if mode=="drift": race.drift.elapsed = 90.0; race.drift.rules.score = race.roadmap.run_target-1.0
			elif mode=="challenge":
				race.session.progress.records[1].laps = race.session.laps_required
				race.player_car.finish_time = race.roadmap.run_target+1.0
			else: race.session.time_attack.expired = true
			check(race.roadmap.award().contains("NOT BEATEN") and race.roadmap.completed()==tier,mode+"_failure_%d" % tier)
			race.show_menu()
			start_fixture()
			complete_fixture()
			check(race.roadmap.completed()==tier+1,mode+"_award_%d" % tier)
			var before: Dictionary = race.profile.data.challenge_roadmaps.duplicate(true)
			race.roadmap.award()
			check(before==race.profile.data.challenge_roadmaps,mode+"_duplicate_guard_%d" % tier)
			race.show_menu()
			race.menu_flow.show_step(3)
			await settle(2)
			if tier in [0,4]: save_frame(mode+"_stage_%d" % (tier+1))
		check(not race.roadmap.row.get_child(0).disabled,mode+"_replay_unlocked")
		await settle(2) # Drain menu's deferred initial focus before selecting replay.
		race.roadmap.row.get_child(0).grab_focus()
		await settle(1)
		await press("ui_accept",30)
		await settle(2)
		report(mode+"_replay_focus",str(get_viewport().gui_get_focus_owner()))
		check(race.roadmap.stage()==0,mode+"_replay_selection")
	var reloaded: RefCounted = STORE.new()
	reloaded.path = race.profile.path
	reloaded.load_profile()
	check(reloaded.data.challenge_roadmaps==race.profile.data.challenge_roadmaps and reloaded.data.challenge_roadmaps.size()==3,"disk_reload")
	reloaded = null
	check(STORE.defaults().challenge_roadmaps.is_empty(),"fresh_profile_isolation")
	race.menu_flow.choose_mode("challenge")
	check(race.course.select("toys_r_you"),"other_track_select")
	check(race.roadmap.completed()==0,"per_track_isolation")
	race.menu_flow.choose_mode("challenge")
	check(race.course.select("game_table"),"return_completed_track")
	start_fixture()
	race.session.progress.records[1].laps = 3
	race.player_car.finish_time = race.roadmap.run_target
	race.player_car.impacts = 1
	check(race.roadmap.award().contains("NOT BEATEN"),"dirty_challenge_rejected")
	race.show_menu()
	check(ROADMAP.validate({"bad":5,"drift|bazaar|1|roadmap-1":6}).is_empty(),"invalid_progress_rejected")
	race.menu_flow.choose_mode("quick")
	check(not race.roadmap.row.visible,"ordinary_mode_unchanged")
	race.course.shutdown()
	await settle(4)
	report("failures",failures)
	report("passed",failures.is_empty())
	finish()
