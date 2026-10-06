extends Camera3D
# Keep the course card's original framing while travelling around its route.
const SPEED: float = 7.0
var track: Node3D
var centre: Vector3
var ratio: float = 1.0
var station: float = 0.0
var heading: float = 0.0
var preview_box: Control

func configure(course: Node3D, bounds_centre: Vector3, scale_ratio: float) -> void:
	track = course
	centre = bounds_centre
	ratio = scale_ratio
	preview_box = get_parent().get_parent().get_parent()
	station = track.definition.start_station+minf(18.0,track.total_length*0.12)
	var section: Dictionary = track.at(station)
	size = maxf(section.width*ratio*3.5,0.4)
	var forward: Vector2 = track.direction(station)
	heading = atan2(forward.y,forward.x)
	place(0.0,true)

func _process(delta: float) -> void:
	if not is_instance_valid(track) or not preview_box.is_visible_in_tree(): return
	var step: float = minf(delta,0.1)
	station = fposmod(station+SPEED*step,track.total_length)
	place(step)

func place(delta: float, immediate: bool = false) -> void:
	var section: Dictionary = track.at(station)
	var focus: Vector3 = (section.position-centre)*ratio+Vector3.UP*0.12
	if not track.definition.imported_surface: focus.y = section.position.y*ratio+0.12
	var forward: Vector2 = track.direction(station)
	var blend: float = 1.0 if immediate else 1.0-exp(-3.0*delta)
	heading = lerp_angle(heading,atan2(forward.y,forward.x),blend)
	var trail: Vector3 = Vector3(-cos(heading),0,-sin(heading))
	var side: Vector3 = Vector3(-sin(heading),0,cos(heading))
	var destination: Vector3 = focus+(trail+side*0.45+Vector3.UP*1.25)*size
	position = destination if immediate else position.lerp(destination,blend)
	var desired: Basis = Transform3D(Basis.IDENTITY,position).looking_at(focus,Vector3.UP).basis
	basis = desired if immediate else Basis(basis.get_rotation_quaternion().slerp(desired.get_rotation_quaternion(),blend))
