extends RefCounted
# Three distinct Casino courses. Old single-course cup progress is incompatible.
const COURSES: Array[String] = ["felt_sprint","card_bridge","game_table"]
const LAPS: Array[int] = [3,3,3]

static func course_id(cup: Dictionary) -> String:
	return COURSES[mini(cup.get("rounds",[]).size(),2)]
const POINTS: Array[int] = [10,6,4,2]

static func validate(raw: Variant) -> Dictionary:
	if not raw is Dictionary or raw.get("id")!="casino_v1": return {}
	var rounds: Variant = raw.get("rounds")
	if not rounds is Array or rounds.size()>3: return {}
	var clean: Array = []
	for round_rows: Variant in rounds:
		if not round_rows is Array or round_rows.size()!=4: return {}
		var ids: Array[int] = []
		var rows: Array = []
		for row: Variant in round_rows:
			if not row is Dictionary: return {}
			var id: Variant = row.get("player")
			var time: Variant = row.get("time")
			if typeof(id) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(id)) or id<1 or id>4 or id!=int(id) or int(id) in ids: return {}
			if typeof(time) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(time)) or time<0.0 or time>7200.0: return {}
			if typeof(row.get("finished"))!=TYPE_BOOL: return {}
			if row.finished and time<=0.0: return {}
			ids.append(int(id))
			rows.append({"player":int(id),"time":float(time),"finished":row.finished})
		clean.append(rows)
	return {"id":"casino_v1","rounds":clean}

static func fresh() -> Dictionary:
	return {"id":"casino_v1","rounds":[]}

static func standings(cup: Dictionary, finished_only: bool = false) -> Array:
	var totals: Array = []
	for id: int in range(1,5): totals.append({"player":id,"points":0,"wins":0,"time":0.0})
	for rows: Array in cup.rounds:
		for rank: int in range(rows.size()):
			var row: Dictionary = rows[rank]
			var total: Dictionary = totals[row.player-1]
			total.points += POINTS[rank] if row.finished or not finished_only else 0
			total.wins += 1 if rank==0 and row.finished else 0
			total.time += row.time if row.finished else 7200.0
	totals.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		if a.points!=b.points: return a.points>b.points
		if a.wins!=b.wins: return a.wins>b.wins
		if a.time!=b.time: return a.time<b.time
		return a.player<b.player)
	return totals

static func append_round(cup: Dictionary, results: Array) -> bool:
	if cup.rounds.size()>=3: return false
	var rows: Array = []
	for row: Dictionary in results:
		rows.append({"player":row.player,"finished":row.finished,"time":row.time if row.finished else 0.0})
	var candidate: Dictionary = {"id":"casino_v1","rounds":cup.rounds.duplicate(true)}
	candidate.rounds.append(rows)
	if validate(candidate).is_empty(): return false
	cup.rounds = candidate.rounds
	return true
