extends "res://tests/autopilot/probe_base.gd"

func _enter_tree() -> void:
	super._enter_tree()
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(func(node: Node) -> void:
		if node.name=="Sequence": node.hardware_input_isolated = true)

func _ready() -> void:
	await super._ready()
	await settle(2)
	var app: Node = get_tree().current_scene
	var race: Node3D = app.get_node("Race")
	race.profile.read_only = true
	race.machine_settings.read_only = true
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	var sequence: Control = app.get_node("Opening/Sequence")
	report("studio_first",sequence.studio_active and not race.music.playing and not sequence.video.is_playing() and not sequence.skip_button.visible)
	save_frame("fade_from_black")
	while sequence.studio_elapsed<2.0: await get_tree().process_frame
	save_frame("jaylabs_playing")
	while sequence.studio_hold_elapsed<0.0: await get_tree().process_frame
	report("actual_video_finished",sequence.studio_finished_at>4.9 and sequence.studio_finished_at<5.6)
	while sequence.studio_hold_elapsed<1.5: await get_tree().process_frame
	report("holds_last_frame",sequence.studio_active and is_equal_approx(sequence.studio_visibility(),1.0) and not race.music.playing)
	save_frame("last_frame_hold")
	while sequence.studio_hold_elapsed<3.25: await get_tree().process_frame
	report("fade_after_three_seconds",sequence.studio_active and sequence.studio_visibility()<0.8 and sequence.studio_visibility()>0.3)
	save_frame("studio_fades_out")
	while sequence.studio_active: await get_tree().process_frame
	report("intro_starts_after_hold_and_fade",sequence.studio_hold_elapsed>=3.6 and race.music.playing and sequence.video.is_playing() and sequence.elapsed<0.1)
	await get_tree().create_timer(0.2,true).timeout
	save_frame("intro_fades_in")
	var timing_ok: bool = sequence.studio_finished_at>4.9 and sequence.studio_finished_at<5.6 and sequence.studio_hold_elapsed>=3.6 and race.music.playing and sequence.video.is_playing()
	sequence.timeline_offset = sequence.PROMPT_TIME+1.0-sequence._audio_clock()
	await settle(3)
	await press("start_race",40)
	for i: int in range(120):
		if race.profile_menu.visible: break
		await get_tree().process_frame
	report("profile_flow_retained",race.profile_menu.visible and not get_tree().paused)
	save_frame("profiles_after_intro")
	report("passed",timing_ok and race.profile_menu.visible and not get_tree().paused)
	race.set_physics_process(false)
	for car: CharacterBody3D in race.all_cars: car.set_physics_process(false)
	for player: Node in app.find_children("*","AudioStreamPlayer",true,false):
		player.stop()
		player.stream = null
	get_tree().paused = false
	await settle(3)
	call_deferred("finish")
