extends Node2D
var race: Node2D
var line: PackedVector2Array = PackedVector2Array()
var map_scale: float = 0.065
var map_offset: Vector2 = Vector2.ZERO
func _ready() -> void:
	race = get_parent().get_parent()
	rebuild()
func rebuild() -> void:
	line.clear()
	var points: PackedVector2Array = race.get_node("Track").points
	if points.is_empty(): return
	var bounds := Rect2(points[0],Vector2.ZERO)
	for point in points: bounds = bounds.expand(point)
	map_scale = minf(192.0/maxf(bounds.size.x,1.0),130.0/maxf(bounds.size.y,1.0))
	map_offset = Vector2(4,4)-bounds.position*map_scale
	for point in points: line.append(point*map_scale+map_offset)
	queue_redraw()
func _draw() -> void:
	draw_rect(Rect2(-12,-24,226,176),Color(0.12,0.16,0.15,0.92))
	if line.size()<2: return
	draw_polyline(line,Color("#b9c5ad"),4,true)
	for car in race.cars:
		if not car.active: continue
		var tint: Color = Color("#ee7656") if car.player==1 else (Color("#69b9d2") if car.player==2 else (Color("#e4c568") if car.player==3 else Color("#9ac77b")))
		var pos: Vector2 = car.position*map_scale+map_offset
		draw_circle(pos,4.0 if not car.ai else 2.8,tint)
		if not car.ai: draw_arc(pos,7,0,TAU,16,Color.WHITE,1,true)
