extends "res://tests/autopilot/probe_base.gd"

func _enter_tree() -> void:
	super._enter_tree()
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(func(node: Node) -> void:
		if node.name=="Race" and node.get("profile")!=null: node.profile.path = "res://tests/fixtures/race_quality_read_only.json"
		if node.name=="Sequence" and node.get("hardware_input_isolated")!=null: node.hardware_input_isolated = true)

func _ready() -> void:
	await super._ready()
	await settle(5)
	var app: Node = get_tree().current_scene
	var race: Node3D = app.get_node("Race")
	app.get_node("Opening").queue_free()
	get_tree().paused = false
	race.get_node("HUD").show()
	race.profile.read_only = true
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	var flow: RefCounted = race.menu_flow
	var rotation: Node = flow.vehicle_rotation
	flow.show_step(0)
	rotation.reset_transition()
	var selected_vehicle: String = race.player_car.base_tuning.id
	var preferences: String = JSON.stringify(race.profile.data)
	var passed: bool = true
	var start: int = Time.get_ticks_msec()
	save_frame("00_initial")
	for cycle: int in range(1,6):
		while not rotation.fading: await get_tree().process_frame
		var seconds: float = (Time.get_ticks_msec()-start)/1000.0
		var on_time: bool = absf(seconds-cycle*5.0)<0.4
		while flow.vehicle_art.self_modulate.a>0.6: await get_tree().process_frame
		var blended: bool = rotation.incoming.visible and rotation.incoming.self_modulate.a>0.0 and flow.vehicle_art.self_modulate.a>0.0
		flow.refresh()
		passed = passed and on_time and blended and flow.vehicle_art.texture==flow.artwork[(cycle-1)%5]
		if cycle==1:
			await settle(1)
			save_frame("01_crossfade")
		while rotation.fading: await get_tree().process_frame
		await settle(2)
		var changed: bool = flow.vehicle_art.texture==flow.artwork[cycle%5] and flow.vehicle_art.self_modulate.a==1.0 and not rotation.incoming.visible
		passed = passed and changed
		report("cycle_%d" % cycle,{"seconds":seconds,"on_time":on_time,"blended":blended,"changed":changed})
		save_frame("vehicle_%d" % cycle)
	passed = passed and race.player_car.base_tuning.id==selected_vehicle and JSON.stringify(race.profile.data)==preferences
	# Leave during a transition: garage artwork must immediately be fully opaque.
	rotation.elapsed = 4.99
	rotation._process(0.02)
	rotation._process(0.3)
	flow.show_step(2)
	await settle(3)
	var garage_ok: bool = not rotation.active and not rotation.fading and flow.vehicle_art.self_modulate.a==1.0 and flow.vehicle_art.texture==flow.artwork[flow.vehicle] and not rotation.incoming.visible
	passed = passed and garage_ok
	report("garage_transition_cancelled",garage_ok)
	save_frame("garage")
	flow.show_step(0)
	race.menu.hide()
	await settle(3)
	rotation._process(6.0)
	var hidden_ok: bool = not rotation.fading and rotation.elapsed==0.0
	passed = passed and hidden_ok
	report("hidden_menu_stopped",hidden_ok)
	race.menu.show()
	await settle(3)
	passed = passed and not rotation.fading and flow.vehicle_art.self_modulate.a==1.0
	report("passed",passed)
	# Release the MP3 playback before tearing down this disposable renderer.
	race.music.stop()
	await settle(5)
	finish()
