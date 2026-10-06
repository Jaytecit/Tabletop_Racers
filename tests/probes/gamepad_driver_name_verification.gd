extends "res://tests/autopilot/probe_base.gd"
var failures: Array[String] = []
func check(value: bool, label: String) -> void:
	report(label,value)
	if not value: failures.append(label)
func pad(button: int) -> void:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.device = 777
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await settle(2)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await settle(2)
func _ready() -> void:
	await super._ready()
	await settle(4)
	var app: Node = get_tree().current_scene
	var race: Node3D = app.get_node("Race")
	check(race.profile.read_only and race.profile_directory.read_only,"read_only_personal_profiles")
	race.controller.set_physics_process(false)
	race.controller.device = -1
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	for pair: Array in [["ui_accept",JOY_BUTTON_A],["ui_left",JOY_BUTTON_DPAD_LEFT],["ui_right",JOY_BUTTON_DPAD_RIGHT],["ui_up",JOY_BUTTON_DPAD_UP],["ui_down",JOY_BUTTON_DPAD_DOWN]]:
		var binding: InputEventJoypadButton = InputEventJoypadButton.new()
		binding.device = 777
		binding.button_index = pair[1]
		InputMap.action_add_event(pair[0],binding)
	app.get_node("Opening/Sequence").hardware_input_isolated = true
	app.get_node("Opening/Sequence")._restore_menu()
	app.get_node("Opening").queue_free()
	get_tree().paused = false
	race.profile_menu.open()
	race.profile_menu.create()
	await settle(3)
	var menu: Control = race.profile_menu
	var keyboard: Control = menu.name_keyboard
	await pad(JOY_BUTTON_A)
	check(keyboard.visible and keyboard.keys[0].has_focus(),"a_opens_name_keyboard")
	await pad(JOY_BUTTON_DPAD_DOWN)
	for i: int in range(3): await pad(JOY_BUTTON_DPAD_RIGHT)
	check(keyboard.keys[9].has_focus(),"dpad_moves_to_j")
	await pad(JOY_BUTTON_A)
	await pad(JOY_BUTTON_DPAD_UP)
	for i: int in range(3): await pad(JOY_BUTTON_DPAD_LEFT)
	await pad(JOY_BUTTON_A)
	await pad(JOY_BUTTON_DPAD_UP)
	check(keyboard.keys[24].has_focus(),"focus_wraps_inside_keyboard")
	await pad(JOY_BUTTON_A)
	check(keyboard.draft=="JAY","gamepad_enters_name")
	await settle(3)
	save_frame("gamepad_driver_name")
	await pad(JOY_BUTTON_DPAD_RIGHT)
	await pad(JOY_BUTTON_DPAD_RIGHT)
	await pad(JOY_BUTTON_A)
	check(keyboard.draft=="JA","delete_last_letter")
	await pad(JOY_BUTTON_DPAD_LEFT)
	await pad(JOY_BUTTON_A)
	for i: int in range(3): await pad(JOY_BUTTON_DPAD_RIGHT)
	await pad(JOY_BUTTON_A)
	check(not keyboard.visible and menu.name_input.text=="JAZ" and menu.name_input.has_focus(),"done_returns_name_to_profile")
	await pad(JOY_BUTTON_A)
	await pad(JOY_BUTTON_A)
	await pad(JOY_BUTTON_B)
	check(not keyboard.visible and menu.name_input.text=="JAZ" and menu.visible,"b_cancels_draft_only")
	menu.editor.get_node("GamepadNameEntry").grab_focus()
	await pad(JOY_BUTTON_A)
	check(keyboard.visible,"pad_keys_button_opens")
	keyboard.keys[27].grab_focus()
	await pad(JOY_BUTTON_A)
	check(keyboard.draft.is_empty(),"clear_name")
	keyboard.keys[28].grab_focus()
	await pad(JOY_BUTTON_A)
	check(keyboard.visible and menu.name_input.text=="JAZ","empty_name_cannot_commit")
	keyboard.keys[0].grab_focus()
	for i: int in range(10): await pad(JOY_BUTTON_A)
	check(keyboard.draft=="AAAAAAAAA","nine_letter_limit")
	# Drive the left stick through the actual GUI action map as well.
	var stick_binding: InputEventJoypadMotion = InputEventJoypadMotion.new()
	stick_binding.device = 777
	stick_binding.axis = JOY_AXIS_LEFT_X
	stick_binding.axis_value = 1.0
	InputMap.action_add_event("ui_right",stick_binding)
	var stick: InputEventJoypadMotion = stick_binding.duplicate()
	Input.parse_input_event(stick)
	await settle(2)
	stick = stick.duplicate()
	stick.axis_value = 0.0
	Input.parse_input_event(stick)
	await settle(2)
	check(keyboard.keys[1].has_focus(),"left_stick_moves_focus")
	await pad(JOY_BUTTON_B)
	race.controls_setup.select_button = JOY_BUTTON_X
	race.controls_setup.apply_pad()
	await pad(JOY_BUTTON_X)
	check(keyboard.visible and "X: SELECT" in keyboard.hint.text,"remapped_select_opens_keyboard")
	await pad(JOY_BUTTON_X)
	check(keyboard.draft=="JAZA","remapped_select_enters_letter")
	await pad(JOY_BUTTON_B)
	# Start/back polling must not leave the profile screen or launch a race.
	race.controller.buttons[0] = 1
	race.controller._physics_process(1.0/60.0)
	check(menu.visible and race.phase==0 and race.controller.buttons[0]==0,"profile_isolates_menu_shortcuts")
	var directory: RefCounted = preload("res://scripts/profiles/profile_directory.gd").new()
	directory.root = summer_out_dir.path_join("profile-fixture")
	directory.legacy_path = summer_out_dir.path_join("absent.json")
	directory.load_directory()
	var created: Dictionary = directory.create_profile(menu.name_input.text,menu.selected_portrait)
	check(created.error==OK,"gamepad_name_saves")
	var store: RefCounted = preload("res://scripts/profile_store.gd").new()
	if created.error==OK:
		store.path = directory.payload_path(created.id)
		store.load_profile()
		check(store.data.identity.name=="JAZ","gamepad_name_reloads")
	report("failures",failures)
	report("passed",failures.is_empty())
	for voice: Node in app.find_children("*","AudioStreamPlayer",true,false):
		voice.stop()
		voice.stream = null
	await settle(3)
	finish()
