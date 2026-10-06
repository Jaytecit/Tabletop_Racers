extends Node
signal gate_warning(car: CharacterBody3D, penalized: bool)
signal phase_changed(value: int)
signal lap_completed(car: CharacterBody3D, lap: int)
signal racer_finished(car: CharacterBody3D)
signal racer_eliminated(car: CharacterBody3D, rank: int)
signal time_extended(seconds: float)
signal results_ready(rows: Array)
enum Phase { SETUP, COUNTDOWN, RACING, RESULTS, FAILURE, FINISHING, PREVIEW }
const GATE_GRACE: float = 5.0
const GATE_PENALTY: float = 5.0
const FINISH_WINDOW: float = 20.0
var phase: int = Phase.SETUP
var paused: bool = false
var race_time: float = 0.0
var countdown: float = 3.8
var finish_deadline: float = -1.0
var laps_required: int = 3
var cars: Array = []
var track: Node3D
var progress: RefCounted = preload("res://scripts/race/race_progress.gd").new()
var results: Array = []
var lap_crossing_time: float = 0.0
var mode: String = "quick"
var elimination: RefCounted = preload("res://scripts/race/elimination_rules.gd").new()
var time_attack: RefCounted = preload("res://scripts/race/time_attack_rules.gd").new()
var time_attack_settings: Dictionary = {"start":0.0,"extension":0.0}

func configure(vehicles: Array, route: Node3D) -> void:
	cars = vehicles
	track = route

func change_phase(value: int) -> void:
	phase = value
	phase_changed.emit(value)

func reset() -> void:
	paused = false
	race_time = 0.0
	countdown = 3.8
	finish_deadline = -1.0
	results.clear()
	elimination.reset(self)
	time_attack.reset(time_attack_settings.start,time_attack_settings.extension)
	if not track.validation_errors.is_empty():
		progress.records.clear()
		change_phase(Phase.FAILURE)
		return
	for i: int in range(cars.size()):
		var row_spacing: float = maxf(1.5,cars[i].tuning.collision_size.x+0.2)
		var lateral: float = maxf(0.48,cars[i].tuning.collision_size.z*0.5+0.1)
		cars[i].reset_car(track.definition.start_station-float(int(i/2.0))*row_spacing,-lateral if i%2==0 else lateral)
	progress.reset(cars,track.total_length)

func start() -> void:
	reset()
	if not track.validation_errors.is_empty(): return
	change_phase(Phase.COUNTDOWN)

func menu() -> void:
	reset()
	if not track.validation_errors.is_empty(): return
	change_phase(Phase.SETUP)

func toggle_pause() -> void:
	if phase in [Phase.COUNTDOWN,Phase.RACING,Phase.FINISHING]:
		paused = not paused

func tick(delta: float) -> void:
	if paused: return
	if phase==Phase.COUNTDOWN:
		countdown -= delta
		if countdown<=0.8: change_phase(Phase.RACING)
	if phase in [Phase.RACING,Phase.FINISHING]:
		# Check the previous tick boundary. A crossing within this tick may still
		# beat the deadline; observe() tests its interpolated crossing time.
		if mode=="time_attack" and race_time>=time_attack.deadline:
			time_attack.expired = true
			classify()
			return
		race_time += delta
		for car: CharacterBody3D in cars:
			if mode=="elimination" and car.player in elimination.eliminated: continue
			var record: Dictionary = progress.records[car.player]
			if record.missed_deadline>=0.0 and race_time>=record.missed_deadline:
				record.missed_deadline = -1.0
				record.penalty += GATE_PENALTY
				if mode=="time_attack": time_attack.deadline -= GATE_PENALTY
				gate_warning.emit(car,true)
				car.crash(false)
		if phase==Phase.FINISHING and finish_deadline>=0.0 and race_time>=finish_deadline:
			classify()

func observe(car: CharacterBody3D, hit: Vector2, delta: float) -> void:
	if paused or phase not in [Phase.RACING,Phase.FINISHING] or car.finish_time>=0.0: return
	var crossing: Dictionary = progress.observe(car,hit,delta,race_time)
	if mode=="time_attack" and crossing.has("checkpoint"):
		var ordinal: int = progress.records[car.player].laps*track.definition.gate_count+int(crossing.checkpoint)
		if time_attack.checkpoint(ordinal,crossing.crossing_time):
			time_extended.emit(time_attack.extension)
		elif crossing.crossing_time>time_attack.deadline:
			time_attack.expired = true
			classify()
			return
	if crossing.has("missed_gate"):
		var record: Dictionary = progress.records[car.player]
		if record.missed_deadline<0.0:
			record.missed_deadline = race_time+GATE_GRACE
			gate_warning.emit(car,false)
		return
	if crossing.has("lap"):
		lap_crossing_time = crossing.crossing_time
		lap_completed.emit(car,crossing.lap)
		if mode=="drift": return
		if mode=="elimination":
			elimination.lap_completed(car,crossing.lap)
			return
		if crossing.lap>=laps_required:
			progress.mark_finished(car,crossing.crossing_time)
			# Parked finishers must leave the line clear for remaining racers.
			car.collision_layer = 0
			car.collision_mask = 0
			racer_finished.emit(car)
			if car.player==1:
				finish_deadline = race_time+FINISH_WINDOW
				change_phase(Phase.FINISHING)
			var all_finished: bool = true
			for other: CharacterBody3D in cars:
				if other.finish_time<0.0: all_finished = false
			if all_finished: classify()

func classify() -> void:
	if phase==Phase.RESULTS: return
	if mode=="elimination":
		results = elimination.rows()
		change_phase(Phase.RESULTS)
		results_ready.emit(results)
		return
	results.clear()
	for id: int in progress.ordered_ids():
		var record: Dictionary = progress.records[id]
		results.append({"player":id,"rank":results.size()+1,"finished":record.finish_time>=0.0,
			"time":record.finish_time,"penalty":record.penalty,"laps":record.laps,"progress":record.distance,
			"points":[10,6,4,2,1,0,0,0][results.size()]})
	change_phase(Phase.RESULTS)
	results_ready.emit(results)

func fail() -> void:
	paused = false
	change_phase(Phase.FAILURE)

func rank_of(car: CharacterBody3D) -> int:
	if mode=="elimination": return elimination.ordered_ids().find(car.player)+1
	return progress.rank_of(car.player)
