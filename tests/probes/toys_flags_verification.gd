extends "res://tests/autopilot/probe_base.gd"
const FLAGS: Script = preload("res://scripts/tracks/imported_checkpoint_flags.gd")
var failures: Array[String] = []

func inspect_flags(race: Node3D, stage: String) -> void:
	var root: Node3D = race.track.get_node("Generated/CheckpointFlags")
	if not root.ready_for_inspection: failures.append(stage+": not ready")
	failures.append_array(root.placement_errors)
	var markers: Node3D = root.get_node("CheckpointFlags")
	if not markers.find_children("*","CollisionObject3D",true,false).is_empty(): failures.append(stage+": collision obstacle")
	var coverage: Dictionary = root.reused_cues.duplicate()
	var records: Array = []
	for flag: Node3D in markers.get_children():
		var index: int = flag.get_meta("checkpoint")
		var gate: Dictionary = race.track.gates[index]
		var heading: Vector2 = race.track.direction(gate.station)
		var delta: Vector3 = flag.position-gate.position
		if absf(Vector2(delta.x,delta.z).dot(heading))>0.01: failures.append(stage+": plane %d" % index)
		if flag.get_meta("layer")!=gate.layer: failures.append(stage+": layer %d" % index)
		var edges: Array[Vector3] = FLAGS.plane_edges(race.track,gate)
		var normal: Vector3 = Vector3(-heading.y,0,heading.x)
		var sign_value: float = -1.0 if delta.dot(normal)<0.0 else 1.0
		var edge: Vector3 = edges[0 if sign_value<0.0 else 1]
		if (flag.position-edge).dot(normal)*sign_value<0.4: failures.append(stage+": clearance %d" % index)
		var elevated: bool = flag.get_meta("elevated")
		if elevated and not FLAGS.cue_clear_at(race.track,flag.position,heading): failures.append(stage+": elevated prop clearance %d" % index)
		if not elevated:
			var support: Dictionary = FLAGS.support_at(race.track,flag.position)
			if support.is_empty() or absf(support.position.y-flag.position.y)>0.01: failures.append(stage+": support %d" % index)
			if not FLAGS.clear_at(race.track,flag.position,heading): failures.append(stage+": prop clearance %d" % index)
		var labels: int = 0
		for child: Node in flag.get_children():
			if child is Label3D:
				labels += 1
				if child.text!=("FINISH" if index==0 else str(index)): failures.append(stage+": label %d" % index)
				if not child.no_depth_test: failures.append(stage+": obscured label %d" % index)
		if labels!=1: failures.append(stage+": label count %d" % index)
		coverage[index] = true
		records.append({"gate":index,"layer":gate.layer,"position":str(flag.position),"elevated":elevated})
	if coverage.size()!=race.track.gates.size(): failures.append(stage+": missing gate")
	if markers.get_child_count()>race.track.gates.size()*2: failures.append(stage+": duplicates")
	report(stage,records)
	report(stage+"_reused_cues",root.reused_cues)

func procedural_checks(race: Node3D) -> void:
	var track: Node3D = race.track
	var counts: Dictionary = {"polygons":0,"inside":0,"outside":0,"markers":0}
	for i: int in range(track.starts.size()):
		if track.road_polygon(i)!=track.legacy_road_polygon(i): failures.append("procedural polygon changed")
		counts.polygons += 1
		if track.definition.id!="game_table": continue
		var width: float = track.definition.sections[track.section_ids[i]].width*0.5
		var p: Vector3 = track.starts[i].lerp(track.ends[i],0.5)
		var normal: Vector3 = track.edge_offset(i).lerp(track.edge_offset(i+1),0.5)
		var station: float = (track.lengths[i]+track.lengths[i+1])*0.5
		for sign_value: float in [-1.0,1.0]:
			if not track.project_3d(p+normal*(width-0.02)*sign_value,station).supported: failures.append("procedural inside")
			if track.project_3d(p+normal*(width+0.08)*sign_value,station).supported: failures.append("procedural outside")
			counts.inside += 1
			counts.outside += 1
	for flag: Node3D in track.get_node("Generated/CheckpointFlags").get_children():
		var gate: Dictionary = track.gates[flag.get_meta("checkpoint")]
		var heading: Vector2 = track.direction(gate.station)
		var normal: Vector3 = Vector3(-heading.y,0,heading.x)
		var sign_value: float = -1.0 if (flag.position-gate.position).dot(normal)<0.0 else 1.0
		if flag.position.distance_to(gate.position+normal*(gate.width*0.5+0.45)*sign_value)>0.001: failures.append("procedural marker moved")
		counts.markers += 1
	report(track.definition.id+"_regression",counts)

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(summer_out_dir)
	await super._ready()
	await settle(3)
	var race: Node3D = get_tree().current_scene.get_node("Race")
	race.profile.read_only = true
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.using_pad = false
	race.controller.device = -1
	var helper: Node = load("res://tests/probes/toys_live.gd").new()
	race.add_child(helper)
	report("select",helper.select_course())
	await settle_physics(5)
	inspect_flags(race,"initial")
	report("gates",helper.gate_checks())
	report("alignment",load("res://tests/probes/toys_alignment_checks.gd").check(race.track.definition))
	race.track.get_node("Generated/RouteDebugOverlay").hide()
	helper.overview()
	await settle(3)
	save_frame("flags_no_overlay")
	for gate: Dictionary in race.track.gates:
		race.camera.size = 17
		race.camera.position = gate.position+Vector3(0,22,14)
		race.camera.look_at(gate.position)
		await settle(2)
		save_frame("gate_%d" % gate.index)
	for i: int in range(3):
		race.track.rebuild_art()
		await settle_physics(5)
		inspect_flags(race,"rebuild_%d" % i)
	# Exercise both bridge decks without changing the course's saved/real checkpoints.
	var original_gates: Array[Dictionary] = race.track.gates.duplicate(true)
	var test_gates: Array[Dictionary] = [original_gates[0]]
	for span: int in [45*24+12,36*24+12]:
		var station: float = race.track.lengths[span]
		var gate: Dictionary = race.track.at(station)
		gate.station = station
		gate.index = test_gates.size()
		test_gates.append(gate)
	race.track.gates = test_gates
	race.track.rebuild_art()
	await settle_physics(5)
	inspect_flags(race,"bridge_decks")
	race.track.get_node("Generated/RouteDebugOverlay").hide()
	race.camera.size = 25
	race.camera.position = test_gates[1].position+Vector3(0,25,16)
	race.camera.look_at(test_gates[1].position)
	await settle(3)
	save_frame("bridge_decks")
	race.track.gates = original_gates
	report("select_game_table",helper.select_course("game_table"))
	await settle_physics(4)
	procedural_checks(race)
	report("switch_away",helper.select_course("practice_patch"))
	await settle_physics(4)
	procedural_checks(race)
	var procedural: Node3D = race.track.get_node("Generated/CheckpointFlags")
	report("procedural_marker_count",procedural.get_child_count())
	if procedural.get_child_count()!=race.track.gates.size()*2: failures.append("procedural marker count")
	report("switch_back",helper.select_course())
	await settle_physics(5)
	inspect_flags(race,"switched_markers")
	race.track.get_node("Generated/RouteDebugOverlay").hide()
	helper.start_test(1,1)
	for i: int in range(340): await get_tree().physics_frame
	save_frame("driving_flags")
	report("failures",failures)
	report("passed",failures.is_empty() and _reports.gates.failures.is_empty() and _reports.alignment.failures.is_empty() and _reports.select.selected and _reports.switch_away.selected and _reports.switch_back.selected)
	finish()


