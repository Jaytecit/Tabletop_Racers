extends "res://tests/autopilot/probe_base.gd"
var capture_prefix: String = "toybox"
var audit_size: Vector2i = Vector2i(1920,1080)
var course_id: String = "toybox_trestle"

func _ready() -> void:
	await super._ready()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	get_tree().root.size = audit_size
	await settle(8)
	var race: Node = get_tree().current_scene.get_node("Race")
	race.controller.set_physics_process(false)
	race.controller.set_process_input(false)
	race.controller.device = -1
	race.controller.using_pad = false
	race.profile.path = "user://scenery_audit_test.json"
	race.race_mode = "quick"
	race.course.select(course_id)
	race.rival_count = 0
	race.start_race()
	race.paused_race = true
	race.banner.visible = false
	var audit: RefCounted = preload("res://scripts/tracks/scenery_coverage.gd").new()
	audit.configure(race)
	var stations: Array[float] = []
	for step: int in range(int(ceil(race.track.total_length/2.0))): stations.append(minf(step*2.0,race.track.total_length-0.01))
	for gate: Dictionary in race.track.gates: stations.append(gate.station)
	var samples: Array = []
	var reference_gaps: Array = []
	var warning_gaps: Array = []
	var captures: Dictionary = {}
	for station: float in stations:
		for lane_fraction: float in [-1.0,0.0,1.0]:
			var lane: float = lane_fraction*minf(2.0,race.track.at(station).width*0.5-0.5)
			for lead: float in [0.0,3.2]:
				var point: Vector3 = race.track.sample_3d(station)
				var direction: Vector2 = race.track.direction(station)
				race.player_car.position = point+Vector3(-direction.y,0,direction.x)*lane+Vector3.UP*0.32
				race.player_car.station = station
				race.player_car.rotation.y = -direction.angle()
				race.camera_driver.reset(race.camera,race.player_car)
				var offset: Vector3 = Vector3(direction.x,0,direction.y)*lead
				race.camera.position += offset
				# Settle the local foreground fade without advancing the paused race.
				race.player_car.velocity = Vector3(direction.x,0,direction.y)*lead/0.20
				for frame: int in range(90): race.camera_driver.tick(race.camera,race.player_car,1.0/60.0)
				race.player_car.velocity = Vector3.ZERO
				await get_tree().physics_frame
				race.banner.visible = false
				var entry: Dictionary = audit.sample(race,station,lane,lead)
				samples.append(entry)
				if entry.reference_gap: reference_gaps.append(entry)
				if entry.warning_gap: warning_gaps.append(entry)
				var sector: int = int(station/race.track.total_length*12.0)
				var category: String = ("gap" if entry.reference_gap else ("warning" if entry.warning_gap else "sector"))+"_%02d"%sector
				if lane==0.0 and lead==3.2 and not captures.has(category):
					captures[category] = station
					race.get_node("HUD/Status").text = "CAMERA AUDIT · %.1fm\nLANE %.1f · LEAD %.1f"%[station,lane,lead]
					await settle(2)
					save_frame(capture_prefix+"_"+category)
	report("track_id",race.track.definition.id)
	report("resolution",str(audit_size))
	report("route_revision",race.track.definition.revision)
	report("cue_count",audit.cues.size())
	report("sample_count",samples.size())
	report("reference_gap_count",reference_gaps.size())
	report("warning_gap_count",warning_gaps.size())
	report("samples",samples)
	report("capture_stations",captures)
	report("passed",reference_gaps.is_empty() and warning_gaps.is_empty())
	for suffix: String in ["",".bak",".tmp",".bak.tmp"]: DirAccess.remove_absolute("user://scenery_audit_test.json"+suffix)
	finish()
