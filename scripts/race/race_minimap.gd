extends Control
const MAP_FONT: Font = preload("res://assets/arcade/arcade_font.fnt")
# Cache the authoritative route; only live markers need periodic redraws.
var race: Node3D
var route: Resource
var segments: Array[PackedVector2Array] = []
var layers: PackedInt32Array = []
var lower_lines: PackedVector2Array = []
var upper_lines: PackedVector2Array = []
var centre: Vector2 = Vector2.ZERO
var fit: float = 1.0
var tick: float = 0.0
var rebuilds: int = 0
var panel: StyleBoxFlat

func _ready() -> void:
	race = get_parent().get_parent()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel = panel_style()

func map_position(position3: Vector3) -> Vector2:
	return (Vector2(position3.x,position3.z)-centre)*fit+size*0.5

func rebuild() -> void:
	route = race.track.definition
	segments.clear()
	layers.clear()
	lower_lines.clear()
	upper_lines.clear()
	var bounds: Rect2 = Rect2(race.track.points[0],Vector2.ZERO)
	for point: Vector2 in race.track.points: bounds = bounds.expand(point)
	centre = bounds.get_center()
	fit = minf((size.x-32.0)/maxf(bounds.size.x,1.0),(size.y-40.0)/maxf(bounds.size.y,1.0))
	for index: int in range(race.track.starts.size()):
		segments.append(PackedVector2Array([map_position(race.track.starts[index]),map_position(race.track.ends[index])]))
		layers.append(race.track.at(race.track.lengths[index]).layer)
		if layers[-1]>0: upper_lines.append_array(segments[-1])
		else: lower_lines.append_array(segments[-1])
	rebuilds += 1
	queue_redraw()

func _process(delta: float) -> void:
	visible = race.phase in [1,2,5]
	if not visible: return
	if route!=race.track.definition: rebuild()
	tick += delta
	if tick>=0.05:
		tick = 0.0
		queue_redraw()

func _draw() -> void:
	if route==null: return
	draw_style_box(panel,Rect2(Vector2.ZERO,size))
	# Draw upper lanes last, with a dark halo exposing the crossing separation.
	if not lower_lines.is_empty(): draw_multiline(lower_lines,Color("8adfff"),3.0,true)
	if not upper_lines.is_empty():
		draw_multiline(upper_lines,Color("102422"),7.0,true)
		draw_multiline(upper_lines,Color("fff000"),3.0,true)
	var start: Vector2 = map_position(race.track.sample_3d(route.start_station))
	draw_rect(Rect2(start-Vector2(3,3),Vector2(6,6)),Color.WHITE)
	for car: CharacterBody3D in race.cars:
		var marker: Vector2 = map_position(car.position).clamp(Vector2(8,8),size-Vector2(8,8))
		var colour: Color = car.get_meta("vehicle_colour",Color.WHITE)
		draw_circle(marker,6.5 if car==race.player_car else 6.0,Color.WHITE if car==race.player_car else Color("102422"))
		draw_circle(marker,4.5,colour)

func panel_style() -> StyleBoxFlat:
	return preload("res://scripts/race/arcade_presentation.gd").box(Color(0.028,0.16,0.48,0.90),Color("00d5ff"),2)
