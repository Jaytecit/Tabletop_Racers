extends RefCounted
# Geometry shares the endpoints, widths and heights used by vehicle sampling.
static func material(color: Color) -> StandardMaterial3D:
	var result: StandardMaterial3D = StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.9
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	return result

static func quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for vertex: Vector3 in [a,b,c,a,c,d]: tool.add_vertex(vertex)

static func mesh_node(parent: Node, name: String, tool: SurfaceTool, color: Color) -> void:
	tool.generate_normals()
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = name
	node.mesh = tool.commit()
	node.material_override = material(color)
	parent.add_child(node)

static func rebuild(track: Node3D) -> void:
	for child: Node in track.get_children():
		track.remove_child(child)
		child.free()
	var generated: Node3D = Node3D.new()
	generated.name = "Generated"
	track.add_child(generated)
	if track.definition.imported_surface:
		var markers: Node3D = preload("res://scripts/tracks/imported_checkpoint_flags.gd").new()
		markers.name = "CheckpointFlags"
		generated.add_child(markers)
		var debug_script: Script = preload("res://scripts/tracks/route_debug_overlay.gd")
		if debug_script.ENABLED:
			var overlay: Node3D = debug_script.new()
			overlay.name = "RouteDebugOverlay"
			generated.add_child(overlay)
		return
	var chalk: SurfaceTool = SurfaceTool.new()
	chalk.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outline: SurfaceTool = SurfaceTool.new()
	outline.begin(Mesh.PRIMITIVE_TRIANGLES)
	var surfaces: Dictionary = preload("res://scripts/tracks/surface_definition.gd").presets()
	var decks: Dictionary = {}
	for name: String in surfaces:
		var tool: SurfaceTool = SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		decks[name] = {"tool":tool,"count":0}
	for i: int in range(track.starts.size()):
		var section: Resource = track.definition.sections[track.section_ids[i]]
		var a: Vector3 = track.starts[i]
		var b: Vector3 = track.ends[i]
		var na: Vector3 = track.edge_offset(i)
		var nb: Vector3 = track.edge_offset(i+1)
		var w: float = section.width*0.5
		for side: float in [-1.0,1.0]:
			if track.definition.id=="game_table":
				# Flat painted ribbons: the dark border stays readable on pale timber.
				quad(outline,a+na*(w-0.27)*side+Vector3.UP*0.025,b+nb*(w-0.27)*side+Vector3.UP*0.025,b+nb*(w-0.01)*side+Vector3.UP*0.025,a+na*(w-0.01)*side+Vector3.UP*0.025)
				quad(chalk,a+na*(w-0.21)*side+Vector3.UP*0.03,b+nb*(w-0.21)*side+Vector3.UP*0.03,b+nb*(w-0.07)*side+Vector3.UP*0.03,a+na*(w-0.07)*side+Vector3.UP*0.03)
			else:
				quad(chalk,a+na*(w-0.045)*side+Vector3.UP*0.02,b+nb*(w-0.045)*side+Vector3.UP*0.02,b+nb*(w+0.045)*side+Vector3.UP*0.02,a+na*(w+0.045)*side+Vector3.UP*0.02)
		if section.surface!="felt" or ((a.y>0.01 or b.y>0.01) and track.definition.id!="game_table"):
			quad(decks[section.surface].tool,a-na*w,b-nb*w,b+nb*w,a+na*w)
			decks[section.surface].count += 1
		if section.edge=="guarded":
			for side: float in [-1.0,1.0]:
				var wall: StaticBody3D = StaticBody3D.new()
				var shape: CollisionShape3D = CollisionShape3D.new()
				var box: BoxShape3D = BoxShape3D.new()
				box.size = Vector3(a.distance_to(b)+0.04,0.65,0.15)
				shape.shape = box
				wall.position = (a+b)*0.5+(na+nb).normalized()*(w+0.10)*side+Vector3.UP*0.30
				wall.rotation.y = -Vector2(b.x-a.x,b.z-a.z).angle()
				wall.add_child(shape)
				generated.add_child(wall)
	if track.definition.id=="game_table":
		mesh_node(generated,"EdgeOutline",outline,Color("38251b"))
		mesh_node(generated,"ChalkBoundaries",chalk,Color("fff2c2"))
		for edge_name: String in ["EdgeOutline","ChalkBoundaries"]:
			var edge: MeshInstance3D = generated.get_node(edge_name)
			edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			edge.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else: mesh_node(generated,"ChalkBoundaries",chalk,Color("725239") if track.definition.id in ["cereal_slalom","plate_rim","countertop_table","desk_drawer","toybox_trestle"] else Color("e6dca5"))
	for name: String in decks:
		if decks[name].count>0:
			mesh_node(generated,name.capitalize()+"Deck",decks[name].tool,surfaces[name].color)
			if track.definition.id in ["cereal_slalom","plate_rim","countertop_table","desk_drawer","toybox_trestle"] and name in ["wood","paper"]:
				generated.get_node(name.capitalize()+"Deck").material_override = load("res://scripts/tracks/kitchen_art.gd").surface_material(name=="paper")
			if track.definition.id=="game_table" and name=="wood":
				var bridge_material: ShaderMaterial = ShaderMaterial.new()
				bridge_material.shader = load("res://assets/imported/casino/bridge_wood.gdshader")
				generated.get_node("WoodDeck").material_override = bridge_material
			if track.definition.id=="countertop_table" and name=="wood":
				generated.get_node("WoodDeck").material_override = load("res://scripts/tracks/author_countertop.gd").road_material()
			if track.definition.id=="desk_drawer" and name=="paper":
				generated.get_node("PaperDeck").material_override = load("res://scripts/tracks/author_desk.gd").paper_material()
			if track.definition.id=="carpet_cruise" and name=="fabric":
				generated.get_node("FabricDeck").material_override = load("res://scripts/tracks/bedroom_art.gd").carpet_material()
			if track.definition.id=="plate_rim" and name=="wood":
				generated.get_node("WoodDeck").material_override = load("res://scripts/tracks/author_plate_rim.gd").road_material()
			if track.definition.id=="card_bridge":
				generated.get_node(name.capitalize()+"Deck").set_meta("camera_occluder",true)
				generated.get_node(name.capitalize()+"Deck").set_meta("fade_strength",0.98)
	var start: SurfaceTool = SurfaceTool.new()
	start.begin(Mesh.PRIMITIVE_TRIANGLES)
	var gate: Dictionary = track.gates[0]
	var direction: Vector2 = track.direction(gate.station)
	var forward: Vector3 = Vector3(direction.x,0,direction.y)
	var side: Vector3 = Vector3(-direction.y,0,direction.x)
	var p: Vector3 = gate.position+Vector3.UP*0.03
	quad(start,p-side*gate.width*0.5-forward*0.12,p+side*gate.width*0.5-forward*0.12,p+side*gate.width*0.5+forward*0.12,p-side*gate.width*0.5+forward*0.12)
	mesh_node(generated,"StartLine",start,Color("f4e8cb"))

	checkpoint_markers(track,generated)

# Procedural placement stays unchanged; imported courses supply measured placements.
static func checkpoint_markers(track: Node3D, generated: Node3D, placements: Array[Dictionary] = []) -> void:
	var markers: Node3D = Node3D.new()
	markers.name = "CheckpointFlags"
	generated.add_child(markers)
	if placements.is_empty() and not track.definition.imported_surface:
		for checkpoint: Dictionary in track.gates:
			var heading: Vector2 = track.direction(checkpoint.station)
			var normal: Vector3 = Vector3(-heading.y,0,heading.x)
			for side_sign: float in [-1.0,1.0]:
				placements.append({"gate":checkpoint,"side":side_sign,"position":checkpoint.position+normal*(checkpoint.width*0.5+0.45)*side_sign,"elevated":false})
	for placement: Dictionary in placements:
		var checkpoint: Dictionary = placement.gate
		var index: int = checkpoint.index
		var heading: Vector2 = track.direction(checkpoint.station)
		var flag: Node3D = Node3D.new()
		flag.name = "Gate%d_%s" % [index,"Left" if placement.side<0.0 else "Right"]
		flag.position = placement.position
		flag.rotation.y = -heading.angle()
		flag.set_meta("checkpoint",index)
		flag.set_meta("layer",checkpoint.layer)
		flag.set_meta("elevated",placement.elevated)
		markers.add_child(flag)
		if not placement.elevated:
			var pole: MeshInstance3D = MeshInstance3D.new()
			var shaft: CylinderMesh = CylinderMesh.new()
			shaft.top_radius = 0.035
			shaft.bottom_radius = 0.05
			shaft.height = 1.35
			pole.mesh = shaft
			pole.position.y = 0.675
			pole.material_override = material(Color("f4e8cb"))
			flag.add_child(pole)
		var cloth: SurfaceTool = SurfaceTool.new()
		cloth.begin(Mesh.PRIMITIVE_TRIANGLES)
		for vertex: Vector3 in [Vector3(0,1.35,0),Vector3(0,0.85,0),Vector3(0.65,1.1,0)]:
			cloth.add_vertex(vertex-Vector3.UP*1.1 if track.definition.imported_surface else vertex)
		mesh_node(flag,"Pennant",cloth,Color("f4e8cb") if index==0 else Color("f1c44f"))
		if track.definition.imported_surface:
			var pennant: MeshInstance3D = flag.get_node("Pennant")
			pennant.position.y = 1.1
			pennant.rotation.x = -PI/4.0
			pennant.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var number: Label3D = Label3D.new()
		number.text = "FINISH" if index==0 else str(index)
		number.position = Vector3(0,1.65,0)
		number.font_size = 48
		number.pixel_size = 0.009
		number.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		# Checkpoint numbers and FINISH text always respect scenery depth, so a
		# low chase camera can never read them through the track or the room.
		number.no_depth_test = false
		flag.add_child(number)
