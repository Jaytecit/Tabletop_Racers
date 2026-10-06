extends "res://tests/fixtures/track_eight_before.gd"
var span_bounds: Array[Rect2] = []
# Opt-in probe-only inclusive timers. No route or gameplay changes.
var measurements: Dictionary = {}

func record_cost(method: String, begun: int) -> void:
	var elapsed: int = Time.get_ticks_usec()-begun
	if not measurements.has(method): measurements[method] = {"calls":0,"total_usec":0,"max_usec":0}
	var row: Dictionary = measurements[method]
	row.calls += 1
	row.total_usec += elapsed
	row.max_usec = maxi(row.max_usec,elapsed)

func project_3d(pos: Vector3, hint: float = -1.0, window: float = 5.0) -> Dictionary:
	var begun: int = Time.get_ticks_usec()
	var result: Dictionary = super.project_3d(pos,hint,window)
	record_cost("project_3d",begun)
	return result

func at(station: float) -> Dictionary:
	var begun: int = Time.get_ticks_usec()
	var result: Dictionary = super.at(station)
	record_cost("at",begun)
	return result

func direction(station: float) -> Vector2:
	var begun: int = Time.get_ticks_usec()
	var result: Vector2 = super.direction(station)
	record_cost("direction",begun)
	return result

func measured_height(index: int, point: Vector2) -> float:
	var begun: int = Time.get_ticks_usec()
	var result: float = super.measured_height(index,point)
	record_cost("measured_height",begun)
	return result

