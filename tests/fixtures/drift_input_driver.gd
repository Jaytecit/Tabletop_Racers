extends "res://scripts/vehicles/ai_driver.gd"
# Verification-only deliberate alternating steering. This drives the real car
# through ordinary commands; no position, velocity or scoring state is injected.
func read_commands(car: CharacterBody3D) -> Dictionary:
	var command: Dictionary = super.read_commands(car)
	var track: Node3D = car.track
	var lane: float = (Vector2(car.position.x,car.position.z)-track.sample(car.station)).dot(track.direction(car.station).orthogonal())
	if absf(lane)<2.0 and car.state==0:
		command.steer = clampf(command.steer+0.70*sin(car.race.race_time*2.2),-1.0,1.0)
		command.throttle = 1.0
		command.brake = 0.0
	command.boost = false
	return command
