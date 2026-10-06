@tool
extends RefCounted
const INTRO: Script = preload("res://scripts/tracks/author_intro_courses.gd")
const ART: Script = preload("res://scripts/tracks/blackjack_art.gd")

static func build_all() -> void:
	# Preserve the launch/jump and return sector, add a dealer-side racing sequence.
	var points: Array[Vector3] = [
		Vector3(-18.75,0,-29.166668),Vector3(-10.75,0,-29.166668),
		Vector3(-4.75,0,-29.166668),Vector3(1.25,0,-29.166668),
		Vector3(8.333333,0,-29.166668),Vector3(28.333332,0,-26.25),
		Vector3(64,0,-32),Vector3(92,0,-18),Vector3(100,0,5),
		Vector3(85,0,25),Vector3(62,0,25),Vector3(62,0,52),
		Vector3(39,0,67),Vector3(12,0,53),Vector3(8.75,0,32.083332),
		Vector3(-4.583333,0,17.916668),Vector3(-22.083332,0,14.166667),
		Vector3(-36.666668,0,21.666668),Vector3(-47.916668,0,5.416667),
		Vector3(-47.916668,0,-15),Vector3(-36.666668,0,-29.166668)]
	var definition: Resource = load("res://scripts/tracks/track_definition.gd").new()
	definition.id = "game_table"
	definition.revision = 5
	definition.start_station = 1.0
	for i: int in range(points.size()):
		var section: Resource = load("res://scripts/tracks/route_section.gd").new()
		section.id = "table_%d" % i
		section.next_id = "table_%d" % ((i+1)%points.size())
		section.start = points[i]
		section.end = points[(i+1)%points.size()]
		section.before = points[posmod(i-1,points.size())]
		section.after = points[(i+2)%points.size()]
		section.curved = true
		if i==1:
			section.start.y = 0.035
			section.end.y = 1.235
			section.curved = false
			section.surface = "wood"
			section.edge = "raised"
			section.jump_exit = true
			section.anchor = false
		definition.sections.append(section)
	var track: Node3D = load("res://showcase_track.gd").new()
	track.definition = definition
	track.build()
	assert(track.validation_errors.is_empty(),str(track.validation_errors))
	assert(ResourceSaver.save(definition,"res://tracks/game_table/definition.tres")==OK)
	definition.take_over_path("res://tracks/game_table/definition.tres")
	var environment: Node3D = load("res://environments/casino/blackjack.tscn").instantiate()
	var previous: Node = environment.get_node_or_null("BlackjackEnvironment")
	if previous!=null: previous.free()
	var support: Node3D = environment.get_node("Support")
	var table: StaticBody3D = support.get_node("FeltTable")
	var top: MeshInstance3D = table.get_node("Mesh")
	top.mesh = top.mesh.duplicate()
	top.mesh.size = Vector3(230,0.08,170)
	var collision: CollisionShape3D = table.get_child(0)
	collision.shape = collision.shape.duplicate()
	collision.shape.size = top.mesh.size
	var rim: MeshInstance3D = support.get_node("TableEdge")
	rim.mesh = rim.mesh.duplicate()
	rim.mesh.size = Vector3(231,0.9,171)
	var old_ramp: Node = support.get_node_or_null("CardRampSupport")
	if old_ramp!=null: old_ramp.free()
	var ramp: StaticBody3D = StaticBody3D.new()
	ramp.name = "CardRampSupport"
	ramp.collision_mask = 2
	support.add_child(ramp)
	var ramp_shape: CollisionShape3D = CollisionShape3D.new()
	var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	shape.backface_collision = true
	var a: Vector3 = definition.sections[1].start
	var b: Vector3 = definition.sections[1].end
	var side: Vector3 = Vector3(0,0,3)
	shape.set_faces(PackedVector3Array([a-side,a+side,b+side,a-side,b+side,b-side]))
	ramp_shape.shape = shape
	ramp.add_child(ramp_shape)
	ART.build(environment,track)
	INTRO.stamp(environment,environment)
	var packed: PackedScene = PackedScene.new()
	assert(packed.pack(environment)==OK)
	assert(ResourceSaver.save(packed,"res://environments/casino/blackjack.tscn")==OK)
	var entry: Resource = load("res://scripts/tracks/track_entry.gd").new()
	entry.id = "game_table"
	entry.title = "Blackjack Grand Prix"
	entry.cup = "Casino"
	entry.order_in_cup = 3
	entry.route = definition
	entry.environment = load("res://environments/casino/blackjack.tscn")
	entry.preview = INTRO.preview(track,"res://tracks/game_table/preview.res")
	entry.target_lap_seconds = Vector2(35,50)
	entry.description = "Casino felt · card-shoe jump · dealer hairpin and return chicane"
	assert(ResourceSaver.save(entry,"res://tracks/game_table/entry.tres")==OK)
	print("BLACKJACK revision=",definition.revision," length=",track.total_length," sections=",definition.sections.size())
	environment.free()
	track.free()
