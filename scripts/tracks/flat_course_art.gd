@tool
extends RefCounted
# Shared casino kit for flat introductory layouts; authored from the real route.
const ART: Script = preload("res://scripts/tracks/blackjack_art.gd")

static func build(track: Node3D) -> Node3D:
	var environment: Node3D = Node3D.new()
	environment.name = "CourseEnvironment"
	var support: Node = load("res://environments/shared/felt_table.tscn").instantiate()
	# Bake support once; do not serialize its inherited children as scene overrides.
	support.scene_file_path = ""
	environment.add_child(support)
	if track.definition.id in ["felt_sprint","card_bridge"]:
		var table: StaticBody3D = support.get_node("FeltTable")
		var top: MeshInstance3D = table.get_node("Mesh")
		top.mesh = top.mesh.duplicate()
		var bounds: Rect2 = Rect2(track.points[0],Vector2.ZERO)
		for point: Vector2 in track.points: bounds = bounds.expand(point)
		var extent: Vector2 = bounds.position.abs().max(bounds.end.abs())*2.0+Vector2(28,28)
		top.mesh.size = Vector3(extent.x,0.08,extent.y)
		var collision: CollisionShape3D = table.get_child(0)
		collision.shape = collision.shape.duplicate()
		collision.shape.size = top.mesh.size
		var rim: MeshInstance3D = support.get_node("TableEdge")
		rim.mesh = rim.mesh.duplicate()
		rim.mesh.size = Vector3(top.mesh.size.x+1.0,0.9,top.mesh.size.z+1.0)
	# The baked legacy start label belongs to Blackjack's old editor pose.
	for child: Node in support.get_children():
		if child is Label3D: child.free()
	var landmarks: Node3D = ART.group(environment,"Landmarks",Vector3.ZERO)
	var cues: Node3D = ART.group(environment,"TracksideCues",Vector3.ZERO)
	for i: int in range(int(ceil(track.total_length/3.0))):
		var station: float = float(i)*3.0
		var point: Vector3 = track.sample_3d(station)
		var direction: Vector2 = track.direction(station)
		var normal: Vector3 = Vector3(-direction.y,0,direction.x)
		for side: float in [-1.0,1.0]:
			var position: Vector3 = point+normal*4.6*side
			if track.at(station).layer>0: position.y = 0.0
			if track.project_3d(position).distance<4.4: continue
			var cue: Node3D = ART.group(cues,"Chip%03d_%d" % [i,int(side)],position)
			cue.set_meta("cue_station",station)
			ART.chips(cue,Vector3.ZERO,ART.RED if i%2==0 else ART.GOLD,1,0.28)
			ART.batch(cue)
	for i: int in range(8):
		var station: float = track.total_length*float(i)/8.0
		var direction: Vector2 = track.direction(station)
		var normal: Vector3 = Vector3(-direction.y,0,direction.x)
		var position: Vector3 = track.sample_3d(station)+normal*8.5*(1.0 if i%2==0 else -1.0)
		if track.definition.id=="card_bridge": position.y = 0.0
		if track.project_3d(position).distance<6.8: continue
		var sector: Node3D = ART.group(landmarks,"Sector%d" % i,position)
		sector.rotation.y = -direction.angle()
		match i%4:
			0:
				ART.chips(sector,Vector3.ZERO,ART.RED,7)
				ART.chips(sector,Vector3(2,0,1),Color("4ba5c9"),4)
			1:
				ART.card(sector,Vector3.ZERO,0.2,0,2.8)
				ART.card(sector,Vector3(0.8,0.05,1.0),-0.1,1,2.8)
			2: ART.drink(sector,Vector3.ZERO)
			3: ART.cash(sector,Vector3.ZERO,0.2)
		ART.flat_text(sector,"SectorPrint",Vector3(0,0.02,-2.4),"PRACTICE" if track.definition.id=="practice_patch" else ("CARD BRIDGE" if track.definition.id=="card_bridge" else "FELT SPRINT"),0.55,ART.GOLD)
		ART.batch(sector)
	ART.build_guidance(environment,track)
	return environment
