extends "res://tests/autopilot/probe_base.gd"
const CATALOG: Script = preload("res://scripts/tracks/content_catalog.gd")
const CAPS: Script = preload("res://scripts/tracks/course_capabilities.gd")
var failures: Array[String] = []
var checks: int = 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func _ready() -> void:
	super._ready()
	await settle(4)
	var race: Node = get_tree().current_scene.get_node("Race")
	race.profile.read_only = true
	race.machine_settings.read_only = true
	race.profile_directory.read_only = true
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.device = -1
	race.controller.using_pad = false
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	var cold_paths: Array[String] = []
	for id: String in CATALOG.IDS:
		if id!=race.track_id:
			var theme: String = "casino" if id=="game_table" else "tabletop"
			var name_id: String = "blackjack" if id=="game_table" else id
			var path: String = "res://environments/%s/%s.tscn" % [theme,name_id]
			if not ResourceLoader.has_cached(path): cold_paths.append(path)
	check(CATALOG.IDS==CAPS.ACCEPTED,"accepted_ids_match_catalogue")
	check(CATALOG.eligible_courses("drift")==CATALOG.DRIFT_COURSES,"drift_only_bazaar")
	for mode: String in CAPS.MODES:
		for id: String in CATALOG.eligible_courses(mode):
			check(id in CATALOG.IDS,"filtered_course_accepted_"+id+mode)
			check(CATALOG.validate_mode(id,mode).is_empty(),"eligible_valid_"+id+mode)
	check(not CATALOG.validate_mode("raceway","quick").is_empty(),"unverified_route_rejected")
	check(not CATALOG.validate_mode("beach_buggies","quick").is_empty(),"retired_rejected")
	check(not CATALOG.validate_mode("bazaar","unknown").is_empty(),"unknown_mode_rejected")
	check(not CATALOG.validate_mode("bazaar","quick","hovercraft").is_empty(),"unknown_vehicle_rejected")
	check(not CATALOG.validate_mode("topspeed_oval","drift").is_empty(),"unsupported_combination_rejected")
	check(CATALOG.eligible_courses("unknown").is_empty(),"unknown_filter_empty")
	check(not CATALOG.load_entry("raceway").get("error","").is_empty(),"unregistered_load_rejected")
	var copy: Dictionary = CAPS.describe("bazaar")
	copy.modes.clear()
	check(CAPS.describe("bazaar").modes.has("drift"),"metadata_mutation_isolated")
	for path: String in cold_paths: check(not ResourceLoader.has_cached(path),"classification_did_not_load_"+path)
	check(cold_paths.size()>=8,"lazy_check_covers_unselected_environments")
	await settle(3)
	race.course.refresh()
	var choice: OptionButton = race.menu.get_node("TrackSelect")
	for mode: String in ["quick","trial","drift"]:
		race.race_mode = mode
		race.course.refresh()
		for index: int in range(CATALOG.IDS.size()):
			check(choice.is_item_disabled(index)==(not CATALOG.validate_mode(CATALOG.IDS[index],mode).is_empty()),"selector_"+mode+str(index))
	race.race_mode = "quick"
	race.course.refresh()
	get_tree().current_scene.get_node("Opening").queue_free()
	get_tree().paused = false
	race.get_node("HUD").show()
	race.menu_flow.show_step(3)
	await settle(2)
	save_frame("accepted-selector")
	report("checks",checks)
	report("failures",failures)
	report("passed",failures.is_empty())
	finish()
