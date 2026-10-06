@tool
extends RefCounted
static func export_meshes(course_id: String) -> Dictionary:
	var root: Node = load("res://environments/tabletop/%s.tscn" % course_id).instantiate()
	var data: Array = []
	for node: Node in root.get_children():
		if node is MeshInstance3D:
			for surface: int in range(node.mesh.get_surface_count()):
				var arrays: Array = node.mesh.surface_get_arrays(surface)
				var vertices: Array = []
				for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
					var point: Vector3 = node.transform*vertex
					vertices.append([point.x,point.y,point.z])
				data.append({"name":str(node.get_meta("source_mesh_name",node.name)),"surface":surface,"vertices":vertices,"indices":Array(arrays[Mesh.ARRAY_INDEX])})
	var output: String = "res://tests/baselines/content/%s/alignment/imported_mesh_audit_uncompressed.json" % course_id
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(data))
	root.free()
	return {"meshes":data.size(),"path":output}
