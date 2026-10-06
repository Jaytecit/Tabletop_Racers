@tool
extends RefCounted
# Rebuild only the route from measured model-space boundaries. Keeps imported art.
static func apply_measurement() -> Dictionary:
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tracks/toys_r_you/measured_route.json"))
	var definition: Resource = load("res://scripts/tracks/track_definition.gd").new()
	definition.id = "toys_r_you"
	definition.revision = 2
	definition.imported_surface = true
	definition.start_station = 0.0
	for i: int in range(58):
		var section: Resource = load("res://scripts/tracks/route_section.gd").new()
		section.id = "toys_%02d" % i
		section.next_id = "toys_%02d" % ((i+1)%58)
		section.surface = "wood"
		section.layer = 1 if i in [44,45,46,47] else 0
		for j: int in range(25):
			var row: Dictionary = rows[(i*24+j)%rows.size()]
			section.center_samples.append(vector(row.center))
			section.left_samples.append(vector(row.left))
			section.right_samples.append(vector(row.right))
		section.start = section.center_samples[0]
		section.end = section.center_samples[24]
		section.before = section.start
		section.after = section.end
		section.width = section.width_at(0.5)
		definition.sections.append(section)
	var track: Node3D = load("res://showcase_track.gd").new()
	track.definition = definition
	track.build()
	var result: Dictionary = {"errors":Array(track.validation_errors),"length":track.total_length}
	if track.validation_errors.is_empty():
		assert(ResourceSaver.save(definition,"res://tracks/toys_r_you/definition.tres")==OK)
		definition.take_over_path("res://tracks/toys_r_you/definition.tres")
		var entry: Resource = load("res://tracks/toys_r_you/entry.tres")
		entry.route = definition
		entry.preview = load("res://scripts/tracks/author_intro_courses.gd").preview(track,"res://tracks/toys_r_you/preview.res")
		assert(ResourceSaver.save(entry,"res://tracks/toys_r_you/entry.tres")==OK)
	track.free()
	return result

static func vector(values: Array) -> Vector3:
	return Vector3(values[0],values[1],values[2])
