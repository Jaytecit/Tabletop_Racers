extends RefCounted
const OFFSET: Vector3 = Vector3(3.5,15.0,10.0)
const MODES: Array[String] = ["CHASE","OVERHEAD","CLOSE CHASE"]
const DEFAULT_MODE: int = 0
const DEFAULTS_VERSION: int = 1
const CLOSE_DISTANCE: float = 4.8
const CLOSE_HEIGHT: float = 1.8
const CLOSE_SIZE: float = 10.5
# Perspective fields of view per mode. The chase cameras sit far from the car,
# so they take a long lens; the close chase sits on its tail and needs a wide one.
const CHASE_FOV: float = 42.0
const OVERHEAD_FOV: float = 46.0
const CLOSE_FOV: float = 68.0
var mode: int = DEFAULT_MODE
var focus: Vector3 = Vector3.ZERO
var lead: Vector3 = Vector3.ZERO
var preview_elapsed: float = -1.0
var occluders: Array[MeshInstance3D] = []
var feedback_offset: Vector3 = Vector3.ZERO
var feedback_shape: SphereShape3D = SphereShape3D.new()
var clearance_shape: SphereShape3D = SphereShape3D.new()
var clearance_adjustments: int = 0

func collect(node: Node) -> void:
	if node is MeshInstance3D and not node.get_meta("camera_occlusion_exempt",false) and (node.get_aabb().size.y>0.6 or node.get_meta("camera_occluder",false)): occluders.append(node)
	for child: Node in node.get_children(): collect(child)

func configure(race: Node3D) -> void:
	clear()
	for prop_name: String in ["CourseEnvironment","BlackjackEnvironment"]:
		var prop: Node = race.get_node_or_null(prop_name)
		if prop!=null: collect(prop)
	if race.track.definition.id=="card_bridge": collect(race.track)

func clear() -> void:
	for mesh: MeshInstance3D in occluders:
		if is_instance_valid(mesh): mesh.transparency = 0.0
	occluders.clear()

func reset(camera: Camera3D, car: CharacterBody3D) -> void:
	feedback_offset = Vector3.ZERO
	preview_elapsed = -1.0
	# Every driving mode stays perspective. An orthographic chase or overhead
	# view reads as flat: parallel lines never converge and nothing changes size
	# with distance, so the picture loses all depth cues.
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = CLOSE_FOV if mode==2 else (OVERHEAD_FOV if mode==1 else CHASE_FOV)
	camera.near = 0.05
	camera.far = 400.0 if mode==2 else 150.0
	focus = car.position
	lead = Vector3.ZERO
	place_camera(camera,car,0.0,true)
	for mesh: MeshInstance3D in occluders:
		if is_instance_valid(mesh): mesh.transparency = 0.0

func tick(camera: Camera3D, car: CharacterBody3D, delta: float) -> void:
	camera.position -= feedback_offset
	feedback_offset = Vector3.ZERO
	var target: Vector3 = car.safe_position if car.state==3 else car.position
	target.y = maxf(target.y,0.0)
	var velocity_lead: Vector3 = Vector3(car.velocity.x,0,car.velocity.z)*0.20 if car.state==0 else Vector3.ZERO
	lead = lead.lerp(velocity_lead.limit_length(3.2),1.0-exp(-3.5*delta))
	focus.x = lerpf(focus.x,target.x,1.0-exp(-7.0*delta))
	focus.z = lerpf(focus.z,target.z,1.0-exp(-7.0*delta))
	focus.y = lerpf(focus.y,target.y,1.0-exp(-3.0*delta))
	place_camera(camera,car,delta)
	for mesh: MeshInstance3D in occluders:
		if not is_instance_valid(mesh): continue
		var bounds: AABB = mesh.global_transform*mesh.get_aabb()
		var obscures: bool = mode!=2 and bounds.grow(0.20).intersects_segment(camera.global_position,car.global_position+Vector3(0,0.35,0))!=null
		mesh.transparency = move_toward(mesh.transparency,float(mesh.get_meta("fade_strength",0.75)) if obscures else 0.0,delta*4.0)

func cycle(camera: Camera3D, car: CharacterBody3D) -> void:
	mode = (mode+1)%MODES.size()
	reset(camera,car)

func place_camera(camera: Camera3D, car: CharacterBody3D, delta: float, immediate: bool = false) -> void:
	var offset: Vector3 = OFFSET
	if mode==1: offset = Vector3(0,24,0.01)
	elif mode==2:
		var heading: float = car.safe_heading if car.state!=0 else car.heading
		offset = Vector3(-cos(heading)*CLOSE_DISTANCE,CLOSE_HEIGHT,-sin(heading)*CLOSE_DISTANCE)
	var destination: Vector3 = focus+lead+offset
	camera.position = destination if immediate or mode!=2 else camera.position.lerp(destination,1.0-exp(-7.0*delta))
	# Near/far framing keeps the road rushing past the lens; a constant lens size
	# would cancel the perspective change and flatten the shot again.
	if mode==1: camera.fov = OVERHEAD_FOV
	elif mode==0: camera.fov = CHASE_FOV
	if mode==2:
		# A swept near-plane volume prevents cutting through props, bridge decks
		# and rising road. Query in world space; race roots can be rotated.
		var anchor: Vector3 = car.global_position+Vector3.UP*0.65
		var motion: Vector3 = camera.global_position-anchor
		clearance_shape.radius = 0.24
		var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		query.shape = clearance_shape
		query.transform = Transform3D(Basis.IDENTITY,anchor)
		query.motion = motion
		query.collision_mask = 1
		query.margin = 0.03
		var fractions: PackedFloat32Array = car.get_world_3d().direct_space_state.cast_motion(query)
		if not fractions.is_empty() and fractions[0]<1.0:
			camera.global_position = anchor+motion*maxf(0.0,fractions[0]-0.02)
			clearance_adjustments += 1
		var heading: float = car.safe_heading if car.state!=0 else car.heading
		var look: Vector3 = focus+Vector3(cos(heading)*3.8,0.4,sin(heading)*3.8)
		camera.look_at(car.get_parent().to_global(look))
	else: camera.look_at(focus+lead)

# Average nearby route samples so bends and ramp joins become gentle flight arcs.
func flight_point(track: Node3D, station: float) -> Vector3:
	var point: Vector3 = Vector3.ZERO
	for i: int in range(-4,5):
		point += track.sample_3d(station+float(i)*2.0)*float(5-absi(i))
	return point/25.0

func preview(camera: Camera3D, track: Node3D, elapsed: float) -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	var delta: float = clampf(elapsed-preview_elapsed,0.0,0.1)
	var fresh: bool = preview_elapsed<0.0 or elapsed<preview_elapsed
	preview_elapsed = elapsed
	# Ease away from the grid, then cruise along the route at a steady drone pace.
	var station: float = track.definition.start_station+7.0*(elapsed-1.5*(1.0-exp(-elapsed/1.5)))
	var target: Vector3 = flight_point(track,station+2.0)
	var heading: Vector3 = flight_point(track,station+12.0)-flight_point(track,station-12.0)
	var yaw: float = atan2(-heading.x,-heading.z)
	var entry: float = smoothstep(0.0,3.0,elapsed)
	var angle: float = lerp_angle(atan2(OFFSET.x,OFFSET.z),yaw,entry)
	var flight_offset: Vector3 = Vector3(sin(angle)*12.5,18.5+sin(elapsed*0.35)*0.45,cos(angle)*12.5)
	var origin: Vector3 = track.sample_3d(track.definition.start_station)
	target = origin.lerp(target,entry)
	var destination: Vector3 = target+OFFSET.lerp(flight_offset,entry)
	if fresh:
		camera.position = origin+OFFSET
		camera.look_at(origin)
	else:
		camera.position = camera.position.lerp(destination,1.0-exp(-3.0*delta))
		var desired: Basis = Transform3D(Basis.IDENTITY,camera.position).looking_at(target,Vector3.UP).basis
		camera.basis = Basis(camera.basis.get_rotation_quaternion().slerp(desired.get_rotation_quaternion(),1.0-exp(-2.5*delta)))
	camera.size = lerpf(14.0,18.0,entry)
	camera.far = 250.0
	# Only fade an object when it blocks the shot; the room stays intact.
	for mesh: MeshInstance3D in occluders:
		if not is_instance_valid(mesh): continue
		var bounds: AABB = mesh.global_transform*mesh.get_aabb()
		var obscures: bool = bounds.grow(0.2).intersects_segment(camera.global_position,target+Vector3.UP*0.35)!=null
		mesh.transparency = move_toward(mesh.transparency,float(mesh.get_meta("fade_strength",0.75)) if obscures else 0.0,delta*4.0)

func apply_feedback(camera: Camera3D, car: CharacterBody3D, offset: Vector3) -> void:
	if offset.is_zero_approx(): return
	var local_offset: Vector3 = camera.basis*offset.limit_length(0.18)
	var destination: Vector3 = camera.get_parent().to_global(camera.position+local_offset)
	# Suppress cosmetic movement near physical surfaces; do not fade the environment.
	feedback_shape.radius = maxf(camera.near,0.24)
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = feedback_shape
	query.transform = Transform3D(Basis.IDENTITY,destination)
	query.collision_mask = 1
	var space: PhysicsDirectSpaceState3D = car.get_world_3d().direct_space_state
	if not space.intersect_shape(query,1).is_empty(): return
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(camera.global_position,destination,1)
	if not space.intersect_ray(ray).is_empty(): return
	feedback_offset = local_offset
	camera.position += feedback_offset
