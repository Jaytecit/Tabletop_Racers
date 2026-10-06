extends "res://tests/autopilot/probe_base.gd"

var race: Node3D
var failures: Array[String] = []

func _enter_tree() -> void:
	super._enter_tree()
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_isolate)

func _isolate(node: Node) -> void:
	if node.name == "Race" and node.get("profile") != null:
		node.profile.path = "res://tests/fixtures/opening_read_only.json"
	if node.name == "Sequence" and node.get("hardware_input_isolated") != null:
		node.hardware_input_isolated = true

func check(condition: bool, message: String) -> void:
	report(message, condition)
	if not condition: failures.append(message)

func _ready() -> void:
	await super._ready()
	await settle(4)
	var app: Node = get_tree().current_scene
	race = app.get_node("Race")
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.device = -1
	race.controller.using_pad = false
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	var opening: Control = app.get_node("Opening/Sequence")
	check(race.profile.read_only, "read_only_profile")
	check(get_tree().paused and not race.get_node("HUD").visible, "startup_isolated_from_menu")
	check(race.music.playing and opening.music == race.music, "one_shared_music_player")
	var stream_id: int = race.music.stream.get_instance_id()
	var player_id: int = race.music.get_instance_id()
	check(opening.video.is_playing(), "video_playback_started")
	check(opening.video.volume_db <= -80.0, "video_audio_muted")
	await wait_time(opening, 0.8)
	var first_video_frame: PackedByteArray = opening.video.get_video_texture().get_image().get_data()
	await wait_time(opening, 1.5)
	check(opening.video.get_video_texture().get_image().get_data() != first_video_frame, "video_frames_advance")
	save_frame("01_world_reveal")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/video/opening/video-manifest.json"))
	check(absf(opening.LOGO_TIME - 45.03) < 0.001, "logo_authored_on_drop_at_45_03")
	check(manifest.scene_beats.size() == opening.SHOT_BEATS.size(), "montage_and_cards_share_cue_count")
	for i: int in range(opening.SHOT_BEATS.size()):
		check(float(manifest.scene_beats[i]) == opening.SHOT_BEATS[i], "montage_card_cue_%d_matches" % i)
		check(opening.shot_index(opening.SHOT_BEATS[i]) == i, "shot_boundary_%d_selects_correct_card" % i)
	for cue: Array in [[10.5, "01b_world_buggy_crossfade"], [13.0, "02_buggy"],
		[20.5, "02b_buggy_truck_crossfade"], [23.0, "03_monster_truck"],
		[30.5, "03b_truck_drift_crossfade"], [33.0, "04_drift"],
		[40.5, "04b_drift_formula_crossfade"], [43.0, "05_overtake"],
		[50.5, "05b_formula_boat_crossfade"], [53.0, "06_speedboat"],
		[61.5, "07_roxy_card"], [64.5, "08_bea_card"],
		[67.5, "09_finn_card"], [70.5, "10_kit_card"],
		[75.0, "11_stunt"], [85.0, "12_charge"],
		[92.4, "13_callback_truck"], [93.4, "14_callback_drift"],
		[94.4, "15_callback_boat"], [95.4, "16_callback_charge"]]:
		await wait_time(opening, opening.FIRST_BEAT + float(cue[0]) * opening.BEAT)
		save_frame(str(cue[1]))
	await wait_time(opening, opening.LOGO_TIME - 0.12)
	save_frame("17_pre_drop_dip")
	report("pre_drop_capture_seconds", opening.elapsed)
	check(opening.logo_hit_time < 0.0 and opening.video.is_playing(), "montage_reaches_drop_without_early_title")
	await wait_time(opening, opening.LOGO_TIME + 0.02)
	save_frame("18_logo_impact")
	check(opening.logo_hit_time - opening.LOGO_TIME < 0.08, "logo_hits_audio_drop_within_80ms")
	check(opening.impact.playing, "main_logo_impact_audio_playing")
	check(is_zero_approx(opening.title_music_duck), "drop_music_not_ducked_by_main_logo")
	report("logo_hit_seconds", opening.logo_hit_time)
	report("audio_at_logo_capture", opening._audio_clock())
	await wait_time(opening, opening.LOGO_TIME + 0.8)
	save_frame("19_title_without_not")
	check(opening.logo_hit_time >= opening.LOGO_TIME and opening.not_hit_time < 0, "main_title_first")
	check(not opening.video.is_playing(), "video_stopped_at_title")
	check(not opening.skip_button.visible, "skip_hidden_during_title_reveal")
	await wait_time(opening, opening.NOT_TIME + 0.14)
	save_frame("07_not_impact")
	check(absf(opening.not_hit_time - opening.logo_hit_time - 1.875) < 0.08, "not_lands_four_beats_later")
	check(opening.impact.playing, "impact_audio_playing")
	report("impact_bus_peak_db", AudioServer.get_bus_peak_volume_left_db(AudioServer.get_bus_index("Effects"), 0))
	await wait_time(opening, opening.PROMPT_TIME + 0.4)
	save_frame("08_press_start")
	check(opening.start_button.visible and get_tree().paused and race.phase == 0, "waits_for_start")
	var position_before: float = race.music.get_playback_position()
	await get_tree().create_timer(0.6, true).timeout
	check(is_instance_valid(opening) and not opening.leaving, "title_does_not_auto_enter_menu")
	# A held start fades out, then waits for release so it cannot select a menu item.
	input_action("ui_accept", true)
	await get_tree().create_timer(0.5, true).timeout
	check(opening.leaving and get_tree().paused, "held_start_consumed")
	input_action("ui_accept", false)
	await settle(5)
	check(not app.has_node("Opening") and not get_tree().paused, "start_enters_menu")
	check(race.get_node("HUD").visible and race.menu_flow.step == 0 and race.phase == 0, "menu_restored_without_accidental_selection")
	check(race.music.get_instance_id() == player_id and race.music.stream.get_instance_id() == stream_id, "music_identity_preserved")
	check(race.music.get_playback_position() > position_before + 0.8, "music_continues_without_restart")
	save_frame("09_menu_continuity")
	# Replay solely in this disposable test to prove the skip path independently.
	app.play_opening()
	await settle(3)
	opening = app.get_node("Opening/Sequence")
	var before_skip: float = race.music.get_playback_position()
	input_action("ui_cancel", true)
	input_action("ui_cancel", false)
	await get_tree().create_timer(0.6, true).timeout
	check(opening.elapsed >= opening.LOGO_TIME and opening.elapsed < opening.NOT_TIME, "skip_reaches_title_on_next_beat")
	check(race.music.get_playback_position() < before_skip + 1.0, "skip_does_not_seek_music")
	await wait_time(opening, opening.PROMPT_TIME + 0.1)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await settle(4)
	save_frame("10_title_720p")
	check(opening.get_global_rect().encloses(opening.start_button.get_global_rect()), "start_button_fits_720p")
	DisplayServer.window_set_size(Vector2i(1600, 720))
	await settle(4)
	save_frame("11_title_ultrawide")
	check(opening.get_global_rect().encloses(opening.start_button.get_global_rect()), "start_button_fits_ultrawide")
	# The visible pointer button routes through exactly the same Start transition.
	opening.start_button.pressed.emit()
	await get_tree().create_timer(0.5, true).timeout
	await settle(3)
	check(not app.has_node("Opening") and race.menu_flow.step == 0, "pointer_start_enters_menu")
	# A real controller Start button is separate from the standard A/ui_accept map.
	app.play_opening()
	await settle(3)
	opening = app.get_node("Opening/Sequence")
	pad_start(true)
	pad_start(false)
	await wait_time(opening, opening.PROMPT_TIME + 0.1)
	pad_start(true)
	await get_tree().create_timer(0.5, true).timeout
	check(opening.leaving and get_tree().paused, "controller_start_held_consumed")
	pad_start(false)
	await settle(5)
	check(not app.has_node("Opening") and race.menu_flow.step == 0, "controller_start_enters_menu")
	race.menu_flow.home.get_node("Quick").grab_focus()
	input_action("ui_accept", true)
	input_action("ui_accept", false)
	await settle(3)
	check(race.menu_flow.step == 1, "menu_accept_works_after_opening")
	report("failures", failures)
	report("passed", failures.is_empty())
	for player: Node in app.find_children("*", "AudioStreamPlayer", true, false): player.stop()
	await settle(3)
	finish()

func wait_time(opening: Control, target: float) -> void:
	while is_instance_valid(opening) and opening.elapsed < target:
		await get_tree().process_frame
	await settle(2)

func input_action(action: StringName, down: bool) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = down
	Input.parse_input_event(event)

func pad_start(down: bool) -> void:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.device = 0
	event.button_index = JOY_BUTTON_START
	event.pressed = down
	event.set_meta("opening_test_input", true)
	Input.parse_input_event(event)
