extends RefCounted
# Per-car seeded decisions; difficulty changes commands, never vehicle physics.
const PROFILES: Array[Dictionary] = [
	{"speed":0.81,"look":0.26,"margin":0.65,"pass":0.65,"error":0.020,"boost":false},
	{"speed":0.95,"look":0.22,"margin":0.55,"pass":1.05,"error":0.010,"boost":true},
	{"speed":1.04,"look":0.19,"margin":0.48,"pass":1.35,"error":0.006,"boost":true},
	{"speed":1.07,"look":0.19,"margin":0.48,"pass":1.6,"error":0.003,"boost":true}]
var overrides: Dictionary = {}
var difficulty: int = 1
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var lateral_target: float = 0.0
var steering_error: float = 0.0
var decision_time: float = 0.0
var stalled_time: float = 0.0
var net_advance: float = 0.0
var last_station: float = 0.0
var recoveries: int = 0
var passes: int = 0
var boost_active: bool = false
var attacking: bool = false
var attack_decisions: int = 0

func is_attacker(car: CharacterBody3D) -> bool:
	return difficulty==3 and car!=car.race.player_car and car.player in [2,3]

func reset(car: CharacterBody3D, seed_value: int) -> void:
	rng.seed = seed_value+car.player*104729
	lateral_target = car.lane
	steering_error = 0.0
	decision_time = 0.0
	stalled_time = 0.0
	net_advance = 0.0
	last_station = car.station
	recoveries = 0
	passes = 0
	boost_active = false
	attacking = false
	attack_decisions = 0

func read_commands(car: CharacterBody3D) -> Dictionary:
	var dt: float = car.get_physics_process_delta_time()
	var profile: Dictionary = PROFILES[clampi(difficulty,0,3)].duplicate()
	profile.merge(overrides,true)
	var track: Node3D = car.track
	var speed: float = Vector2(car.velocity.x,car.velocity.z).length()
	var pos2: Vector2 = Vector2(car.position.x,car.position.z)
	var advance: float = wrapf(car.station-last_station,-track.total_length*0.5,track.total_length*0.5)
	last_station = car.station
	# Collision jitter must not masquerade as forward progress.
	net_advance += advance
	stalled_time += dt
	if net_advance>0.5 or car.airborne:
		net_advance = 0.0
		stalled_time = 0.0
	if stalled_time>3.5:
		stalled_time = 0.0
		net_advance = 0.0
		recoveries += 1
		return {"throttle":0.0,"brake":0.0,"steer":0.0,"boost":false,"reset_requested":true}
	# Sample braking distance, not just one fixed bend angle. This catches
	# opposite turns in a chicane that would otherwise cancel one another.
	var look: float = 2.1+speed*float(profile.look)
	var tangent: Vector2 = track.direction(car.station+look)
	var normal: Vector2 = track.direction(car.station).orthogonal()
	var current_lane: float = (pos2-track.sample(car.station)).dot(normal)
	var width: float = minf(float(track.at(car.station).width),float(track.at(car.station+look).width))
	var traffic_width: float = car.tuning.traffic_half_width*2.0
	var lane_limit: float = maxf(0.0,width*0.5-float(profile.margin)-car.tuning.traffic_half_width)
	var blocked: bool = false
	var nearest: float = INF
	var blocked_lane: float = 0.0
	var horizon: float = 1.8+speed*0.28
	for other: CharacterBody3D in car.race.cars:
		if other==car or other.finish_time>=0.0 or other.state!=0 or other.immunity>0.0: continue
		if absf(other.position.y-car.position.y)>0.7: continue
		var along: float = wrapf(other.station-car.station,-track.total_length*0.5,track.total_length*0.5)
		var other_lane: float = (Vector2(other.position.x,other.position.z)-track.sample(other.station)).dot(track.direction(other.station).orthogonal())
		if along> -0.6 and along<horizon and absf(other_lane-current_lane)<car.tuning.traffic_half_width+other.tuning.traffic_half_width+0.15:
			blocked = true
			if along<nearest:
				nearest = along
				blocked_lane = other_lane
	# Attackers intercept the player along the route; the fourth car races to win.
	# Height/state checks prevent targeting across bridge layers or recovery immunity.
	var victim: CharacterBody3D = car.race.player_car
	var player_gap: float = wrapf(victim.station-car.station,-track.total_length*0.5,track.total_length*0.5)
	attacking = car!=victim and victim.finish_time<0.0 and victim.state==0 and victim.immunity<=0.0 and not car.airborne and not victim.airborne and absf(victim.position.y-car.position.y)<0.7 and width>=4.5 and ((is_attacker(car) and absf(player_gap)<18.0) or (difficulty==2 and absf(player_gap)<5.0))
	decision_time -= dt
	if decision_time<=0.0:
		decision_time = 0.16 if difficulty>=2 else 0.25
		steering_error = rng.randf_range(-float(profile.error),float(profile.error))
		var chosen: float = clampf(car.lane,-lane_limit,lane_limit)
		if blocked:
			var best_score: float = -INF
			for candidate_value: float in [-lane_limit,lane_limit,blocked_lane-traffic_width-0.25-float(profile.pass)*0.15,blocked_lane+traffic_width+0.25+float(profile.pass)*0.15]:
				var candidate: float = clampf(candidate_value,-lane_limit,lane_limit)
				var clearance: float = 10.0
				for other: CharacterBody3D in car.race.cars:
					if other==car or other.finish_time>=0.0 or other.state!=0 or other.immunity>0.0 or absf(other.position.y-car.position.y)>0.7: continue
					var along: float = wrapf(other.station-car.station,-track.total_length*0.5,track.total_length*0.5)
					if along< -1.5 or along>horizon: continue
					var other_lane: float = (Vector2(other.position.x,other.position.z)-track.sample(other.station)).dot(track.direction(other.station).orthogonal())
					clearance = minf(clearance,absf(candidate-other_lane))
				var score: float = clearance-absf(candidate-current_lane)*0.12
				if clearance>traffic_width+0.1 and score>best_score:
					best_score = score
					chosen = candidate
			if best_score==-INF: chosen = current_lane
			elif absf(chosen-lateral_target)>0.6: passes += 1
		if attacking:
			var victim_lane: float = (Vector2(victim.position.x,victim.position.z)-track.sample(victim.station)).dot(track.direction(victim.station).orthogonal())
			chosen = clampf(victim_lane,-lane_limit,lane_limit)
			attack_decisions += 1
		lateral_target = move_toward(lateral_target,chosen,0.95 if attacking else 0.75)
	lateral_target = clampf(lateral_target,-lane_limit,lane_limit)
	var target: Vector2 = track.sample(car.station+look)+tangent.orthogonal()*lateral_target
	var error: float = wrapf((target-pos2).angle()-car.heading,-PI,PI)
	var bend: float = absf(wrapf(track.direction(car.station+4.8).angle()-track.direction(car.station).angle(),-PI,PI))
	var steer: float = clampf(error*2.8+steering_error,-1.0,1.0)
	var safe_speed: float = car.top_speed*car.tuning.boost_speed
	var preview_speed: float = maxf(speed,car.top_speed*car.tuning.boost_speed)
	var braking_horizon: float = preview_speed*preview_speed/(2.0*maxf(car.tuning.braking,0.001))+speed*0.35+look
	for step: int in range(7):
		var ahead: float = float(step)*braking_horizon/6.0
		var curvature: float = absf(track.direction(car.station+ahead).angle_to(track.direction(car.station+ahead+2.0)))/2.0
		var corner_speed: float = sqrt(9.0/maxf(curvature,0.025))*float(profile.speed)
		safe_speed = minf(safe_speed,sqrt(corner_speed*corner_speed+2.0*car.tuning.braking*maxf(ahead-1.0,0.0)))
	var boost_line: bool = bool(profile.boost) and width>=4.5 and (not blocked or attacking) and absf(error)<0.10 and bend<0.12 and safe_speed>=car.top_speed*car.tuning.boost_speed*float(profile.speed)*0.98
	boost_active = boost_line and (car.boost>(10.0 if boost_active else 65.0) or car.tuning.boost_drain==0.0) and speed>6.0
	# A boosted straight needs a boosted target; the old normal-speed target
	# caused the throttle to close before the AI could use its boost reserve.
	var desired: float = minf(safe_speed,car.top_speed*(car.tuning.boost_speed if boost_active else 1.0)*float(profile.speed))
	desired *= clampf(1.0-absf(error)*0.18,0.55,1.0)
	if width<4.5:
		# Hold the centre on the exposed deck; approach it without boost.
		lateral_target = move_toward(lateral_target,0.0,dt*3.0)
		desired = minf(desired,car.top_speed*0.72)
	if attacking and is_attacker(car) and player_gap< -1.5:
		# Stay just ahead to obstruct; chase at full pace when behind.
		desired = minf(desired,maxf(2.0,Vector2(victim.velocity.x,victim.velocity.z).length()-(-player_gap-2.0)*1.5))
	if blocked and not attacking and absf(lateral_target-blocked_lane)<traffic_width+0.15:
		desired = minf(desired,maxf(0.0,(nearest-1.0)*2.5))
	var throttle: float = 1.0 if speed<desired else (-0.8 if speed>desired+0.4 else 0.0)
	return {"throttle":maxf(throttle,0.0),"brake":maxf(-throttle,0.0),"steer":steer,
		"boost":boost_active,"reset_requested":false}
