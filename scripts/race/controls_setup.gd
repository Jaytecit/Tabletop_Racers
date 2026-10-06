extends Node
const ACTIONS: Array[String] = ["p1_go","p1_brake","p1_left","p1_right","boost","reset_car","pause_race","restart","menu","cycle_camera"]
const TITLES: Array[String] = ["Accelerate","Brake","Steer left","Steer right","Boost","Recover car","Pause","Retry","Return to menu","Cycle camera"]
const PAD_NAMES: Array[String] = ["A","B","X","Y"]
var race: Node3D
var panel: Panel
var mask: ColorRect
var focus_modes: Dictionary = {}
var launch: Button
var waiting: String = ""
var rows: Dictionary = {}
var defaults: Dictionary = {}
var select_button: int = JOY_BUTTON_A
var boost_button: int = JOY_BUTTON_A
var config_path: String = "user://controls.cfg"
var pad_choices: Dictionary = {}
var config: ConfigFile = ConfigFile.new()

func setup(race_owner: Node3D) -> void:
	race = race_owner
	if not InputMap.has_action("cycle_camera"):
		InputMap.add_action("cycle_camera")
	bind_key("cycle_camera",KEY_C)
	config_path = str(race.get_meta("controls_config_path","user://controls.cfg"))
	for action: String in ACTIONS: defaults[action] = InputMap.action_get_events(action)
	config.load(config_path)
	for action: String in ACTIONS:
		if config.has_section_key("keyboard",action): bind_key(action,int(config.get_value("keyboard",action)))
	select_button = clampi(int(config.get_value("pad","select",0)),0,3)
	boost_button = clampi(int(config.get_value("pad","boost",0)),0,3)
	apply_pad()
	apply_camera_preferences()
	launch = Button.new()
	launch.text = "CONTROLS SETUP"
	launch.position = Vector2(278,615)
	launch.size = Vector2(230,36)
	race.menu.add_child(launch)
	race.menu.get_node("Controller").hide()
	launch.pressed.connect(open)
	mask = ColorRect.new()
	mask.size = race.menu.size
	mask.color = Color(0,0,0,0.55)
	race.menu.add_child(mask)
	mask.hide()
	panel = Panel.new()
	panel.name = "ControlsSetup"
	panel.position = Vector2(210,8)
	panel.size = Vector2(730,658)
	panel.theme = race.menu.theme
	panel.add_theme_stylebox_override("panel",preload("res://scripts/race/arcade_presentation.gd").box(preload("res://scripts/race/arcade_presentation.gd").INK))
	race.menu.add_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.position = Vector2(24,16)
	column.size = Vector2(682,626)
	column.add_theme_constant_override("separation",6)
	panel.add_child(column)
	var title: Label = Label.new()
	title.text = "(NOT) THE REAL THING / CONTROLS"
	column.add_child(title)
	var help: Label = Label.new()
	help.text = "Select a keyboard binding, then press a key. ESC cancels.\nArrow keys also drive. RT/LT drive; stick/D-pad steer.\nCamera: chase / overhead / close chase."
	help.add_theme_font_size_override("font_size",12)
	column.add_child(help)
	for index: int in range(ACTIONS.size()):
		var row: HBoxContainer = HBoxContainer.new()
		column.add_child(row)
		var caption: Label = Label.new()
		caption.text = TITLES[index]
		caption.custom_minimum_size.x = 320
		row.add_child(caption)
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(340,30)
		row.add_child(button)
		var action: String = ACTIONS[index]
		rows[action] = button
		button.pressed.connect(func() -> void:
			waiting = action
			button.text = "PRESS A KEY (ESC CANCELS)")
	for kind: String in ["select","boost"]:
		var row: HBoxContainer = HBoxContainer.new()
		column.add_child(row)
		var caption: Label = Label.new()
		caption.text = "Gamepad "+kind.capitalize()
		caption.custom_minimum_size.x = 320
		row.add_child(caption)
		var choice: OptionButton = OptionButton.new()
		pad_choices[kind] = choice
		choice.name = kind
		choice.custom_minimum_size = Vector2(340,30)
		for text: String in PAD_NAMES: choice.add_item(text)
		choice.select(select_button if kind=="select" else boost_button)
		row.add_child(choice)
		choice.item_selected.connect(func(index: int) -> void:
			if kind=="select": select_button = index
			else: boost_button = index
			config.set_value("pad",kind,index)
			apply_pad()
			config.save(config_path))
	var camera_row: HBoxContainer = HBoxContainer.new()
	column.add_child(camera_row)
	var camera_caption: Label = Label.new()
	camera_caption.text = "Gamepad camera"
	camera_caption.custom_minimum_size.x = 320
	camera_row.add_child(camera_caption)
	var camera_choice: OptionButton = OptionButton.new()
	camera_choice.custom_minimum_size = Vector2(340,30)
	camera_choice.add_item("RIGHT STICK CLICK",JOY_BUTTON_RIGHT_STICK)
	camera_choice.add_item("LEFT STICK CLICK",JOY_BUTTON_LEFT_STICK)
	camera_choice.select(1 if int(config.get_value("pad","camera",JOY_BUTTON_RIGHT_STICK))==JOY_BUTTON_LEFT_STICK else 0)
	camera_row.add_child(camera_choice)
	pad_choices["camera"] = camera_choice
	camera_choice.item_selected.connect(func(index: int) -> void:
		config.set_value("pad","camera",camera_choice.get_item_id(index))
		apply_pad()
		config.save(config_path))
	var reset: Button = Button.new()
	reset.text = "RESTORE DEFAULTS"
	column.add_child(reset)
	reset.pressed.connect(restore_defaults)
	var close: Button = Button.new()
	close.text = "DONE"
	column.add_child(close)
	close.pressed.connect(func() -> void:
		close_setup())
	panel.hide()
	refresh()

func restore_defaults() -> void:
	waiting = ""
	for action: String in ACTIONS:
		InputMap.action_erase_events(action)
		for event: InputEvent in defaults[action]: InputMap.action_add_event(action,event)
	select_button = JOY_BUTTON_A
	boost_button = JOY_BUTTON_A
	for choice: OptionButton in pad_choices.values(): choice.select(0)
	config.clear()
	config.save(config_path)
	apply_pad()
	race.camera_driver.mode = race.camera_driver.DEFAULT_MODE
	race.camera_driver.reset(race.camera,race.player_car)
	refresh()

func close_setup() -> void:
	waiting = ""
	panel.hide()
	mask.hide()
	for control: Control in focus_modes:
		if is_instance_valid(control): control.focus_mode = focus_modes[control]
	focus_modes.clear()
	launch.grab_focus()

func suppress_focus(node: Node, except: Node = null) -> void:
	if node==panel or node==except: return
	if node is Control:
		focus_modes[node] = node.focus_mode
		node.focus_mode = Control.FOCUS_NONE
	for child: Node in node.get_children(): suppress_focus(child,except)

func open() -> void:
	if panel.visible: return
	suppress_focus(race.menu)
	mask.show()
	mask.move_to_front()
	panel.show()
	panel.move_to_front()
	rows[ACTIONS[0]].grab_focus()

func select_name() -> String:
	return PAD_NAMES[select_button]

func apply_pad() -> void:
	race.controller.boost_button = boost_button
	var camera_button: int = int(config.get_value("pad","camera",JOY_BUTTON_RIGHT_STICK))
	race.controller.camera_button = camera_button if camera_button in [JOY_BUTTON_RIGHT_STICK,JOY_BUTTON_LEFT_STICK] else JOY_BUTTON_RIGHT_STICK
	for event: InputEvent in InputMap.action_get_events("ui_accept"):
		if event is InputEventJoypadButton: InputMap.action_erase_event("ui_accept",event)
	var accept: InputEventJoypadButton = InputEventJoypadButton.new()
	accept.device = -1
	accept.button_index = select_button as JoyButton
	InputMap.action_add_event("ui_accept",accept)

func apply_camera_preferences() -> void:
	# Adopt high chase once, then honour subsequent saved camera choices.
	race.camera_driver.mode = race.camera_driver.DEFAULT_MODE
	if int(config.get_value("camera","defaults_version",0))==race.camera_driver.DEFAULTS_VERSION:
		race.camera_driver.mode = clampi(int(config.get_value("camera","mode",race.camera_driver.DEFAULT_MODE)),0,2)
	config.set_value("camera","defaults_version",race.camera_driver.DEFAULTS_VERSION)
	config.set_value("camera","mode",race.camera_driver.mode)

func save_camera_mode() -> void:
	config.set_value("camera","defaults_version",race.camera_driver.DEFAULTS_VERSION)
	config.set_value("camera","mode",race.camera_driver.mode)
	config.save(config_path)

func bind_key(action: String, key: int) -> void:
	InputMap.action_erase_events(action)
	var event: InputEventKey = InputEventKey.new()
	event.keycode = key as Key
	InputMap.action_add_event(action,event)

func refresh() -> void:
	for action: String in ACTIONS:
		var events: Array[InputEvent] = InputMap.action_get_events(action)
		rows[action].text = events[0].as_text() if not events.is_empty() else "UNBOUND"

func _input(event: InputEvent) -> void:
	if waiting=="" or not panel.visible: return
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if event.keycode!=KEY_ESCAPE:
			for other: String in ACTIONS:
				if other==waiting: continue
				for binding: InputEvent in InputMap.action_get_events(other):
					if binding is InputEventKey and binding.keycode==event.keycode:
						rows[waiting].text = "KEY ALREADY IN USE"
						waiting = ""
						return
			bind_key(waiting,event.keycode)
			config.set_value("keyboard",waiting,event.keycode)
			config.save(config_path)
		waiting = ""
		refresh()
