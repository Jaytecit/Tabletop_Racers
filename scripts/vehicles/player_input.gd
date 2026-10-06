extends RefCounted
# Shared command fields: throttle, brake, steer, boost, reset_requested.
func read_commands(car: CharacterBody3D) -> Dictionary:
	var steer: float = clampf(Input.get_axis("p1_left","p1_right")+Input.get_axis("p2_left","p2_right"),-1.0,1.0)
	var throttle: float = clampf(Input.get_axis("p1_brake","p1_go")+Input.get_axis("p2_brake","p2_go"),-1.0,1.0)
	if car.race.controller.using_pad:
		steer = car.race.controller.steering()
		throttle = car.race.controller.throttle()
	return {"throttle":maxf(throttle,0.0),"brake":maxf(-throttle,0.0),"steer":steer,
		"boost":(Input.is_action_pressed("boost") or car.race.controller.boost_pressed()) and (car.boost>2.0 or car.tuning.boost_drain==0.0) and throttle>0.0,
		"reset_requested":Input.is_action_just_pressed("reset_car")}
