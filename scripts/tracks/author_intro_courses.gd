@tool
extends RefCounted
# Editor-only authoring recipe. Runtime loads the saved entries and scenery.
const DEFINITION: Script = preload("res://scripts/tracks/track_definition.gd")
const SECTION: Script = preload("res://scripts/tracks/route_section.gd")
const ENTRY: Script = preload("res://scripts/tracks/track_entry.gd")

static func stamp(node: Node, root: Node) -> void:
	for child: Node in node.get_children():
		child.owner = root
		stamp(child,root)

static func route(id: String, points: Array[Vector2]) -> Resource:
	var definition: Resource = DEFINITION.new()
	definition.id = id
	definition.revision = 1
	definition.start_station = 5.0
	for i: int in range(points.size()):
		var section: Resource = SECTION.new()
		section.id = "%s_%d" % [id,i]
		section.next_id = "%s_%d" % [id,(i+1)%points.size()]
		var p: Vector2 = points[i]
		var q: Vector2 = points[(i+1)%points.size()]
		var before: Vector2 = points[posmod(i-1,points.size())]
		var after: Vector2 = points[(i+2)%points.size()]
		section.start = Vector3(p.x,0,p.y)
		section.end = Vector3(q.x,0,q.y)
		section.before = Vector3(before.x,0,before.y)
		section.after = Vector3(after.x,0,after.y)
		section.curved = true
		definition.sections.append(section)
	return definition

static func preview(track: Node3D, path: String) -> Texture2D:
	# A route-specific map texture is also a lightweight asset for catalogue cards.
	var image: Image = Image.create(320,200,false,Image.FORMAT_RGBA8)
	image.fill(Color("172c29"))
	var bounds: Rect2 = Rect2(track.points[0],Vector2.ZERO)
	for p: Vector2 in track.points: bounds = bounds.expand(p)
	var scale_factor: float = minf(280.0/bounds.size.x,160.0/bounds.size.y)
	var centre: Vector2 = bounds.get_center()
	for i: int in range(int(track.total_length*8.0)):
		var p: Vector2 = (track.sample(float(i)/8.0)-centre)*scale_factor+Vector2(160,100)
		for x: int in range(-2,3):
			for y: int in range(-2,3): image.set_pixel(clampi(int(p.x)+x,0,319),clampi(int(p.y)+y,0,199),Color("e6dca5"))
	var start: Vector2 = (track.sample(track.definition.start_station)-centre)*scale_factor+Vector2(160,100)
	for x: int in range(-4,5):
		for y: int in range(-4,5): image.set_pixel(clampi(int(start.x)+x,0,319),clampi(int(start.y)+y,0,199),Color("ef6546"))
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	assert(ResourceSaver.save(texture,path)==OK)
	texture.take_over_path(path)
	return texture

static func build_entry(id: String, title: String, definition: Resource, environment_path: String, target: Vector2, description: String, order: int) -> void:
	DirAccess.make_dir_recursive_absolute("res://tracks/"+id)
	var track: Node3D = load("res://showcase_track.gd").new()
	track.definition = definition
	track.build()
	assert(track.validation_errors.is_empty(),str(track.validation_errors))
	if id!="game_table":
		assert(ResourceSaver.save(definition,"res://tracks/%s/definition.tres" % id)==OK)
		definition.take_over_path("res://tracks/%s/definition.tres" % id)
		var environment: Node3D = load("res://scripts/tracks/flat_course_art.gd").build(track)
		stamp(environment,environment)
		var packed: PackedScene = PackedScene.new()
		assert(packed.pack(environment)==OK)
		assert(ResourceSaver.save(packed,environment_path)==OK)
		environment.free()
	var entry: Resource = ENTRY.new()
	entry.id = id
	entry.title = title
	entry.cup = "Practice" if id=="practice_patch" else "Casino"
	entry.order_in_cup = order
	entry.route = definition
	entry.environment = load(environment_path)
	entry.preview = preview(track,"res://tracks/%s/preview.res" % id)
	entry.target_lap_seconds = target
	entry.description = description
	assert(ResourceSaver.save(entry,"res://tracks/%s/entry.tres" % id)==OK)
	print("AUTHORED ",id," length=",track.total_length," gates=",track.gates.size())
	track.free()

static func build_all() -> void:
	build_entry("game_table","Blackjack Grand Prix",load("res://tracks/game_table/definition.tres"),"res://environments/casino/blackjack.tscn",Vector2(35,50),"Casino felt · card-shoe jump · three-lap showcase",3)
	var practice: Array[Vector2] = [Vector2(-23,-19),Vector2(0,-19),Vector2(23,-13),Vector2(27,6),Vector2(12,20),Vector2(-9,17),Vector2(-28,6),Vector2(-31,-9)]
	for i: int in range(practice.size()): practice[i] *= 1.3
	build_entry("practice_patch","Practice Patch",route("practice_patch",practice),"res://environments/casino/practice_patch.tscn",Vector2(15,25),"Flat felt · gentle bends · solo practice",0)
	# Monza adaptation: first/second variants, paired Lesmos, Ascari and a long final sweep.
	var sprint: Array[Vector2] = [Vector2(-48,36),Vector2(26,36),Vector2(38,36),Vector2(44,28),Vector2(38,20),Vector2(50,12),Vector2(58,-4),Vector2(50,-22),Vector2(34,-32),Vector2(22,-32),Vector2(18,-23),Vector2(6,-30),Vector2(-12,-38),Vector2(-28,-32),Vector2(-32,-18),Vector2(-25,-8),Vector2(-40,8),Vector2(-46,5),Vector2(-54,16),Vector2(-48,23),Vector2(-60,30),Vector2(-63,44)]
	for i: int in range(sprint.size()): sprint[i] *= 1.5
	var sprint_route: Resource = route("felt_sprint",sprint)
	sprint_route.revision = 2
	build_entry("felt_sprint","Felt Sprint",sprint_route,"res://environments/casino/felt_sprint.tscn",Vector2(35,55),"Flat felt · long straights · three braking chicanes · Monza-inspired",1)
