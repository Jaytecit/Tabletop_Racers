extends "res://tests/autopilot/probe_base.gd"
func _ready() -> void:
	await super._ready()
	await settle(4)
	var race: Node3D = get_tree().current_scene.get_node("Race")
	race.profile.path = "user://roulette_verification.json"
	race.profile.read_only = true
	race.race_mode = "quick"
	race.course.select("game_table")
	race.rival_count = 3
	race.race_laps = 1
	var helper: Node = load("res://tests/probes/roulette_live.gd").new()
	helper.name = "RouletteProof"
	race.add_child(helper)
	var support: Dictionary = helper.support_report()
	report("support",support)
	await settle(3)
	save_frame("01_roulette_menu")
	race.menu.get_node("Start").pressed.emit()
	await settle(2)
	save_frame("02_course_orbit")
	await key(KEY_ENTER,50)
	for i: int in range(210): await get_tree().physics_frame
	race.player_car.ai = false
	race.controller.using_pad = false
	var before: Vector3 = race.player_car.position
	var before_frame: int = Engine.get_physics_frames()
	await press("p1_go",500)
	for i: int in range(2): await get_tree().physics_frame
	var moved: float = before.distance_to(race.player_car.position)
	report("player_input",{"before_frame":before_frame,"after_frame":Engine.get_physics_frames(),"distance":moved,"phase":race.phase})
	save_frame("03_player_driving")
	var station: float = helper.bridge_station()
	helper.pose_car(station)
	race.player_car.ai = false
	race.session.progress.reset(race.cars,race.track.total_length)
	for i: int in range(3): await get_tree().physics_frame
	var edge_before: Dictionary = {"state":race.player_car.state,"position":str(race.player_car.position),"frame":Engine.get_physics_frames()}
	save_frame("04_exposed_bridge")
	var d: Vector2 = race.track.direction(station)
	race.player_car.position += Vector3(-d.y,0,d.x)*3.5
	for i: int in range(3): await get_tree().physics_frame
	var fell: bool = race.player_car.state==2
	report("fall",{"before":edge_before,"after":{"state":race.player_car.state,"position":str(race.player_car.position),"frame":Engine.get_physics_frames()},"passed":fell})
	save_frame("05_bridge_fall")
	for i: int in range(170): await get_tree().physics_frame
	var recovered: bool = race.player_car.state==0 and absf(race.player_car.position.y-8.0)<0.2
	report("recovery",{"passed":recovered,"state":race.player_car.state,"position":str(race.player_car.position),"station":race.player_car.station,"laps":race.player_car.laps})
	save_frame("06_bridge_recovery")
	var gate_before: int = race.player_car.gate
	var laps_before: int = race.player_car.laps
	race.player_car.position = race.track.sample_3d(station+race.track.total_length*0.4)
	for i: int in range(2): await get_tree().physics_frame
	var shortcut_blocked: bool = race.player_car.laps==laps_before and race.player_car.gate==gate_before
	report("shortcut_blocked",shortcut_blocked)
	helper.overview()
	await settle(4)
	save_frame("07_casino_room")
	report("render",helper.performance_report())
	report("passed",support.missing.is_empty() and support.height_mismatch.is_empty() and moved>0.2 and fell and recovered and shortcut_blocked)
	finish()
