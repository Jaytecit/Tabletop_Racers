extends "res://tests/autopilot/probe_base.gd"

var failures: Array[String] = []

func _enter_tree() -> void:
	super._enter_tree()
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(func(node: Node) -> void:
		if node.name == "Race" and node.get("profile") != null:
			node.profile.path = "res://tests/fixtures/opening_read_only.json"
			node.profile_directory.read_only = true
			node.machine_settings.read_only = true
		if node.name == "Sequence": node.hardware_input_isolated = true)

func check(condition: bool, key: String) -> void:
	report(key, condition)
	if not condition: failures.append(key)

func _ready() -> void:
	await super._ready()
	await settle(4)
	var app: Node = get_tree().current_scene
	var race: Node3D = app.get_node("Race")
	var opening: Control = app.get_node("Opening/Sequence")
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.device = -1
	race.controller.using_pad = false
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	race.machine_settings.data.merge({"mute":false,"master":1.0,"music":1.0,"effects":1.0},true)
	race.setup_menu.apply_audio()
	check(race.profile.read_only and race.machine_settings.read_only and race.profile_directory.read_only, "read_only_profiles")
	check(get_tree().paused and not race.get_node("HUD").visible, "opening_isolates_menu")
	check(opening.video.is_playing() and opening.video.volume_db <= -80.0, "silent_blended_video_playing")
	check(race.music.stream == race.OPENING_MUSIC and race.music.playing and race.music.bus == "Music", "single_shared_intro_music")
	check(absf(race.OPENING_MUSIC.get_length()-187.633)<0.08, "approved_mix_duration")
	check(absf(race.MENU_MUSIC.get_length()-184.033)<0.08, "theme_menu_duration")
	await wait_time(opening, 1.0)
	save_frame("01_jaylabs")
	var first: PackedByteArray = opening.video.get_video_texture().get_image().get_data()
	await wait_time(opening, 4.0)
	save_frame("02_jaylabs_theme_blend")
	check(opening.video.get_video_texture().get_image().get_data()!=first, "decoder_frames_advance")
	await wait_time(opening, 5.0)
	check(opening.skip_button.visible and not opening.start_button.visible, "skip_after_blend")
	for cue: Array in [[33.0,"03_tunnel"],[45.0,"04_speedboat"],[51.0,"05_monster"],[130.5,"06_overhead"]]:
		await wait_time(opening, float(cue[0]))
		var drift: float = absf(opening.video.stream_position-opening._audio_clock())
		report(str(cue[1])+"_clock_drift",drift)
		check(drift<0.30,str(cue[1])+"_synced_to_theme")
		save_frame(str(cue[1]))
	report("video_sync_corrections",opening.video_sync_corrections)
	check(opening.video.is_playing() and opening.impact_count==0, "full_montage_without_early_thud")
	await wait_time(opening, opening.LOGO_TIME+0.1)
	check(not opening.video.is_playing() and opening.impact_count==0, "title_reveal_before_thud")
	save_frame("07_title_before_not")
	await wait_time(opening, opening.NOT_TIME+0.08)
	check(opening.impact_count==1 and opening.impact.playing and opening.impact.bus=="Effects", "not_landing_plays_one_effects_thud")
	check(absf(opening.not_hit_time-opening.NOT_TIME)<0.1, "thud_within_100ms_of_landing")
	report("thud_seconds",opening.not_hit_time)
	report("effects_peak_db",AudioServer.get_bus_peak_volume_left_db(AudioServer.get_bus_index("Effects"),0))
	save_frame("08_not_landing")
	await wait_time(opening, opening.PROMPT_TIME+0.15)
	check(opening.start_button.visible and opening.impact_count==1, "wait_for_start_no_repeat_thud")
	var before: float = race.music.get_playback_position()
	input_action("ui_accept",true)
	await get_tree().create_timer(0.5,true).timeout
	check(opening.leaving and get_tree().paused, "held_start_isolated")
	input_action("ui_accept",false)
	await settle(5)
	check(not app.has_node("Opening") and not get_tree().paused and race.profile_menu.visible, "start_opens_profiles")
	check(race.music.stream==race.OPENING_MUSIC and race.music.get_playback_position()>before, "theme_continues_into_profiles")
	race.profile_menu.hide()
	race.show_menu()
	await settle(3)
	check(race.music.stream==race.OPENING_MUSIC and race.music.playing, "menu_refresh_preserves_intro_tail")
	race.music.seek(race.OPENING_MUSIC.get_length()-0.25)
	await get_tree().create_timer(0.8,true).timeout
	check(race.music.stream==race.MENU_MUSIC and race.music.playing and race.music.get_playback_position()<2.0, "menu_repeats_theme_without_rocket")
	# Exercise skip through real input, without seeking or restarting shared audio.
	app.play_opening()
	await settle(3)
	opening = app.get_node("Opening/Sequence")
	await wait_time(opening, 4.5)
	before = race.music.get_playback_position()
	input_action("ui_cancel",true)
	input_action("ui_cancel",false)
	await wait_time(opening, opening.PROMPT_TIME+0.1)
	check(opening.impact_count==1 and race.music.get_playback_position()<before+5.0, "skip_keeps_song_position_and_thud")
	DisplayServer.window_set_size(Vector2i(1280,720))
	await settle(3)
	check(opening.get_global_rect().encloses(opening.start_button.get_global_rect()), "start_fits_720p")
	save_frame("09_skip_title_720p")
	pad_start(true)
	await get_tree().create_timer(0.5,true).timeout
	check(opening.leaving and get_tree().paused, "controller_held_start_isolated")
	pad_start(false)
	await settle(5)
	check(not app.has_node("Opening") and not get_tree().paused, "controller_start_enters_profiles")
	race.profile_menu.hide()
	# Existing Town Square: verify its assigned song through real race playback.
	race.race_mode = "quick"
	race.profile_selected = true # Existing read-only verification fixture only.
	race.difficulty = 2
	race.course.select("town_square")
	await settle(5)
	check(race.track_id=="town_square" and race.course.error.is_empty(), "town_square_selected")
	check(race.SOUNDTRACK.path_for_course("town_square")=="res://audio/music/menu_pulsing.mp3", "town_square_old_menu_song")
	race.start_race()
	await settle(4)
	check(race.music.playing and race.music.stream.loop and absf(race.music.stream.get_length()-race.selected_race_music().get_length())<0.05, "town_square_song_playing_looped")
	race.music.seek(race.music.stream.get_length()-0.2)
	await get_tree().create_timer(0.7,true).timeout
	check(race.music.playing and race.music.get_playback_position()<2.0, "town_square_song_wraps")
	race.show_menu()
	await settle(4)
	check(race.music.stream==race.MENU_MUSIC and race.music.playing, "race_return_uses_theme_menu")
	save_frame("10_theme_menu_after_town_square")
	race.setup_menu.set_mute(true)
	check(race.muted and AudioServer.is_bus_mute(0), "master_mute_retained")
	race.setup_menu.set_mute(false)
	check(not race.muted and not AudioServer.is_bus_mute(0), "master_unmute_retained")
	report("failures",failures)
	report("passed",failures.is_empty())
	for player: Node in app.find_children("*","AudioStreamPlayer",true,false):
		player.stop()
		player.stream = null
	get_tree().paused = false
	app.queue_free()
	await settle(5)
	finish()

func wait_time(opening: Control, target: float) -> void:
	while is_instance_valid(opening) and opening.elapsed<target:
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
	event.set_meta("opening_test_input",true)
	Input.parse_input_event(event)

