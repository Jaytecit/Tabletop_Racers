extends RefCounted
# Cosmetic transforms only. The CharacterBody and its collision shape are never written.
const MAX_STEER: float = 0.45
var enabled: bool = true
var car: CharacterBody3D
var mounts: Array[Node3D] = []
var rolls: Array[Node3D] = []
var radii: Array[float] = []
var body_parts: Array[Node3D] = []
var body_rest: Array[Transform3D] = []
var last_position: Vector3
var last_speed: float = 0.0
var pitch: float = 0.0
var lean: float = 0.0
var compression: float = 0.0
var roll_angle: float = 0.0
var propeller_angle: float = 0.0

func configure(vehicle: CharacterBody3D) -> void:
	car = vehicle
	for mount: Node3D in car.visual.get_node("Wheels").get_children():
		var roll: Node3D = Node3D.new()
		roll.name = "Roll"
		var parts: Array[Node] = mount.get_children()
		mount.add_child(roll)
		for part: Node in parts: part.reparent(roll, false)
		mounts.append(mount)
		rolls.append(roll)
		radii.append(float(mount.get_meta("wheel_radius")))
	for part: Node3D in car.visual.get_children():
		if part.name == "Wheels": continue
		body_parts.append(part)
		body_rest.append(part.transform)
	reset()

func reset() -> void:
	last_position = car.position
	last_speed = 0.0
	pitch = 0.0
	lean = 0.0
	compression = 0.0
	roll_angle = 0.0
	propeller_angle = 0.0
	for i: int in range(body_parts.size()): body_parts[i].transform = body_rest[i]
	for mount: Node3D in mounts: mount.rotation = Vector3.ZERO
	for roll: Node3D in rolls: roll.rotation = Vector3.ZERO

func land(strength: float) -> void:
	compression = maxf(compression, clampf(strength, 0.0, 1.0)*0.035)

func tick(delta: float, steer: float) -> void:
	var forward: Vector3 = Vector3(cos(car.heading), 0, sin(car.heading))
	var displacement: Vector3 = car.position-last_position
	last_position = car.position
	var speed: float = car.velocity.dot(forward)
	var acceleration: float = (speed-last_speed)/maxf(delta, 0.001)
	last_speed = speed
	if not enabled: return
	# Actual signed travel, not requested speed; reject reset/teleport distances.
	var travel: float = displacement.dot(forward) if displacement.length() < 1.0 else 0.0
	for i: int in range(mounts.size()):
		mounts[i].rotation.y = -clampf(steer, -1.0, 1.0)*MAX_STEER if mounts[i].position.x > 0 else 0.0
		rolls[i].rotation.z = wrapf(rolls[i].rotation.z-travel/radii[i], -PI, PI)
	roll_angle = rolls[0].rotation.z if not rolls.is_empty() else 0.0
	pitch = lerpf(pitch, clampf(acceleration*0.0018, -0.04, 0.04), 1.0-exp(-16.0*delta))
	lean = lerpf(lean, clampf(-steer*absf(speed)*0.004, -0.06, 0.06), 1.0-exp(-16.0*delta))
	compression = move_toward(compression, 0.0, delta*0.18)
	var response: Transform3D = Transform3D(Basis.from_euler(Vector3(lean,0,pitch)), Vector3(0,-compression,0))
	for i: int in range(body_parts.size()): body_parts[i].transform = response*body_rest[i]
	var rudder: Node3D = car.visual.get_node_or_null("Rudder")
	if rudder!=null: rudder.rotation.y = -steer*0.45
	var propeller: Node3D = car.visual.get_node_or_null("Propeller")
	if propeller!=null:
		propeller_angle = wrapf(propeller_angle-travel*20.0,-PI,PI)
		propeller.rotation.x = propeller_angle
	car.visual.rotation.z = lerpf(car.visual.rotation.z, atan2(-car.surface_normal.dot(forward),car.surface_normal.y) if not car.airborne else -0.12, minf(delta*8.0,1.0))
	car.visual.rotation.x = 0.0
