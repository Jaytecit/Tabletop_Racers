extends "res://tests/autopilot/probe_base.gd"
func _ready() -> void:
	await super._ready()
	await settle(4)
	var race: Node = get_tree().current_scene.get_node("Race")
	race.profile.path = "user://m6a_speed_test.json"
	race.race_mode = "quick"
	race.rival_count = 0
	race.course.select("felt_sprint")
	race.start_race()
	race.session.change_phase(2)
	var car: CharacterBody3D = race.player_car
	car.tuning = car.tuning.duplicate()
	var trials: Array = []
	for multiplier: float in [1.0,1.2,1.3,1.4]:
		car.top_speed = 11.0*multiplier
		for boosted: bool in [false,true]:
			car.reset_car(8.0,0.0)
			Input.action_press("p1_go")
			if boosted: Input.action_press("boost")
			for frame: int in range(75): await get_tree().physics_frame
			var speed: float = Vector2(car.velocity.x,car.velocity.z).length()
			Input.action_release("p1_go")
			Input.action_release("boost")
			var start: Vector3 = car.position
			Input.action_press("p1_brake")
			var ticks: int = 0
			while Vector2(car.velocity.x,car.velocity.z).length()>0.4 and ticks<120:
				await get_tree().physics_frame
				ticks += 1
			Input.action_release("p1_brake")
			trials.append({"multiplier":multiplier,"boost":boosted,"speed":speed,"stop_distance":start.distance_to(car.position),"stop_seconds":ticks/60.0,"crashes":car.crashes})
	report("trials",trials)
	finish()
