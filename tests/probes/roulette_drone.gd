extends "res://tests/autopilot/probe_base.gd"
func _ready() -> void:
	await super._ready()
	await settle(3)
	var race: Node3D = get_tree().current_scene.get_node("Race")
	race.profile.read_only = true
	race.course.select("game_table")
	race.rival_count = 1
	race.race_laps = 1
	race.menu.get_node("Start").pressed.emit()
	await settle(3)
	var initial: Vector3 = race.camera.position
	for i: int in range(240): await get_tree().physics_frame
	report("live_preview",{"phase":race.phase,"travel":initial.distance_to(race.camera.position),"size":race.camera.size})
	save_frame("01_live_drone")
	race.paused_race = true
	race.camera_driver.reset(race.camera,race.player_car)
	race.camera_driver.preview(race.camera,race.track,0.0)
	var previous: Vector3 = race.camera.position
	var rotation: Quaternion = race.camera.basis.get_rotation_quaternion()
	var max_step: float = 0.0
	var max_turn: float = 0.0
	var inside: bool = true
	var min_height: float = INF
	var max_height: float = -INF
	for i: int in range(1,6001):
		race.camera_driver.preview(race.camera,race.track,float(i)/60.0)
		var point: Vector3 = race.camera.position
		var next_rotation: Quaternion = race.camera.basis.get_rotation_quaternion()
		max_step = maxf(max_step,previous.distance_to(point))
		max_turn = maxf(max_turn,rotation.angle_to(next_rotation))
		inside = inside and absf(point.x)<160.0 and absf(point.z)<160.0 and point.y<90.0 and point.y>0.0
		min_height = minf(min_height,point.y)
		max_height = maxf(max_height,point.y)
		previous = point
		rotation = next_rotation
		if i in [900,2300,3300,4500]:
			await settle(2)
			save_frame("flight_%04d" % i)
	report("full_flight",{"inside_room":inside,"max_step":max_step,"max_turn_degrees":rad_to_deg(max_turn),"min_height":min_height,"max_height":max_height})
	var roof_visible: bool = true
	for mesh: MeshInstance3D in race.camera_driver.occluders:
		if mesh.get_meta("overview_hide",false): roof_visible = roof_visible and mesh.transparency==0.0
	report("roof_retained",roof_visible)
	race.paused_race = false
	await key(KEY_ENTER,50)
	await settle(3)
	var restored: bool = race.phase==1 and is_equal_approx(race.camera.size,14.0) and race.camera.projection==Camera3D.PROJECTION_ORTHOGONAL
	report("countdown_restores_camera",restored)
	save_frame("06_countdown")
	report("passed",inside and max_step<0.3 and max_turn<deg_to_rad(2.0) and roof_visible and restored)
	finish()
