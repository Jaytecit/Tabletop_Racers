extends "res://tests/probes/eight_car_course_survey.gd"
func run() -> void:
	race.race_mode = "quick"
	race.show_menu()
	race.menu_flow.show_step(0)
	check(race.menu_flow.eight_car_button.is_visible_in_tree(),"shortcut_visible")
	save_frame("eight_shortcut")
	race.menu_flow.eight_car_button.pressed.emit()
	await settle(3)
	while race.course.loading: await get_tree().process_frame
	await settle(5)
	check(race.track_id=="moonlight_junk_heap" and race.rival_count==7 and race.difficulty==2 and race.race_laps==3,"shortcut_setup")
	check(race.menu_flow.step==3 and race.cars.size()==8 and race.player_car.base_tuning.id=="buggy","shortcut_grid")
	check(not race.player_car.ai,"human_player")
	save_frame("eight_course_setup")
	race.start_race()
	race.begin_countdown()
	race.session.countdown = 0.81
	await settle(5)
	await press("p1_go",800)
	check(race.player_car.velocity.length()>0.1,"human_input")
	check(race.get_node("HUD/RaceMinimap").position.y>=race.get_node("HUD/Standings").position.y+160.0,"eight_hud_clearance")
	race.all_cars[7].crash(false)
	for tick: int in range(420):
		await get_tree().physics_frame
		if race.all_cars[7].state==0: break
	check(race.all_cars[7].state==0,"eighth_car_recovers_in_traffic")
	race.toggle_pause()
	race.toggle_pause()
	var raw: Dictionary = race.profile.data.duplicate(true)
	raw.quick_race.rivals = 7
	check(race.profile.validate(raw).quick_race.rivals==7,"saved_seven_rivals")
	race.show_menu()
	race.difficulty = 3
	race.configure_quick_race()
	check(race.cars.size()==8,"nightmare_keeps_eight")
	race.rival_count = 3
	race.show_menu()
	check(race.cars.size()==4 and race.all_cars[7].collision_layer==0,"four_car_return")
	race.difficulty = 2
	race.rival_count = 0
	race.show_menu()
	check(race.cars.size()==1,"solo_return")
	var rows: Array = []
	for i: int in range(8): rows.append({"player":i+1,"rank":i+1,"time":100.0+i,"finished":true,"penalty":0.0})
	preload("res://scripts/race/arcade_podium.gd").show_results(race,rows)
	for i: int in range(8):
		var tile: Control = race.results_panel.get_node("Podium/Place%d"%(i+1))
		check(tile.position.y+tile.size.y<=258.0,"result_bounds_%d"%i)
