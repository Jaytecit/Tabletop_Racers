extends RefCounted
const IDS: Array[String] = ["buggy","monster_truck","racing_car","drift_car","speedboat"]
const TITLES: Array[String] = ["BEACH BUGGY","MONSTER TRUCK","RACING CAR","DRIFT CAR","SPEEDBOAT"]

static func definition(id: String) -> Resource:
	if id not in IDS: return null
	return load("res://scenes/vehicles/%s_definition.tres" % id)

static func title(id: String) -> String:
	var index: int = IDS.find(id)
	return TITLES[index] if index>=0 else "UNKNOWN VEHICLE"
