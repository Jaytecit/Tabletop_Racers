extends Node3D
# Temporary route inspection. Set ENABLED false to remove it on the next rebuild.
# Uses the same sampled polygons as track containment; never moves them to the GLB.
const ENABLED: bool = false

func _ready() -> void:
	var track: Node3D = get_parent().get_parent()
	if ENABLED: draw_route(track)

func ribbon(tool: SurfaceTool, a: Vector3, b: Vector3, width: float) -> void:
	var delta: Vector3 = b-a
	var normal: Vector3 = Vector3(-delta.z,0,delta.x).normalized()*width*0.5
	var lift: Vector3 = Vector3.UP*0.06
	for p: Vector3 in [a-normal,b-normal,b+normal,a-normal,b+normal,a+normal]:
		tool.add_vertex(p+lift)

func draw_route(track: Node3D) -> void:
	var left: SurfaceTool = SurfaceTool.new()
	var right: SurfaceTool = SurfaceTool.new()
	var centre: SurfaceTool = SurfaceTool.new()
	for tool: SurfaceTool in [left,right,centre]: tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(track.starts.size()):
		var edge_a: PackedVector3Array = track.road_edges(i)
		var edge_b: PackedVector3Array = track.road_edges(i+1)
		var a: Vector3 = track.starts[i]
		var b: Vector3 = track.ends[i]
		ribbon(left,edge_a[0],edge_b[0],0.08)
		ribbon(right,edge_a[1],edge_b[1],0.08)
		if int(track.lengths[i]/0.8)%2==0: ribbon(centre,a,b,0.07)
	var tools: Array[SurfaceTool] = [left,right,centre]
	var names: Array[String] = ["CyanEdge","MagentaEdge","YellowCentreline"]
	var colors: Array[Color] = [Color("00ffff"),Color("ff36cf"),Color("ffff00")]
	for i: int in range(tools.size()):
		tools[i].generate_normals()
		var mesh: MeshInstance3D = MeshInstance3D.new()
		mesh.name = names[i]
		mesh.mesh = tools[i].commit()
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = colors[i]
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		# X-ray display keeps a below-surface mismatch visible.
		material.no_depth_test = true
		material.render_priority = 100
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mesh)
