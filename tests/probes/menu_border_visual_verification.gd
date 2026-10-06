extends "res://tests/autopilot/probe_base.gd"

func _ready() -> void:
	await super._ready()
	await settle(5)
	var app: Node = get_tree().current_scene
	var race: Node3D = app.get_node("Race")
	race.profile.read_only = true
	race.machine_settings.read_only = true
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.device = -1
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	var opening: Node = app.get_node("Opening/Sequence")
	opening.hardware_input_isolated = true
	report("removed_intro_caption",opening.ACTIONS[0].is_empty())
	await settle(3)
	save_frame("intro_no_caption")
	opening._restore_menu()
	app.get_node("Opening").queue_free()
	get_tree().paused = false
	race.get_node("HUD").show()
	race.profile_menu.hide()
	race.profile_selected = true
	race.show_menu()
	race.menu_flow.show_step(0)
	await settle(4)
	var flow: RefCounted = race.menu_flow
	var heading_bottom: float = flow.heading.position.y+flow.heading.size.y
	var setup_top: float = race.controls_setup.launch.position.y
	var frame_centre: float = flow.option_frame.position.y+flow.option_frame.size.y*0.5
	report("centred_group",is_equal_approx(frame_centre,(heading_bottom+setup_top)*0.5))
	report("noninteractive_borders",flow.option_frame.mouse_filter==Control.MOUSE_FILTER_IGNORE and flow.preview_frame.mouse_filter==Control.MOUSE_FILTER_IGNORE)
	save_frame("option_borders")
	race.profile.data.identity = {"name":"JAY","portrait_id":2}
	race.profile.vehicle().points = 7
	race.profile.vehicle().stats.grip = 0.5
	race.profile.data.cup_wins = 2
	race.profile.data.tournament_wins = 1
	flow.choose_mode("quick")
	await settle(4)
	var page: Control = flow.driver_stats
	var saved_face: AtlasTexture = page.portrait.texture
	var stats_ok: bool = page.visible and page.driver_name.text=="JAY" and saved_face.region==Rect2(0,128,128,128) and page.bars.grip.value==10 and page.budget.text.begins_with("7 AVAILABLE") and not race.menu.get_node("DriverCards").visible
	report("saved_driver_stats",stats_ok)
	report("stats_next_focus",flow.next.has_focus())
	save_frame("jay_player_stats")
	var previous_level: float = page.bars.speed.value
	race.stats_test_mode = 0
	race.stats_menu.open()
	race.stats_menu.adjust("speed",1)
	race.stats_menu.apply()
	await settle(3)
	var upgrade_ok: bool = page.bars.speed.value==previous_level+1 and page.budget.text.begins_with("6 AVAILABLE")
	report("upgrade_refresh",upgrade_ok)
	var bios_fit: bool = true
	for portrait_id: int in range(4):
		race.profile.data.identity = {"name":"Charlotte","portrait_id":portrait_id}
		page.refresh()
		await settle(2)
		bios_fit = bios_fit and page.bio.get_minimum_size().y<=106 and page.driver_name.text=="CHARLOTTE"
	report("all_portrait_bios_fit",bios_fit)
	flow.advance()
	report("assigned_mode_skips_garage",flow.step==3)
	flow.go_back()
	report("course_back_returns_stats",flow.step==1 and page.visible)
	flow.choose_mode("freestyle")
	flow.advance()
	report("freestyle_keeps_garage",flow.step==2)
	race.race_mode = "freestyle"
	flow.show_step(2)
	await settle(4)
	save_frame("garage_preview_border")
	flow.show_step(3)
	await settle(4)
	save_frame("course_preview_border")
	race.race_mode = "tournament"
	race.profile.data.tournament = race.tournament.RULES.fresh("toybox",2)
	flow.show_step(3)
	await settle(4)
	var abandon: Button = race.tournament.abandon
	var footer_clear: bool = abandon.visible and not abandon.get_rect().intersects(race.menu.get_node("Start").get_rect()) and not abandon.get_rect().intersects(flow.back.get_rect())
	report("tournament_footer_clear",footer_clear)
	save_frame("tournament_footer")
	report("passed",footer_clear and stats_ok and upgrade_ok and bios_fit and is_equal_approx(frame_centre,(heading_bottom+setup_top)*0.5) and flow.preview_frame.visible)
	race.set_physics_process(false)
	for car: CharacterBody3D in race.all_cars: car.set_physics_process(false)
	for audio: Node in app.find_children("*","AudioStreamPlayer",true,false):
		audio.stop()
		audio.stream = null
	await settle(3)
	call_deferred("finish")
