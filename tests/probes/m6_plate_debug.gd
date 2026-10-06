extends "res://tests/probes/m6_plate_gates.gd"
func _ready() -> void:
	await get_tree().process_frame
	await settle(5)
	race = get_tree().current_scene.get_node("Race")
	race.course.select("plate_rim")
	race.set_physics_process(false)
	for car: CharacterBody3D in race.all_cars: car.set_physics_process(false)
	race.session.configure(race.all_cars,race.track)
	var samples: Array = []
	var car: CharacterBody3D = race.player_car
	for gate: Dictionary in race.track.gates:
		for lane: float in [-3.6,0.0,3.6]:
			var expected: int = 8 if gate.index==0 else gate.index
			fixture(car,gate.station,lane,expected)
			var previous: float = car.station
			var hit: Vector2 = place(car,gate.station+0.15,lane)
			var support: Dictionary = car.physical_support(car.position)
			race.session.observe(car,hit,0.05)
			samples.append({"gate":gate.index,"lane":lane,"delta_before":previous-gate.station,"delta_after":car.station-gate.station,"support_y":support.get("position",Vector3.ZERO).y,"car_y":car.position.y,"passed":car.gate!=expected})
	report("samples",samples)
	finish()
