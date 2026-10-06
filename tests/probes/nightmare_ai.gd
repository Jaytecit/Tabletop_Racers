extends "res://tests/autopilot/probe_base.gd"
var course_id: String = "blackjack"
var failures: Array[String] = []
func check(label: String, value: bool) -> void:
	report(label,value)
	if not value: failures.append(label)
func _ready() -> void:
	await super._ready()
	await settle(3)
	var race: Node = get_tree().current_scene.get_node("Race")
	race.profile.path = "user://nightmare_ai_test.json"
	race.race_mode = "quick"
	race.course.select(course_id)
	race.menu.get_node("QuickRace/Difficulty").item_selected.emit(3)
	check("menu_and_save",race.profile.load_profile().quick_race.difficulty==3 and race.rival_count==3)
	check("nightmare_record_key",race.profile.valid_record_key(race.profile.record_key("quick",3,3,3)))
	race.race_laps = 1
	race.player_car.ai = true
	for child: Node in get_children():
		if child is Timer: child.ignore_time_scale = true
	Engine.time_scale = 8.0
	Engine.physics_ticks_per_second = 480
	Engine.max_physics_steps_per_frame = 32
	var runs: Array[Dictionary] = []
	for level: int in range(4):
		race.difficulty = level
		race.rival_count = 0 if level==3 else 3
		race.race_seed = 3100+level
		race.start_race()
		check("car_count_%d"%level,race.cars.size()==4)
		if level==3:
			check("two_attackers_one_runner",race.cars[1].ai_driver.is_attacker(race.cars[1]) and race.cars[2].ai_driver.is_attacker(race.cars[2]) and not race.cars[3].ai_driver.is_attacker(race.cars[3]))
		for frame: int in range(11000):
			await get_tree().physics_frame
			if race.phase==3: break
		var stats: Array[Dictionary] = []
		for car: CharacterBody3D in race.cars:
			stats.append({"player":car.player,"time":car.finish_time,"attacks":car.ai_driver.attack_decisions,"recoveries":car.ai_driver.recoveries,"impacts":car.impacts})
		check("finish_%d"%level,race.session.results.size()==4)
		if level==3: check("attackers_engaged",race.cars[1].ai_driver.attack_decisions>0 and race.cars[2].ai_driver.attack_decisions>0 and race.cars[3].ai_driver.attack_decisions==0)
		runs.append({"difficulty":level,"cars":stats})
		await settle()
		save_frame("difficulty_%d"%level)
	report("runs",runs)
	report("failures",failures)
	report("passed",failures.is_empty())
	finish()
