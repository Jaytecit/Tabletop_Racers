extends "res://tests/autopilot/probe_base.gd"

func _enter_tree() -> void:
	super._enter_tree()
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(func(node: Node) -> void:
		if node.name=="Race" and node.get("profile")!=null:
			node.profile.path = "res://tests/fixtures/race_quality_read_only.json"
		if node.name=="Sequence" and node.get("hardware_input_isolated")!=null:
			node.hardware_input_isolated = true)

func _ready() -> void:
	await super._ready()
	await settle(5)
	var race: Node3D = get_tree().current_scene.get_node("Race")
	get_tree().current_scene.get_node("Opening").queue_free()
	get_tree().paused = false
	race.get_node("HUD").show()
	race.profile.read_only = true
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.device = -1
	race.controller.using_pad = false
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	var flow: RefCounted = race.menu_flow
	flow.choose_mode("freestyle")
	flow.show_step(0)
	await verify_navigation(race)
	var brand: Script = preload("res://scripts/race/game_brand.gd")
	report("brand_name",ProjectSettings.get_setting("application/config/name")==brand.NAME and race.menu.get_node("Title").text==brand.NAME)
	report("brand_logo",race.menu.get_node("BrandLogo").texture!=null and race.menu.get_node("BrandLogo").visible)
	report("saved_profile_location",OS.get_user_data_dir().replace("\\","/").ends_with("Godot/app_userdata/Room Run · Miniature Grand Prix"))
	report("home",flow.step==0 and flow.home.visible and not race.menu.get_node("Start").visible)
	save_frame("00_home")
	race.menu.get_node("ModePage/Quick").grab_focus()
	await press("ui_accept",80)
	await settle(3)
	report("keyboard_mode",flow.step==1)
	race.garage.cards[2].pressed.emit()
	await settle(3)
	save_frame("01_driver")
	save_frame("02_buggy")
	report("standard_assigned_class",flow.step==3 and not flow.next_vehicle.visible and race.player_car.base_tuning.id=="buggy")
	flow.choose_mode("freestyle")
	flow.show_step(2)
	var gallery: bool = true
	for i: int in range(1,5):
		race.menu.get_node("NextVehicle").pressed.emit()
		await settle(2)
		gallery = gallery and flow.vehicle==i and flow.vehicle_art.texture!=null and flow.vehicle_status.text.begins_with("GRIP") and race.player_car.base_tuning.id==flow.ART_IDS[i]
		save_frame("02_vehicle_%d" % i)
	race.menu.get_node("NextVehicle").pressed.emit()
	report("gallery_wrap",gallery and flow.vehicle==0)
	race.menu.get_node("PreviousVehicle").pressed.emit()
	report("gallery_reverse",flow.vehicle==4)
	race.menu.get_node("FlowNext").pressed.emit()
	await settle(3)
	report("freestyle_course_class",flow.step==3 and flow.vehicle_art.texture==flow.artwork[4] and race.player_car.base_tuning.id=="speedboat" and race.menu.get_node("Start").visible)
	flow.choose_mode("quick")
	flow.show_step(3)
	# Exercise the existing course-selection signal, including its default vehicle.
	var tracks: OptionButton = race.menu.get_node("TrackSelect")
	var catalog: Script = preload("res://scripts/tracks/content_catalog.gd")
	tracks.item_selected.emit(catalog.IDS.find("game_table"))
	for frame: int in range(1200):
		await settle(1)
		if not race.course.loading: break
	report("course_default",flow.vehicle==0 and flow.step==3 and race.track_id=="game_table")
	save_frame("03_course")
	flow.show_step(0)
	race.controls_setup.launch.pressed.emit()
	await settle(3)
	report("setup_open",race.setup_menu.panel.visible)
	save_frame("04_setup")
	race.setup_menu.close()
	flow.show_step(3)
	await settle(3)
	race.menu.get_node("Start").pressed.emit()
	await settle(3)
	report("launch",race.phase==6 and not race.menu.visible and race.player_car.base_tuning.resource_path=="res://scenes/vehicles/buggy_definition.tres")
	race.begin_countdown()
	while race.phase==1: await get_tree().physics_frame
	await press("p1_go",600)
	report("driving",race.player_car.velocity.length()>0.1)
	# Actual session classification produces ranked records for the podium.
	race.session.classify()
	await settle_physics(12)
	await settle(3)
	report("podium",race.results_panel.visible and race.results_panel.get_node("Podium").get_child_count()==8)
	race.results_panel.get_node("Retry").grab_focus()
	await key(KEY_RIGHT,20)
	await settle(1)
	report("results_right",race.results_panel.get_node("Menu").has_focus())
	await key(KEY_DOWN,20)
	await settle(1)
	report("results_row_boundary",race.results_panel.get_node("Menu").has_focus())
	save_frame("05_podium")
	race.results_panel.get_node("Menu").pressed.emit()
	await settle(3)
	report("return_home",flow.step==0 and flow.home.visible)
	race.menu.get_node("ModePage/Trial").pressed.emit()
	report("trial",race.race_mode=="trial" and flow.step==1)
	race.menu.get_node("FlowBack").pressed.emit()
	report("back_home",flow.step==0)
	flow.home.get_node("Quick").grab_focus()
	flow.advance()
	report("pad_start_mode",flow.step==1 and race.race_mode=="quick")
	var passed: bool = true
	for value: Variant in _reports.values():
		if value is bool: passed = passed and value
	report("passed",passed)
	report("user_data_path",OS.get_user_data_dir())
	# Let the audio mixer release playback resources before quitting the test.
	for player: Node in get_tree().current_scene.find_children("*","AudioStreamPlayer",true,false):
		player.stop()
		player.stream = null
	await settle_physics(10)
	finish()

func verify_navigation(race: Node3D) -> void:
	var directions: Array[String] = ["ui_left","ui_right","ui_up","ui_down"]
	var keys: Array[int] = [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]
	var buttons: Array[int] = [JOY_BUTTON_DPAD_LEFT,JOY_BUTTON_DPAD_RIGHT,JOY_BUTTON_DPAD_UP,JOY_BUTTON_DPAD_DOWN]
	for i: int in range(4):
		var keyboard: InputEventKey = InputEventKey.new()
		keyboard.keycode = keys[i] as Key
		InputMap.action_add_event(directions[i],keyboard)
		var pad: InputEventJoypadButton = InputEventJoypadButton.new()
		pad.button_index = buttons[i] as JoyButton
		InputMap.action_add_event(directions[i],pad)
		var stick: InputEventJoypadMotion = InputEventJoypadMotion.new()
		stick.axis = JOY_AXIS_LEFT_X if i<2 else JOY_AXIS_LEFT_Y
		stick.axis_value = -1.0 if i in [0,2] else 1.0
		InputMap.action_add_event(directions[i],stick)
	var navigation: Node = race.get_node("MenuNavigation")
	var transitions: Array = []
	var passed: bool = true
	for page: int in range(8):
		if page<4: race.menu_flow.show_step(page)
		elif page==4: race.setup_menu.open()
		elif page==5:
			race.setup_menu.close()
			race.controls_setup.open()
		elif page==6:
			race.controls_setup.close_setup()
			race.menu_flow.show_step(1)
			race.stats_menu.open()
		else:
			race.stats_menu.shop = true
			race.stats_menu.refresh()
		await settle(3)
		var panel: Control = navigation.active_panel()
		var controls: Array = []
		for row: Array in navigation.rows: controls.append_array(row)
		for source: Control in controls:
			for d: int in range(4):
				for device: int in range(3):
					source.grab_focus()
					await settle(1)
					var neighbour: NodePath = source.get(["focus_neighbor_left","focus_neighbor_right","focus_neighbor_top","focus_neighbor_bottom"][d])
					var expected: Control = source.get_node(neighbour)
					if d<2 and (source is HSlider or (page==6 and source in race.stats_menu.choices.values())): expected = source
					var event: InputEvent
					if device==0:
						var key_event: InputEventKey = InputEventKey.new()
						key_event.keycode = keys[d] as Key
						key_event.pressed = true
						event = key_event
					elif device==1:
						var pad_event: InputEventJoypadButton = InputEventJoypadButton.new()
						pad_event.button_index = buttons[d] as JoyButton
						pad_event.pressed = true
						event = pad_event
					else:
						var stick_event: InputEventJoypadMotion = InputEventJoypadMotion.new()
						stick_event.axis = JOY_AXIS_LEFT_X if d<2 else JOY_AXIS_LEFT_Y
						stick_event.axis_value = -1.0 if d in [0,2] else 1.0
						event = stick_event
					Input.parse_input_event(event)
					await settle(1)
					var actual: Control = get_viewport().gui_get_focus_owner()
					var valid: bool = actual==expected and panel.is_ancestor_of(actual)
					if d<2: valid = valid and absf(actual.get_global_rect().get_center().y-source.get_global_rect().get_center().y)<23.0
					passed = passed and valid
					transitions.append({"page":page,"from":str(source.get_path()),"direction":directions[d],"device":device,"to":str(actual.get_path()),"passed":valid})
					if event is InputEventJoypadMotion: event.axis_value = 0.0
					else: event.set("pressed",false)
					Input.parse_input_event(event)
					await settle(1)
		save_frame("navigation_%d" % page)
		if page==4:
			var slider: HSlider = panel.find_child("master",true,false)
			slider.value = 50.0
			slider.grab_focus()
			await key(KEY_RIGHT,20)
			await settle(1)
			report("slider_single_adjustment",slider.value==51.0 and slider.has_focus())
			race.setup_menu.apply_display()
			await settle(3)
			var enabled: bool = false
			for row: Array in navigation.rows: enabled = enabled or race.setup_menu.confirm in row
			race.setup_menu.revert_display()
			await settle(3)
			var removed: bool = true
			for row: Array in navigation.rows: removed = removed and race.setup_menu.confirm not in row
			report("display_focus_rebuild",enabled and removed and race.setup_menu.resolution.has_focus())
		if page==7: race.stats_menu.close()
	var evidence: FileAccess = FileAccess.open(summer_out_dir.path_join("focus_transitions.json"),FileAccess.WRITE)
	evidence.store_string(JSON.stringify(transitions,"  "))
	report("directional_navigation",passed)
	race.menu_flow.show_step(1)
	await settle(3)
	race.garage.cards[2].grab_focus()
	var column_trace: Array = []
	column_trace.append({"focus":str(get_viewport().gui_get_focus_owner().get_path()),"column":navigation.preferred_x})
	var source_row: int = -1
	for i: int in range(navigation.rows.size()):
		if race.garage.cards[2] in navigation.rows[i]: source_row = i
	# The current driver page has one row below its cards. Do not count a
	# clamped Down as movement and then incorrectly expect two Ups to undo it.
	var steps: int = mini(2,navigation.rows.size()-1-source_row)
	for direction: int in [KEY_DOWN,KEY_UP]:
		for i: int in range(steps):
			await key(direction,20)
			await settle(1)
			column_trace.append({"focus":str(get_viewport().gui_get_focus_owner().get_path()),"column":navigation.preferred_x})
	report("column_trace",column_trace)
	report("column_restored",steps>0 and race.garage.cards[2].has_focus())
	race.garage.cards[3].grab_focus()
	for i: int in range(10):
		var repeated: InputEventKey = InputEventKey.new()
		repeated.keycode = KEY_RIGHT
		repeated.pressed = true
		repeated.echo = i>0
		Input.parse_input_event(repeated)
		await settle(1)
	await key(KEY_RIGHT,500)
	report("held_row_boundary",race.garage.cards[3].has_focus())
	for device: int in range(2):
		var held: InputEvent
		if device==0:
			var pad: InputEventJoypadButton = InputEventJoypadButton.new()
			pad.button_index = JOY_BUTTON_DPAD_RIGHT
			pad.pressed = true
			held = pad
		else:
			var stick: InputEventJoypadMotion = InputEventJoypadMotion.new()
			stick.axis = JOY_AXIS_LEFT_X
			stick.axis_value = 1.0
			held = stick
		Input.parse_input_event(held)
		await get_tree().create_timer(0.6).timeout
		report("held_pad_boundary_%d" % device,race.garage.cards[3].has_focus())
		if held is InputEventJoypadMotion: held.axis_value = 0.0
		else: held.set("pressed",false)
		Input.parse_input_event(held)
	race.menu_flow.show_step(0)
	await settle(2)
	race.setup_menu.open()
	await settle(2)
	race.setup_menu.close()
	await settle(2)
	report("modal_focus_return",race.controls_setup.launch.has_focus())
	race.menu_flow.show_step(0)
	await settle(3)
