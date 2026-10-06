extends "res://tests/probes/eight_car_course_survey.gd"
func _enter_tree() -> void:
	super._enter_tree()
	get_tree().node_added.connect(func(node: Node) -> void:
		if node.name=="Track" and node.get_script()==preload("res://showcase_track.gd"):
			node.set_script(preload("res://tests/fixtures/profiled_eight_before.gd") if OS.get_environment("EIGHT_PROFILE_BEFORE")=="1" else preload("res://tests/fixtures/profiled_track.gd"))
		elif node is CharacterBody3D and node.get_script()==preload("res://scripts/vehicles/arcade_car.gd"):
			var player: int = node.player
			var ai: bool = node.ai
			var lane: float = node.lane
			var tuning: Resource = node.tuning
			node.set_script(preload("res://tests/fixtures/profiled_car.gd"))
			node.player = player
			node.ai = ai
			node.lane = lane
			node.tuning = tuning)
func run() -> void:
	Engine.max_fps = 60
	await select_course("moonlight_junk_heap","quick")
	for i: int in range(8): check(race.cars[i].player==i+1 and race.cars[i].ai,"profiled_identity_%d"%i)
	race.track.measurements.clear()
	for car: Node in race.cars: car.measurements.clear()
	report("performance",await sample(900))
	report("route",race.track.measurements)
	var totals: Dictionary = {}
	for car: Node in race.cars:
		for method: String in car.measurements:
			if not totals.has(method): totals[method] = {"calls":0,"usec":0,"max_usec":0}
			totals[method].calls += car.measurements[method].calls
			totals[method].usec += car.measurements[method].usec
			totals[method].max_usec = maxi(totals[method].max_usec,car.measurements[method].max_usec)
	report("cars",totals)
	check(race.cars.size()==8,"eight")
