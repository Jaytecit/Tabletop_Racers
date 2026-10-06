extends "res://tests/probes/race_quality_ai_verification.gd"
# One uninterrupted opening -> menu -> full race -> guarded results -> retry.
func send_action(action: StringName, down: bool) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = down
	Input.parse_input_event(event)

func tap(action: StringName) -> void:
	send_action(action,true)
	await settle(2)
	send_action(action,false)
	await settle(3)

func activate(button: Button) -> void:
	button.grab_focus()
	await tap(&"ui_accept")

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
	var opening: Control = app.get_node("Opening/Sequence")
	check(race.profile.read_only and opening.hardware_input_isolated,"isolated_startup")
	while opening.elapsed<opening.PROMPT_TIME+0.3: await get_tree().process_frame
	await settle(3)
	save_frame("opening_title")
	var music: int = race.music.get_instance_id()
	await tap(&"ui_accept")
	for frame: int in range(120):
		await get_tree().process_frame
		if not app.has_node("Opening"): break
	check(not app.has_node("Opening") and not get_tree().paused and race.menu_flow.step==0,"opening_to_menu")
	check(race.music.get_instance_id()==music and race.music.playing,"continuous_menu_music")
	await activate(race.menu_flow.home.get_node("Quick"))
	check(race.menu_flow.step==1,"quick_to_driver")
	await activate(race.garage.cards[0])
	await activate(race.menu_flow.next)
	check(race.menu_flow.step==2,"driver_to_vehicle")
	await activate(race.menu_flow.next)
	check(race.menu_flow.step==3,"vehicle_to_course")
	var choice: OptionButton = race.menu.get_node("TrackSelect")
	var index: int = preload("res://scripts/tracks/content_catalog.gd").IDS.find("toys_r_you")
	choice.select(index)
	choice.item_selected.emit(index)
	while race.course.loading: await get_tree().process_frame
	check(race.track_id=="toys_r_you" and race.course.error.is_empty(),"selected_toys")
	race.rival_count = 3
	race.race_laps = 3
	race.difficulty = 2
	race.profile.vehicle().stats = preload("res://scripts/vehicles/player_stats.gd").neutral()
	race.garage.apply_stats(race)
	await activate(race.menu.get_node("Start"))
	check(race.phase==6,"start_to_preview")
	await tap(&"ui_accept")
	check(race.phase==1,"preview_to_countdown")
	while race.phase==1: await get_tree().physics_frame
	check(race.phase==2,"countdown_to_race")
	Input.action_press("p1_go")
	Input.action_press("boost")
	await settle_physics(45)
	Input.action_release("boost")
	Input.action_release("p1_go")
	check(race.player_car.velocity.length()>1.0 and race.player_car.boost<100.0,"driver_accelerates_and_boosts")
	await tap(&"pause_race")
	var paused_time: float = race.race_time
	await settle_physics(8)
	check(race.paused_race and race.race_time==paused_time,"pause_freezes_clock")
	await tap(&"pause_race")
	await tap(&"cycle_camera")
	check(not race.paused_race,"resume")
	race.player_car.ai = true
	var held: bool = false
	for frame: int in range(24000):
		await get_tree().physics_frame
		if race.player_car.laps==2 and not held:
			held = true
			send_action(&"ui_accept",true)
			# HUD updates at 10Hz; wait for that update and its presented frame.
			await settle(8)
			check(race.get_node("HUD/Status").text.begins_with("LAP 3/3"),"final_lap_hud")
			save_frame("final_lap")
		if race.phase==3: break
	check(race.phase==3 and race.session.results.size()==4,"full_race_classified")
	await settle(20)
	check(race.phase==3 and race.results_panel.get_node("Retry").disabled,"held_accept_cannot_retry")
	send_action(&"ui_accept",false)
	await settle(20)
	save_frame("results")
	check(not race.results_panel.get_node("Retry").disabled,"release_enables_results")
	await activate(race.results_panel.get_node("Retry"))
	check(race.phase==6 and race.track_id=="toys_r_you","retry_to_preview")
	await tap(&"menu")
	check(race.phase==0 and race.menu.visible,"return_to_menu")
	check(race.profile.read_only,"read_only_finish")
	await settle(4)
	save_frame("returned_menu")
	report("failures",failures)
	report("passed",failures.is_empty())
	for node: Node in app.find_children("*","AudioStreamPlayer",true,false): node.stop()
	await settle(5)
	finish()
