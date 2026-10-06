extends Node3D
# One bounded mesh/material per car. Vertices and indices are reused; the shader
# ages strips without allocating per-strip nodes, materials or per-frame tweens.
const CAPACITY: int = 128
const LIFETIME: float = 7.0
const OFFSET: float = 0.012
var clock: float = 0.0
var cursor: int = 0
var live: int = 0
var previous: Dictionary = {}
var strips: Array[Dictionary] = []
var mesh: ArrayMesh = ArrayMesh.new()
var material: ShaderMaterial = ShaderMaterial.new()
var vertices: PackedVector3Array = PackedVector3Array()
var colours: PackedColorArray = PackedColorArray()
var uvs: PackedVector2Array = PackedVector2Array()
var births: PackedVector2Array = PackedVector2Array()
var indices: PackedInt32Array = PackedInt32Array()
var drawing: MeshInstance3D

func _ready() -> void:
	material.shader = preload("res://assets/effects/tyre_marks.gdshader")
	material.set_shader_parameter("lifetime",LIFETIME)
	drawing = MeshInstance3D.new()
	drawing.mesh = mesh
	drawing.material_override = material
	drawing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(drawing)
	vertices.resize(CAPACITY*4)
	colours.resize(CAPACITY*4)
	uvs.resize(CAPACITY*4)
	births.resize(CAPACITY*4)
	indices.resize(CAPACITY*6)
	strips.resize(CAPACITY)
	for i: int in range(CAPACITY):
		strips[i] = {}
		var offset: int = i*4
		uvs[offset] = Vector2(0,0)
		uvs[offset+1] = Vector2(1,0)
		uvs[offset+2] = Vector2(0,1)
		uvs[offset+3] = Vector2(1,1)
		for j: int in range(6): indices[i*6+j] = offset+[0,2,1,1,2,3][j]

func age(delta: float) -> void:
	clock += delta
	material.set_shader_parameter("clock",clock)
	live = 0
	for strip: Dictionary in strips:
		if not strip.is_empty() and clock-float(strip.born)<LIFETIME: live += 1
	drawing.visible = live>0

func break_strip() -> void:
	previous.clear()

func clear() -> void:
	break_strip()
	cursor = 0
	live = 0
	clock = 0.0
	vertices.fill(Vector3.ZERO)
	colours.fill(Color(0,0,0,0))
	births.fill(Vector2.ZERO)
	for i: int in range(strips.size()): strips[i] = {}
	mesh.clear_surfaces()
	drawing.hide()

func sample(contacts: Array[Dictionary], strength: float, enabled: bool, width: float, reduced: bool) -> void:
	if not enabled or strength<=0.0:
		break_strip()
		return
	var changed: bool = false
	var seen: Dictionary = {}
	for contact: Dictionary in contacts:
		var id: int = contact.id
		seen[id] = true
		var point: Vector3 = contact.position
		var normal: Vector3 = contact.normal
		var old: Dictionary = previous.get(id,{})
		previous[id] = contact.duplicate()
		if old.is_empty(): continue
		var travel: Vector3 = point-old.position
		# Lost contact, teleports, bridge layers and sharp normal changes cannot join.
		if travel.length()>0.95 or absf(travel.dot(normal))>0.12 or normal.dot(old.normal)<0.85: continue
		if travel.length()<0.06:
			previous[id] = old
			continue
		var side: Vector3 = travel.cross(normal).normalized()*width*0.5
		var base: int = cursor*4
		vertices[base] = to_local(old.position+old.normal*OFFSET-side)
		vertices[base+1] = to_local(old.position+old.normal*OFFSET+side)
		vertices[base+2] = to_local(point+normal*OFFSET-side)
		vertices[base+3] = to_local(point+normal*OFFSET+side)
		for j: int in range(4):
			colours[base+j] = Color(1,1,1,strength*(0.28 if reduced else 0.52))
			births[base+j] = Vector2(clock,0)
		strips[cursor] = {"born":clock,"from":old.position,"to":point,"normal":normal,"wheel":id}
		cursor = (cursor+1)%(64 if reduced else CAPACITY)
		changed = true
	for id: int in previous.keys():
		if not seen.has(id): previous.erase(id)
	if changed:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_COLOR] = colours
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_TEX_UV2] = births
		arrays[Mesh.ARRAY_INDEX] = indices
		mesh.clear_surfaces()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		age(0.0)

func diagnostic_state() -> Dictionary:
	return {"capacity":CAPACITY,"live":live,"connections":previous.size(),"nodes":2,"clock":clock}
