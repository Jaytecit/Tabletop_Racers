extends "res://tests/autopilot/probe_base.gd"
func _ready() -> void:
	await super._ready()
	await settle(5)
	var race: Node = get_tree().current_scene.get_node("Race")
	race.controller.set_physics_process(false)
	race.controller.set_process_input(false)
	race.controller.device = -1
	race.controller.using_pad = false
	race.profile.path = "user://m6_toybox_jump.json"
	race.profile.read_only = true
	race.race_mode = "quick"
	race.rival_count = 0
	race.course.select("toybox_trestle")
	var launch: float = 0.0
	for i: int in range(int(race.track.total_length)):
		if race.track.at(float(i)).section==5:
			launch = float(i)
			break
	var runs: Array = []
	var passed: bool = launch>0.0
	for lane: float in [-2,0,2]:
		race.start_race()
		race.session.countdown = 0.8
		race.session.tick(0.05)
		var car: CharacterBody3D = race.player_car
		var station: float = launch-8.0
		var direction: Vector2 = race.track.direction(station)
		car.position = race.track.sample_3d(station)+Vector3(-direction.y,0,direction.x)*lane
		car.station = station
		car.heading = direction.angle()
		car.velocity = Vector3(direction.x,0,direction.y)*16.0
		car.previous_ground = car.position.y
		race.session.progress.rebase(car)
		race.camera_driver.reset(race.camera,car)
		var airborne_frames: int = 0
		var max_height: float = car.position.y
		Input.action_press("p1_go")
		for frame: int in range(100):
			await get_tree().physics_frame
			max_height = maxf(max_height,car.position.y)
			if car.airborne:
				airborne_frames += 1
				if lane==0 and airborne_frames==8: save_frame("toybox_airborne")
		Input.action_release("p1_go")
		var clean: bool = airborne_frames>5 and car.jumps==1 and not car.airborne and car.crashes==0 and car.position.x>75.0 and absf(car.position.y-2.2)<0.1
		passed = passed and clean
		runs.append({"lane":lane,"passed":clean,"airborne_frames":airborne_frames,"max_height":max_height,"jumps":car.jumps,"crashes":car.crashes,"landing":car.position})
		if lane==0: save_frame("toybox_landing")
	report("runs",runs)
	report("passed",passed)
	finish()
