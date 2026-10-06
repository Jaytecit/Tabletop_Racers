@tool
extends RefCounted
const INTRO: Script = preload("res://scripts/tracks/author_intro_courses.gd")
const BEDROOM: Script = preload("res://scripts/tracks/bedroom_art.gd")

static func build_all() -> void:
	# Medium launch, constant-radius carousel, offset double apex, open return.
	var points: Array[Vector2] = [Vector2(-65,-35),Vector2(-20,-35),Vector2(25,-35),Vector2(50,-28),Vector2(68,-10),Vector2(75,15),Vector2(68,40),Vector2(50,58),Vector2(25,65),Vector2(0,58),Vector2(-20,40),Vector2(-35,30),Vector2(-52,40),Vector2(-72,32),Vector2(-85,10),Vector2(-82,-15)]
	for i: int in range(points.size()): points[i] *= 1.25
	var definition: Resource = INTRO.route("carpet_cruise",points)
	definition.start_station = 24.0
	for section: Resource in definition.sections: section.surface = "fabric"
	var track: Node3D = load("res://showcase_track.gd").new()
	track.definition = definition
	track.build()
	assert(track.validation_errors.is_empty(),str(track.validation_errors))
	DirAccess.make_dir_recursive_absolute("res://tracks/carpet_cruise")
	DirAccess.make_dir_recursive_absolute("res://environments/bedroom")
	assert(ResourceSaver.save(definition,"res://tracks/carpet_cruise/definition.tres")==OK)
	definition.take_over_path("res://tracks/carpet_cruise/definition.tres")
	var environment: Node3D = BEDROOM.build(track)
	INTRO.stamp(environment,environment)
	var packed: PackedScene = PackedScene.new()
	assert(packed.pack(environment)==OK)
	assert(ResourceSaver.save(packed,"res://environments/bedroom/carpet_cruise.tscn")==OK)
	var entry: Resource = load("res://scripts/tracks/track_entry.gd").new()
	entry.id = "carpet_cruise"
	entry.title = "Carpet Cruise"
	entry.cup = "Bedroom"
	entry.order_in_cup = 1
	entry.route = definition
	entry.environment = load("res://environments/bedroom/carpet_cruise.tscn")
	entry.preview = INTRO.preview(track,"res://tracks/carpet_cruise/preview.res")
	entry.target_lap_seconds = Vector2(35,45)
	entry.description = "Bedroom · woven carpet · broad carousel · offset double apex"
	assert(ResourceSaver.save(entry,"res://tracks/carpet_cruise/entry.tres")==OK)
	print("CARPET_CRUISE length=",track.total_length," gates=",track.gates.size())
	environment.free()
	track.free()
