extends "res://scripts/vehicles/arcade_car.gd"
var measurements: Dictionary = {}
func cost(method: String, start: int) -> void:
	if not measurements.has(method): measurements[method] = {"calls":0,"usec":0,"max_usec":0}
	var elapsed: int = Time.get_ticks_usec()-start
	measurements[method].calls += 1
	measurements[method].usec += elapsed
	measurements[method].max_usec = maxi(measurements[method].max_usec,elapsed)
func _physics_process(delta: float) -> void:
	var start: int = Time.get_ticks_usec()
	super._physics_process(delta)
	cost("physics",start)
func physical_support(point: Vector3) -> Dictionary:
	var start: int = Time.get_ticks_usec()
	var result: Dictionary = super.physical_support(point)
	cost("support_ray",start)
	return result
func align_class_collision() -> void:
	var start: int = Time.get_ticks_usec()
	super.align_class_collision()
	cost("align_collision",start)
