extends Node
# Live verification helper. Does not change handling or save player progression.
var evidence: Dictionary = {}
var race: Node3D

func _ready() -> void:
	race = get_parent()
	race.profile.read_only = true

func support_report() -> Dictionary:
	var failures: Array = []
	var obstacle_hits: Array = []
	var checks: int = 0
	var space: PhysicsDirectSpaceState3D = race.get_world_3d().direct_space_state
	for station: int in range(0,int(race.track.total_length),2):
		var data: Dictionary = race.track.at(float(station))
		var direction: Vector2 = race.track.direction(float(station))
		for lateral: float in [0.0,-data.width*0.5+0.55,data.width*0.5-0.55]:
			var p: Vector3 = data.position+Vector3(-direction.y,0,direction.x)*lateral
			var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p+Vector3.UP*0.6,p-Vector3.UP*1.0,1)
			var hit: Dictionary = space.intersect_ray(query)
			checks += 1
			if hit.is_empty():
				failures.append({"station":station,"lane":lateral,"point":str(p)})
			elif absf(hit.position.y-p.y)>0.16:
				obstacle_hits.append({"station":station,"lane":lateral,"expected":p.y,"actual":hit.position.y,"node":str(hit.collider.name)})
	evidence.support = {"checks":checks,"missing":failures,"height_mismatch":obstacle_hits}
	return evidence.support

func start_test(difficulty: int = 1, laps: int = 1) -> void:
	race.race_mode = "quick"
	race.rival_count = 3
	race.race_laps = laps
	race.difficulty = difficulty
	race.race_seed = 3096+difficulty
	race.start_race()
	race.player_car.ai = true
	race.begin_countdown()

func snapshot() -> Dictionary:
	var cars: Array = []
	for car: CharacterBody3D in race.cars:
		cars.append({"player":car.player,"station":car.station,"position":str(car.position),"laps":car.laps,"finish":car.finish_time,"crashes":car.crashes,"impacts":car.impacts,"recoveries":car.ai_driver.recoveries,"gate":car.gate,"state":car.state,"penalty":race.session.progress.records[car.player].penalty})
	evidence.state = {"phase":race.phase,"time":race.race_time,"cars":cars,"results":race.session.results.size(),"validation":race.track.validation_errors}
	return evidence.state

func overview() -> void:
	race.show_menu()
	race.menu.hide()
	race.banner.hide()
	race.get_node("HUD").hide()
	for car: Node3D in race.all_cars: car.hide()
	race.camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	race.camera.fov = 65
	race.camera.far = 700
	race.camera.position = Vector3(100,65,140)
	race.camera.look_at(Vector3(-5,-15,0))
	for mesh: MeshInstance3D in race.camera_driver.occluders:
		mesh.transparency = 0.0
		if mesh.get_meta("overview_hide",false): mesh.visible = false
	for mesh: Node in race.get_node("CourseEnvironment/RoomArchitecture").get_children():
		if mesh is MeshInstance3D and (mesh.name=="FrontWall" or str(mesh.name).begins_with("SideWall")):
			mesh.visible = false

func pose_car(station: float, lateral: float = 0.0) -> void:
	race.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	race.camera.size = 14
	race.get_node("HUD").show()
	race.menu.hide()
	for car: Node3D in race.all_cars: car.show()
	race.player_car.reset_car(station,lateral)
	race.camera_driver.reset(race.camera,race.player_car)
	race.camera.look_at(race.player_car.position)

func height_grid() -> Dictionary:
	var result: Dictionary = {}
	var space: PhysicsDirectSpaceState3D = race.get_world_3d().direct_space_state
	for z: float in [-45,-35,-25,-15,0,15,25,35,45]:
		var row: Array = []
		for x: float in [-110,-90,-70,-50,-30,-10,10,30,50,70,90,105]:
			var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(x,25,z),Vector3(x,-15,z),1)
			var hit: Dictionary = space.intersect_ray(query)
			if hit.is_empty(): row.append(null)
			else: row.append(snappedf(hit.position.y,0.01))
		result[str(z)] = row
	return result

func performance_report() -> Dictionary:
	return {"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"triangles":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"static_memory_mb":Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0}

func bridge_station() -> float:
	for i: int in range(race.track.starts.size()):
		if race.track.section_ids[i]==11: return race.track.lengths[i]+12.0
	return 0.0

func restore_preferences() -> void:
	race.rival_count = 1
	race.race_laps = 3
	race.difficulty = 1
	race.profile.read_only = false
	race.save_preferences()
	race.profile.read_only = true
