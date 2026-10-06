extends "res://tests/autopilot/probe_base.gd"
var failures: Array[String] = []
func check(label: String, value: bool) -> void:
	report(label,value)
	if not value: failures.append(label)
func _ready() -> void:
	await super._ready()
	await settle(30)
	var race: Node = get_tree().current_scene.get_node("Race")
	# Input regression must never overwrite the player's saved driver or preferences.
	race.profile.path = "user://m4_input_test.json"
	race.profile.data.gold_livery = false
	race.race_mode = "quick"
	race.rival_count = 3
	race.race_laps = 3
	race.show_menu()
	check("paired_flags",race.track.get_node("Generated/CheckpointFlags").get_child_count()==16)
	race.garage.cards[3].pressed.emit()
	check("selected_driver",race.garage.selected==3)
	check("selected_livery",race.player_car.visual.get_node("Body").material_override.albedo_color==race.garage.COLORS[3])
	await settle(5)
	save_frame("garage")
	await press("start_race",100)
	for frame: int in range(200): await get_tree().physics_frame
	check("racing",race.phase==2)
	var before: Vector3 = race.player_car.position
	await press("p1_go",500)
	check("keyboard_drives",race.player_car.position.distance_to(before)>0.5)
	check("engine_layers",race.engine_sound.playing and race.engine_layer.playing)
	check("music_playing",race.music.playing)
	race.toggle_pause()
	var clock: float = race.race_time
	for frame: int in range(10): await get_tree().physics_frame
	check("pause_freezes",race.race_time==clock and race.music.stream_paused and race.engine_layer.stream_paused)
	race.toggle_pause()
	# Controlled legal-sample fixture exercises the visible missed-gate sequence.
	race.set_physics_process(false)
	for car: CharacterBody3D in race.cars: car.set_physics_process(false)
	race.start_race()
	race.session.countdown = 0.8
	race.session.tick(0.05)
	var car: CharacterBody3D = race.player_car
	var boundary: float = race.track.definition.start_station+race.track.total_length/8.0
	car.station = boundary-0.1
	var direction: Vector2 = race.track.direction(car.station)
	car.position = race.track.sample_3d(car.station)+Vector3(-direction.y,0,direction.x)*4.1
	race.session.progress.rebase(car)
	car.station = boundary+0.1
	direction = race.track.direction(car.station)
	car.position = race.track.sample_3d(car.station)+Vector3(-direction.y,0,direction.x)*4.1
	race.session.observe(car,Vector2(car.station,4.1),0.05)
	race._physics_process(0.05)
	check("visible_warning",race.banner.visible and race.banner.text.contains("MISSED GATE"))
	await settle()
	save_frame("missed_gate")
	race.session.tick(5.0)
	race._physics_process(0.05)
	check("visible_penalty",race.banner.text.contains("+5s PENALTY"))
	await settle()
	save_frame("penalty")
	report("failures",failures)
	report("passed",failures.is_empty())
	for suffix: String in ["",".bak",".tmp",".bak.tmp"]:
		DirAccess.remove_absolute("user://m4_input_test.json"+suffix)
	finish()
