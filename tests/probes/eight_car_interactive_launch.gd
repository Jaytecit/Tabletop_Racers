extends "res://tests/autopilot/probe_base.gd"
func _enter_tree() -> void:
	super._enter_tree()
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	get_tree().node_added.connect(func(node: Node) -> void:
		if node.name=="Controller":
			node.set_process_input(false)
			node.set_physics_process(false))
func _ready() -> void:
	await super._ready()
	var app: Node = get_tree().current_scene
	var failures: Array = []
	for frame: int in range(600):
		await get_tree().process_frame
		if app.get("ready_for_driver")==true or app.get("startup_error") not in [null,""]: break
	if app.get("ready_for_driver")!=true: failures.append("interactive grid not ready: "+str(app.get("startup_error")))
	var race: Node3D = app.get_node("Race")
	race.controller.device = -1
	report("startup_error",app.get("startup_error"))
	report("phase",race.phase)
	report("rivals",race.rival_count)
	report("course",race.track_id)
	report("human",not race.player_car.ai)
	report("read_only",race.profile.read_only and race.profile_directory.read_only and race.machine_settings.read_only)
	if race.phase!=6 or race.cars.size()!=8 or race.track_id!="moonlight_junk_heap" or race.player_car.ai: failures.append("wrong grid")
	if not race.profile.read_only or not race.profile_directory.read_only: failures.append("personal save protection")
	save_frame("interactive_grid")
	race.begin_countdown()
	race.session.countdown = 0.81
	await settle(5)
	await press("p1_go",800)
	if race.player_car.velocity.length()<0.1: failures.append("human throttle")
	report("failures",failures)
	report("passed",failures.is_empty())
	for voice: Node in app.find_children("*","AudioStreamPlayer",true,false):
		voice.stop()
		voice.stream = null
	await settle(3)
	finish()
