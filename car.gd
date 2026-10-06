extends CharacterBody2D
@export var player: int = 1
@export var ai: bool = false
@export var top_speed: float = 330.0
@export var lane: float = 0.0
var race: Node2D
var track: Node2D
var active: bool = true
var frozen: bool = false
var laps: int = 0
var distance: float = 0.0
var station: float = 0.0
var safe_station: float = 0.0
var safe_position: Vector2
var safe_rotation: float = 0.0
var progress_gate: int = 1
var state: int = 0
var state_time: float = 0.0
var immunity: float = 0.0
var boost: float = 100.0
var boosting: bool = false
var boost_was_on: bool = false
var skid_tick: float = 0.0
var crashes: int = 0
var car_hits: int = 0
var lap_started: float = 0.0
var best_lap: float = 0.0
var last_lap: float = 0.0
var finish_time: float = -1.0
var crash_raised: bool = false
var recovery_from: Vector2
var collision_cooldown: float = 0.0
var wrong_way: float = 0.0
var effect_tick: float = 0.0
@onready var effects: Node2D = get_parent().get_node("Particles")
@onready var controller: Node = get_parent().get_node("Controller")
@onready var tail_a: Sprite2D = $Visual/TailA
@onready var tail_b: Sprite2D = $Visual/TailB
@onready var visual: Node2D = $Visual
@onready var shadow: Sprite2D = $Shadow
@onready var flame: Node2D = $Visual/Flame

func _ready() -> void:
	race = get_parent()
	track = race.get_node("Track")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	safe_position = position

func reset_car(start: float, lateral: float) -> void:
	station = fposmod(start,track.get("total_length"))
	safe_station = station
	distance = start-25.0
	position = track.call("sample",station) + track.call("direction",station).orthogonal()*lateral
	rotation = track.call("direction",station).angle()
	safe_position = position
	safe_rotation = rotation
	velocity = Vector2.ZERO
	laps = 0
	progress_gate = 1
	finish_time = -1.0
	lap_started = 0.0
	last_lap = 0.0
	best_lap = 0.0
	boost = 100.0
	crashes = 0
	car_hits = 0
	wrong_way = 0.0
	effect_tick = 0.0
	boost_was_on = false
	tail_a.modulate = Color("#7c332c")
	tail_b.modulate = tail_a.modulate
	state = 0
	immunity = 0.0
	frozen = false
	visual.position = Vector2.ZERO
	visual.rotation = 0.0
	visual.scale = Vector2.ONE
	visual.modulate = Color.WHITE
	shadow.scale = Vector2.ONE
	shadow.position = Vector2(3,4)
	collision_layer = 2 if active else 0
	collision_mask = 2 if active else 0
	visible = active

func _physics_process(delta: float) -> void:
	if race.get("paused_race"): return
	if not active or race.get("phase") != 2 or frozen or finish_time >= 0.0:
		velocity = Vector2.ZERO
		flame.visible = false
		return
	if not position.is_finite() or not velocity.is_finite():
		race.call("fail_safe","Invalid car state")
		return
	collision_cooldown = maxf(0.0,collision_cooldown-delta)
	immunity = maxf(0.0,immunity-delta)
	if state != 0:
		animate_recovery(delta)
		return
	if immunity<=0.0:
		collision_layer = 2
		collision_mask = 2
	var hit: Vector3 = track.call("project",position)
	var previous_station: float = station
	station = hit.x
	var route_length: float = track.get("total_length")
	var advance: float = wrapf(station-previous_station,-route_length*0.5,route_length*0.5)
	if absf(advance)<55.0 and hit.y<=track.half_width:
		distance += advance
	if hit.y < track.half_width-16.0:
		safe_station = station
		safe_position = track.call("sample",station) + track.call("direction",station).orthogonal()*clampf(lane,-20.0,20.0)
		safe_rotation = track.call("direction",station).angle()
	if hit.y > track.half_width+3.0:
		crash(hit.z > 0.25)
		return
	var forward: Vector2 = Vector2.RIGHT.rotated(rotation)
	var speed: float = velocity.length()
	var steer: float = 0.0
	var throttle: float = 0.0
	boosting = false
	if ai:
		var look: float = 85.0+speed*0.28
		var target: Vector2 = track.call("sample",station+look)
		var tangent: Vector2 = track.call("direction",station+look)
		target += tangent.orthogonal()*lane
		for other in race.get("cars"):
			if other == self or not other.active or other.state != 0: continue
			var relative: Vector2 = other.position-position
			if relative.dot(forward)>0.0 and relative.dot(forward)<90.0 and absf(relative.dot(forward.orthogonal()))<30.0:
				target += tangent.orthogonal()*(36.0 if player%2==0 else -36.0)
		var desired: Vector2 = (target-position).normalized()
		var error: float = wrapf(desired.angle()-rotation,-PI,PI)
		steer = clampf(error*2.8,-1.0,1.0)
		var bend: float = absf(wrapf(track.call("direction",station+160.0).angle()-track.call("direction",station).angle(),-PI,PI))
		var desired_speed: float = top_speed * clampf(1.0-bend*0.55-absf(error)*0.25,0.44,1.0)
		throttle = 1.0 if speed < desired_speed else (-0.7 if speed>desired_speed+20.0 else 0.0)
		boosting = absf(error)<0.10 and bend<0.12 and boost>30.0 and speed>180.0
	else:
		steer = Input.get_axis("p1_left","p1_right")+Input.get_axis("p2_left","p2_right")
		steer = clampf(steer,-1.0,1.0)
		throttle = clampf(Input.get_axis("p1_brake","p1_go")+Input.get_axis("p2_brake","p2_go"),-1.0,1.0)
		if controller.using_pad:
			steer = controller.steering()
			throttle = controller.throttle()
		boosting = (Input.is_action_pressed("boost") or controller.boost_pressed()) and boost>2.0 and throttle>0.0
	var reverse_sign: float = -1.0 if velocity.dot(forward)<-10.0 else 1.0
	rotation += steer*lerpf(3.8,2.4 if ai else 2.0,minf(speed/top_speed,1.0))*clampf(speed/35.0,0.0,1.0)*reverse_sign*delta
	forward = Vector2.RIGHT.rotated(rotation)
	if boosting and not boost_was_on and not ai:
		race.call("play_sound","boost")
	boost_was_on = boosting
	if boosting:
		boost = maxf(0.0,boost-34.0*delta)
	else:
		boost = minf(100.0,boost+13.0*delta)
	var acceleration: float = 470.0 if ai else 500.0
	velocity += forward*throttle*acceleration*(1.5 if boosting else 1.0)*delta
	velocity *= exp(-0.28*delta)
	var side: Vector2 = forward.orthogonal()
	velocity -= side*velocity.dot(side)*minf((4.7 if ai else 1.8)*delta,1.0)
	velocity = velocity.limit_length(top_speed*(1.35 if boosting else 1.0))
	var before: Vector2 = velocity
	move_and_slide()
	for i in range(get_slide_collision_count()):
		var contact: KinematicCollision2D = get_slide_collision(i)
		var other: Object = contact.get_collider()
		if other is CharacterBody2D and contact.get_normal().dot(before)<-8.0:
			var impulse: float = minf(-before.dot(contact.get_normal())*0.48,100.0)
			other.velocity -= contact.get_normal()*impulse
			velocity = before.bounce(contact.get_normal())*0.65
			car_hits += 1
			if collision_cooldown<=0.0:
				race.call("play_sound","bump")
				effects.burst(position,rotation,2,18,Color("#eec686"))
				if not ai: controller.rumble(0.45,0.12)
				collision_cooldown = 0.25
			break
	wrong_way = wrong_way+delta if velocity.dot(track.call("direction",station)) < -35.0 else maxf(0.0,wrong_way-delta*2.0)
	visual.modulate.a = 0.45 if immunity>0.0 and int(immunity*10.0)%2==0 else 1.0
	flame.visible = boosting
	flame.scale.x = 1.0+sin(float(race.get("race_time"))*50.0)*0.15
	skid_tick += delta
	if skid_tick>0.08 and absf(velocity.dot(side))>45.0:
		race.get_node("Skids").call("stamp",position,rotation)
		skid_tick = 0.0
	effect_tick += delta
	if effect_tick>=0.06:
		effect_tick = 0.0
		if boosting: effects.burst(position-forward*16.0,rotation,1,3)
		if absf(velocity.dot(side))>55.0: effects.burst(position-forward*8.0,rotation,0,2)
	tail_a.modulate = Color("#ff604a") if throttle<0.0 else Color("#7c332c")
	tail_b.modulate = tail_a.modulate
	visual.rotation = lerpf(visual.rotation,clampf(velocity.dot(side)/900.0,-0.12,0.12),minf(delta*8.0,1.0))
	shadow.position = Vector2(3,4)
	race.call("update_progress",self)

func crash(raised: bool) -> void:
	if state!=0 or not active: return
	crash_raised = raised
	state = 2 if raised else 1
	state_time = 0.0
	crashes += 1
	collision_layer = 0
	collision_mask = 0
	flame.visible = false
	race.call("play_sound","fall" if raised else "crash")
	effects.burst(position,rotation,2,30,$Visual/Body.modulate)
	effects.burst(position,rotation,0,16)
	if not ai: controller.rumble(0.8,0.35)
	if not ai: race.set("shake",10.0)

func animate_recovery(delta: float) -> void:
	state_time += delta
	if state==1 or state==2:
		position += velocity*delta
		velocity *= exp(-3.5*delta)
		var duration: float = 1.0 if state==2 else 0.7
		var t: float = clampf(state_time/duration,0.0,1.0)
		visual.rotation += delta*(9.0 if state==2 else 13.0)
		if state==2:
			visual.scale = Vector2.ONE*lerpf(1.0,0.25,t*t)
			visual.position.y = 130.0*t*t
			visual.modulate.a = 1.0-t*0.6
			shadow.scale = Vector2.ONE*lerpf(1.0,0.45,t)
			shadow.position.y = 140.0*t*t
		else:
			visual.modulate = Color(1.0,1.0-t*0.6,1.0-t*0.7,1.0)
		if t>=1.0:
			recovery_from = position+visual.position
			visual.position = Vector2.ZERO
			state = 3
			state_time = 0.0
			rotation = safe_rotation
			race.call("play_sound","return")
			effects.burst(safe_position,safe_rotation,3,24)
	elif state==3:
		var t: float = clampf(state_time/0.85,0.0,1.0)
		var eased: float = 1.0-pow(1.0-t,3.0)
		position = recovery_from.lerp(safe_position,eased)+Vector2(0,-sin(t*PI)*65.0)
		visual.scale = Vector2.ONE*lerpf(0.35,1.0,eased)
		visual.rotation = lerpf(visual.rotation,0.0,minf(delta*8.0,1.0))
		visual.modulate = Color(0.55+0.45*t,0.85+0.15*t,1.0,0.55+0.45*t)
		shadow.scale = Vector2.ONE
		shadow.position = Vector2(3,4+sin(t*PI)*45)
		if t>=1.0:
			position = safe_position
			station = safe_station
			rotation = safe_rotation
			velocity = Vector2.RIGHT.rotated(rotation)*65.0
			visual.scale = Vector2.ONE
			visual.rotation = 0.0
			visual.modulate = Color.WHITE
			state = 0
			immunity = 1.5
			effects.burst(position,rotation,3,18)
			collision_layer = 0
			collision_mask = 0
	if state==0 and immunity<=0.0:
		collision_layer = 2
		collision_mask = 2
