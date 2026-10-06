extends "res://tests/autopilot/probe_base.gd"
var failures: Array[String] = []
func check(value: bool, label: String) -> void:
	if not value: failures.append(label)
func _ready() -> void:
	await settle(5)
	var race: Node3D = get_tree().current_scene.get_node("Race")
	race.profile.read_only = true
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.using_pad = false
	race.controller.device = -1
	race.profile_selected = true
	race.profile_menu.hide()
	race.show_menu()
	var store: Script = load("res://scripts/profile_store.gd")
	var old: Dictionary = store.defaults()
	old.schema_version = 14
	old.vehicles.buggy.points = 7
	old.vehicles.racing_car.points = 11
	old.vehicles.buggy.bling = 130
	old.vehicles.racing_car.bling = 80
	var migrated: Dictionary = store.validate(old)
	check(migrated.wallet=={"points":18,"bling":210},"historical wallet migration")
	check(store.validate(migrated).wallet==migrated.wallet,"migration does not duplicate balance")
	race.profile.data = migrated
	race.menu_flow.show_step(0)
	check(not race.menu.has_node("ChangeProfile"),"profile removed from home")
	check(race.menu.get_node("Copyright").text.contains("2.22.23"),"version footer")
	race.menu.get_node("Quit").pressed.emit()
	await settle(2)
	check(race.menu_flow.quit_dialog.visible,"quit confirmation opens")
	save_frame("quit_confirmation")
	race.menu_flow.quit_dialog.get_cancel_button().pressed.emit()
	race.menu_flow.quit_dialog.hide()
	race.setup_menu.open()
	await settle(2)
	var change: Button = race.setup_menu.panel.find_child("ChangeProfile",true,false)
	check(change.is_visible_in_tree(),"profile available in setup")
	check(change.get_global_rect().end.y<=race.setup_menu.panel.get_global_rect().end.y,"setup button fits")
	save_frame("setup")
	change.pressed.emit()
	check(race.profile_menu.visible and not race.setup_menu.panel.visible,"profile opens from setup")
	race.profile_menu.hide()
	race.show_menu()
	race.menu_flow.show_step(0)
	await settle(2)
	save_frame("main_menu")
	race.rewards_awarded = false
	race.stats_test_mode = 0
	race.award_race_rewards([{"player":1,"finished":true,"rank":1}])
	check(race.profile.wallet().points==19,"race rewards go to driver")
	race.profile.data.quick_race.vehicle_id = "racing_car"
	check(race.profile.wallet().points==19,"balance survives vehicle switch")
	check(load("res://scripts/vehicles/vehicle_progression.gd").purchase(race.profile.vehicle(),1,race.profile.wallet()),"paint uses driver bling")
	check(race.profile.wallet().bling==120,"paint debits shared wallet")
	race.stats_menu.open()
	race.stats_menu.adjust("grip",1)
	race.stats_menu.apply()
	check(race.profile.wallet().points==18,"upgrade debits driver wallet")
	check(store.validate(race.profile.data).wallet==race.profile.wallet(),"driver wallet survives validation")
	var other: RefCounted = store.new()
	check(other.wallet().points==0,"different driver remains independent")
	race.profile.data.quick_race.vehicle_id = race.player_car.base_tuning.id
	race.start_race()
	race.begin_countdown()
	race.session.change_phase(2)
	for car: Node in race.all_cars: car.set_physics_process(false)
	var d: Vector2 = race.track.direction(race.player_car.station)
	race.player_car.velocity = Vector3(-d.x*3,0,-d.y*3)
	race.update_wrong_way(0.7)
	check(race.wrong_way_notice.visible,"reverse travel warns")
	await settle(2)
	save_frame("wrong_way")
	race.player_car.velocity *= -1
	race.update_wrong_way(0.1)
	check(not race.wrong_way_notice.visible,"forward travel clears warning")
	race.player_car.velocity = Vector3.ZERO
	race.update_wrong_way(1.0)
	check(not race.wrong_way_notice.visible,"stationary car does not warn")
	for voice: AudioStreamPlayer in race.voices: voice.stop()
	race.on_gate_warning(race.player_car,false)
	race.on_lap_completed(race.player_car,1)
	race._physics_process(0.05)
	check(is_equal_approx(race.music.volume_db,race.MUSIC_VOLUME_DB),"notification does not duck music")
	var silent: bool = true
	for voice: AudioStreamPlayer in race.voices: silent = silent and not voice.playing
	check(silent,"race notices play no cue")
	race.session.classify()
	await settle(3)
	check(race.results_panel.has_node("CourseSelect"),"course selection result action")
	save_frame("results")
	race.results_panel.get_node("CourseSelect").pressed.emit()
	check(race.phase==0 and race.menu_flow.step==3 and race.menu.visible,"results to course selection")
	await settle(2)
	save_frame("course_selection")
	race.session.change_phase(3)
	race.show_menu()
	check(race.phase==0 and race.menu_flow.step==0,"results to main menu")
	report("failures",failures)
	report("passed",failures.is_empty())
	finish()
