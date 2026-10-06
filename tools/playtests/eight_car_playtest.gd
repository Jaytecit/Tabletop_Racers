extends "res://scripts/app.gd"
# Interactive practice launch: real hardware input, no personal profile writes.
var ready_for_driver: bool = false
var startup_error: String = ""
func _enter_tree() -> void:
	get_tree().node_added.connect(func(node: Node) -> void:
		if node.name=="Race" and node.get("profile_directory")!=null:
			node.profile_directory.read_only = true
			node.machine_settings.read_only = true)
func play_opening() -> void:
	pass
func _ready() -> void:
	super._ready()
	await get_tree().process_frame
	var selected: String = race.profile_directory.index.last_selected
	if race.profile_directory.valid_id(selected) and not race.profile_directory.entry_for(selected).is_empty():
		race.profile.path = race.profile_directory.payload_path(selected)
		race.profile.load_profile()
		race.active_profile_id = selected
	race.profile.read_only = true
	race.profile_directory.read_only = true
	race.machine_settings.read_only = true
	race.profile.data.setup = race.machine_settings.data
	race.profile_selected = true
	race.profile_menu.hide()
	race.race_mode = "quick"
	race.rival_count = 7
	race.difficulty = 2
	race.race_laps = 3
	race.stats_test_mode = 0
	race.garage.select(race,int(race.profile.data.identity.portrait_id)%4)
	if not race.course.select("moonlight_junk_heap"):
		startup_error = race.course.error
		return
	while race.course.loading: await get_tree().process_frame
	await get_tree().process_frame
	if not race.course.error.is_empty():
		startup_error = race.course.error
		return
	race.start_race()
	ready_for_driver = race.phase==race.session.Phase.PREVIEW and race.cars.size()==8 and not race.player_car.ai
	if not ready_for_driver: startup_error = "Eight-car grid did not become ready."
