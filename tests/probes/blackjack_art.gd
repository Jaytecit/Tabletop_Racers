extends "res://tests/autopilot/probe_base.gd"
# Rendered acceptance walkthrough. All writes go to a disposable profile.
var failures: Array[String] = []
func check(title: String, condition: bool) -> void:
	report(title,condition)
	if not condition: failures.append(title)

func tap_gamepad_a() -> void:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.device = 0
	event.button_index = JOY_BUTTON_A
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await settle(2)

func _ready() -> void:
	await super._ready()
	await settle(3)
	var race: Node3D = get_tree().current_scene.get_node("Race")
	race.profile.path = summer_out_dir.path_join("test-profile.json")
	race.profile.read_only = false
	race.race_mode = "quick"
	check("blackjack_loads",race.course.select("game_table"))
	race.show_menu()
	await settle(3)
	check("course_illustration_visible",race.menu.get_node("CourseIllustration").visible and not race.menu.get_node("Diorama").visible)
	check("world_hud_hidden_in_menu",not race.get_node("HUD/Top").visible)
	check("portrait_pixel_size",race.menu.get_node("DriverCards").get_child(0).get_node("Portrait").texture.get_size()==Vector2(128,128))
	check("portrait_display_size",race.menu.get_node("DriverCards").get_child(0).get_node("Portrait").size==Vector2(128,128))
	check("profile_display_size",race.menu.get_node("DriverProfile/Face").size==Vector2(80,80))
	save_frame("01_blackjack_menu")
	for index: int in range(4):
		race.garage.cards[index].grab_focus()
		await key(KEY_ENTER,60)
		await settle(2)
		check("keyboard_driver_%d" % index,race.garage.selected==index and race.phase==0)
		check("profile_driver_%d" % index,race.menu.get_node("DriverProfile/Name").text==race.garage.DRIVERS[index].split(" · ")[1])
	save_frame("02_driver_profile")
	race.garage.cards[1].grab_focus()
	await tap_gamepad_a()
	check("gamepad_driver",race.garage.selected==1 and race.phase==0)
	var difficulty: OptionButton = race.menu.get_node("QuickRace/Difficulty")
	difficulty.grab_focus()
	await tap_gamepad_a()
	check("gamepad_opens_difficulty",difficulty.get_popup().visible)
	save_frame("02b_difficulty_popup")
	difficulty.get_popup().hide()
	race.garage.select(race,3)
	race.save_preferences()
	var mode: OptionButton = race.menu.get_node("Mode")
	mode.emit_signal("item_selected",1)
	await settle(2)
	check("trial_controls",race.race_mode=="trial" and race.menu.get_node("QuickRace/Rivals").disabled)
	mode.emit_signal("item_selected",2)
	await settle(2)
	check("cup_controls",race.race_mode=="cup" and race.menu.get_node("TrackSelect").disabled)
	mode.emit_signal("item_selected",0)
	race.course.select("carpet_cruise")
	await settle(3)
	check("other_course_diorama",race.menu.get_node("Diorama").visible and not race.menu.get_node("CourseIllustration").visible)
	race.course.select("game_table")
	race.show_menu()
	get_window().size = Vector2i(1280,720)
	await settle(4)
	save_frame("03_menu_720p")
	check("menu_inside_viewport",get_viewport().get_visible_rect().encloses(race.menu.get_rect()))
	get_window().size = Vector2i(1200,800)
	race.menu.get_node("Start").grab_focus()
	await key(KEY_ENTER,60)
	await settle(3)
	check("keyboard_opens_preview",race.phase==6 and not race.menu.visible)
	check("preview_hud_hidden",not race.get_node("HUD/Top").visible)
	save_frame("03b_course_preview")
	await tap_gamepad_a()
	check("select_starts_countdown",race.phase==1)
	check("race_hud_visible",race.get_node("HUD/Top").visible)
	save_frame("04_blackjack_grid")
	for _frame: int in range(250): await get_tree().physics_frame
	var before: Vector3 = race.player_car.position
	await press("p1_go",600)
	check("car_drives",race.player_car.position.distance_to(before)>0.5)
	save_frame("05_blackjack_driving")
	race.toggle_pause()
	check("pause_works",race.paused_race)
	save_frame("06_pause")
	race.banner.visible = false
	for section: int in range(2):
		race.player_car.position = race.track.sample_3d(race.track.total_length*(0.11 if section==0 else 0.22))
		race.camera_driver.reset(race.camera,race.player_car)
		await settle(3)
		save_frame("06b_casino_detail_%d" % section)
	race.toggle_pause()
	race.show_menu()
	await settle(3)
	check("return_to_menu",race.phase==0 and race.menu.visible)
	check("profile_persists_selection",race.profile.data.quick_race.driver==3)
	check("route_validation",race.track.validation_errors.is_empty())
	check("woven_felt",race.get_node("CourseEnvironment/Support/FeltTable/Mesh").material_override is ShaderMaterial)
	# Exercise the real result presenter with a fixture; no race records are fabricated.
	race.menu.visible = false
	race.session.change_phase(3)
	var rows: Array = []
	for player: int in range(1,5):
		rows.append({"player":player,"rank":player,"time":61.25+player,"finished":true,"laps":3,"penalty":0.0})
	race.on_results_ready(rows)
	await settle(3)
	check("results_visible",race.results_panel.visible and race.banner.visible and race.banner.text.contains("RESULTS"))
	save_frame("07_results")
	race.show_menu()
	await settle(2)
	# Compare frame cost in the live renderer after startup and asset import.
	report("render_fps",Engine.get_frames_per_second())
	report("failures",failures)
	report("passed",failures.is_empty())
	finish()
