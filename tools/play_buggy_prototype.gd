extends SceneTree
# Separate manual-test entry point. Production scenes and profile remain untouched.
var race: Node3D
var ready_to_drive: bool = false
var colour_index: int = 0
const COLOURS: Array[Color] = [Color("ef6546"),Color("4ba5c9"),Color("f1c44f"),Color("86bb5b")]

func _initialize() -> void:
	node_added.connect(_isolate)
	_launch.call_deferred()

func _isolate(node: Node) -> void:
	if node.name=="Race" and node.get("profile")!=null:
		node.profile.path = "res://tests/fixtures/race_quality_read_only.json"
	if node.name=="Sequence" and node.get("hardware_input_isolated")!=null:
		node.hardware_input_isolated = true

func _launch() -> void:
	DisplayServer.window_set_title("BUGGY WHEEL PROTOTYPE — read-only test")
	var app: Node = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	current_scene = app
	await process_frame
	race = app.get_node("Race")
	if app.has_node("Opening"): app.get_node("Opening").queue_free()
	paused = false
	assert(race.profile.read_only)
	race.get_node("HUD").show()
	race.menu_flow.choose_mode("freestyle")
	assert(race.course.select("game_table"))
	while race.course.loading: await process_frame
	race.rival_count = 3
	race.race_laps = 9
	race.start_race()
	race.begin_countdown()
	race.session.countdown = 0.81
	for i: int in range(4):
		var car: CharacterBody3D = race.all_cars[i]
		var replacement: Node3D = preload("res://scripts/vehicles/buggy_wheel_prototype.gd").build(COLOURS[i])
		car.visual.free()
		car.visual = replacement
		car.add_child(replacement)
		car.wheels = replacement.get_node("Wheels").get_children()
		car.visual_motion = preload("res://scripts/vehicles/buggy_prototype_motion.gd").new()
		car.visual_motion.configure(car)
		replacement.get_node("DriverNumber").text = "%02d"%(i+1)
	# This proof has no garage/menu transitions: shader materials are prototype-only.
	for action: String in ["menu","restart"]: InputMap.action_erase_events(action)
	for binding: Array in [["p1_go",KEY_W],["p1_brake",KEY_S],["p1_left",KEY_A],["p1_right",KEY_D],["boost",KEY_SPACE],["reset_car",KEY_F],["cycle_camera",KEY_C],["pause_race",KEY_ENTER]]:
		InputMap.action_erase_events(binding[0])
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = binding[1]
		event.device = -1
		InputMap.action_add_event(binding[0],event)
	var controls: Label = Label.new()
	controls.text = "BUGGY PROOF · W/S drive/reverse · A/D steer · SPACE boost · F recover · C camera · F6 colour · ESC close"
	controls.position = Vector2(12,770)
	controls.add_theme_font_size_override("font_size",15)
	race.get_node("HUD").add_child(controls)
	for title: String in ["Retry","Menu"]: race.results_panel.get_node(title).hide()
	race.get_node("Retro").hide()
	ready_to_drive = true
	print("BUGGY_PROTOTYPE_READY: four animated-wheel copies, read-only profile")
	if "--prototype-smoke" in OS.get_cmdline_user_args():
		await physics_frame
		await physics_frame
		assert(race.player_car.wheels.size()==4)
		quit()

func _finalize() -> void:
	race = null

func _process(_delta: float) -> bool:
	if not ready_to_drive: return false
	if Input.is_physical_key_pressed(KEY_ESCAPE):
		quit()
		return false
	if Input.is_physical_key_pressed(KEY_F6):
		if not root.has_meta("colour_held"):
			root.set_meta("colour_held",true)
			colour_index = (colour_index+1)%4
			var meshes: Array[MeshInstance3D] = preload("res://scripts/vehicles/imported_visual.gd").paint_meshes(race.player_car.visual)
			meshes[0].material_override.set_shader_parameter("player_colour",COLOURS[colour_index])
	else: root.remove_meta("colour_held")
	# Stop polling driving input when this dedicated manual test loses focus.
	if DisplayServer.get_name()!="headless" and not DisplayServer.window_is_focused() and race.phase in [1,2,5] and not race.paused_race:
		race.toggle_pause()
	return false
