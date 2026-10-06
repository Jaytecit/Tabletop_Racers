@tool
extends RefCounted
const INTRO: Script = preload("res://scripts/tracks/author_intro_courses.gd")
const ART: Script = preload("res://scripts/tracks/blackjack_art.gd")
const BEDROOM: Script = preload("res://scripts/tracks/bedroom_art.gd")
const WOOD: Script = preload("res://scripts/tracks/kitchen_art.gd")

static func toybox(parent: Node3D) -> void:
	ART.box(parent,"Box",Vector3(0,1.2,0),Vector3(5.0,2.4,3.4),BEDROOM.BLUE)
	ART.box(parent,"Lid",Vector3(0,2.5,0),Vector3(5.4,0.25,3.8),BEDROOM.CORAL)
	ART.box(parent,"Latch",Vector3(0,1.8,-1.75),Vector3(0.7,0.7,0.12),ART.GOLD)
	ART.collider(parent,Vector3(0,1.3,0),Vector3(5.4,2.7,3.8))

static func build_environment(track: Node3D) -> Node3D:
	var root: Node3D = BEDROOM.build(track)
	# Keep the woven floor and continuous close cues; replace generic landmarks.
	var old: Node = root.get_node("Landmarks")
	root.remove_child(old)
	old.free()
	var support: Node3D = ART.group(root,"TrestleSupport",Vector3.ZERO)
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(track.starts.size()):
		if track.definition.sections[track.section_ids[i]].surface!="wood": continue
		var a: Vector3 = track.starts[i]-Vector3.UP*0.015
		var b: Vector3 = track.ends[i]-Vector3.UP*0.015
		var na: Vector3 = track.edge_offset(i)*5.3
		var nb: Vector3 = track.edge_offset(i+1)*5.3
		load("res://scripts/tracks/track_builder.gd").quad(tool,a+na,b+nb,b-nb,a-na)
	tool.generate_normals()
	var deck: MeshInstance3D = MeshInstance3D.new()
	deck.name = "SupportedBookTrestle"
	deck.mesh = tool.commit()
	deck.material_override = WOOD.surface_material()
	support.add_child(deck)
	deck.create_trimesh_collision()
	var landmarks: Node3D = ART.group(root,"Landmarks",Vector3.ZERO)
	for i: int in range(int(ceil(track.total_length/14.0))):
		var station: float = float(i)*14.0
		var direction: Vector2 = track.direction(station)
		var pos: Vector3 = track.sample_3d(station)+Vector3(-direction.y,0,direction.x)*12.0*(1 if i%2==0 else -1)
		if track.project_3d(pos).distance<10.5: continue
		var prop: Node3D = ART.group(landmarks,"ToySector%02d"%i,pos)
		prop.rotation.y = -direction.angle()
		match i%3:
			0: BEDROOM.blocks(prop)
			1: BEDROOM.books(prop)
			2: toybox(prop)
		ART.batch(prop)
	# Visible block columns explain the trestle's support without entering the road.
	for station: float in [135.0,153.0,172.0,191.0]:
		var point: Vector3 = track.sample_3d(station)
		var direction: Vector2 = track.direction(station)
		for side: float in [-1,1]:
			var pillar: Node3D = ART.group(root,"BlockPier",point+Vector3(-direction.y,0,direction.x)*6.3*side)
			ART.box(pillar,"Block",Vector3(0,-point.y*0.5,0),Vector3(1.0,maxf(point.y,0.15),1.0),BEDROOM.BLUE if side<0 else BEDROOM.CORAL)
			ART.batch(pillar)
	return root

static func build_all() -> void:
	var points: Array[Vector2] = [Vector2(-100,-45),Vector2(-50,-45),Vector2(-25,-38),Vector2(0,-45),Vector2(25,-45),Vector2(65,-45),Vector2(71,-45),Vector2(110,-45),Vector2(126,-25),Vector2(118,-5),Vector2(95,10),Vector2(74,-10),Vector2(54,8),Vector2(42,35),Vector2(20,56),Vector2(-28,62),Vector2(-75,45),Vector2(-110,15),Vector2(-120,-20)]
	var definition: Resource = INTRO.route("toybox_trestle",points)
	definition.start_station = 20.0
	var heights: Array[float] = [0,0,0,0,2.2,2.2,2.2,2.2,0,0,0,0,0,0,0,0,0,0,0]
	for i: int in range(points.size()):
		var section: Resource = definition.sections[i]
		section.surface = "wood" if i in [3,4,5,6,7] else "fabric"
		section.start.y = heights[i]
		section.end.y = heights[(i+1)%heights.size()]
		section.before.y = section.start.y
		section.after.y = section.end.y
		section.edge = "raised" if i in [3,4,5,6,7] else "shoulder"
		if i in [4,5]: section.curved = false
		if i==5:
			section.end.y = 3.0
			section.jump_exit = true
			section.anchor = false
	var track: Node3D = load("res://showcase_track.gd").new()
	track.definition = definition
	track.build()
	assert(track.validation_errors.is_empty(),str(track.validation_errors))
	DirAccess.make_dir_recursive_absolute("res://tracks/toybox_trestle")
	assert(ResourceSaver.save(definition,"res://tracks/toybox_trestle/definition.tres")==OK)
	definition.take_over_path("res://tracks/toybox_trestle/definition.tres")
	var environment: Node3D = build_environment(track)
	INTRO.stamp(environment,environment)
	var packed: PackedScene = PackedScene.new()
	assert(packed.pack(environment)==OK)
	assert(ResourceSaver.save(packed,"res://environments/bedroom/toybox_trestle.tscn")==OK)
	var entry: Resource = load("res://scripts/tracks/track_entry.gd").new()
	entry.id = "toybox_trestle"
	entry.title = "Toybox Trestle"
	entry.cup = "Bedroom"
	entry.order_in_cup = 3
	entry.route = definition
	entry.environment = load("res://environments/bedroom/toybox_trestle.tscn")
	entry.preview = INTRO.preview(track,"res://tracks/toybox_trestle/preview.res")
	entry.target_lap_seconds = Vector2(45,60)
	entry.description = "Bedroom toys · block kink · book trestle · modest jump · landing hairpin"
	assert(ResourceSaver.save(entry,"res://tracks/toybox_trestle/entry.tres")==OK)
	print("TOYBOX_TRESTLE length=",track.total_length," gates=",track.gates.size())
	environment.free()
	track.free()
