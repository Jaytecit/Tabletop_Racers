extends "res://tests/autopilot/probe_base.gd"
func _ready() -> void:
	await super._ready()
	await settle(5)
	var race: Node3D = get_tree().current_scene.get_node("Race")
	race.profile.read_only = true
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.device = -1
	race.controller.using_pad = false
	var original_profile: RefCounted = race.profile
	var store: RefCounted = load("res://scripts/profile_store.gd").new()
	store.path = summer_out_dir+"/profile.json"
	store.data = original_profile.data.duplicate(true)
	race.profile = store
	race.controls_setup.config_path = summer_out_dir+"/controls.cfg"
	var setup: Node = race.setup_menu
	setup.open()
	await settle(3)
	save_frame("setup")
	report("setup_focus",get_viewport().gui_get_focus_owner()==setup.resolution and setup.resolution.focus_mode==Control.FOCUS_ALL)
	race.start_race()
	report("blocks_race",race.phase==0)
	store.data.setup.master = 0.65
	store.data.setup.music = 0.25
	store.data.setup.effects = 0.8
	setup.apply_audio()
	report("audio_buses",is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(0)),0.65) and is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))),0.25) and race.music.bus=="Music" and race.engine_sound.bus=="Effects")
	race.play_sound("menu")
	await get_tree().create_timer(0.03).timeout
	report("audio_feedback",race.voices[0].playing or race.voices[1].playing or race.voices[2].playing or race.voices[3].playing)
	setup.set_mute(true)
	report("mute",AudioServer.is_bus_mute(0) and race.muted)
	setup.set_mute(false)
	setup.set_pixels(false)
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_P
	event.pressed = true
	race._unhandled_input(event)
	report("pixels_shortcut",setup.pixels.button_pressed and store.data.setup.pixels and race.get_node("Retro").visible)
	var before: Vector2i = DisplayServer.window_get_size()
	setup.resolution.select(0)
	setup.fullscreen.set_pressed_no_signal(false)
	setup.apply_display()
	await settle(3)
	report("display_applied",DisplayServer.window_get_size()==setup.sizes[0] and not setup.previous_display.is_empty())
	setup.display_timer.timeout.emit()
	await settle(3)
	report("display_auto_revert",DisplayServer.window_get_size()==before and setup.previous_display.is_empty())
	setup.resolution.select(0)
	setup.fullscreen.set_pressed_no_signal(false)
	setup.apply_display()
	setup.confirm_display()
	await settle(3)
	save_frame("setup_960")
	report("display_confirmed",setup.previous_display.is_empty() and store.data.setup.width==setup.sizes[0].x)
	var restored: RefCounted = load("res://scripts/profile_store.gd").new()
	restored.path = store.path
	restored.load_profile()
	report("persisted",restored.data.setup==store.data.setup)
	var legacy: Dictionary = load("res://scripts/profile_store.gd").validate({"schema_version":4})
	report("legacy_defaults",legacy.setup.master==1.0 and legacy.setup.pixels and not legacy.setup.fullscreen)
	setup.close()
	report("focus_restored",race.controls_setup.launch.focus_mode==Control.FOCUS_ALL and get_viewport().gui_get_focus_owner()==race.controls_setup.launch)
	race.controls_setup.open()
	await settle(3)
	save_frame("controls")
	report("controls_access",race.controls_setup.panel.visible and race.controls_setup.rows.cycle_camera.focus_mode==Control.FOCUS_ALL)
	race.controls_setup.close_setup()
	setup.open()
	var close_before: Vector2i = DisplayServer.window_get_size()
	var close_before_mode: int = DisplayServer.window_get_mode()
	setup.resolution.select(setup.sizes.size()-1)
	setup.fullscreen.set_pressed_no_signal(false)
	setup.apply_display()
	await settle(3)
	var close_applied: Vector2i = DisplayServer.window_get_size()
	var close_previous: Dictionary = setup.previous_display.duplicate()
	setup.close()
	await settle(3)
	report("close_display_values",{"before":str(close_before),"applied":str(close_applied),"previous":str(close_previous),"after":str(DisplayServer.window_get_size()),"expected":str(setup.sizes[0])})
	report("close_reverts",DisplayServer.window_get_size()==close_before and DisplayServer.window_get_mode()==close_before_mode and setup.previous_display.is_empty())
	report("passed",_reports.setup_focus and _reports.blocks_race and _reports.audio_buses and _reports.audio_feedback and _reports.mute and _reports.pixels_shortcut and _reports.display_applied and _reports.display_auto_revert and _reports.display_confirmed and _reports.persisted and _reports.legacy_defaults and _reports.focus_restored and _reports.controls_access and _reports.close_reverts)
	finish()
