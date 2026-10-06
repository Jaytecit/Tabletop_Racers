extends RefCounted
# Bounded cosmetic event owner. RaceSession and the car remain authoritative.
const KINDS: Array[StringName] = [&"boost_start",&"landing",&"impact",&"recovery_start",&"recovery_end"]
var race: Node3D
var emitted: Dictionary = {}
var suppressed: Dictionary = {}
var cooldowns: Dictionary = {}
var shake: float = 0.0
var shake_time: float = 0.0
var clock: float = 0.0
var impact_duck: float = 0.0
var last_event: Dictionary = {}
var messages: Array[Dictionary] = []
var message_priority: int = -1
var message_key: StringName = &""
var stable_rank: int = 0
var candidate_rank: int = 0
var rank_age: float = 0.0
var rank_cooldown: float = 0.0

func post(text: String, duration: float, priority: int, key: StringName = &"") -> void:
	if text.is_empty(): return
	# State notices describe the current state, so discard superseded queued values.
	if key != &"":
		messages = messages.filter(func(item: Dictionary) -> bool: return item.get("key",&"") != key)
	if race.message_time <= 0.0 or priority > message_priority or (key != &"" and key == message_key):
		race.message = text
		race.message_time = duration
		message_priority = priority
		message_key = key
		return
	for item: Dictionary in messages:
		if item.text == text: return
	messages.append({"text":text,"duration":duration,"priority":priority,"key":key})
	messages.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.priority>b.priority)
	if messages.size()>4: messages.resize(4)

func tick_messages(delta: float) -> void:
	race.message_time = maxf(0.0,race.message_time-delta)
	if race.message_time<=0.0:
		message_priority = -1
		message_key = &""
		if not messages.is_empty():
			var item: Dictionary = messages.pop_front()
			post(item.text,item.duration,item.priority,item.get("key",&""))
	if race.race_mode == "trial" or race.phase != 2: return
	var current: int = race.rank_of(race.player_car)
	if stable_rank == 0: stable_rank = current
	rank_cooldown = maxf(0.0,rank_cooldown-delta)
	if current != candidate_rank:
		candidate_rank = current
		rank_age = 0.0
	else: rank_age += delta
	if current != stable_rank and rank_age >= 0.35:
		if rank_cooldown <= 0.0:
			post(("UP TO P%d" if current < stable_rank else "NOW P%d") % current,1.2,0)
			rank_cooldown = 1.5
		stable_rank = current

func configure(value: Node3D) -> void:
	race = value
	clear()

func reduced() -> bool:
	return race.machine_settings.data.get("reduced_effects",false)

func handle_event(kind: StringName, car: CharacterBody3D, strength: float, world_position: Vector3, normal: Vector3 = Vector3.UP) -> void:
	if not is_instance_valid(race) or not is_instance_valid(car) or car not in race.cars or kind not in KINDS: return
	if race.paused_race or race.phase not in [2,5] or car.finish_time >= 0.0: return
	if not is_finite(strength) or not world_position.is_finite(): return
	strength = clampf(strength,0.0,1.0)
	var key: String = "%d:%s" % [car.player,kind]
	if cooldowns.get(key,0.0) > 0.0:
		suppressed[kind] = int(suppressed.get(kind,0))+1
		return
	cooldowns[key] = 0.25 if kind == &"impact" else 0.08
	emitted[kind] = int(emitted.get(kind,0))+1
	last_event = {"kind":kind,"strength":strength,"position":world_position,"player":car.player}
	var local: bool = car == race.player_car
	var nearby: bool = car.global_position.distance_to(race.player_car.global_position)<12.0
	if not local and not nearby: return
	car.effects.event(kind,strength,world_position,normal)
	match kind:
		&"boost_start":
			if local: race.play_sound("boost")
		&"landing", &"impact":
			race.play_sound("landing" if kind == &"landing" else "bump", -8.0*(1.0-strength)-(0.0 if local else 8.0))
			if local:
				race.controller.rumble(0.4*strength,0.12)
				impact_duck = maxf(impact_duck,2.5*strength if strength>=0.4 else 0.0)
				if not reduced():
					shake = maxf(shake,strength*(0.08 if kind == &"landing" else 0.18))
					shake_time = 0.10 if kind == &"landing" else 0.18
		&"recovery_start":
			race.play_sound("fall" if car.state == 2 else "crash")
			if local:
				shake = 0.0
				race.controller.rumble(0.8,0.3)
		&"recovery_end":
			if local: shake = 0.0

func tick(delta: float) -> void:
	if race.paused_race: return
	clock += delta
	for key: String in cooldowns: cooldowns[key] = maxf(0.0,float(cooldowns[key])-delta)
	shake_time = maxf(0.0,shake_time-delta)
	shake = move_toward(shake,0.0,delta*1.0)
	impact_duck = move_toward(impact_duck,0.0,delta*2.5/0.12)
	if reduced(): shake = 0.0

func camera_offset() -> Vector3:
	if shake_time<=0.0 or reduced(): return Vector3.ZERO
	return Vector3(sin(clock*93.0),cos(clock*79.0)*0.55,0)*shake

func clear() -> void:
	shake = 0.0
	shake_time = 0.0
	impact_duck = 0.0
	clock = 0.0
	cooldowns.clear()
	emitted.clear()
	suppressed.clear()
	last_event.clear()
	messages.clear()
	message_priority = -1
	message_key = &""
	stable_rank = 0
	candidate_rank = 0
	rank_age = 0.0
	rank_cooldown = 0.0
	if is_instance_valid(race):
		for car: CharacterBody3D in race.cars:
			car.effects.clear()
			car.debris.emitting = false
			car.debris.hide()
			car.debris.position = Vector3(-0.45,0.2,0)

func diagnostic_state() -> Dictionary:
	var bursts: int = 0
	var voices: int = 0
	for car: CharacterBody3D in race.cars:
		if car.debris.emitting: bursts += 1
		if car.sparks.emitting: bursts += 1
	for voice: AudioStreamPlayer in race.voices:
		if voice.playing: voices += 1
	return {"emitted":emitted.duplicate(),"suppressed":suppressed.duplicate(),"shake":shake,"duck":impact_duck,"active_bursts":bursts,"active_voices":voices,"burst_capacity":8,"particle_capacity":384,"voice_capacity":race.voices.size()}
