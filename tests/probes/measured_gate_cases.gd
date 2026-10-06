extends RefCounted
# Cross measured planes directly. A route-relative lateral offset changes its
# plane position at sharp bends and is not a valid crossing fixture there.
static func run(race: Node3D) -> Dictionary:
	race.show_menu()
	race.session.configure(race.all_cars,race.track)
	var failures: Array = []
	var checks: int = 0
	for car: CharacterBody3D in race.all_cars: car.set_physics_process(false)
	for car: CharacterBody3D in race.all_cars:
		for gate: Dictionary in race.track.gates:
			var edges: Array[Vector3] = preload("res://scripts/tracks/imported_checkpoint_flags.gd").plane_edges(race.track,gate)
			if edges.size()!=2:
				failures.append({"gate":gate.index,"error":"missing plane edges"})
				continue
			var heading: Vector2 = race.track.direction(gate.station)
			var forward: Vector3 = Vector3(heading.x,0,heading.y)
			for mode: String in ["forward","reverse","wrong_height","repeat","skip"]:
				for across: float in [0.1,0.5,0.9]:
					var crossing: Vector3 = edges[0].lerp(edges[1],across)
					var direction: float = -1.0 if mode=="reverse" else 1.0
					var expected: int = race.track.gates.size() if gate.index==0 else int(gate.index)
					car.reset_car(gate.station-0.15*direction,0.0)
					car.position = crossing-forward*0.15*direction
					race.session.progress.reset(race.all_cars,race.track.total_length)
					var record: Dictionary = race.session.progress.records[car.player]
					record.gate = expected
					if mode=="skip": record.gate = 1 if expected!=1 else 2
					if mode=="repeat": record.gate = expected+1
					car.gate = record.gate
					var before_gate: int = car.gate
					car.position = crossing+forward*0.15*direction
					if mode=="wrong_height": car.position.y -= 3.0
					var projected: Dictionary = race.track.project_3d(car.position,gate.station)
					var result: Dictionary = race.session.progress.observe(car,Vector2(projected.station,projected.distance),0.05,1.0)
					var passed: bool = car.gate==(1 if gate.index==0 else expected+1) if mode=="forward" else car.gate==before_gate and not result.has("lap")
					checks += 1
					if not passed: failures.append({"gate":gate.index,"car":car.player,"mode":mode,"across":across,"crossing":str(crossing),"projected":projected,"result":result})
	for car: CharacterBody3D in race.all_cars: car.set_physics_process(true)
	race.show_menu()
	return {"checks":checks,"failures":failures}
