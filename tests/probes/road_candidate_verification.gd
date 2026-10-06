extends "res://tests/autopilot/probe_base.gd"
# This probe loads candidates into its disposable instance only. No resource saves.
var candidate: Node3D
var camera: Camera3D
var rows: Array
var manifest: Dictionary
var failures: Array = []

func _enter_tree() -> void:
	# Restore the existing script sidecar mapping before the boot scene loads.
	var uid: int = ResourceUID.text_to_id("uid://144hv5b6kwah")
	if ResourceUID.has_id(uid): ResourceUID.set_id(uid,"res://showcase_track.gd")
	else: ResourceUID.add_id(uid,"res://showcase_track.gd")
	super._enter_tree()
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(func(node: Node) -> void:
		if node.name=="Race" and node.get("profile")!=null:
			node.profile.path = "res://tests/fixtures/race_quality_read_only.json"
		if node.name=="Sequence" and node.get("hardware_input_isolated")!=null:
			node.hardware_input_isolated = true)

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(summer_out_dir)
	await super._ready()
	await settle(3)
	var race: Node3D = get_tree().current_scene.get_node("Race")
	if not race.profile.read_only:
		report("passed",false)
		report("error","Read-only profile was not installed before setup")
		finish()
		return
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	get_tree().current_scene.get_node("Opening").queue_free()
	get_tree().paused = false
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.using_pad = false
	race.controller.device = -1
	race.process_mode = Node.PROCESS_MODE_DISABLED
	race.hide()
	for ui: Node in race.get_children():
		if ui is CanvasLayer: ui.hide()
	# Isolate candidate collision from the unrelated boot course.
	get_tree().current_scene.remove_child(race)
	race.queue_free()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var path: String = ""
	for i: int in range(args.size()-1):
		if args[i]=="--road-candidate": path = args[i+1]
	if path.is_empty():
		report("passed",false)
		report("error","Missing --road-candidate evidence directory")
		finish()
		return
	manifest = JSON.parse_string(FileAccess.get_file_as_string(path+"/measurement_manifest_candidate.json"))
	rows = JSON.parse_string(FileAccess.get_file_as_string(path+"/measured_candidate.json"))
	var result: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path+"/result.json"))
	if not result.get("passed",false) or rows.is_empty() or rows.size()%24!=0:
		report("passed",false)
		report("error","Candidate did not pass source gates")
		finish()
		return
	# Source primitive IDs need an explicit engine mapping when the importer
	# regroups surfaces. The proven path is one selected surface per road node.
	for primitive: Dictionary in manifest.road_primitives:
		if int(primitive.surface)!=0 or primitive.has("triangle_indices"):
			report("passed",false)
			report("error","Rendered probe requires reviewed engine mapping for masked or multi-surface road nodes")
			finish()
			return
	candidate = Node3D.new()
	add_child(candidate)
	var source_path: String = ProjectSettings.localize_path(str(manifest.source).replace("\\","/"))
	if FileAccess.get_sha256(source_path)!=manifest.source_sha256:
		report("passed",false)
		report("error","Source hash changed after extraction")
		finish()
		return
	var raw: Node3D = load(source_path).instantiate()
	var meshes: Array[MeshInstance3D] = []
	var transforms: Array[Transform3D] = []
	var transform: Transform3D = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*manifest.transform.scale),vector(manifest.transform.offset))
	load("res://scripts/tracks/author_toys_r_you.gd").collect(raw,transform,meshes,transforms)
	var selected_vertices: PackedVector3Array = []
	var found: Array[String] = []
	for i: int in range(meshes.size()):
		var source: MeshInstance3D = meshes[i]
		if str(source.name).begins_with("sky_"): continue
		var mesh: MeshInstance3D = MeshInstance3D.new()
		mesh.name = source.name
		mesh.mesh = source.mesh
		mesh.transform = transforms[i]
		if manifest.has("visible_meshes"): mesh.visible = str(source.name) in manifest.visible_meshes
		candidate.add_child(mesh)
		for surface: int in range(mesh.mesh.get_surface_count()):
			var material: Material = source.get_active_material(surface)
			if material != null:
				material = material.duplicate()
				if material is BaseMaterial3D: material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mesh.set_surface_override_material(surface,material)
		if str(source.name) in manifest.road_meshes:
			found.append(str(source.name))
			if mesh.mesh.get_surface_count()!=1:
				failures.append({"gate":"ambiguous_import_surface_mapping","name":str(source.name)})
			mesh.create_trimesh_collision()
			for surface: int in range(mesh.mesh.get_surface_count()):
				var arrays: Array = mesh.mesh.surface_get_arrays(surface)
				for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]: selected_vertices.append(mesh.transform*vertex)
	raw.free()
	for name: String in manifest.road_meshes:
		if name not in found: failures.append({"gate":"selected_import_missing","name":name})
	var landmark_errors: Array = []
	for landmark: Array in manifest.source_landmarks_game:
		var target: Vector3 = vector(landmark)
		var best: float = INF
		for vertex: Vector3 in selected_vertices: best = minf(best,vertex.distance_to(target))
		landmark_errors.append(best)
		if best>manifest.landmark_tolerance: failures.append({"gate":"landmark","target":str(target),"error":best})
	report("import",{"road_meshes":found,"landmark_errors":landmark_errors,"tolerance":manifest.landmark_tolerance})
	var track: Node3D = build_track()
	report("runtime_validation",Array(track.validation_errors))
	if not track.validation_errors.is_empty(): failures.append({"gate":"runtime_validation"})
	await settle_physics(3)
	var support_failures: Array = []
	var support_checks: int = 0
	var containment_failures: Array = []
	var max_height_error: float = 0.0
	var space: PhysicsDirectSpaceState3D = candidate.get_world_3d().direct_space_state
	for i: int in range(rows.size()):
		var row: Dictionary = rows[i]
		# Own centre height, plus near-edge support (actual engine collision).
		for p: Vector3 in [vector(row.center),vector(row.left).lerp(vector(row.center),0.08),vector(row.right).lerp(vector(row.center),0.08)]:
			var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP,p-Vector3.UP,1))
			support_checks += 1
			var error: float = absf(hit.position.y-p.y) if not hit.is_empty() else INF
			if not hit.is_empty(): max_height_error = maxf(max_height_error,error)
			if hit.is_empty() or error>manifest.height_tolerance:
				support_failures.append({"span":i,"point":str(p),"error":error if is_finite(error) else "missing"})
		var next: Dictionary = rows[(i+1)%rows.size()]
		for fraction: float in [0.04,0.5,0.96,-0.08,1.08]:
			var a: Vector3 = vector(row.left).lerp(vector(next.left),0.5)
			var b: Vector3 = vector(row.right).lerp(vector(next.right),0.5)
			var point: Vector3 = a.lerp(b,fraction)
			var expected: bool = fraction>=0.0 and fraction<=1.0
			var station: float = (track.lengths[i]+track.lengths[i+1])*0.5
			var projection: Dictionary = track.project_3d(point,station,2.0)
			if projection.supported != expected:
				containment_failures.append({"span":i,"fraction":fraction})
	report("physical_support",{"checks":support_checks,"tolerance":manifest.height_tolerance,"max_error":max_height_error,"failures":support_failures})
	report("containment",{"checks":rows.size()*5,"failures":containment_failures})
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.far = 1000
	candidate.add_child(camera)
	camera.current = true
	var low: Vector3 = vector(rows[0].left)
	var high: Vector3 = low
	for row: Dictionary in rows:
		for p: Vector3 in [vector(row.left),vector(row.right)]:
			low = low.min(p)
			high = high.max(p)
	var extent: Vector3 = high-low
	var middle: Vector3 = (high+low)*0.5
	var aspect: float = get_viewport().get_visible_rect().size.x/get_viewport().get_visible_rect().size.y
	var overview_size: float = maxf(extent.z,extent.x/aspect)*1.12
	var overview_position: Vector3 = middle+Vector3.UP*(maxf(extent.x,extent.z)+50)
	camera.size = overview_size
	camera.position = overview_position
	camera.rotation_degrees = Vector3(-90,0,0)
	await settle(3)
	save_frame("source_overview")
	var overlay: Node3D = load("res://scripts/tracks/route_debug_overlay.gd").new()
	var overlay_holder: Node3D = Node3D.new()
	candidate.add_child(overlay_holder)
	overlay_holder.add_child(overlay)
	overlay.draw_route(track)
	for mesh: MeshInstance3D in overlay.get_children(): mesh.material_override.no_depth_test = false
	await settle(3)
	save_frame("depth_overview")
	for i: int in range(manifest.section_layers.size()):
		var p: Vector3 = vector(rows[i*24+12].center)
		camera.size = maxf(12.0,vector(rows[i*24+12].left).distance_to(vector(rows[i*24+12].right))*2.5)
		camera.position = p+Vector3(0,35,0)
		await settle(1)
		save_frame("section_%03d" % i)
	for mesh: MeshInstance3D in overlay.get_children(): mesh.material_override.no_depth_test = true
	camera.size = overview_size
	camera.position = overview_position
	await settle(2)
	save_frame("xray_overview")
	report("failures",failures)
	report("passed",failures.is_empty() and support_failures.is_empty() and containment_failures.is_empty())
	report("scope","Candidate import, support, runtime corridor and rendered source comparison; not race/checkpoint acceptance")
	report("render_monitors",{"fps":Performance.get_monitor(Performance.TIME_FPS),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
	finish()

func vector(values: Array) -> Vector3:
	return Vector3(values[0],values[1],values[2])

func build_track() -> Node3D:
	var definition: Resource = load("res://scripts/tracks/track_definition.gd").new()
	definition.id = manifest.id
	definition.imported_surface = true
	for i: int in range(rows.size()/24):
		var section: Resource = load("res://scripts/tracks/route_section.gd").new()
		section.id = "%s_%03d" % [manifest.id,i]
		section.next_id = "%s_%03d" % [manifest.id,(i+1)%(rows.size()/24)]
		section.surface = manifest.section_surfaces[i]
		section.layer = manifest.section_layers[i]
		for step: int in range(25):
			var row: Dictionary = rows[(i*24+step)%rows.size()]
			section.left_samples.append(vector(row.left))
			section.right_samples.append(vector(row.right))
			section.center_samples.append(vector(row.center))
		section.start = section.center_samples[0]
		section.end = section.center_samples[24]
		section.before = section.start
		section.after = section.end
		section.width = section.width_at(0.5)
		definition.sections.append(section)
	var track: Node3D = load("res://showcase_track.gd").new()
	track.definition = definition
	track.build()
	# Geometry queries work without adding generated artwork to the test scene.
	add_child(track)
	track.hide()
	return track
