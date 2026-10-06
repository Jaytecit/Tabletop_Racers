extends "res://tests/autopilot/probe_base.gd"
const STATS: Script = preload("res://scripts/vehicles/player_stats.gd")

func toggle(ui: Node) -> void:
	ui.test_button.grab_focus()
	var event: InputEventAction = InputEventAction.new()
	event.action = "ui_accept"
	event.pressed = true
	Input.parse_input_event(event)
	await settle(1)
	event = InputEventAction.new()
	event.action = "ui_accept"
	event.pressed = false
	Input.parse_input_event(event)
	await settle(2)

func _ready() -> void:
	await super._ready()
	await settle(5)
	var race: Node3D = get_tree().current_scene.get_node("Race")
	race.profile.read_only = true
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.device = -1
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	race.controls_setup.config_path = summer_out_dir+"/controls.cfg"
	race.show_menu()
	race.menu_flow.show_step(1)
	var saved: Dictionary = race.profile.vehicle().duplicate(true)
	var ui: Node = race.stats_menu
	ui.open()
	await toggle(ui)
	report("zero",race.stats_test_mode==1 and ui.choices.grip.text.contains("0.00") and is_equal_approx(race.player_car.top_speed,race.player_car.base_tuning.top_speed*0.8))
	save_frame("zero_stats")
	await toggle(ui)
	report("full",race.stats_test_mode==2 and ui.choices.grip.text.contains("6.00") and is_equal_approx(race.player_car.top_speed,race.player_car.base_tuning.top_speed*1.24))
	save_frame("full_stats")
	ui.adjust("grip",1)
	ui.apply()
	report("no_spending",race.profile.vehicle()==saved and ui.panel.visible and ui.save_button.disabled)
	ui.close()
	race.start_race()
	race.begin_countdown()
	report("race_uses_full",is_equal_approx(race.player_car.tuning.grip,race.player_car.base_tuning.grip*1.4) and race.trial.stats_code()=="4.00,4.00,4.00,4.00,4.00")
	race.trial.finish_run()
	report("no_records",race.trial.result_note.contains("RECORDS DISABLED"))
	race.award_race_rewards([{"player":1,"rank":1,"finished":true},{"player":2,"rank":2,"finished":true}])
	report("no_rewards",race.profile.vehicle()==saved and race.reward_note.contains("REWARDS DISABLED"))
	race.start_race()
	report("retry_keeps_full",race.stats_test_mode==2 and is_equal_approx(race.player_car.top_speed,race.player_car.base_tuning.top_speed*1.24))
	race.show_menu()
	race.menu_flow.show_step(1)
	ui.open()
	await toggle(ui)
	report("restore_earned",race.stats_test_mode==0 and STATS.code(race.active_stats())==STATS.code(saved.stats) and race.profile.vehicle()==saved)
	report("rivals_unchanged",is_equal_approx(race.all_cars[1].top_speed,race.all_cars[1].base_tuning.top_speed))
	for i: int in range(6): await toggle(ui)
	report("repeat_safe",race.stats_test_mode==0 and race.profile.vehicle()==saved)
	var passed: bool = true
	for value: Variant in _reports.values():
		if value is bool and not value: passed = false
	report("passed",passed)
	race.set_physics_process(false)
	for player: Node in race.find_children("*","AudioStreamPlayer",true,false):
		player.stop()
		player.stream = null
	await settle(3)
	call_deferred("finish")

