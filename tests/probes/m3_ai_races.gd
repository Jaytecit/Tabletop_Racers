extends "res://tests/autopilot/probe_base.gd"
func _ready() -> void:
	await super._ready()
	await settle(2)
	var race: Node = get_tree().current_scene.get_node("Race")
	race.profile.path = "user://m3_ai_races_test.json"
	race.race_mode = "quick"
	race.rival_count = 3
	race.course.select("game_table")
	for child: Node in get_children():
		if child is Timer: child.ignore_time_scale = true
	Engine.time_scale = 8.0
	Engine.physics_ticks_per_second = 480
	Engine.max_physics_steps_per_frame = 32
	race.player_car.ai = true
	var runs: Array[Dictionary] = []
	var passed: bool = true
	for run: int in range(20):
		race.difficulty = run%3
		race.race_seed = 1000+run
		race.start_race()
		for frame: int in range(13000):
			await get_tree().physics_frame
			if race.phase==3: break
		var stats: Array[Dictionary] = []
		var complete: bool = race.phase==3 and race.session.results.size()==4
		for car: CharacterBody3D in race.cars:
			complete = complete and car.finish_time>=0.0
			stats.append({"player":car.player,"time":car.finish_time,"crashes":car.crashes,"impacts":car.impacts,"recoveries":car.ai_driver.recoveries,"passing_decisions":car.ai_driver.passes})
		runs.append({"seed":race.race_seed,"difficulty":race.difficulty,"complete":complete,"cars":stats})
		report("runs",runs)
		passed = passed and complete
		if run in [0,1,2,19]:
			await settle()
			save_frame("finish_%02d"%run)
	report("runs",runs)
	report("passed",passed)
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	race.show_menu()
	await settle(2)
	save_frame("menu")
	finish()
