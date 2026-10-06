extends "res://tests/autopilot/probe_base.gd"

func _enter_tree() -> void:
	super._enter_tree()
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(func(node: Node) -> void:
		if node.name=="Race" and node.get("profile")!=null: node.profile.path = "res://tests/fixtures/race_quality_read_only.json"
		if node.name=="Sequence" and node.get("hardware_input_isolated")!=null: node.hardware_input_isolated = true)

func _ready() -> void:
	await super._ready()
	await settle(4)
	var app: Node = get_tree().current_scene
	var race: Node3D = app.get_node("Race")
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.using_pad = false
	race.controller.device = -1
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	app.get_node("Opening").queue_free()
	get_tree().paused = false
	race.get_node("HUD").show()
	race.start_race()
	race.begin_countdown()
	race.camera_driver.mode = 0
	var passed: bool = true
	for mode: int in [1,2,0]:
		Input.action_press("cycle_camera")
		await settle_physics(2)
		Input.action_release("cycle_camera")
		await settle(2)
		var intact: bool = is_instance_valid(app) and get_tree().current_scene==app
		report("scene_intact_%d" % mode,intact)
		if not intact:
			passed = false
			break
		var valid: bool = race.phase==1 and race.camera_driver.mode==mode and race.profile.read_only
		report("countdown_mode_%d" % mode,valid)
		passed = passed and valid
		save_frame("countdown_mode_%d" % mode)
	report("passed",passed)
	finish()
