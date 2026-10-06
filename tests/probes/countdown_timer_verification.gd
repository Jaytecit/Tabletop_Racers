extends "res://tests/probes/race_quality_ai_verification.gd"

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
	race.profile.read_only = true
	race.machine_settings.read_only = true
	race.profile_directory.read_only = true
	race.profile_selected = true
	race.profile_menu.hide()
	race.show_menu()
	for mode: String in ["time_attack","drift"]:
		race.menu_flow.choose_mode(mode)
		while race.course.loading: await get_tree().process_frame
		if mode=="time_attack": check(race.course.select("game_table"),"time_attack_course")
		check(race.course.error.is_empty(),mode+"_load")
		race.start_race()
		race.begin_countdown()
		race.session.change_phase(2)
		race.player_car.ai = true
		var initial: float = race.displayed_race_time()
		await settle_physics(60)
		race.update_hud()
		var remaining: float = race.displayed_race_time()
		check(remaining<initial and remaining>0.0,mode+"_counts_down")
		var metrics: Label = race.get_node("HUD/RaceMetrics")
		check(metrics.text.begins_with("%.2fs" % remaining),mode+"_hud_remaining")
		if mode=="time_attack":
			var before: float = race.displayed_race_time()
			check(race.session.time_attack.checkpoint(1,race.race_time),"extension_awarded")
			check(is_equal_approx(race.displayed_race_time(),before+race.session.time_attack.extension),"extension_increases_display")
			race.session.time_attack.deadline -= 5.0
			check(is_equal_approx(race.displayed_race_time(),before+race.session.time_attack.extension-5.0),"penalty_reduces_display")
		race.paused_race = true
		var paused: float = race.displayed_race_time()
		await settle_physics(15)
		check(is_equal_approx(paused,race.displayed_race_time()),mode+"_pause_freezes")
		await settle(2)
		save_frame(mode+"_countdown")
		race.paused_race = false
		# Timer-boundary fixture verifies final HUD clamps to zero after expiry.
		if mode=="time_attack": race.session.time_attack.deadline = race.race_time-1.0
		else: race.drift.elapsed = race.drift.RULES.DURATION
		await settle_physics(3)
		race.update_hud()
		check(race.phase==3 and race.displayed_race_time()==0.0,mode+"_expired_zero")
		check(metrics.text.begins_with("0.00s"),mode+"_expired_hud")
		race.results_action()
		race.begin_countdown()
		race.update_hud()
		check(race.displayed_race_time()>0.0,mode+"_retry_restores_budget")
		race.show_menu()
	race.menu_flow.choose_mode("quick")
	race.start_race()
	race.begin_countdown()
	race.session.change_phase(2)
	await settle_physics(20)
	race.session.progress.records[1].penalty = 5.0
	race.update_hud()
	check(is_equal_approx(race.displayed_race_time(),race.race_time+5.0),"untimed_elapsed_with_penalty")
	check(race.get_node("HUD/RaceMetrics").text.begins_with("%.2fs" % (race.race_time+5.0)),"untimed_hud_elapsed")
	race.show_menu()
	race.course.shutdown()
	await settle(4)
	report("failures",failures)
	report("passed",failures.is_empty())
	finish()
