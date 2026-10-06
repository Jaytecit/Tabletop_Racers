extends "res://tests/autopilot/probe_base.gd"

func back() -> void:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.device = 63
	event.button_index = JOY_BUTTON_B
	event.pressed = true
	Input.parse_input_event(event)
	await settle(1)
	event = InputEventJoypadButton.new()
	event.device = 63
	event.button_index = JOY_BUTTON_B
	event.pressed = false
	Input.parse_input_event(event)
	await settle(2)

func _ready() -> void:
	await super._ready()
	await settle(5)
	var race: Node3D = get_tree().current_scene.get_node("Race")
	race.profile.read_only = true
	race.controller.set_physics_process(false)
	race.controller.device = -1
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	race.controls_setup.config_path = summer_out_dir+"/controls.cfg"
	race.show_menu()
	race.menu_flow.choose_mode("freestyle")
	race.menu_flow.show_step(3)
	await back()
	report("one_step_back",race.menu_flow.step==2)
	await back()
	report("vehicle_to_driver",race.menu_flow.step==1)
	race.stats_menu.open()
	await back()
	report("stats_back",not race.stats_menu.panel.visible and race.menu_flow.step==1)
	race.setup_menu.open()
	await back()
	report("setup_back",not race.setup_menu.panel.visible and race.menu_flow.step==1)
	race.controls_setup.open()
	race.controls_setup.waiting = "boost"
	await back()
	report("cancel_rebind",race.controls_setup.waiting=="" and race.controls_setup.panel.visible)
	await back()
	report("controls_back",not race.controls_setup.panel.visible and race.menu_flow.step==1)
	await back()
	await back()
	report("home_stays_home",race.menu_flow.step==0 and race.phase==0)
	race.start_race()
	race.begin_countdown()
	race.session.change_phase(2)
	await back()
	report("racing_keeps_brake",race.phase==2)
	race.session.change_phase(3)
	await back()
	report("results_back",race.phase==0 and race.menu.visible)
	save_frame("back_to_menu")
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
