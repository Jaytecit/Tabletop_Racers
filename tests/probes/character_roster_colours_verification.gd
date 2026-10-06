extends "res://tests/autopilot/probe_base.gd"
const CHARACTERS: Script = preload("res://scripts/profiles/character_catalog.gd")
const VISUAL: Script = preload("res://scripts/vehicles/imported_visual.gd")
var failures: Array[String] = []
func check(value: bool, label: String) -> void:
	report(label,value)
	if not value: failures.append(label)
func _ready() -> void:
	await super._ready()
	await settle(5)
	var app: Node = get_tree().current_scene
	var race: Node3D = app.get_node("Race")
	check(race.profile.read_only and race.profile_directory.read_only,"read_only_profiles")
	race.machine_settings.read_only = true
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.device = -1
	for action: StringName in InputMap.get_actions(): InputMap.action_erase_events(action)
	app.get_node("Opening/Sequence").hardware_input_isolated = true
	app.get_node("Opening/Sequence")._restore_menu()
	app.get_node("Opening").queue_free()
	get_tree().paused = false
	race.profile_selected = true
	race.show_menu()
	race.course.select("game_table")
	while race.course.loading: await get_tree().process_frame
	race.profile.data.identity.name = "Jay"
	race.profile.data.gold_livery = false
	race.profile.data.character_colour_id = -1
	var unique_names: Array = []
	var unique_colours: Array = []
	for i: int in range(8):
		check(CHARACTERS.NAMES[i] not in unique_names and CHARACTERS.COLOURS[i] not in unique_colours and not CHARACTERS.BIOS[i].is_empty(),"character_identity_%d"%i)
		unique_names.append(CHARACTERS.NAMES[i])
		unique_colours.append(CHARACTERS.COLOURS[i])
		race.profile.data.identity.portrait_id = i
		race.garage.select(race,0)
		var roster: Array = []
		for slot: int in range(4):
			var character: int = CHARACTERS.portrait_for_slot(i,slot)
			var car: CharacterBody3D = race.all_cars[slot]
			check(car.get_meta("vehicle_colour").is_equal_approx(CHARACTERS.COLOURS[character]),"character_colour_%d_%d"%[i,slot])
			check(race.names[slot]==("Jay" if slot==0 else CHARACTERS.NAMES[character].to_upper()),"character_name_%d_%d"%[i,slot])
			check(race.identities.racers[car.player].bio==CHARACTERS.BIOS[character],"character_bio_%d_%d"%[i,slot])
			roster.append(character)
		check(roster[0]==i and roster[1]!=i and roster[2]!=i and roster[3]!=i,"no_player_clone_%d"%i)
		# The catalogue can assign all eight identities without repeats; race size remains four.
		var eight: Array[int] = []
		for slot: int in range(8): eight.append(CHARACTERS.portrait_for_slot(i,slot))
		check(eight.size()==8 and 0 in eight and 1 in eight and 2 in eight and 3 in eight and 4 in eight and 5 in eight and 6 in eight and 7 in eight,"eight_identity_assignment_%d"%i)
	race.profile_menu.open()
	race.profile_menu.create()
	for i: int in range(8):
		race.profile_menu.choose_portrait(i)
		check(race.profile_menu.character_name.text==CHARACTERS.NAMES[i].to_upper() and race.profile_menu.character_bio.text==CHARACTERS.BIOS[i],"profile_bio_display_%d"%i)
	await settle(3)
	save_frame("named_character_picker")
	race.profile_menu.hide()
	race.profile.data.identity.portrait_id = 6
	race.show_menu()
	race.menu_flow.show_step(1)
	check(race.menu_flow.colour_choice.item_count==9 and race.menu_flow.colour_choice.visible,"garage_colour_picker")
	await settle(3)
	save_frame("character_stats_colour")
	var reference_stats: Dictionary = race.profile.vehicle().stats.duplicate()
	for i: int in range(8):
		race.menu_flow.colour_choice.item_selected.emit(i+1)
		check(race.profile.data.character_colour_id==i and race.player_car.get_meta("vehicle_colour").is_equal_approx(CHARACTERS.COLOURS[i]),"select_paint_%d"%i)
		check(race.profile.vehicle().stats==reference_stats,"paint_preserves_skills_%d"%i)
		var raw: Dictionary = race.profile.data.duplicate(true)
		check(race.profile.validate(raw).character_colour_id==i,"paint_roundtrip_%d"%i)
	race.menu_flow.colour_choice.item_selected.emit(0)
	check(race.player_car.get_meta("vehicle_colour").is_equal_approx(CHARACTERS.COLOURS[6]),"automatic_character_colour")
	for vehicle: String in ["buggy","monster_truck","racing_car","drift_car","speedboat"]:
		race.set_vehicle(vehicle)
		race.profile.vehicle().paint = "stock"
		race.profile.data.character_colour_id = 7
		race.garage.select(race,0)
		preload("res://scripts/race/race_lighting.gd").set_lamps(race,true)
		for car: CharacterBody3D in race.all_cars:
			var colour: Color = car.get_meta("vehicle_colour")
			for mesh: MeshInstance3D in VISUAL.paint_meshes(car.visual):
				check(mesh.material_override.get_shader_parameter("player_colour").is_equal_approx(colour),"mesh_%s_%d"%[vehicle,car.player])
			check(car.get_node("VehicleLamps/TaillightL").light_color.is_equal_approx(colour) and car.get_node("VehicleLamps/TaillightR").light_color.is_equal_approx(colour),"lighting_%s_%d"%[vehicle,car.player])
	race.set_vehicle("buggy")
	race.profile.data.character_colour_id = 6
	race.garage.select(race,0)
	race.race_mode = "freestyle"
	race.show_menu()
	race.menu_flow.show_step(2)
	await settle(3)
	save_frame("garage_character_colour")
	# Existing unlocked paint wins in automatic mode; explicit palettes override only appearance.
	race.profile.data.character_colour_id = -1
	race.profile.vehicle().paint = "chrome"
	race.garage.select(race,0)
	check(race.player_car.get_meta("vehicle_colour").is_equal_approx(preload("res://scripts/vehicles/vehicle_progression.gd").COLORS[3]),"equipped_paint_kept")
	race.profile.data.gold_livery = true
	race.garage.select(race,0)
	check(race.player_car.get_meta("vehicle_colour").is_equal_approx(Color("e7ba52")),"gold_kept")
	race.profile.data.character_colour_id = 6
	race.garage.select(race,0)
	check(race.profile.data.gold_livery and race.player_car.get_meta("vehicle_colour").is_equal_approx(CHARACTERS.COLOURS[6]),"palette_preserves_gold_unlock")
	race.profile.data.gold_livery = false
	race.profile.vehicle().paint = "stock"
	race.race_mode = "quick"
	race.rival_count = 3
	race.difficulty = 2
	race.start_race()
	race.begin_countdown()
	race.session.countdown = 0.81
	for i: int in range(4): await get_tree().physics_frame
	await press("p1_go",1000)
	check(race.player_car.velocity.length()>0.1,"drives_with_character_palette")
	check(race.cars.size()==4 and race.rival_count==3,"four_car_selection_retained")
	await settle(3)
	save_frame("character_grid")
	var rows: Array = []
	for car: CharacterBody3D in race.cars: rows.append({"player":car.player,"rank":car.player,"time":10.0+car.player,"finished":true,"penalty":0.0})
	race.show_menu()
	preload("res://scripts/race/arcade_podium.gd").show_results(race,rows)
	var podium: Node = race.results_panel.get_node("Podium")
	check(podium.get_node("Driver1").tooltip_text==CHARACTERS.NAMES[7].to_upper(),"podium_ai_name")
	var old_profile: Dictionary = race.profile.defaults()
	old_profile.schema_version = 15
	old_profile.erase("character_colour_id")
	check(race.profile.validate(old_profile).character_colour_id==-1,"legacy_profile_default")
	report("failures",failures)
	report("passed",failures.is_empty())
	for voice: Node in app.find_children("*","AudioStreamPlayer",true,false):
		voice.stop()
		voice.stream = null
	await settle(3)
	finish()
