extends Node
# Index metadata is cheap; only the selected circuit's route is loaded/built.
var entries: Array = []
var current_id: String = ""
var error_message: String = ""
func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tracks/catalog.json"))
	if not parsed is Array:
		error_message = "Track catalog must be an array"
		return
	var seen: Dictionary = {}
	for entry in parsed:
		if not entry is Dictionary: continue
		var id: String = str(entry.get("id",""))
		var path: String = str(entry.get("file",""))
		if id.is_empty() or seen.has(id) or not path.begins_with("res://tracks/") or not path.ends_with(".json"):
			print("Skipped invalid/duplicate catalog entry: ",id)
			continue
		seen[id] = true
		entries.append({"id":id,"file":path,"title":str(entry.get("title",id)),"description":str(entry.get("description",""))})
func definition(index: int) -> Dictionary:
	error_message = ""
	if index<0 or index>=entries.size():
		error_message = "Track selection is out of range"
		return {}
	var entry: Dictionary = entries[index]
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(entry.file)))
	if not parsed is Dictionary:
		error_message = "Cannot read track "+str(entry.id)
		return {}
	var route: Variant = parsed.get("route",[])
	if not route is Array or route.size()<4 or route.size()>256:
		error_message = "Track route needs 4–256 control points"
		return {}
	var packed := PackedVector2Array()
	for point in route:
		if not point is Array or point.size()!=2 or not (point[0] is float or point[0] is int) or not (point[1] is float or point[1] is int):
			error_message = "Invalid route coordinate"
			return {}
		var pos := Vector2(float(point[0]),float(point[1]))
		if not pos.is_finite() or pos.x<100.0 or pos.y<100.0 or pos.x>3000.0 or pos.y>2200.0:
			error_message = "Route lies outside the room"
			return {}
		if not packed.is_empty() and pos.distance_to(packed[packed.size()-1])<100.0:
			error_message = "Route control points are too close"
			return {}
		packed.append(pos)
	if packed[0].distance_to(packed[packed.size()-1])<100.0:
		error_message = "Closing control points are too close"
		return {}
	var width_value: Variant = parsed.get("half_width",84.0)
	var laps_value: Variant = parsed.get("laps",3)
	var road_value: Variant = parsed.get("road_color","#606963")
	if not (width_value is float or width_value is int) or not (laps_value is float or laps_value is int) or not road_value is String or not Color.html_is_valid(road_value):
		error_message = "Track width, laps or road color is invalid"
		return {}
	var width: float = float(width_value)
	if width<70.0 or width>120.0:
		error_message = "Track half-width must be 70–120"
		return {}
	return {"id":str(entry.id),"title":str(entry.get("title",entry.id)),"description":str(entry.get("description","")),"corners":packed,"half_width":width,"raised":bool(parsed.get("raised",false)),"laps":clampi(int(laps_value),1,9),"road_color":Color(road_value)}
