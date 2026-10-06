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
	var race: Node3D = get_tree().current_scene.get_node("Race")
	get_tree().current_scene.get_node("Opening").queue_free()
	get_tree().paused = false
	race.get_node("HUD").show()
	race.profile.read_only = true
	race.controller.device = -1
	race.controller.using_pad = false
	race.race_mode = "quick"
	await settle(3)
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	var song: AudioStream = race.MENU_MUSIC
	report("menu_song",race.music.stream==song and race.music.playing and not song.loop)
	report("menu_full_length",absf(song.get_length()-180.035875)<0.05)
	report("music_bus",race.music.bus=="Music")
	race.music.seek(10.0)
	race.menu_flow.show_step(1)
	race.setup_menu.open()
	await settle(3)
	race.setup_menu.close()
	race.show_menu()
	await settle(3)
	report("menu_refresh_continues",race.music.stream==song and race.music.get_playback_position()>=10.0)
	# Switch the actual course while in the menu: cleanup must not restart music.
	var catalog: Script = preload("res://scripts/tracks/content_catalog.gd")
	var other: String = "topspeed_oval" if race.track_id=="game_table" else "game_table"
	race.menu.get_node("TrackSelect").item_selected.emit(catalog.IDS.find(other))
	for frame: int in range(900):
		await settle(1)
		if not race.course.loading: break
	report("course_switch_continues",race.track_id==other and race.music.stream==song and race.music.get_playback_position()>=10.0)
	# Seek into the natural ending and observe real completion, not a fake signal.
	var completions: Array[int] = [0]
	race.music.finished.connect(func() -> void: completions[0]+=1)
	race.music.seek(song.get_length()-0.4)
	await get_tree().create_timer(1.0).timeout
	report("menu_replays_after_silence",completions[0]==1 and race.music.playing and race.music.get_playback_position()<2.0)
	race.show_menu()
	await settle(3)
	report("menu_replay_continues",race.music.playing and race.music.stream==song)
	race.difficulty = 1
	race.start_race()
	await settle(3)
	report("race_music",race.music.stream!=song and race.music.stream.loop and race.music.playing)
	report("course_source",race.selected_race_music().resource_path==race.SOUNDTRACK.path_for_course(race.track_id))
	race.music.seek(race.music.stream.get_length()-0.3)
	await get_tree().create_timer(0.8).timeout
	report("course_loop_wraps",race.music.playing and race.music.get_playback_position()<2.0 and completions[0]==1)
	var active_music: AudioStream = race.music.stream
	race.final_lap_music = race.hard_music
	race.on_lap_completed(race.player_car,race.session.laps_required-1)
	report("final_lap_keeps_course_song",race.music.stream==active_music)
	race.begin_countdown()
	race.toggle_pause()
	report("race_music_pauses",race.music.stream_paused)
	race.show_menu()
	await settle(3)
	report("return_restarts_menu_song",race.music.stream==song and race.music.playing and not race.music.stream_paused and race.music.get_playback_position()<2.0)
	var course_song: AudioStream = race.selected_race_music()
	var tracks: Array[AudioStream] = [course_song,course_song,course_song,course_song]
	for level: int in range(4):
		race.difficulty = level
		race.start_race()
		await settle(3)
		report("difficulty_%d_track" % level,race.selected_race_music()==tracks[level] and race.music.stream.get_class()==tracks[level].get_class() and absf(race.music.stream.get_length()-tracks[level].get_length())<0.05 and race.music.stream.loop and race.music.playing)
		race.music.seek(race.music.stream.get_length()-0.3)
		await get_tree().create_timer(0.8).timeout
		report("difficulty_%d_wrap" % level,race.music.playing and race.music.get_playback_position()<2.0)
		race.begin_countdown()
		race.toggle_pause()
		report("difficulty_%d_pause" % level,race.music.stream_paused)
		race.show_menu()
		await settle(3)
		report("difficulty_%d_return_menu" % level,race.music.stream==song and race.music.playing and not race.music.stream_paused)
	report("hard_source",race.hard_music.resource_path=="res://audio/music/hard_jungle.mp3" and absf(race.hard_music.get_length()-120.032625)<0.05)
	report("nightmare_full_length",absf(race.NIGHTMARE_MUSIC.get_length()-120.032625)<0.05)
	# Exercise every catalogue mapping through the actual selector and player,
	# without changing or loading unrelated scenery. Restore the real course ID.
	var current_id: String = race.track_id
	for id: String in catalog.IDS:
		race.track_id = id
		var source: AudioStream = race.selected_race_music()
		report(id+"_mapping",source.resource_path==race.SOUNDTRACK.TRACKS[id] and source.get_length()>100.0)
		for level: int in range(4):
			race.difficulty = level
			report(id+"_difficulty_%d" % level,race.selected_race_music()==source)
		race.music.stream = race.looped_music(source)
		race.music.play()
		race.music.seek(source.get_length()-0.3)
		await get_tree().create_timer(0.8).timeout
		report(id+"_loop",race.music.playing and race.music.get_playback_position()<2.0 and race.music.stream.loop and not source.loop)
	race.track_id = current_id
	var water: AudioStream = load(race.SOUNDTRACK.WATER_MUSIC)
	race.music.stream = race.looped_music(water)
	race.music.play()
	await settle(3)
	report("water_ready",water.resource_path.ends_with("Wake Velocity.mp3") and water.get_length()>100.0 and race.music.playing and race.music.stream.loop)
	report("water_not_registered",not "WATER" in catalog.CLASSIFICATION.values().map(func(value: Dictionary) -> String: return value.group))
	race.show_menu()
	await settle(3)
	race.start_race()
	await settle(3)
	save_frame("course_music_race")
	race.show_menu()
	race.setup_menu.set_mute(true)
	report("menu_mute",AudioServer.is_bus_mute(0))
	race.setup_menu.set_mute(false)
	report("menu_unmute",not AudioServer.is_bus_mute(0))
	var passed: bool = true
	for value: Variant in _reports.values(): passed = passed and value==true
	report("passed",passed)
	for player: Node in get_tree().current_scene.find_children("*","AudioStreamPlayer",true,false):
		player.stop()
		player.stream = null
	await settle_physics(10)
	finish()
