extends "res://tests/autopilot/probe_base.gd"
var failures: Array[String] = []
func check(label: String, passed: bool) -> void:
	report(label,passed)
	if not passed: failures.append(label)
func _ready() -> void:
	await super._ready()
	await settle(5)
	var race: Node = get_tree().current_scene.get_node("Race")
	race.course.select("plate_rim")
	race.start_race()
	race.session.change_phase(2)
	race.controller.set_physics_process(false)
	race.controller.using_pad = false
	for car: Node in race.all_cars: car.set_physics_process(false)
	var car: CharacterBody3D = race.player_car
	car.ai = false
	var presets: Dictionary = car.surface_presets
	check("legacy_neutral",presets.wood.grip==1.0 and presets.paper.drag==1.0 and presets.felt.grip==1.0)
	check("revision",race.track.definition.revision==2)
	var station: float = race.track.lengths[3*24+12]
	var origin: Vector3 = race.track.sample_3d(station)
	var forward: Vector2 = race.track.direction(station)
	var sideways: Vector2 = forward.orthogonal()
	var residuals: Array[float] = []
	for grip: float in [1.0,0.88]:
		presets.ceramic.grip = grip
		car.position = origin
		car.station = station
		car.heading = forward.angle()
		car.state = 0
		car.finish_time = -1.0
		car.airborne = false
		car.immunity = 1.0
		car.velocity = Vector3(forward.x*8.0+sideways.x*3.0,0,forward.y*8.0+sideways.y*3.0)
		car._physics_process(1.0/60.0)
		residuals.append(Vector2(car.velocity.x,car.velocity.z).dot(sideways))
	presets.ceramic.grip = 0.88
	report("lateral_residuals",residuals)
	check("ceramic_reduces_lateral_bite",residuals[1]>residuals[0]+0.02)
	var transitions: int = 0
	for i: int in range(1,race.track.starts.size()):
		var boundary: float = race.track.lengths[i]
		var before: Dictionary = race.track.project_3d(race.track.sample_3d(boundary-0.1),boundary-0.1)
		var after: Dictionary = race.track.project_3d(race.track.sample_3d(boundary+0.1),boundary+0.1)
		if before.surface==after.surface: continue
		transitions += 1
		check("transition_%d_supported"%i,before.supported and after.supported and before.position.distance_to(after.position)<0.3)
		for at: float in [boundary-0.1,boundary+0.1]:
			car.position = race.track.sample_3d(at)
			car.station = at
			car.heading = race.track.direction(at).angle()
			car.velocity = Vector3.ZERO
			car.airborne = false
			car._physics_process(1.0/60.0)
			check("transition_%d_finite_%s"%[i,str(at)],car.position.is_finite() and car.velocity.is_finite() and not car.airborne)
	report("transition_count",transitions)
	check("four_transitions",transitions==4)
	race.show_menu()
	save_frame("ceramic_menu")
	report("failures",failures)
	report("passed",failures.is_empty())
	finish()
