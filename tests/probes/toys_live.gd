extends "res://tests/probes/roulette_live.gd"
func select_course(id: String = "toys_r_you") -> Dictionary:
	race.profile.read_only = true
	race.race_mode = "quick"
	return {"selected":race.course.select(id),"error":race.course.error}
func overview() -> void:
	race.show_menu()
	race.menu.hide()
	race.banner.hide()
	race.get_node("HUD").hide()
	for car: Node3D in race.all_cars: car.hide()
	race.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	race.camera.size = 132
	race.camera.far = 400
	race.camera.position = Vector3(0,200,0)
	race.camera.rotation_degrees = Vector3(-90,0,0)
func race_view() -> void:
	race.get_node("HUD").show()
	for car: Node3D in race.all_cars: car.show()
	race.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	race.camera_driver.reset(race.camera,race.player_car)
func support_report() -> Dictionary:
	var failures: Array = []
	var checks: int = 0
	var space: PhysicsDirectSpaceState3D = race.get_world_3d().direct_space_state
	for station: int in range(0,int(race.track.total_length),2):
		var data: Dictionary = race.track.at(float(station))
		var direction: Vector2 = race.track.direction(float(station))
		for lateral: float in [0.0,-1.5,1.5]:
			var p: Vector3 = data.position+Vector3(-direction.y,0,direction.x)*lateral
			var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p+Vector3.UP*0.5,p-Vector3.UP*1.0,1)
			var hit: Dictionary = space.intersect_ray(query)
			checks += 1
			if hit.is_empty() or absf(hit.position.y-p.y)>0.5:
				failures.append({"station":station,"lane":lateral,"expected":p.y,"actual":hit.position.y if not hit.is_empty() else -999.0})
	return {"checks":checks,"failures":failures}
func player_control() -> void:
	race.player_car.ai = false
func countdown() -> void:
	race.begin_countdown()

func release_to_user() -> void:
	race.player_car.ai = false
	race.show_menu()
	race.profile.read_only = false
	queue_free()

func inputs(action: String, seconds: float = 0.5) -> void:
	if not InputMap.has_action(action): return
	Input.action_press(action)
	await get_tree().create_timer(seconds).timeout
	Input.action_release(action)

func gate_checks() -> Dictionary:
	race.show_menu()
	race.session.configure(race.all_cars,race.track)
	var failures: Array = []
	var checks: int = 0
	for car: CharacterBody3D in race.all_cars:
		car.set_physics_process(false)
	for car: CharacterBody3D in race.all_cars:
		for gate: Dictionary in race.track.gates:
			for mode: String in ["forward","reverse","wrong_height","repeat","skip"]:
				for lane: float in [-1.5,0.0,1.5]:
					var expected: int = 8 if gate.index==0 else gate.index
					car.reset_car(gate.station-0.15,-lane)
					race.session.progress.reset(race.all_cars,race.track.total_length)
					var record: Dictionary = race.session.progress.records[car.player]
					record.gate = expected
					car.gate = expected
					if mode=="skip":
						record.gate = 1 if expected!=1 else 2
						car.gate = record.gate
					if mode=="repeat":
						record.gate = expected+1
						car.gate = record.gate
					var before_gate: int = car.gate
					if mode=="reverse":
						car.reset_car(gate.station+0.15,-lane)
						car.gate = before_gate
						race.session.progress.rebase(car)
					var p: Vector3 = race.track.sample_3d(gate.station+(-0.15 if mode=="reverse" else 0.15))
					var d: Vector2 = race.track.direction(gate.station)
					car.position = p+Vector3(-d.y,0,d.x)*lane
					if mode=="wrong_height": car.position.y -= 3.0
					var projected: Dictionary = race.track.project_3d(car.position,gate.station)
					var result: Dictionary = race.session.progress.observe(car,Vector2(projected.station,projected.distance),0.05,1.0)
					var passed: bool = car.gate==(1 if gate.index==0 else expected+1) if mode=="forward" else car.gate==before_gate and not result.has("lap")
					checks += 1
					if not passed: failures.append("%s car%d gate%d lane%.1f" % [mode,car.player,gate.index,lane])
	for car: CharacterBody3D in race.all_cars: car.set_physics_process(true)
	race.show_menu()
	evidence.gates = {"checks":checks,"failures":failures}
	return evidence.gates

func save_evidence() -> Dictionary:
	evidence.state = snapshot()
	evidence.support = support_report()
	evidence.performance = performance_report()
	evidence.generated_nodes = race.track.get_node("Generated").get_child_count()
	DirAccess.make_dir_recursive_absolute("res://tests/baselines/content/toys_r_you")
	var file: FileAccess = FileAccess.open("res://tests/baselines/content/toys_r_you/live_results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence,"\t"))
	return evidence

func capture(image_name: String) -> void:
	DirAccess.make_dir_recursive_absolute("res://tests/baselines/content/toys_r_you")
	get_viewport().get_texture().get_image().save_png("res://tests/baselines/content/toys_r_you/"+image_name+".png")

