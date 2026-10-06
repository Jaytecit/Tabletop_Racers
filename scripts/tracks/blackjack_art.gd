extends RefCounted
# Original blackjack props, baked by the editor. Shared palette and batched geometry.
const BUILDER = preload("res://scripts/tracks/track_builder.gd")
const BACK = preload("res://assets/blackjack/card_back.svg")
const ACE = preload("res://assets/blackjack/ace_spades.svg")
const SEVEN = preload("res://assets/blackjack/seven_hearts.svg")
const IVORY: Color = Color("f4e8cb")
const INK: Color = Color("172c29")
const GOLD: Color = Color("d3ac69")
const RED: Color = Color("bf493d")

static func group(parent: Node, title: String, position: Vector3) -> Node3D:
	var node: Node3D = Node3D.new()
	node.name = title
	node.position = position
	parent.add_child(node)
	return node

static func shape(parent: Node, title: String, mesh: PrimitiveMesh, pos: Vector3, color: Color) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = title
	node.mesh = mesh
	node.position = pos
	node.material_override = BUILDER.material(color)
	parent.add_child(node)
	return node

static func box(parent: Node, title: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	return shape(parent,title,mesh,pos,color)

static func cylinder(parent: Node, title: String, pos: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	return shape(parent,title,mesh,pos,color)

static func flat_text(parent: Node, title: String, pos: Vector3, text: String, size: float, color: Color = IVORY) -> Label3D:
	var node: Label3D = Label3D.new()
	node.name = title
	node.position = pos
	node.rotation_degrees.x = -90
	node.text = text
	node.font_size = 64
	node.font = load("res://assets/arcade/arcade_font.fnt")
	node.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	node.pixel_size = size/64.0
	node.modulate = color
	node.outline_size = 0
	parent.add_child(node)
	return node

static func card(parent: Node, pos: Vector3, angle: float, face: int = -1, width: float = 2.4) -> Node3D:
	var node: Node3D = group(parent,"FaceDownCard" if face<0 else "CompleteFaceCard",pos)
	node.rotation.y = angle
	box(node,"PaperEdge",Vector3.ZERO,Vector3(width,0.045,width*1.4),IVORY)
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(width,width*1.4)
	var top: MeshInstance3D = shape(node,"PrintedFace",plane,Vector3(0,0.025,0),IVORY)
	top.material_override.albedo_texture = BACK if face<0 else (ACE if face==0 else SEVEN)
	top.material_override.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	top.set_meta("card_face","back" if face<0 else ("ace_spades" if face==0 else "seven_hearts"))
	return node

static func collider(parent: Node, pos: Vector3, size: Vector3, radius: float = -1.0) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "PropCollision"
	body.position = pos
	body.collision_mask = 2
	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	if radius>0.0:
		var cylinder_shape: CylinderShape3D = CylinderShape3D.new()
		cylinder_shape.radius = radius
		cylinder_shape.height = size.y
		collision_shape.shape = cylinder_shape
	else:
		var box_shape: BoxShape3D = BoxShape3D.new()
		box_shape.size = size
		collision_shape.shape = box_shape
	body.add_child(collision_shape)
	parent.add_child(body)

static func chips(parent: Node, pos: Vector3, color: Color, count: int = 5, radius: float = 0.85) -> void:
	collider(parent,pos+Vector3.UP*float(count)*0.10,Vector3(radius*2,float(count)*0.20,radius*2),radius)
	for i: int in range(count):
		var y: float = pos.y+0.10+float(i)*0.20
		cylinder(parent,"Chip",Vector3(pos.x,y,pos.z),radius,0.18,color)
		for tick: int in range(8):
			var angle: float = float(tick)*TAU/8.0
			var stripe: MeshInstance3D = box(parent,"EdgeInsert",Vector3(pos.x+cos(angle)*radius*0.85,y,pos.z+sin(angle)*radius*0.85),Vector3(radius*0.25,0.19,radius*0.20),IVORY)
			stripe.rotation.y = -angle
	cylinder(parent,"ChipInset",pos+Vector3.UP*(float(count)*0.2+0.005),radius*0.63,0.014,IVORY)
	cylinder(parent,"ChipCentre",pos+Vector3.UP*(float(count)*0.2+0.015),radius*0.49,0.014,color)
	if radius>0.5:
		flat_text(parent,"ChipValue",pos+Vector3.UP*(float(count)*0.2+0.036),"25" if color==RED else "100",radius*0.60,IVORY)

static func drink(parent: Node, pos: Vector3) -> void:
	collider(parent,pos+Vector3.UP*0.70,Vector3(1.6,1.4,1.6),0.8)
	cylinder(parent,"Coaster",pos+Vector3.UP*0.04,1.1,0.08,INK)
	var coaster_rim: TorusMesh = TorusMesh.new()
	coaster_rim.inner_radius = 0.98
	coaster_rim.outer_radius = 1.07
	coaster_rim.rings = 16
	coaster_rim.ring_segments = 6
	shape(parent,"CoasterGoldRim",coaster_rim,pos+Vector3.UP*0.09,GOLD)
	cylinder(parent,"GlassBase",pos+Vector3.UP*0.18,0.8,0.22,Color("4ba5c9"))
	cylinder(parent,"AmberDrink",pos+Vector3.UP*0.75,0.72,1.05,Color("c37d63"))
	var rim: TorusMesh = TorusMesh.new()
	rim.inner_radius = 0.66
	rim.outer_radius = 0.81
	rim.rings = 16
	rim.ring_segments = 12
	shape(parent,"GlassRim",rim,pos+Vector3.UP*1.34,IVORY)
	for offset: Vector3 in [Vector3(-0.25,1.24,0.1),Vector3(0.23,1.24,-0.15)]:
		var ice: MeshInstance3D = box(parent,"IceCube",pos+offset,Vector3(0.38,0.24,0.38),Color("b2d4cd"))
		ice.rotation.y = 0.5

static func cash(parent: Node, pos: Vector3, angle: float = 0.0) -> void:
	var note: Node3D = group(parent,"Banknotes",pos)
	note.rotation.y = angle
	box(note,"PaperStack",Vector3(0,0.13,0),Vector3(3.4,0.25,1.65),IVORY)
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(3.4,1.65)
	var face: MeshInstance3D = shape(note,"EngravedBanknote",plane,Vector3(0,0.26,0),IVORY)
	face.material_override.albedo_texture = load("res://assets/arcade/banknote.svg")
	face.material_override.albedo_color = Color.WHITE
	face.material_override.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	for edge: int in range(3):
		box(note,"PaperLayers",Vector3(0,0.05+float(edge)*0.075,0.83),Vector3(3.3,0.016,0.01),GOLD)

static func ashtray(parent: Node, pos: Vector3) -> void:
	collider(parent,pos+Vector3.UP*0.18,Vector3(2.6,0.36,2.6),1.3)
	cylinder(parent,"AshtrayBase",pos+Vector3.UP*0.13,1.3,0.25,Color("4ba5c9"))
	cylinder(parent,"AshWell",pos+Vector3.UP*0.27,0.93,0.03,INK)
	var rim: TorusMesh = TorusMesh.new()
	rim.inner_radius = 0.94
	rim.outer_radius = 1.34
	rim.rings = 24
	rim.ring_segments = 8
	shape(parent,"AshtrayRim",rim,pos+Vector3.UP*0.30,Color("b2d4cd"))
	var cigarette: MeshInstance3D = box(parent,"Cigarette",pos+Vector3(0.7,0.42,0),Vector3(1.25,0.13,0.13),IVORY)
	cigarette.rotation.y = 0.4
	box(parent,"Filter",pos+Vector3(1.12,0.44,-0.17),Vector3(0.35,0.14,0.14),GOLD)
	for i: int in range(5):
		cylinder(parent,"Ash",pos+Vector3(float(i%3)*0.20-0.35,0.30,floorf(float(i)/3.0)*0.25-0.1),0.09,0.035,Color("c37d63"))

static func shoe(parent: Node, pos: Vector3) -> void:
	var node: Node3D = group(parent,"CardShoe",pos)
	collider(node,Vector3(0,0.7,0),Vector3(3.2,1.4,5.3))
	box(node,"Base",Vector3(0,0.18,0),Vector3(3.2,0.36,5.3),INK)
	for side: float in [-1.0,1.0]:
		var wall: MeshInstance3D = box(node,"ShoeWall",Vector3(side*1.5,0.7,0),Vector3(0.2,1.3,5.3),GOLD)
		wall.material_override = preload("res://scripts/tracks/blackjack_surface.gd").wood_material()
		box(node,"BrassRim",Vector3(side*1.5,1.36,0),Vector3(0.24,0.08,5.3),GOLD)
	box(node,"RearStop",Vector3(0,0.75,-2.55),Vector3(3.0,1.2,0.18),INK)
	box(node,"SixDecks",Vector3(0,0.55,-0.45),Vector3(2.5,0.7,3.5),IVORY)
	card(node,Vector3(0,0.92,-0.45),0,-1,2.5)
	card(node,Vector3(0,0.38,2.0),0,-1,2.5)

# Bake same-colour primitives together per landmark so camera fading stays local.
static func batch(node: Node3D) -> void:
	var groups: Dictionary = {}
	for child: Node in node.get_children():
		if child is Node3D and not child is MeshInstance3D: batch(child)
		if not child is MeshInstance3D: continue
		var mesh: MeshInstance3D = child
		if not mesh.material_override is StandardMaterial3D: continue
		var mat: StandardMaterial3D = mesh.material_override
		if mat.albedo_texture!=null: continue
		var key: String = mat.albedo_color.to_html()
		if not groups.has(key): groups[key] = {"tool":SurfaceTool.new(),"nodes":[],"mat":mat}
		groups[key].nodes.append(mesh)
		groups[key].tool.append_from(mesh.mesh,0,mesh.transform)
	for key: String in groups:
		var entry: Dictionary = groups[key]
		var merged: MeshInstance3D = MeshInstance3D.new()
		merged.name = "Batch_"+key
		merged.mesh = entry.tool.commit()
		merged.material_override = entry.mat
		node.add_child(merged)
		for old: Node in entry.nodes:
			node.remove_child(old)
			old.free()

static func build(root: Node3D, track: Node3D) -> Node3D:
	var art: Node3D = group(root,"BlackjackEnvironment",Vector3.ZERO)
	art.set_meta("theme","blackjack")
	build_felt_details(art,track)
	# Route-aligned sets sit outside the widest road plus a generous shoulder.
	var landmark_count: int = maxi(24,int(ceil(track.total_length/12.0)))
	for i: int in range(landmark_count):
		var station: float = float(i)*track.total_length/float(landmark_count)
		var point: Vector3 = track.sample_3d(station)
		var tangent: Vector2 = track.direction(station)
		var normal: Vector3 = Vector3(-tangent.y,0,tangent.x)
		var side_sign: float = -1.0 if i%2==0 else 1.0
		var position: Vector3 = point+normal*(8.5 if track.definition.revision>=4 else 6.5)*side_sign
		position.y = 0.0
		# Reject locations near any other route sector, including the jump.
		if track.project_3d(position).distance<5.7: continue
		var sector: Node3D = group(art,"Landmark%02d"%i,position)
		sector.rotation.y = -tangent.angle()+(PI if side_sign<0.0 else 0.0)
		match i%6:
			0:
				chips(sector,Vector3(-1,0,0),RED,7)
				chips(sector,Vector3(1,0,1),Color("4ba5c9"),4)
				card(sector,Vector3(0,0.03,2.4),0.25,0)
			1:
				cash(sector,Vector3.ZERO,0.2)
				chips(sector,Vector3(0,0,2),INK,3)
			2:
				drink(sector,Vector3.ZERO)
				ashtray(sector,Vector3(2.8,0,0))
			3:
				card(sector,Vector3(-1.3,0.035,0),-0.15,0)
				card(sector,Vector3(1.3,0.04,0.5),0.15,1)
				card(sector,Vector3(0,0.08,2.8),0.30)
			4:
				shoe(sector,Vector3.ZERO)
				chips(sector,Vector3(2.7,0,0),RED,6)
			5:
				chips(sector,Vector3(-1,0,0),Color("86bb5b"),5)
				drink(sector,Vector3(1.6,0,1.4))
		# Low felt prints remain legible when a hero prop fades.
		flat_text(sector,"BettingSpot",Vector3(0,0.015,-2.3),"BLACKJACK  •  BET "+str((i+1)*5),0.48,GOLD)
		batch(sector)

	# Ground-level casino cues at both shoulders connect the landmark sectors.
	var shoulder: Node3D = group(art,"ShoulderChips",Vector3.ZERO)
	for step: int in range(int(track.total_length/3.0)):
		var station: float = float(step)*3.0
		var point: Vector3 = track.sample_3d(station)
		var tangent: Vector2 = track.direction(station)
		var normal: Vector3 = Vector3(-tangent.y,0,tangent.x)
		if point.y>0.02: continue
		for side_sign: float in [-1.0,1.0]:
			var pos: Vector3 = point+normal*4.15*side_sign
			if track.project_3d(pos).distance<3.6: continue
			cylinder(shoulder,"LooseChip",pos+Vector3.UP*0.08,0.30,0.12,RED if step%2==0 else GOLD)
			cylinder(shoulder,"CentreSpot",pos+Vector3.UP*0.15,0.18,0.01,IVORY)
	batch(shoulder)
	var felt: Node3D = group(art,"BlackjackFeltPrint",Vector3(4,0.015,1))
	flat_text(felt,"TableTitle",Vector3.ZERO,"BLACKJACK",3.5,GOLD)
	flat_text(felt,"TableRules",Vector3(0,0,4),"PAYS 3 TO 2",1.3,IVORY)
	flat_text(felt,"DealerRule",Vector3(0,0,6),"DEALER STANDS ON 17",0.80,GOLD)
	# Replace spool support with casino chip columns beneath the existing ramp.
	var support: Node3D = group(art,"ChipRampSupport",Vector3(-6.05,0,-29.166667))
	for z: float in [-2.35,2.35]:
		chips(support,Vector3(0,0,z),INK,4,0.65)
	batch(support)

	# A full face-down card sits on the wooden shoe ramp; physics stays authored.
	var ramp: Node3D = group(art,"ShoeRamp",Vector3.ZERO)
	var start: Vector3 = Vector3(-10.75,0.057,-29.166667)
	var end: Vector3 = Vector3(-4.75,1.257,-29.166667)
	var ramp_normal: Vector3 = Vector3(0,0,2.185)
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vertices: Array[Vector3] = [start-ramp_normal,start+ramp_normal,end+ramp_normal,start-ramp_normal,end+ramp_normal,end-ramp_normal]
	var uvs: Array[Vector2] = [Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2(0,1),Vector2(1,0),Vector2(0,0)]
	for i: int in range(6):
		tool.set_uv(uvs[i])
		tool.add_vertex(vertices[i])
	tool.generate_normals()
	var card_top: MeshInstance3D = MeshInstance3D.new()
	card_top.name = "CompleteCardBack"
	card_top.mesh = tool.commit()
	card_top.material_override = BUILDER.material(IVORY)
	card_top.material_override.albedo_texture = BACK
	card_top.material_override.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	card_top.set_meta("card_face","back")
	ramp.add_child(card_top)
	for side: float in [-1.0,1.0]:
		var trim: MeshInstance3D = box(ramp,"ShoeTrim",Vector3(-7.75,0.68,-29.166667+side*3.12),Vector3(6.12,0.12,0.16),INK)
		trim.rotation.z = atan(0.2)
	batch(ramp)
	build_guidance(art,track)
	return art

static func build_felt_details(art: Node3D, track: Node3D) -> void:
	# Flat artwork fills the visible shoulder; large solid props retain their safe offsets.
	var felt_details: Node3D = group(art,"NearFeltDetails",Vector3.ZERO)
	var ink: StandardMaterial3D = BUILDER.material(Color.WHITE)
	ink.albedo_texture = load("res://assets/arcade/betting_spot.svg")
	ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	ink.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	for index: int in range(int(ceil(track.total_length/9.0))):
		var station: float = float(index)*9.0
		var point: Vector3 = track.sample_3d(station)
		if point.y>0.02: continue
		var direction: Vector2 = track.direction(station)
		var normal: Vector3 = Vector3(-direction.y,0,direction.x)
		var position: Vector3 = point+normal*5.5*(1.0 if index%2==0 else -1.0)
		if track.project_3d(position).distance<4.6: continue
		var spot: Node3D = group(felt_details,"BettingPrint%02d" % index,position)
		spot.rotation.y = -direction.angle()
		if index%3==1:
			var face: Node3D = card(spot,Vector3(0,0.02,0),0.12,0 if index%2==0 else 1,2.4)
			for child: Node in face.get_children():
				if child is GeometryInstance3D: child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		else:
			var plane: PlaneMesh = PlaneMesh.new()
			plane.size = Vector2(2.8,2.8)
			var print_mesh: MeshInstance3D = shape(spot,"FeltInk",plane,Vector3(0,0.024,0),Color.WHITE)
			print_mesh.material_override = ink
			print_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func build_guidance(art: Node3D, track: Node3D) -> Node3D:
	var old: Node = art.get_node_or_null("RouteGuidance")
	if old!=null:
		art.remove_child(old)
		old.free()
	var guidance: Node3D = group(art,"RouteGuidance",Vector3.ZERO)
	var tools: Dictionary = {}
	for step: int in range(int(ceil(track.total_length/3.0))):
		var station: float = fposmod(float(step)*3.0+1.5,track.total_length)
		# This S-bend warning precedes the card shoe that occludes the regular position.
		if track.definition.id=="game_table" and track.definition.revision<=3 and step==31: station = 184.5
		var point: Vector3 = track.sample_3d(station)
		var direction: Vector2 = track.direction(station)
		var turn: float = direction.angle_to(track.direction(station+13.0))
		# Keep a warning through the bend's exit, including S-curves whose net angle cancels.
		for ahead: float in [3.9,6.5,9.1]:
			var candidate: float = direction.angle_to(track.direction(station+ahead))
			if absf(candidate)>absf(turn): turn = candidate
		var local_turn: float = track.direction(station-4.0).angle_to(track.direction(station+4.0))
		if absf(local_turn)>absf(turn): turn = local_turn
		var jump: bool = false
		for ahead: float in [0.0,3.9,6.5,9.1,13.0]:
			var section: Resource = track.definition.sections[track.at(station+ahead).section]
			if section.jump_exit: jump = true
		if absf(turn)<0.18 and not jump: continue
		# Flat ink on felt; never imply a second raised ramp beside the real one.
		if point.y>0.02 and not jump and track.definition.id not in ["plate_rim","countertop_table","desk_drawer","toybox_trestle"]: continue
		var normal: Vector3 = Vector3(-direction.y,0,direction.x)
		for side: int in [-1,1]:
			var pos: Vector3 = point+normal*4.5*side
			pos.y = point.y+0.025 if track.definition.id in ["plate_rim","countertop_table","desk_drawer","toybox_trestle"] else 0.025
			if track.project_3d(pos).distance<4.1: continue
			var marker: Node3D = group(guidance,"Jump%03d_%d"%[step,side] if jump else "Turn%03d_%d"%[step,side],pos)
			marker.rotation.y = -direction.angle()
			marker.set_meta("scenery_cue",{"id":str(marker.name),"kind":"jump" if jump else "turn","radius":0.70,"station":station,"turn_sign":signf(turn)})
			if jump:
				# Side-view ramp silhouette plus detached landing line: readable without colour.
				var ramp: SurfaceTool = SurfaceTool.new()
				ramp.begin(Mesh.PRIMITIVE_TRIANGLES)
				for vertex: Vector3 in [Vector3(-0.58,0.009,0.30),Vector3(0.12,0.009,0.30),Vector3(0.12,0.009,-0.30)]: ramp.add_vertex(vertex)
				ramp.generate_normals()
				# append_from must receive indexed triangles when mixed with indexed boxes.
				ramp.index()
				var silhouette: MeshInstance3D = MeshInstance3D.new()
				silhouette.name = "RampSymbol"
				silhouette.mesh = ramp.commit()
				silhouette.material_override = BUILDER.material(IVORY)
				silhouette.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
				silhouette.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				marker.add_child(silhouette)
				box(marker,"LandingMark",Vector3(0.47,0.009,0.30),Vector3(0.28,0.008,0.13),IVORY)
			else:
				# Turn arrow points to the actual upcoming side relative to the approach.
				var side_direction: float = signf(turn)
				box(marker,"ArrowStem",Vector3(-0.16,0.009,0),Vector3(0.65,0.008,0.18),GOLD)
				box(marker,"ArrowBend",Vector3(0.16,0.009,side_direction*0.18),Vector3(0.18,0.008,0.52),GOLD)
				for wing: int in [-1,1]:
					var bar: MeshInstance3D = box(marker,"ArrowHead",Vector3(0.16+wing*0.12,0.009,side_direction*0.34),Vector3(0.40,0.008,0.17),GOLD)
					bar.rotation.y = side_direction*wing*PI/4.0
			# Shared draw meshes for the whole circuit, with logical marker IDs retained.
			for mesh: MeshInstance3D in marker.get_children():
				var color: Color = mesh.material_override.albedo_color
				var key: String = color.to_html()
				if not tools.has(key):
					var tool: SurfaceTool = SurfaceTool.new()
					tool.begin(Mesh.PRIMITIVE_TRIANGLES)
					tools[key] = {"tool":tool,"material":mesh.material_override}
				tools[key].tool.append_from(mesh.mesh,0,marker.transform*mesh.transform)
				marker.remove_child(mesh)
				mesh.free()
	for key: String in tools:
		var mesh: MeshInstance3D = MeshInstance3D.new()
		mesh.name = "Ink_"+key
		mesh.mesh = tools[key].tool.commit()
		mesh.material_override = tools[key].material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		guidance.add_child(mesh)
	return guidance


static func standardize_cards(node: Node) -> void:
	# Baked environment packs and runtime shoulder cards use the same deck scale.
	if node.has_node("PaperEdge") and node.has_node("PrintedFace"):
		var edge: MeshInstance3D = node.get_node("PaperEdge")
		var face: MeshInstance3D = node.get_node("PrintedFace")
		edge.mesh = edge.mesh.duplicate()
		edge.mesh.size = Vector3(2.4,0.045,3.36)
		face.mesh = face.mesh.duplicate()
		face.mesh.size = Vector2(2.4,3.36)
	for child: Node in node.get_children(): standardize_cards(child)
