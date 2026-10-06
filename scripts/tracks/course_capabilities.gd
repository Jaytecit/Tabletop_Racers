extends RefCounted
# Route acceptance and mode coverage are independent of visual classification.
# Only accepted course IDs belong here. No environment resources are loaded.
const MODES: Array[String] = ["quick","trial","freestyle","challenge","time_attack","elimination","tournament","drift","cup"]
const ACCEPTED: Array[String] = ["game_table","toys_r_you","toys_r_asleep","rusty_nuts_workshop","moonlight_junk_heap","firefly_bbq","nighttime_noodles","mount_rainier","topspeed_oval","bazaar","town_square"]
const VEHICLES: Array[String] = ["buggy","monster_truck","racing_car","drift_car","speedboat"]

static func describe(id: String) -> Dictionary:
	if id not in ACCEPTED: return {}
	if id=="town_square":
		return {"route_accepted":true,"modes":["quick","trial","freestyle"],"vehicles":VEHICLES.duplicate(),"loft":false,"layer_review":"one flat source-derived annulus","mode_coverage":"verified circuit and five-class Freestyle; additional modes pending course trials"}
	var modes: Array[String] = ["quick","trial","freestyle","challenge","time_attack","elimination"]
	if id!="bazaar": modes.append("tournament")
	if id=="bazaar": modes.append("drift")
	return {"route_accepted":true,"modes":modes,"vehicles":VEHICLES.duplicate(),"loft":false,"layer_review":"accepted route; see per-course evidence","mode_coverage":"existing enabled modes; full per-course target balance remains pending"}

static func validate(id: String, mode: String, vehicle: String = "") -> String:
	if mode not in MODES: return "Unknown race mode: "+mode
	var capabilities: Dictionary = describe(id)
	if capabilities.is_empty(): return "Course has no accepted route: "+id
	if mode not in capabilities.modes: return "Course %s is not eligible for mode %s" % [id,mode]
	if not vehicle.is_empty() and vehicle not in capabilities.vehicles: return "Unsupported vehicle %s for course %s" % [vehicle,id]
	return ""

static func eligible(mode: String) -> Array[String]:
	var ids: Array[String] = []
	for id: String in ACCEPTED:
		if validate(id,mode).is_empty(): ids.append(id)
	return ids
