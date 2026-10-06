extends RefCounted
const VERSION: String = "time-attack-1"
var deadline: float = 0.0
var extension: float = 0.0
var last_ordinal: int = 0
var expired: bool = false

static func settings(entry: Resource) -> Dictionary:
	var sector: float = (entry.target_lap_seconds.x+entry.target_lap_seconds.y)*0.5/entry.route.gate_count
	return {"start":snappedf(sector*1.8+5.0,0.1),"extension":snappedf(sector*0.9,0.1)}

func reset(start: float, bonus: float) -> void:
	deadline = start
	extension = bonus
	last_ordinal = 0
	expired = false

func remaining(clock: float) -> float:
	return maxf(0.0,deadline-clock)

func checkpoint(ordinal: int, crossing_time: float) -> bool:
	if expired or ordinal!=last_ordinal+1 or crossing_time<0.0 or crossing_time>deadline: return false
	last_ordinal = ordinal
	deadline += extension
	return true
