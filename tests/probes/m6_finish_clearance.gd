extends "res://tests/probes/race_rules.gd"
func advance_car(car: CharacterBody3D, amount: float, delta: float = 0.05) -> void:
	super.advance_car(car,amount,delta)
	if car.finish_time >= 0.0:
		check("finish_collision_clear",car.collision_layer==0 and car.collision_mask==0)
		for other: CharacterBody3D in race.cars:
			if other==car or other.finish_time>=0.0: continue
			var saved: Vector3 = other.position
			other.position = car.position
			check("finished_car_not_recovery_obstacle",not preload("res://scripts/race/race_recovery.gd").occupied(other,car.position))
			other.position = saved
			break
