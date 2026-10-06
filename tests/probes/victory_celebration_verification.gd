extends "res://tests/autopilot/probe_base.gd"
var race: Node3D
var checks: Array[bool] = []

func check(key: String, value: bool) -> void:
	checks.append(value)
	report(key,value)

func prepare() -> void:
	race.start_race()
	race.begin_countdown()
	race.session.countdown = 0.8
	race.session.tick(0.05)
	for car: CharacterBody3D in race.cars: car.set_physics_process(false)

func classify(winner: int) -> void:
	for car: CharacterBody3D in race.cars:
		var time: float = 10.0 if car.player==winner else 12.0+car.player
		race.session.progress.mark_finished(car,time)
	race.session.classify()

func _ready() -> void:
	await super._ready()
	await settle(3)
	race = get_tree().current_scene.get_node("Race")
	race.profile.read_only = true
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.device = -1
	race.controller.using_pad = false
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	race.set_physics_process(false)
	race.race_mode = "quick"
	race.rival_count = 3
	race.race_laps = 1
	race.course.select("game_table")
	prepare()
	# Complete a real lap through the session's legal crossing checks.
	for step: int in range(int(race.track.total_length/0.4)+40):
		race.session.tick(0.05)
		for car: CharacterBody3D in race.cars:
			if car.finish_time>=0.0: continue
			car.station = fposmod(car.station+0.4,race.track.total_length)
			car.position = race.track.sample_3d(car.station)
			race.session.observe(car,Vector2(car.station,0.0),0.05)
		if race.phase==3: break
	check("legal_win_results",race.phase==3 and race.session.results[0].player==1)
	var effect: Node3D = race.victory_celebration
	await get_tree().create_timer(0.65).timeout
	await settle(2)
	check("world_emitters_active",effect.emitters.size()==4 and effect.emitters[0].visible)
	check("staggered_screen_bursts",effect.overlay.diagnostic_state().alive>220 and effect.stage>=1)
	save_frame("procedural_win_podium")
	race.show_menu()
	check("menu_clears",effect.elapsed<0.0 and effect.overlay.diagnostic_state().alive==0 and not effect.emitters[0].visible)
	# Imported course exercises height-aware placement and the same results signal.
	check("imported_selected",race.course.select("toys_r_you"))
	prepare()
	classify(1)
	check("world_at_winner_height",effect.global_position.is_equal_approx(race.player_car.global_position+Vector3.UP*0.25))
	await get_tree().create_timer(0.65).timeout
	await settle(2)
	save_frame("imported_win_podium")
	race.results_panel.hide()
	race.banner.hide()
	await settle(2)
	save_frame("imported_world_confetti")
	race.results_panel.show()
	await get_tree().create_timer(4.6).timeout
	check("effect_expires",effect.elapsed<0.0 and effect.overlay.diagnostic_state().alive==0 and not effect.emitters[0].visible)
	prepare()
	classify(2)
	check("loss_no_confetti",effect.elapsed<0.0 and effect.overlay.diagnostic_state().alive==0)
	race.race_mode = "trial"
	prepare()
	classify(1)
	check("trial_no_win_confetti",effect.elapsed<0.0)
	race.race_mode = "quick"
	var nodes: int = race.get_child_count()
	for cycle: int in range(5):
		prepare()
		classify(1)
		await settle()
		check("cycle_%d_active" % cycle,effect.elapsed>=0.0)
		prepare()
		check("cycle_%d_restart_clean" % cycle,effect.elapsed<0.0 and effect.overlay.diagnostic_state().alive==0)
	check("no_emitter_node_growth",race.get_child_count()==nodes and effect.get_child_count()==4)
	report("passed",not checks.has(false))
	finish()
