extends "res://tests/autopilot/probe_base.gd"

func _enter_tree() -> void:
	super._enter_tree()
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(func(node: Node) -> void:
		if node.name=="Race":
			node.profile.path = "res://tests/fixtures/opening_read_only.json"
			node.profile_directory.read_only = true
			node.machine_settings.read_only = true
		if node.name=="Sequence": node.hardware_input_isolated = true)

func _ready() -> void:
	await super._ready()
	await settle(4)
	var app: Node = get_tree().current_scene
	var race: Node3D = app.get_node("Race")
	var opening: Control = app.get_node("Opening/Sequence")
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	var samples: Array = []
	var peak: float = 0.0
	for target: float in [2.0,4.0,6.0,10.0,20.0]:
		while opening.elapsed<target: await get_tree().process_frame
		var drift: float = absf(opening.video.stream_position-opening._audio_clock())
		peak = maxf(peak,drift)
		samples.append({"audio":opening._audio_clock(),"video":opening.video.stream_position,"drift":drift})
	report("samples",samples)
	report("peak_drift",peak)
	report("passed",peak<0.15)
	app.queue_free()
	get_tree().paused = false
	await settle(5)
	finish()
