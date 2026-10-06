@tool
extends RefCounted
static func check(definition: Resource) -> Dictionary:
	var track: Node3D = load("res://showcase_track.gd").new()
	track.definition = definition
	track.build()
	if not track.validation_errors.is_empty():
		var errors: Array = Array(track.validation_errors)
		track.free()
		return {"errors":errors}
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tracks/beach_buggies/measured_route.json"))
	var failures: Array = []
	var count: int = 0
	var worst: float = 0.0
	for i: int in range(rows.size()):
		var row: Dictionary = rows[i]
		var next: Dictionary = rows[(i+1)%rows.size()]
		var author: Script = load("res://scripts/tracks/author_tabletop.gd")
		var left: Vector3 = author.vector(row.left).lerp(author.vector(next.left),0.5)
		var right: Vector3 = author.vector(row.right).lerp(author.vector(next.right),0.5)
		var station: float = (track.lengths[i]+track.lengths[i+1])*0.5
		for t: float in [0.04,0.5,0.96]:
			var p: Vector3 = left.lerp(right,t)
			var hit: Dictionary = track.project_3d(p,station,2.0)
			count += 1
			if not hit.supported: failures.append({"sample":i,"fraction":t,"kind":"inside"})
		# Both shoulders immediately outside the measured markings must be off-road.
		for t: float in [-0.08,1.08]:
			var p: Vector3 = left.lerp(right,t)
			var hit: Dictionary = track.project_3d(p,station,2.0)
			count += 1
			var in_adjacent: bool = false
			for other: int in range(maxi(0,i-24),mini(rows.size(),i+25)):
				if Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),track.road_polygon(other)): in_adjacent = true
			if hit.supported!=in_adjacent: failures.append({"sample":i,"fraction":t,"kind":"outside union"})
		var edge: PackedVector3Array = track.road_edges(i)
		worst = maxf(worst,minf(edge[0].distance_to(author.vector(row.left)),edge[1].distance_to(author.vector(row.left))))
	track.free()
	return {"checks":count,"failures":failures,"max_boundary_error":worst}
