extends "res://tests/autopilot/probe_base.gd"
var failures: Array[String] = []
var race: Node
var car: CharacterBody3D

func check(name: String, value: bool) -> void:
	report(name,value)
	if not value: failures.append(name)

func prepare(definition: Resource) -> void:
	race.track.definition = definition
	race.track.build()
	if race.track.validation_errors.is_empty(): race.track.rebuild_art()
	race.start_race()
	race.session.countdown = 0.8
	race.session.tick(0.05)
	if not race.track.validation_errors.is_empty(): return
	for other: CharacterBody3D in race.cars:
		other.set_physics_process(false)
		other.velocity = Vector3.ZERO
		other.position += Vector3(30,0,30)
	car.reset_car(1.0,0.0)
	race.session.progress.rebase(car)

func place(station: float, offset: float = 0.0) -> void:
	car.reset_car(station,offset)
	race.session.progress.rebase(car)
	race.session.progress.records[car.player].legal_station = station

func tick(frames: int) -> void:
	for i: int in range(frames):
		car._physics_process(1.0/60.0)
		await get_tree().physics_frame

func returned(name: String, gate: int, laps: int) -> void:
	for i: int in range(240):
		await tick(1)
		if car.state==0: break
	check(name,car.state==0 and car.gate==gate and car.laps==laps and not car.airborne and car.lift_speed==0.0 and car.ramp_velocity==0.0)
	report(name+"_state",{"state":car.state,"gate":car.gate,"laps":car.laps,"airborne":car.airborne,"lift":car.lift_speed,"ramp":car.ramp_velocity})
	check(name+"_ghost",car.immunity>0.0 and car.collision_layer==0)

func _ready() -> void:
	await super._ready()
	await settle(2)
	race = get_tree().current_scene.get_node("Race")
	race.profile.path = "user://track_elevation_test.json"
	race.race_mode = "quick"
	race.rival_count = 3
	race.course.select("game_table")
	car = race.player_car
	race.set_physics_process(false)
	race.controller.set_physics_process(false)
	var table: Resource = load("res://tracks/game_table/definition.tres")
	var bridge: Resource = load("res://tracks/bridge_probe/definition.tres")
	var Validator = preload("res://scripts/tracks/track_validator.gd")
	check("table_valid",Validator.validate(table).is_empty())
	check("bridge_valid",Validator.validate(bridge).is_empty())
	var bad: Resource = table.duplicate(true)
	bad.sections.clear()
	check("empty_rejected",not Validator.validate(bad).is_empty())
	for field: String in ["width","surface","next_id","start","anchor"]:
		bad = table.duplicate(true)
		match field:
			"width": bad.sections[0].width = -1.0
			"surface": bad.sections[0].surface = "unknown"
			"next_id": bad.sections[0].next_id = "missing"
			"start": bad.sections[0].start.x = NAN
			"anchor":
				for section: Resource in bad.sections: section.anchor = false
		check(field+"_rejected",not Validator.validate(bad).is_empty())
	bad = bridge.duplicate(true)
	bad.sections[0].start.y = 0.4
	bad.sections[0].end.y = 0.4
	check("crossing_clearance_rejected",not Validator.validate(bad).is_empty())
	bad = table.duplicate(true)
	for section: Resource in bad.sections: section.anchor = false
	bad.sections[0].anchor = true
	race.track.definition = bad
	race.track.build()
	check("unreachable_anchors_rejected",not race.track.validation_errors.is_empty())
	prepare(table)
	check("generated_route",race.track.gates.size()==8 and race.track.anchors.size()>20 and race.track.has_node("Generated/ChalkBoundaries") and race.track.has_node("Generated/WoodDeck"))
	# A recovery behind a passed gate must preserve it when that gate is re-crossed.
	var gate_station: float = race.track.gates[2].station
	place(gate_station-0.10)
	race.session.progress.records[1].gate = 3
	car.gate = 3
	car.station = gate_station+0.10
	car.position = race.track.sample_3d(car.station)
	race.session.observe(car,Vector2(car.station,0.0),0.05)
	check("passed_gate_survives_reentry",car.gate==3 and car.laps==0)
	prepare(table)
	# Outer ruler lane shares the same authored height and slope as its road art.
	place(race.track.lengths[24]+0.2,2.6)
	await tick(1)
	var sample: Dictionary = race.track.at(car.station)
	check("ruler_outer_lane",car.state==0 and absf(car.position.y-sample.position.y)<0.04 and sample.normal.y<1.0)
	place(race.track.lengths[24]+0.2)
	car.ai = true
	var launched: bool = false
	var landed: bool = false
	for frame: int in range(240):
		await tick(1)
		if car.airborne: launched = true
		if launched and not car.airborne:
			landed = true
			break
	check("jump_landing",launched and landed and car.jumps==1 and car.state==0 and car.lift_speed==0.0)
	car.ai = false
	place(1.0,2.6)
	await tick(20)
	check("inside_width_safe",car.state==0)
	place(1.0,3.2)
	await tick(5)
	check("shoulder_grace",car.state==0 and car.shoulder_time>0.0)
	await tick(15)
	check("shoulder_slowdown",car.state==0 and Vector2(car.velocity.x,car.velocity.z).length()<=car.top_speed*0.5+0.01)
	car.crash(false)
	await returned("shoulder_manual_return",1,0)
	# Manual reset uses the actual input command and the same recovery path.
	place(1.0)
	var manual_gate: int = race.session.progress.records[1].gate
	var manual_laps: int = race.session.progress.records[1].laps
	car.set_physics_process(true)
	await press("reset_car")
	car.set_physics_process(false)
	check("manual_reset",car.state==1)
	await returned("manual_return",manual_gate,manual_laps)
	# A water section on a ground-car route must trigger recovery.
	bad = table.duplicate(true)
	bad.sections[3].surface = "water"
	bad.sections[3].anchor = false
	prepare(bad)
	place(race.track.lengths[3*24]+1.0)
	await tick(1)
	check("water_hazard",car.state==1)
	await returned("water_return",1,0)
	prepare(bridge)
	var upper: float = race.track.project_3d(Vector3(0,2.4,0)).station
	var lower: float = race.track.project_3d(Vector3.ZERO).station
	var high: Dictionary = race.track.project_3d(Vector3(0,2.4,0),upper)
	var low: Dictionary = race.track.project_3d(Vector3.ZERO,lower)
	check("stacked_projection",high.layer==1 and low.layer==0 and absf(high.position.y-2.4)<0.001 and absf(low.position.y)<0.001 and absf(high.station-low.station)>10.0)
	# The station window must keep the chosen route even at the wrong height.
	check("no_layer_trade",race.track.project_3d(Vector3.ZERO,upper).layer==1 and race.track.project_3d(Vector3(0,2.4,0),lower).layer==0)
	place(upper)
	car.position.y = 0.0
	var record: Dictionary = race.session.progress.records[1]
	var old_distance: float = record.distance
	race.session.observe(car,Vector2(upper,0.0),0.05)
	check("wrong_height_no_progress",record.distance==old_distance and car.gate==1)
	# Actual collision bodies pass beneath a bridge, but collide on its deck.
	var other: CharacterBody3D = race.cars[1]
	place(upper-1.5)
	car.collision_mask = 2
	other.position = Vector3(0,0,0)
	other.collision_layer = 2
	await get_tree().physics_frame
	var under: KinematicCollision3D = car.move_and_collide(Vector3(2.0,0,0))
	check("different_layers_no_collision",under==null)
	place(upper-1.5)
	car.collision_mask = 2
	other.position = Vector3(0,2.4,0)
	await get_tree().physics_frame
	var same: KinematicCollision3D = car.move_and_collide(Vector3(2.0,0,0))
	check("same_layer_collision",same!=null and same.get_collider()==other)
	other.position += Vector3(30,0,30)
	place(upper,3.2)
	await tick(1)
	check("raised_edge_fall",car.state==2)
	await tick(20)
	check("fall_descends",car.position.y<2.4)
	await returned("raised_return",1,0)
	# Occupy every lane of the nearest anchor; selection must move farther back.
	place(upper)
	for i: int in range(1,4):
		race.cars[i].position = Vector3(0,2.4,float(i-2))
	var anchor: Dictionary = preload("res://scripts/race/race_recovery.gd").select_anchor(car)
	check("landing_avoids_occupancy",not anchor.is_empty() and fposmod(upper-anchor.station,race.track.total_length)>0.0 and not preload("res://scripts/race/race_recovery.gd").occupied(car,anchor.position))
	car.crash(true)
	await returned("occupied_return",1,0)
	# Ghost remains active while another car overlaps at expiry.
	other.position = car.position
	car.immunity = 0.01
	await tick(1)
	check("ghost_overlap_safe",car.immunity>0.0 and car.collision_layer==0 and car.collision_mask==1)
	other.position += Vector3(30,0,30)
	await tick(8)
	check("ghost_reenables_collision",car.immunity==0.0 and car.collision_layer==2 and car.collision_mask==3)
	# If every available landing lane is blocked, hold safely until space clears.
	place(upper)
	var saved_anchors: Array[Dictionary] = race.track.anchors.duplicate()
	var only_anchor: Dictionary = race.track.at(floor(upper))
	only_anchor.station = floor(upper)
	race.track.anchors.assign([only_anchor])
	var tangent: Vector2 = race.track.direction(only_anchor.station)
	for i: int in range(1,4):
		race.cars[i].position = only_anchor.position+Vector3(-tangent.y,0,tangent.x)*float(i-2)
	car.crash(true)
	await tick(140)
	check("blocked_landing_waits",car.state==3 and not car.recovery_target_valid and car.collision_layer==0 and car.gate==1 and car.laps==0)
	for i: int in range(1,4): race.cars[i].position += Vector3(30,0,30)
	race.track.anchors = saved_anchors
	await returned("unblocked_return",1,0)
	race.camera.position = Vector3(10,24,20)
	race.camera.look_at(Vector3.ZERO)
	race.camera.size = 32.0
	await settle(2)
	save_frame("bridge_layers")
	# Invalid data is rejected by the real session before grid/sample calls.
	bad = table.duplicate(true)
	bad.sections.clear()
	prepare(bad)
	check("invalid_track_safe_failure",race.phase==4 and race.session.progress.records.is_empty() and race.banner.text.contains("TRACK UNAVAILABLE"))
	prepare(table)
	check("valid_track_recovers_menu",race.phase==2 and car.position.is_finite())
	report("failures",failures)
	report("passed",failures.is_empty())
	finish()
