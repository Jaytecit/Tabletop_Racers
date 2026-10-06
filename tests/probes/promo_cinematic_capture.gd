extends "res://tests/probes/race_quality_ai_verification.gd"
# Film-only camera choreography in a disposable read-only runtime.
var filming: bool = false
var shot_time: float = 0.0
var shot_kind: String = ""
var anchor: Vector3
var axis: Vector3
var side: Vector3
var follow: Vector3

func _process(delta: float) -> void:
	if not filming or not is_instance_valid(race): return
	shot_time += delta
	var car: CharacterBody3D = race.player_car
	follow = follow.lerp(car.position,1.0-exp(-8.0*delta))
	var u: float = clampf(shot_time/6.0,0.0,1.0)
	var camera: Camera3D = race.camera
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 48.0
	var target: Vector3 = follow+Vector3.UP*0.35
	if shot_kind=="boost_away":
		camera.position = anchor-axis*(6.0-shot_time*0.8)+side*1.8+Vector3.UP*1.5
		target = car.position+axis*3.0+Vector3.UP*0.25
		camera.fov = 52.0
	elif shot_kind=="low_tracking":
		var heading: Vector3 = Vector3(cos(car.heading),0,sin(car.heading))
		camera.position = follow-heading*4.8+Vector3(-heading.z,0,heading.x)*3.5+Vector3.UP*2.4
		target += heading*1.3
		camera.fov = 57.0
	elif shot_kind=="drift_orbit":
		var angle: float = lerpf(-0.65,0.60,smoothstep(0.0,1.0,u))
		camera.position = follow+(side*cos(angle)-axis*sin(angle))*8.5+Vector3.UP*lerpf(5.0,3.4,u)
	elif shot_kind=="drone_crane":
		camera.position = follow-axis*lerpf(9.0,16.0,u)+side*lerpf(4.0,9.0,u)+Vector3.UP*lerpf(5.0,15.0,u)
		target += axis*3.0
	elif shot_kind=="drone_sweep":
		var angle: float = lerpf(-0.9,0.35,smoothstep(0.0,1.0,u))
		camera.position = follow+(side*cos(angle)-axis*sin(angle))*15.0+Vector3.UP*lerpf(13.0,8.0,u)
		target += axis*2.0
	else:
		camera.position = follow+axis*9.0+side*lerpf(8.0,3.0,u)+Vector3.UP*lerpf(7.0,4.0,u)
		camera.fov = 52.0
	if OS.get_environment("PROMO_ROUTE_CAMERA")=="1" and shot_kind!="boost_away":
		var tangent: Vector2 = race.track.direction(car.station)
		var route_side: Vector3 = Vector3(-tangent.y,0,tangent.x)
		var offset_station: float = -7.0
		var height: float = lerpf(5.0,12.0,u)
		var lateral: float = lerpf(0.5,1.5,u)
		if shot_kind=="low_tracking":
			offset_station = 5.0
			height = 2.2
			lateral = 1.4
		elif shot_kind=="drift_orbit":
			offset_station = -4.0
			height = 3.8
			lateral = lerpf(-1.8,1.8,u)
		elif shot_kind=="drone_sweep":
			height = lerpf(12.0,8.0,u)
			lateral = sin(u*PI)*2.0
		elif shot_kind=="drone_lead":
			offset_station = 8.0
			height = 5.0
			lateral = 1.0
		camera.position = race.track.sample_3d(car.station+offset_station)+route_side*lateral+Vector3.UP*height
		target = car.position+Vector3.UP*0.4
	# Lift cinematic rigs above scenery instead of passing through buildings.
	if OS.get_environment("PROMO_CLEAR_CAMERA")=="1":
		for step: int in range(6):
			var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(race.to_global(target),camera.global_position,1)
			if car.get_world_3d().direct_space_state.intersect_ray(query).is_empty(): break
			camera.position.y += 3.0
	camera.look_at(race.to_global(target))

func choose_station(kind: String, attempt: int) -> float:
	var candidates: Array[Dictionary] = []
	var track: Node3D = race.track
	var reference_path: String = OS.get_environment("PROMO_REFERENCE_RESULT")
	if not reference_path.is_empty():
		var reference: FileAccess = FileAccess.open(reference_path,FileAccess.READ)
		var data: Dictionary = JSON.parse_string(reference.get_as_text())
		for shot: Dictionary in data.reports.shots:
			if shot.camera==kind: return float(shot.start_station)-5.0+float(attempt)*10.0+OS.get_environment("PROMO_START_SHIFT").to_float()
	if kind in ["drift_orbit","low_tracking"]:
		var library_file: FileAccess = FileAccess.open("res://marketing/gameplay-clips-2026-10-06/manifest.json",FileAccess.READ)
		var records: Array = JSON.parse_string(library_file.get_as_text())
		var proven: Array[float] = []
		for record: Dictionary in records:
			if record.course==OS.get_environment("PROMO_COURSE") and record.vehicle=="drift_car": proven.append(float(record.start_station))
		if not proven.is_empty(): return proven[attempt%proven.size()]
	for i: int in range(160):
		var s: float = track.total_length*(float(i)+0.5)/160.0
		var direction: Vector2 = track.direction(s)
		var bend: float = absf(direction.angle_to(track.direction(s+18.0)))
		var line: float = direction.dot(track.direction(s+60.0))
		var width: float = float(track.at(s).width)
		if width<4.0: continue
		var score: float = 0.0
		if kind=="boost_away":
			score = line*10.0-absf(direction.angle_to(track.direction(s+30.0)))*6.0
		elif kind in ["drift_orbit","low_tracking"]:
			score = 2.0-absf(bend-0.7)+minf(width,12.0)*0.03
		else:
			score = minf(width,14.0)*0.06+bend*0.2
		candidates.append({"station":s,"score":score})
	candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.score>b.score)
	return candidates[mini(attempt*7,candidates.size()-1)].station

func _ready() -> void:
	process_priority = 100
	await super_ready()
	var app: Node = get_tree().current_scene
	race = app.get_node("Race")
	check(race.profile.read_only,"read_only_fixture")
	race.profile_directory.read_only = true
	race.machine_settings.read_only = true
	race.profile_selected = true
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.using_pad = false
	race.controller.device = -1
	for action_name: StringName in InputMap.get_actions(): InputMap.action_erase_events(action_name)
	app.get_node("Opening").queue_free()
	get_tree().paused = false
	get_tree().root.content_scale_size = Vector2i(1920,1080)
	race.menu_flow.choose_mode("freestyle")
	var course_id: String = OS.get_environment("PROMO_COURSE")
	check(race.course.select(course_id),"course_selected")
	if not failures.is_empty():
		report("passed",false)
		finish()
		return
	race.rival_count = 0
	race.race_laps = 9
	race.difficulty = 2
	race.race_seed = 6107
	var plan: Array[Dictionary] = [
		{"vehicle":"racing_car","camera":"boost_away"},
		{"vehicle":"racing_car","camera":"drone_crane"},
		{"vehicle":"drift_car","camera":"drift_orbit"},
		{"vehicle":"drift_car","camera":"low_tracking"},
		{"vehicle":"buggy","camera":"drone_sweep"},
		{"vehicle":"monster_truck","camera":"drone_lead"}]
	var only_shot: String = OS.get_environment("PROMO_SHOT")
	var palette: Array[Color] = [Color("ef6546"),Color("4ba5c9"),Color("f1c44f"),Color("86bb5b")]
	var colour_names: Array[String] = ["red","blue","yellow","green"]
	var course_colour: int = ["topspeed_oval","town_square","game_table","mount_rainier"].find(course_id)
	if not OS.get_environment("PROMO_PALETTE_OFFSET").is_empty(): course_colour = OS.get_environment("PROMO_PALETTE_OFFSET").to_int()
	var shots: Array[Dictionary] = []
	var rejected: Array[Dictionary] = []
	for spec_index: int in range(plan.size()):
		var spec: Dictionary = plan[spec_index]
		if spec.camera=="boost_away" and OS.get_environment("PROMO_SKIP_BOOST")=="1": continue
		if not only_shot.is_empty() and spec.camera!=only_shot: continue
		filming = false
		race.show_menu()
		check(race.set_vehicle(spec.vehicle),"vehicle_"+spec.vehicle)
		race.profile.vehicle().stats = preload("res://scripts/vehicles/player_stats.gd").neutral()
		race.garage.apply_stats(race)
		race.start_race()
		race.player_car.ai = true
		race.begin_countdown()
		race.session.countdown = 0.81
		await settle_physics(70)
		race.get_node("HUD").hide()
		var accepted: bool = false
		for attempt: int in range(5):
			filming = false
			var car: CharacterBody3D = race.player_car
			var station_value: float = choose_station(spec.camera,attempt)
			car.reset_car(station_value,0.0)
			var colour_index: int = posmod(course_colour+spec_index,4)
			if not OS.get_environment("PROMO_COLOUR_INDEX").is_empty(): colour_index = OS.get_environment("PROMO_COLOUR_INDEX").to_int()
			for mesh: MeshInstance3D in preload("res://scripts/vehicles/imported_visual.gd").paint_meshes(car.visual):
				preload("res://scripts/vehicles/imported_visual.gd").set_paint(mesh,palette[colour_index])
			car.ai = true
			car.ai_driver.overrides = {"error":0.0,"pass":0.0,"margin":0.65,"speed":0.86}
			if spec.camera=="boost_away":
				car.ai = false
				Input.action_press("p1_go")
				Input.action_press("boost")
			else:
				Input.action_release("p1_go")
				Input.action_release("boost")
				await settle_physics(30)
			anchor = car.position
			axis = Vector3(cos(car.heading),0,sin(car.heading))
			side = Vector3(-axis.z,0,axis.x)
			follow = anchor
			shot_kind = spec.camera
			shot_time = 0.0
			filming = true
			var name: String = course_id+"_"+spec.vehicle+"_"+spec.camera
			if not OS.get_environment("PROMO_SUFFIX").is_empty(): name += "_"+OS.get_environment("PROMO_SUFFIX")
			var folder: String = summer_out_dir+"/"+name+"_take%d"%(attempt+1)
			DirAccess.make_dir_recursive_absolute(folder)
			var shot: Dictionary = {"name":name,"folder":folder.get_file(),"course":course_id,
				"vehicle":spec.vehicle,"camera":spec.camera,"colour":colour_names[colour_index],"start_station":car.station,
				"time_of_day":preload("res://scripts/race/race_lighting.gd").active_time(race),
				"lamps_enabled":car.get_node("VehicleLamps").visible,
				"start_position":str(car.position),"start_frame":Engine.get_process_frames(),
				"start_time":race.race_time,"frames":48 if spec.camera=="boost_away" else (150 if spec.vehicle=="drift_car" else 180),"clean":true,"boost_frames":0,
				"max_speed":0.0,"max_lateral_speed":0.0,"camera_positions":[]}
			for frame: int in range(int(shot.frames)):
				# A real launch, then let the production AI steer the remaining straight.
				if spec.camera=="boost_away" and frame==48:
					Input.action_release("p1_go")
					Input.action_release("boost")
					car.ai = true
				await RenderingServer.frame_post_draw
				var image: Image = get_viewport().get_texture().get_image()
				if image.save_jpg(folder+"/frame_%03d.jpg"%frame,0.96)!=OK: failures.append("save_"+name)
				if car.state!=0 or car.crashes!=0 or car.impacts!=0: shot.clean = false
				if car.boost_was_on: shot.boost_frames += 1
				shot.max_speed = maxf(shot.max_speed,Vector2(car.velocity.x,car.velocity.z).length())
				var normal: Vector2 = Vector2.RIGHT.rotated(car.heading).orthogonal()
				shot.max_lateral_speed = maxf(shot.max_lateral_speed,absf(Vector2(car.velocity.x,car.velocity.z).dot(normal)))
				if frame in [0,60,120,179]: shot.camera_positions.append(str(race.camera.position))
			filming = false
			Input.action_release("p1_go")
			Input.action_release("boost")
			shot["end_frame"] = Engine.get_process_frames()
			shot["end_time"] = race.race_time
			shot["end_station"] = car.station
			shot["motion_distance"] = car.position.distance_to(anchor)
			shot.clean = shot.clean and shot.motion_distance>8.0
			if spec.camera=="boost_away": shot.clean = shot.clean and shot.boost_frames>20 and shot.max_speed>30.0
			if not shot.clean:
				rejected.append(shot)
				report("rejected_takes",rejected)
				write_progress()
				continue
			shots.append(shot)
			report("shots",shots)
			write_progress()
			accepted = true
			break
		check(accepted,"clean_take_"+spec.camera)
	report("failures",failures)
	report("passed",failures.is_empty())
	finish()

func write_progress() -> void:
	var file: FileAccess = FileAccess.open(summer_out_dir+"/capture-progress.json",FileAccess.WRITE)
	if file!=null: file.store_string(JSON.stringify(_reports,"\t"))

func super_ready() -> void:
	DirAccess.make_dir_recursive_absolute(summer_out_dir)
	var deadline: Timer = Timer.new()
	deadline.one_shot = true
	deadline.wait_time = summer_max_seconds
	deadline.timeout.connect(_on_deadline)
	add_child(deadline)
	deadline.start()
	await settle(5)
