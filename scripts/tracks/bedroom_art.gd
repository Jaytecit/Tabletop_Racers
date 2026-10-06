@tool
extends RefCounted
# Original baked bedroom kit; no acquired assets.
const ART: Script = preload("res://scripts/tracks/blackjack_art.gd")
const INTRO: Script = preload("res://scripts/tracks/author_intro_courses.gd")
const BLUE: Color = Color("4ba5c9")
const CORAL: Color = Color("ef6546")

static func carpet_material() -> ShaderMaterial:
	var shader: Shader = Shader.new()
	shader.code = """shader_type spatial;
render_mode cull_disabled;
varying vec2 world;
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xz; }
void fragment() {
	vec2 weave = fract(world * 3.0);
	float fibre = step(0.78,weave.x) * 0.028 + step(0.78,weave.y) * 0.018;
	float seam = max(step(0.98,fract(world.x/9.0)),step(0.98,fract(world.y/9.0)));
	ALBEDO = vec3(0.56,0.32,0.25) + fibre - seam * 0.035;
	ROUGHNESS = 1.0;
}
"""
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	return material

static func blocks(parent: Node3D) -> void:
	for i: int in range(3):
		var pos: Vector3 = Vector3(float(i-1)*1.25,0.65,0)
		ART.box(parent,"ToyBlock",pos,Vector3(1.15,1.3,1.15),[BLUE,CORAL,Color("f1c44f")][i])
		ART.flat_text(parent,"Letter",pos+Vector3.UP*0.66,["A","B","C"][i],0.75,ART.IVORY)
	ART.collider(parent,Vector3(0,0.65,0),Vector3(3.8,1.3,1.2))

static func books(parent: Node3D) -> void:
	for i: int in range(3):
		var pos: Vector3 = Vector3(float(i%2)*0.25,0.14+float(i)*0.35,0)
		ART.box(parent,"Pages",pos,Vector3(3.7,0.28,2.6),ART.IVORY)
		for y: float in [-0.16,0.16]: ART.box(parent,"Cover",pos+Vector3.UP*y,Vector3(4.0,0.06,2.8),BLUE if i%2==0 else CORAL)
	ART.collider(parent,Vector3(0.15,0.55,0),Vector3(4.3,1.1,2.8))

static func spool(parent: Node3D) -> void:
	ART.cylinder(parent,"Thread",Vector3(0,1,0),0.8,1.7,BLUE)
	for y: float in [0.15,1.85]: ART.cylinder(parent,"WoodFlange",Vector3(0,y,0),1.1,0.18,ART.GOLD)
	for i: int in range(8): ART.cylinder(parent,"ThreadRidge",Vector3(0,0.35+float(i)*0.18,0),0.84,0.045,Color("78bed1"))
	ART.collider(parent,Vector3(0,1,0),Vector3(2.2,2,2.2),1.1)

static func button(parent: Node3D, color: Color) -> void:
	ART.cylinder(parent,"Button",Vector3(0,0.08,0),0.35,0.12,color)
	for x: float in [-0.10,0.10]:
		for z: float in [-0.10,0.10]: ART.cylinder(parent,"Hole",Vector3(x,0.145,z),0.045,0.012,ART.INK)
	ART.box(parent,"Fibre",Vector3(0.65,0.035,0),Vector3(0.42,0.04,0.09),ART.GOLD)

static func build(track: Node3D) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "CourseEnvironment"
	root.set_meta("theme","bedroom")
	var bounds: Rect2 = Rect2(track.points[0],Vector2.ZERO)
	for p: Vector2 in track.points: bounds = bounds.expand(p)
	var centre: Vector2 = bounds.get_center()
	var size: Vector2 = bounds.size+Vector2(30,30)
	var floor_group: Node3D = ART.group(root,"CarpetFloor",Vector3(centre.x,0,centre.y))
	var floor_mesh: MeshInstance3D = ART.box(floor_group,"WovenCarpet",Vector3(0,-0.09,0),Vector3(size.x,0.16,size.y),CORAL)
	floor_mesh.material_override = carpet_material()
	ART.collider(floor_group,Vector3(0,-0.09,0),Vector3(size.x,0.16,size.y))
	var cues: Node3D = ART.group(root,"TracksideCues",Vector3.ZERO)
	for i: int in range(int(ceil(track.total_length/3.0))):
		var station: float = float(i)*3.0
		var direction: Vector2 = track.direction(station)
		for side: float in [-1,1]:
			var pos: Vector3 = track.sample_3d(station)+Vector3(-direction.y,0,direction.x)*4.7*side
			if track.project_3d(pos).distance<4.4: continue
			var cue: Node3D = ART.group(cues,"Button%03d_%d"%[i,int(side)],pos)
			cue.set_meta("cue_station",station)
			button(cue,BLUE if i%2==0 else ART.GOLD)
			ART.batch(cue)
	var landmarks: Node3D = ART.group(root,"Landmarks",Vector3.ZERO)
	for i: int in range(int(ceil(track.total_length/14.0))):
		var station: float = float(i)*14.0
		var direction: Vector2 = track.direction(station)
		var pos: Vector3 = track.sample_3d(station)+Vector3(-direction.y,0,direction.x)*10.0*(1.0 if i%2==0 else -1.0)
		if track.project_3d(pos).distance<8.0: continue
		var prop: Node3D = ART.group(landmarks,"BedroomSector%02d"%i,pos)
		prop.rotation.y = -direction.angle()
		match i%3:
			0: blocks(prop)
			1: books(prop)
			2: spool(prop)
		ART.batch(prop)
	ART.build_guidance(root,track)
	return root
