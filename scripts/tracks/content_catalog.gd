extends RefCounted
# Paths only: load the selected environment, never all catalogue scenery.
const IDS: Array[String] = ["game_table","toys_r_you","toys_r_asleep","rusty_nuts_workshop","moonlight_junk_heap","firefly_bbq","nighttime_noodles","mount_rainier","topspeed_oval","bazaar","town_square"]
const TITLES: Array[String] = ["Roulette Grand Prix","Toys R You","Toys R Asleep","Rusty Nuts Workshop","Moonlight Junk Heap","Firefly BBQ","Nighttime Noodles","Mount Rainier","Topspeed Oval","Bazaar","Town Square"]
const ENTRY: Script = preload("res://scripts/tracks/track_entry.gd")
const VALIDATOR: Script = preload("res://scripts/tracks/track_validator.gd")
const VEHICLES: Script = preload("res://scripts/vehicles/vehicle_catalog.gd")
const CAPABILITIES: Script = preload("res://scripts/tracks/course_capabilities.gd")
const DRIFT_COURSES: Array[String] = ["bazaar"]
# Classification is separate from accepted route geometry. Road imports retain
# their neutral legacy friction preset; their rendered road determines the group.
const CLASSIFICATION: Dictionary = {
	"game_table":{"group":"TABLETOP","vehicle":"buggy","surface":"Felt / wood"},
	"toys_r_you":{"group":"TABLETOP","vehicle":"buggy","surface":"Wood"},
	"toys_r_asleep":{"group":"TABLETOP","vehicle":"buggy","surface":"Wood / paper"},
	"rusty_nuts_workshop":{"group":"TABLETOP","vehicle":"buggy","surface":"Wood / paper"},
	"moonlight_junk_heap":{"group":"TABLETOP","vehicle":"buggy","surface":"Wood / paper"},
	"firefly_bbq":{"group":"TABLETOP","vehicle":"buggy","surface":"Wood / paper / fabric"},
	"nighttime_noodles":{"group":"TABLETOP","vehicle":"buggy","surface":"Wood / paper / fabric"},
	"mount_rainier":{"group":"ROAD","vehicle":"racing_car","surface":"Mountain road"},
	"topspeed_oval":{"group":"ROAD","vehicle":"racing_car","surface":"Stadium road"},
	"bazaar":{"group":"ROAD","vehicle":"racing_car","surface":"Market road"},
	"town_square":{"group":"ROAD","vehicle":"racing_car","surface":"Cobblestone road"}
}

static func assigned_vehicle(id: String) -> String:
	return CLASSIFICATION.get(canonical_id(id),{}).get("vehicle","buggy")

static func mode_vehicle(id: String, mode: String) -> String:
	return "drift_car" if mode=="drift" else assigned_vehicle(id)

static func group_title(id: String) -> String:
	return CLASSIFICATION.get(canonical_id(id),{}).get("group","TABLETOP")

static func choice_title(index: int) -> String:
	return group_title(IDS[index])+" · "+TITLES[index]

static func canonical_id(id: String) -> String:
	return "game_table" if id=="blackjack" else id

static func validate_mode(id: String, mode: String, vehicle: String = "") -> String:
	return CAPABILITIES.validate(canonical_id(id),mode,vehicle)

static func eligible_courses(mode: String) -> Array[String]:
	return CAPABILITIES.eligible(mode)

static func load_entry(id: String, vehicle: String = "", freestyle: bool = false, drift: bool = false) -> Dictionary:
	id = canonical_id(id)
	if vehicle.is_empty(): vehicle = assigned_vehicle(id)
	if id not in IDS: return {"error":"Unknown course: "+id}
	var capability_error: String = validate_mode(id,"drift" if drift else ("freestyle" if freestyle else "quick"),vehicle)
	if not capability_error.is_empty(): return {"error":capability_error}
	var path: String = "res://tracks/%s/entry.tres" % id
	if not ResourceLoader.exists(path): return {"error":"Course file unavailable: "+id}
	var environment: String = "blackjack" if id=="game_table" else id
	var theme: String = "kitchen" if id in ["cereal_slalom","plate_rim","countertop_table"] else ("bedroom" if id in ["carpet_cruise","desk_drawer","toybox_trestle"] else "casino")
	if id in ["toys_r_you","toys_r_asleep","rusty_nuts_workshop","moonlight_junk_heap","firefly_bbq","nighttime_noodles","mount_rainier","topspeed_oval","bazaar","town_square"]: theme = "tabletop"
	for required: String in ["res://tracks/%s/definition.tres" % id,"res://environments/%s/%s.tscn" % [theme,environment],"res://tracks/%s/preview.res" % id]:
		if not ResourceLoader.exists(required): return {"error":"Course resource unavailable: "+id}
	var entry: Resource = load(path)
	return validate_entry(entry,id,vehicle,freestyle,drift)

static func validate_entry(entry: Resource, id: String, vehicle: String, freestyle: bool = false, drift: bool = false) -> Dictionary:
	var capability_error: String = validate_mode(id,"drift" if drift else ("freestyle" if freestyle else "quick"),vehicle)
	if not capability_error.is_empty(): return {"error":capability_error}
	if entry==null or not is_instance_of(entry,ENTRY): return {"error":"Invalid course entry"}
	if entry.id!=id or entry.title.is_empty(): return {"error":"Course identity mismatch"}
	if entry.route==null or entry.environment==null or entry.preview==null: return {"error":"Course resources unavailable"}
	if drift and id not in DRIFT_COURSES: return {"error":"Course is not eligible for Drift Challenge"}
	if vehicle not in VEHICLES.IDS or (not freestyle and vehicle!=mode_vehicle(id,"drift" if drift else "quick")): return {"error":"Vehicle cannot enter this course"}
	var errors: Array[String] = VALIDATOR.validate(entry.route)
	if not errors.is_empty(): return {"error":errors[0]}
	if entry.route.id!=id: return {"error":"Route identity mismatch"}
	return {"entry":entry}


