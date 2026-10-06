@tool
extends RefCounted
const INTRO: Script = preload("res://scripts/tracks/author_intro_courses.gd")
const ART: Script = preload("res://scripts/tracks/blackjack_art.gd")
const BUILDER: Script = preload("res://scripts/tracks/track_builder.gd")

static func build_all() -> void:
	# Suzuka-inspired figure eight: linked esses, a hairpin, a sustained sweep,
	# the separated crossover and a final braking sequence.
	var points: Array[Vector3] = [Vector3(-52,0,-34),Vector3(-22,0,-34),Vector3(-6,0,-26),Vector3(-12,0,-16),Vector3(0,0,-6),Vector3(0,0,12),Vector3(-8,0,24),Vector3(5,0,34),Vector3(26,0,40),Vector3(48,0,34),Vector3(62,0,18),Vector3(60,0,6),Vector3(48,0,4),Vector3(34,4.8,0),Vector3(18,4.8,0),Vector3(-18,4.8,0),Vector3(-34,4.8,0),Vector3(-52,0,-4),Vector3(-62,0,-14),Vector3(-54,0,-22),Vector3(-62,0,-30)]
	for i: int in range(points.size()):
		points[i].x *= 1.4
		points[i].z *= 1.4
	var definition: Resource = load("res://scripts/tracks/track_definition.gd").new()
	definition.id = "card_bridge"
	definition.start_station = 8.0
	definition.revision = 2
	for i: int in range(points.size()):
		var section: Resource = load("res://scripts/tracks/route_section.gd").new()
		section.id = "card_bridge_%02d" % i
		section.next_id = "card_bridge_%02d" % ((i+1)%points.size())
		section.start = points[i]
		section.end = points[(i+1)%points.size()]
		section.before = points[posmod(i-1,points.size())]
		section.after = points[(i+2)%points.size()]
		section.curved = true
		if i in range(12,17):
			section.layer = 1
			section.surface = "paper"
			section.edge = "raised"
			section.width = 3.8
		definition.sections.append(section)
	var track: Node3D = load("res://showcase_track.gd").new()
	track.definition = definition
	track.build()
	assert(track.validation_errors.is_empty(),str(track.validation_errors))
	DirAccess.make_dir_recursive_absolute("res://tracks/card_bridge")
	assert(ResourceSaver.save(definition,"res://tracks/card_bridge/definition.tres")==OK)
	definition.take_over_path("res://tracks/card_bridge/definition.tres")
	var environment: Node3D = load("res://scripts/tracks/flat_course_art.gd").build(track)
	build_bridge(environment,track)
	INTRO.stamp(environment,environment)
	var packed: PackedScene = PackedScene.new()
	assert(packed.pack(environment)==OK)
	assert(ResourceSaver.save(packed,"res://environments/casino/card_bridge.tscn")==OK)
	var entry: Resource = load("res://scripts/tracks/track_entry.gd").new()
	entry.id = "card_bridge"
	entry.title = "Card Bridge Circuit"
	entry.cup = "Casino"
	entry.order_in_cup = 2
	entry.route = definition
	entry.environment = load("res://environments/casino/card_bridge.tscn")
	entry.preview = INTRO.preview(track,"res://tracks/card_bridge/preview.res")
	entry.target_lap_seconds = Vector2(40,60)
	entry.description = "Linked esses · narrow exposed bridge · two route heights"
	assert(ResourceSaver.save(entry,"res://tracks/card_bridge/entry.tres")==OK)
	print("CARD_BRIDGE length=",track.total_length," gates=",track.gates.size())
	environment.free()
	track.free()

static func build_bridge(environment: Node3D, track: Node3D) -> void:
	var bridge: Node3D = ART.group(environment,"CardBridge",Vector3.ZERO)
	var warning_station: float = 0.0
	for index: int in range(track.section_ids.size()):
		if track.section_ids[index]==12:
			warning_station = track.lengths[index]-13.0
			break
	var warning: Node3D = ART.group(bridge,"NarrowDeckWarning",track.sample_3d(warning_station))
	warning.rotation.y = -track.direction(warning_station).angle()
	ART.flat_text(warning,"WarningInk",Vector3(0,0.035,0),"NARROW · NO RAILS",0.4,ART.GOLD)
	warning.set_meta("scenery_cue",{"id":"NarrowDeckWarning","kind":"turn","radius":0.7,"station":warning_station})
	var deck: SurfaceTool = SurfaceTool.new()
	deck.begin(Mesh.PRIMITIVE_TRIANGLES)
	var under: SurfaceTool = SurfaceTool.new()
	under.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(track.starts.size()):
		if track.at(track.lengths[i]).layer!=1: continue
		var a: Vector3 = track.starts[i]
		var b: Vector3 = track.ends[i]
		var na: Vector3 = track.edge_offset(i)
		var nb: Vector3 = track.edge_offset(i+1)
		var half_width: float = track.at(track.lengths[i]).width*0.5
		BUILDER.quad(deck,a-na*half_width,b-nb*half_width,b+nb*half_width,a+na*half_width)
		BUILDER.quad(under,a-na*half_width-Vector3.UP*0.06,b-nb*half_width-Vector3.UP*0.06,b+nb*half_width-Vector3.UP*0.06,a+na*half_width-Vector3.UP*0.06)
	deck.generate_normals()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var mesh: ArrayMesh = deck.commit()
	var shape: ConcavePolygonShape3D = mesh.create_trimesh_shape()
	shape.backface_collision = true
	collision.shape = shape
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "ContinuousDeck"
	body.set_meta("camera_fade",true)
	body.add_child(collision)
	bridge.add_child(body)
	BUILDER.mesh_node(bridge,"CardLayers",under,ART.IVORY)
	for title: String in ["CardLayers"]:
		bridge.get_node(title).set_meta("camera_occluder",true)
		bridge.get_node(title).set_meta("fade_strength",0.98)
	# Complete printed cards on the straight summit; margins hold chips above the felt.
	for x: float in [-28.0,-20.0,-12.0,-4.0,4.0,12.0,20.0]:
		var card: Node3D = ART.card(bridge,Vector3(x,4.81,0),PI/2.0,0 if x<0.0 else 1,3.8)
		for node: Node in card.get_children():
			node.set_meta("camera_occluder",true)
			node.set_meta("fade_strength",0.98)
	for x: float in [-20.0,20.0]:
		for side: float in [-1.0,1.0]:
			var pillar: MeshInstance3D = ART.box(bridge,"CardStackAbutment",Vector3(x,2.28,5.5*side),Vector3(4,4.56,1.3),ART.IVORY)
			ART.collider(pillar,Vector3.ZERO,Vector3(4,4.56,1.3))
	# Elevated turn marks are flat ink inside the exposed deck, never floating off its edge.
	var guidance: Node3D = environment.get_node("RouteGuidance")
	for step: int in range(int(ceil(track.total_length/3.0))):
		var station: float = float(step)*3.0
		var point: Vector3 = track.sample_3d(station)
		if track.at(station).layer!=1: continue
		var direction: Vector2 = track.direction(station)
		var turn: float = direction.angle_to(track.direction(station+10.0))
		for ahead: float in [3,5,7]:
			var candidate: float = direction.angle_to(track.direction(station+ahead))
			if absf(candidate)>absf(turn): turn = candidate
		for side: float in [-1,1]:
			var marker: Node3D = ART.group(guidance,"BridgeTurn%03d_%d" % [step,int(side)],point+Vector3(-direction.y,0,direction.x)*1.35*side+Vector3.UP*0.04)
			marker.rotation.y = -direction.angle()
			marker.set_meta("scenery_cue",{"id":str(marker.name),"kind":"turn" if absf(turn)>=0.18 else "ground","radius":0.7,"station":station})
			ART.box(marker,"ArrowStem",Vector3(-0.15,0,0),Vector3(0.65,0.012,0.2),ART.INK)
			if absf(turn)>=0.18: ART.box(marker,"ArrowBend",Vector3(0.15,0,signf(turn)*0.2),Vector3(0.2,0.012,0.6),ART.INK)
			ART.batch(marker)
