extends "res://tests/autopilot/probe_base.gd"
var failures: Array[String] = []
var race: Node3D
var car: CharacterBody3D
func check(name: String, value: bool) -> void:
	report(name,value)
	if not value: failures.append(name)
func frames(count: int) -> void:
	for i: int in range(count):
		car._physics_process(1.0/60.0)
		await get_tree().physics_frame
func prepare() -> void:
	race.start_race()
	race.session.change_phase(2)
	for other: CharacterBody3D in race.cars:
		if other!=car:
			other.set_physics_process(false)
			other.position = Vector3(100,0,100)
			other.collision_layer = 0
			other.collision_mask = 0
func _ready() -> void:
	await super._ready()
	await settle(2)
	race = get_tree().current_scene.get_node("Race")
	car = race.player_car
	car.set_physics_process(false)
	race.controller.device = -1
	race.controller.using_pad = false
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	prepare()
	car.reset_car(1.0,4.0)
	var forward: Vector2 = race.track.direction(1.0)
	car.velocity = Vector3(forward.x,0,forward.y)*car.top_speed
	report("initial_support",{"floor":not car.physical_support(car.position).is_empty(),"road":race.track.project_3d(car.position,car.station).supported,"position":str(car.position)})
	Input.action_press("p1_go")
	Input.action_press("boost")
	await frames(1)
	var entry_speed: float = Vector2(car.velocity.x,car.velocity.z).length()
	check("progressive_deceleration",entry_speed<car.top_speed and entry_speed>car.top_speed*0.5)
	await frames(90)
	var speed: float = Vector2(car.velocity.x,car.velocity.z).length()
	check("offroad_half_speed_under_throttle",speed<=car.top_speed*0.5+0.05 and speed>car.top_speed*0.45)
	check("offroad_no_crash_or_fall",car.state==0 and car.crashes==0 and not car.airborne)
	check("offroad_boost_disabled",not car.sparks.emitting and car.boost>=99.0)
	report("speeds",{"first_frame":entry_speed,"offroad":speed,"normal_limit":car.top_speed})
	save_frame("shoulder")
	Input.action_release("boost")
	var point: Vector3 = race.track.sample_3d(car.station)
	car.position = point
	race.session.progress.rebase(car)
	await frames(30)
	check("reentry_restores_speed",car.state==0 and Vector2(car.velocity.x,car.velocity.z).length()>car.top_speed*0.65)
	Input.action_release("p1_go")
	# A raised label alone at table height must not cause a fall.
	var table: Resource = race.track.definition
	var low: Resource = table.duplicate(true)
	low.sections[0].edge = "raised"
	race.track.definition = low
	race.track.build()
	prepare()
	car.reset_car(1.0,4.0)
	await frames(3)
	check("low_raised_label_no_fall",car.state==0 and car.crashes==0)
	race.track.definition = table
	race.track.build()
	prepare()
	# The actual table collision/visual extent is the falling boundary.
	var floor_shape: CollisionShape3D = race.get_node("CourseEnvironment/Support/FeltTable").get_child(0)
	var local_edge: Vector3 = Vector3(floor_shape.shape.size.x*0.5+0.2,0.04,0.0)
	car.global_position = floor_shape.to_global(local_edge)
	await frames(1)
	check("table_boundary_falls",car.state==2 and car.crashes==1)
	await frames(25)
	check("table_fall_descends",car.position.y<0.0)
	# Test a genuinely raised bridge even when its edge metadata says shoulder.
	var bridge: Resource = load("res://tracks/bridge_probe/definition.tres").duplicate(true)
	bridge.sections[0].edge = "shoulder"
	race.track.definition = bridge
	race.track.build()
	prepare()
	var upper: float = race.track.project_3d(Vector3(0,2.4,0)).station
	car.reset_car(upper,3.2)
	await frames(1)
	check("actual_bridge_height_falls",car.state==2)
	race.track.definition = table
	race.track.build()
	race.show_menu()
	report("failures",failures)
	report("passed",failures.is_empty())
	finish()
