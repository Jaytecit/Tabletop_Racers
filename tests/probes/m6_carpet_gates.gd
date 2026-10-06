extends "res://tests/autopilot/probe_base.gd"
var failures: Array[String] = []
var race: Node
var course_ids: Array[String] = ["carpet_cruise"]

func check(label: String, passed: bool) -> void:
	if not passed: failures.append(label)

func place(car: CharacterBody3D, station: float, lane: float) -> Vector2:
	car.station = fposmod(station,race.track.total_length)
	var direction: Vector2 = race.track.direction(car.station)
	car.position = race.track.sample_3d(car.station)+Vector3(-direction.y,0,direction.x)*lane
	var projected: Dictionary = race.track.project_3d(car.position,car.station)
	car.station = projected.station
	return Vector2(projected.station,projected.distance)

func fixture(car: CharacterBody3D, station: float, lane: float, next_gate: int) -> void:
	race.session.start()
	race.session.countdown = 0.8
	race.session.tick(0.05)
	place(car,station-0.15,lane)
	race.session.progress.rebase(car)
	var record: Dictionary = race.session.progress.records[car.player]
	record.gate = next_gate
	record.legal_station = car.station
	car.gate = next_gate

func _ready() -> void:
	await super._ready()
	await settle(5)
	race = get_tree().current_scene.get_node("Race")
	race.profile.path = "user://m6_gate_test.json"
	race.race_mode = "quick"
	race.rival_count = 3
	race.race_laps = 3
	race.set_physics_process(false)
	race.controller.set_physics_process(false)
	var crossings: int = 0
	for id: String in course_ids:
		if not race.course.select(id):
			failures.append("course_selection_"+race.course.error)
			continue
		for car: CharacterBody3D in race.all_cars: car.set_physics_process(false)
		# All four physical cars use the same rule even though practice UI is solo.
		race.session.configure(race.all_cars,race.track)
		for car: CharacterBody3D in race.all_cars:
			for gate: Dictionary in race.track.gates:
				var expected: int = 8 if gate.index==0 else gate.index
				var lanes: Array = [-3.6,-2.0,0.0,2.0,3.6] if gate.edge=="shoulder" else [-2.0,0.0,2.0]
				for lane: float in lanes:
					fixture(car,gate.station,lane,expected)
					race.session.observe(car,place(car,gate.station+0.15,lane),0.05)
					check("%s_car%d_gate%d_lane%.1f" % [id,car.player,gate.index,lane],car.gate==(1 if gate.index==0 else gate.index+1) and car.laps==(1 if gate.index==0 else 0))
					crossings += 1
				fixture(car,gate.station,0.0,expected)
				place(car,gate.station+0.15,0.0)
				race.session.progress.rebase(car)
				race.session.observe(car,place(car,gate.station-0.15,0.0),0.05)
				check(id+"_reverse_car%d_gate%d" % [car.player,gate.index],car.gate==expected and car.laps==0)
		# Wrong height and guarded shoulders cannot award ordered progress.
		for car: CharacterBody3D in race.all_cars:
			for gate: Dictionary in race.track.gates:
				var expected: int = 8 if gate.index==0 else gate.index
				fixture(car,gate.station,0.0,expected)
				var hit: Vector2 = place(car,gate.station+0.15,0.0)
				car.position.y += -3.2 if gate.position.y>1.0 else 3.2
				race.session.observe(car,hit,0.05)
				check(id+"_wrong_height_car%d_gate%d" % [car.player,gate.index],car.gate==expected and car.laps==0)
				if gate.edge=="guarded":
					for lane: float in [-3.6,3.6]:
						fixture(car,gate.station,lane,expected)
						race.session.observe(car,place(car,gate.station+0.15,lane),0.05)
						check(id+"_guarded_edge_car%d_gate%d" % [car.player,gate.index],car.gate==expected and car.laps==0)
		# Scenery collision shapes must respect the 3.75-unit legal driving band.
		for shape: Node in race.get_node("CourseEnvironment").find_children("*","CollisionShape3D",true,false):
			if shape.shape is ConcavePolygonShape3D or shape.get_parent().get_parent().name=="PlateSupport" or shape.get_parent().name=="FeltTable" or shape.get_parent().get_parent().name in ["BreakfastTable","CarpetFloor"]: continue
			if id=="game_table":
				var art: Node = race.get_node("CourseEnvironment/BlackjackEnvironment")
				if not art.is_ancestor_of(shape) or art.get_node("ChipRampSupport").is_ancestor_of(shape): continue
			if race.get_node("CourseEnvironment").get_node_or_null("CardBridge")!=null and race.get_node("CourseEnvironment/CardBridge").is_ancestor_of(shape): continue
			var radius: float = shape.shape.radius if shape.shape is CylinderShape3D else Vector2(shape.shape.size.x,shape.shape.size.z).length()*0.5
			var point: Vector3 = shape.global_position
			var projected: Dictionary = race.track.project_3d(point)
			check(id+"_prop_clearance_"+str(shape.get_instance_id()),projected.distance-radius>=4.25)
		report(id+"_route_length",race.track.total_length)
	report("legal_gate_crossings",crossings)
	report("failures",failures)
	report("passed",failures.is_empty())
	finish()



