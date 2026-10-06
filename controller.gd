extends Node
# The first connected controller owns driving. Keyboard remains available.
const DEADZONE: float = 0.18
var device: int = -1
var controller_name: String = ""
var using_pad: bool = false
var buttons: PackedByteArray = PackedByteArray([0,0,0,0])
var boost_button: int = JOY_BUTTON_A
var camera_button: int = JOY_BUTTON_RIGHT_STICK
var race: Node
func _ready() -> void:
	# Use standard GUI acceptance so A activates the focused button or popup.
	var accept: InputEventJoypadButton = InputEventJoypadButton.new()
	accept.device = -1
	accept.button_index = JOY_BUTTON_A
	if not InputMap.action_has_event("ui_accept",accept):
		InputMap.action_add_event("ui_accept",accept)
	race = get_parent()
	Input.joy_connection_changed.connect(_connection_changed)
	discover()
func discover() -> void:
	var pads: Array[int] = Input.get_connected_joypads()
	device = pads[0] if not pads.is_empty() else -1
	controller_name = Input.get_joy_name(device) if device>=0 else ""
	buttons.fill(0)
func _connection_changed(id: int, connected: bool) -> void:
	if not connected and id==device:
		Input.stop_joy_vibration(id)
		discover()
		using_pad = false
		if race.phase==1 or race.phase==2 or (race.phase==5 and race.has_method("observe_progress")):
			race.paused_race = true
			race.banner.visible = true
			race.banner.text = "CONTROLLER DISCONNECTED\nESC / START · RESUME"
	else:
		discover()
	if race.has_method("update_hud"): race.update_hud()
func _input(event: InputEvent) -> void:
	# B is reserved for back while browsing; during racing it remains brake/boost.
	if event is InputEventJoypadButton and event.button_index==JOY_BUTTON_B and race.phase in [0,3]:
		if event.pressed: menu_back()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed:
		using_pad = false
	elif event is InputEventJoypadButton and event.pressed and event.device==device:
		using_pad = true
	elif event is InputEventJoypadMotion and event.device==device and absf(event.axis_value)>0.25:
		using_pad = true

func menu_back() -> void:
	if race.get("profile_menu")!=null and race.profile_menu.visible:
		race.profile_menu.go_back()
		return
	if race.get("developer_menu")!=null and race.developer_menu.root.visible:
		race.developer_menu.close()
		return
	if race.get("stats_menu")!=null and race.stats_menu.panel.visible:
		race.stats_menu.close()
	elif race.get("setup_menu")!=null and race.setup_menu.panel.visible:
		race.setup_menu.close()
	elif race.get("controls_setup")!=null and race.controls_setup.panel.visible:
		if race.controls_setup.waiting!="":
			race.controls_setup.waiting = ""
			race.controls_setup.refresh()
		else: race.controls_setup.close_setup()
	elif race.phase==0 and race.get("menu_flow")!=null:
		race.menu_flow.go_back()
	else: race.show_menu()
func axis(value: float) -> float:
	return signf(value)*clampf((absf(value)-DEADZONE)/(1.0-DEADZONE),0.0,1.0)
func steering() -> float:
	if device<0: return 0.0
	var digital: float = float(Input.is_joy_button_pressed(device,JOY_BUTTON_DPAD_RIGHT))-float(Input.is_joy_button_pressed(device,JOY_BUTTON_DPAD_LEFT))
	return digital if digital!=0.0 else axis(Input.get_joy_axis(device,JOY_AXIS_LEFT_X))
func throttle() -> float:
	if device<0: return 0.0
	# Godot normalizes both triggers to 0..1.
	var go: float = maxf(Input.get_joy_axis(device,JOY_AXIS_TRIGGER_RIGHT),float(Input.is_joy_button_pressed(device,JOY_BUTTON_RIGHT_SHOULDER)))
	var brake: float = maxf(Input.get_joy_axis(device,JOY_AXIS_TRIGGER_LEFT),float(Input.is_joy_button_pressed(device,JOY_BUTTON_B) and boost_button!=JOY_BUTTON_B))
	return clampf(go-brake,-1.0,1.0)
func boost_pressed() -> bool:
	return device>=0 and Input.is_joy_button_pressed(device,boost_button)
func edge(button: int, slot: int) -> bool:
	var down: bool = device>=0 and Input.is_joy_button_pressed(device,button)
	var fresh: bool = down and buttons[slot]==0
	buttons[slot] = 1 if down else 0
	return fresh
func _physics_process(_delta: float) -> void:
	if race.get("profile_menu")!=null and race.profile_menu.visible:
		buttons.fill(0)
		return
	if race.get("developer_menu")!=null and race.developer_menu.root.visible: return
	if race.get("controls_setup")!=null and race.controls_setup.panel.visible: return
	if race.get("stats_menu")!=null and race.stats_menu.panel.visible: return
	if race.get("setup_menu")!=null and race.setup_menu.panel.visible: return
	if edge(camera_button,3) and race.has_method("cycle_camera"): race.cycle_camera()
	if edge(JOY_BUTTON_START,0):
		if race.phase==0:
			if race.get("menu_flow")!=null: race.menu_flow.advance()
			else: race.start_race()
		elif race.phase==1 or race.phase==2 or (race.phase==5 and race.has_method("observe_progress")): race.toggle_pause()
	if edge(JOY_BUTTON_BACK,1):
		if race.phase==0 and race.get("menu_flow")!=null: race.menu_flow.go_back()
		else: race.show_menu()
	if edge(JOY_BUTTON_Y,2) and race.phase!=0:
		if boost_button!=JOY_BUTTON_Y and (race.get("controls_setup")==null or race.controls_setup.select_button!=JOY_BUTTON_Y): race.start_race()
func rumble(strength: float, duration: float) -> void:
	if device>=0: Input.start_joy_vibration(device,strength*0.45,strength,duration)
func _exit_tree() -> void:
	if device>=0: Input.stop_joy_vibration(device)
func diagnostic_state() -> Dictionary:
	return {"device":device,"name":controller_name,"connected":Input.get_connected_joypads(),"steering":steering(),"throttle":throttle(),"boost":boost_pressed(),"using_pad":using_pad}
