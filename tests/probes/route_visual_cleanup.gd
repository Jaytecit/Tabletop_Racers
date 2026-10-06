extends "res://tests/autopilot/probe_base.gd"

func _ready() -> void:
	await super._ready()
	await settle(4)
	var race: Node3D = get_tree().current_scene.get_node("Race")
	race.profile.read_only = true
	race.controller.set_process_input(false)
	race.controller.set_physics_process(false)
	race.controller.using_pad = false
	race.controller.device = -1
	var catalog: Script = load("res://scripts/tracks/content_catalog.gd")
	var choices: OptionButton = race.menu.get_node("TrackSelect")
	var failures: Array[String] = []
	if "beach_buggies" in catalog.IDS: failures.append("Beach remains registered")
	if not catalog.load_entry("beach_buggies").has("error"): failures.append("Beach still loads through catalogue")
	if choices.item_count!=catalog.IDS.size(): failures.append("Menu/catalogue count mismatch")
	for index: int in range(choices.item_count):
		if choices.get_item_text(index)=="Beach Buggies": failures.append("Beach remains in menu")
	var checks: Array[Dictionary] = []
	for id: String in ["toys_r_you","toys_r_asleep","rusty_nuts_workshop","moonlight_junk_heap","firefly_bbq","nighttime_noodles"]:
		if not race.course.select(id):
			failures.append(id+": "+race.course.error)
			continue
		await settle_physics(5)
		var overlay: Node = race.track.get_node_or_null("Generated/RouteDebugOverlay")
		var flags: Node = race.track.get_node_or_null("Generated/CheckpointFlags")
		checks.append({"id":id,"overlay_absent":overlay==null,"flags_present":flags!=null})
		if overlay!=null: failures.append(id+": overlay exists")
		if flags==null: failures.append(id+": flags missing")
		race.track.rebuild_art()
		await settle_physics(5)
		if race.track.has_node("Generated/RouteDebugOverlay"): failures.append(id+": overlay returns after rebuild")
		if id=="toys_r_you":
			race.menu.hide()
			race.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			race.camera.size = 132
			race.camera.far = 400
			race.camera.position = Vector3(0,200,0)
			race.camera.rotation_degrees = Vector3(-90,0,0)
			await settle(3)
			save_frame("toys_no_reference_lines")
			race.show_menu()
	race.race_mode = "trial"
	if not race.course.select("toys_r_you"): failures.append("Time Trial selection failed")
	await settle(3)
	save_frame("course_menu")
	report("courses",checks)
	report("menu_count",choices.item_count)
	report("failures",failures)
	report("passed",failures.is_empty())
	finish()
