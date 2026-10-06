extends RefCounted
# Authoring-only camera audit. Never runs in the driving frame loop.
const PREVIEW: float = 13.0
var cues: Array[Dictionary] = []
var minimap: Control

func configure(race: Node3D) -> void:
	cues.clear()
	minimap = race.get_node_or_null("HUD/RaceMinimap")
	var track: Node3D = race.track
	var course: Node = race.get_node_or_null("CourseEnvironment")
	if course!=null and course.has_node("TracksideCues"):
		for marker: Node3D in course.get_node("TracksideCues").get_children():
			cues.append({"id":str(marker.name),"position":marker.global_position+Vector3.UP*0.15,"radius":0.28,"kind":"ground","station":marker.get_meta("cue_station")})
	# Existing baked shoulder chips follow this recipe; positions survive mesh batching.
	for step: int in range(0 if not cues.is_empty() else int(track.total_length/3.0)):
		var station: float = float(step)*3.0
		var point: Vector3 = track.sample_3d(station)
		if point.y>0.02: continue
		var tangent: Vector2 = track.direction(station)
		var normal: Vector3 = Vector3(-tangent.y,0,tangent.x)
		for side: int in [-1,1]:
			var pos: Vector3 = point+normal*4.15*side
			if track.project_3d(pos).distance<3.6: continue
			cues.append({"id":"chip_%03d_%d"%[step,side],"position":pos+Vector3.UP*0.15,"radius":0.30,"kind":"ground","station":station})
	var guidance: Node = race.get_node_or_null("CourseEnvironment/RouteGuidance")
	if guidance==null: guidance = race.get_node_or_null("CourseEnvironment/BlackjackEnvironment/RouteGuidance")
	if guidance==null: guidance = race.get_node_or_null("BlackjackEnvironment/RouteGuidance")
	if guidance!=null:
		for marker: Node3D in guidance.get_children():
			if not marker.has_meta("scenery_cue"): continue
			var cue: Dictionary = marker.get_meta("scenery_cue").duplicate()
			cue.position = marker.global_position
			cues.append(cue)

func visible(camera: Camera3D, cue: Dictionary, car: Node3D) -> bool:
	var point: Vector3 = cue.position
	if camera.is_position_behind(point) or point.distance_to(car.global_position)>15.6: return false
	var size: Vector2 = camera.get_viewport().get_visible_rect().size
	var pixel: Vector2 = camera.unproject_position(point)
	if not Rect2(Vector2(12,12),size-Vector2(24,24)).has_point(pixel): return false
	# HUD panels are opaque; do not count geometry hidden underneath them.
	if Rect2(25,25,415,160).has_point(pixel) or Rect2(size.x-243,25,220,160).has_point(pixel): return false
	if minimap!=null and minimap.visible and minimap.get_global_rect().has_point(pixel): return false
	if pixel.y>size.y-55.0: return false
	var projected_size: float = camera.unproject_position(point+camera.global_basis.x*cue.radius).distance_to(pixel)*2.0
	if projected_size<8.0: return false
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(camera.global_position,point+Vector3.UP*0.03,1)
	var hit: Dictionary = car.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.position.distance_to(point)<0.20

func sample(race: Node3D, station: float, lane: float, lead: float) -> Dictionary:
	var visible_ids: Array[String] = []
	var turn_ids: Array[String] = []
	var jump_ids: Array[String] = []
	for cue: Dictionary in cues:
		if not visible(race.camera,cue,race.player_car): continue
		visible_ids.append(cue.id)
		var forward: float = fposmod(cue.station-station,race.track.total_length)
		if forward<=PREVIEW:
			if cue.kind=="turn": turn_ids.append(cue.id)
			if cue.kind=="jump": jump_ids.append(cue.id)
	var turn_ahead: bool = false
	var jump_ahead: bool = false
	for ahead: float in [3.9,6.5,9.1,13.0]:
		if absf(race.track.direction(station).angle_to(race.track.direction(station+ahead)))>0.38: turn_ahead = true
		var route: Dictionary = race.track.at(station+ahead)
		if race.track.definition.sections[route.section].jump_exit: jump_ahead = true
	return {"station":station,"lane":lane,"lead":lead,"visible_cues":visible_ids,"turn_cues":turn_ids,"jump_cues":jump_ids,
		"reference_gap":visible_ids.size()<2,"turn_ahead":turn_ahead,"jump_ahead":jump_ahead,
		"warning_gap":(turn_ahead and turn_ids.is_empty()) or (jump_ahead and jump_ids.is_empty())}
