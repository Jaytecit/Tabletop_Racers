extends "res://tests/autopilot/probe_base.gd"
func _ready() -> void:
	await super._ready()
	for child: Node in get_children():
		if child is Timer: child.ignore_time_scale = true
	await settle(4)
	var race: Node = get_tree().current_scene.get_node("Race")
	race.profile.path = "user://m6a_bridge_debug.json"
	race.race_mode = "quick"
	race.rival_count = 0
	race.race_laps = 1
	race.difficulty = 2
	race.course.select("card_bridge")
	race.player_car.ai = true
	race.start_race()
	Engine.time_scale = 8.0
	Engine.physics_ticks_per_second = 480
	Engine.max_physics_steps_per_frame = 32
	var trace: Array = []
	var car: CharacterBody3D = race.player_car
	for frame: int in range(13000):
		await get_tree().physics_frame
		if frame%120==0:
			trace.append({"time":race.race_time,"station":car.station,"position":str(car.position),"speed":car.velocity.length(),"gate":car.gate,"state":car.state,"laps":car.laps,"record":race.session.progress.records[1].duplicate()})
		if race.phase==3: break
	report("trace",trace)
	report("gates",race.track.gates)
	report("finish",car.finish_time)
	finish()
