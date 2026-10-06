extends RefCounted
# Only ordered lap events may remove a racer. Equal progress loses by slot ID.
var session: Node
var eliminated: Array[int] = []
var next_lap: int = 2

func reset(owner: Node) -> void:
	session = owner
	eliminated.clear()
	next_lap = 2

func active_ids() -> Array:
	var ids: Array = session.progress.ordered_ids()
	return ids.filter(func(id: int) -> bool: return id not in eliminated)

func ordered_ids() -> Array:
	var ids: Array = active_ids()
	var out: Array[int] = eliminated.duplicate()
	out.reverse()
	ids.append_array(out)
	return ids

func lap_completed(_car: CharacterBody3D, lap: int) -> void:
	if lap<next_lap: return
	var remaining: Array = active_ids()
	if remaining.size()<2: return
	next_lap += 1
	var last: int = remaining.back()
	eliminated.append(last)
	for car: CharacterBody3D in session.cars:
		if car.player!=last: continue
		car.finish_time = INF # Park the body; the authoritative record stays DNF.
		car.set_physics_process(false)
		car.velocity = Vector3.ZERO
		car.collision_layer = 0
		car.collision_mask = 0
		car.hide()
		if last==1:
			session.finish_deadline = -1.0
			session.change_phase(session.Phase.FINISHING)
		session.racer_eliminated.emit(car,remaining.size())
	remaining.erase(last)
	if remaining.size()==1:
		for car: CharacterBody3D in session.cars:
			if car.player==remaining[0]:
				session.progress.mark_finished(car,session.race_time)
				session.racer_finished.emit(car)
		session.classify()

func rows() -> Array:
	var result: Array = []
	for id: int in ordered_ids():
		var record: Dictionary = session.progress.records[id]
		result.append({"player":id,"rank":result.size()+1,"finished":record.finish_time>=0.0,"time":record.finish_time,"penalty":record.penalty,"laps":record.laps,"progress":record.distance,"points":0,"status":"OUT" if id in eliminated else ("WINNER" if record.finish_time>=0.0 else "RACING")})
	return result
