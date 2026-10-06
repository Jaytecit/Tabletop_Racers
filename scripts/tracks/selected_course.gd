extends RefCounted
const CATALOG: Script = preload("res://scripts/tracks/content_catalog.gd")
var race: Node3D
var entry: Resource
var error: String = ""
var last_load_metrics: Dictionary = {}
const CACHE_LIMIT: int = 2
var cached_entries: Dictionary = {}
var cache_order: Array[String] = []
var loading: bool = false
var requested_id: String = ""
var request_serial: int = 0
var validation_worker: Thread

func configure(owner: Node3D) -> void:
	race = owner
	var choice: OptionButton = race.menu.get_node("TrackSelect")
	choice.clear()
	for index: int in range(CATALOG.IDS.size()): choice.add_item(CATALOG.choice_title(index))
	choice.item_selected.connect(func(index: int) -> void:
		request_select(CATALOG.IDS[index]))

func cache_entry(id: String, resource: Resource) -> void:
	cached_entries[id] = resource
	cache_order.erase(id)
	cache_order.append(id)
	while cache_order.size()>CACHE_LIMIT: cached_entries.erase(cache_order.pop_front())

func cancel_selection() -> void:
	request_serial += 1
	loading = false
	requested_id = ""

func shutdown() -> void:
	cancel_selection()
	if validation_worker!=null and validation_worker.is_started(): validation_worker.wait_to_finish()
	validation_worker = null

func request_select(id: String) -> void:
	var requested_at: int = Time.get_ticks_usec()
	id = CATALOG.canonical_id(id)
	if loading and requested_id==id: return
	cancel_selection()
	var serial: int = request_serial
	if id not in CATALOG.IDS:
		error = "Unknown course: "+id
		refresh()
		return
	loading = true
	requested_id = id
	error = ""
	refresh()
	var tree: SceneTree = race.get_tree()
	# Present the loading state before any main-thread validation/instantiation.
	await tree.process_frame
	await tree.process_frame
	if not is_instance_valid(race) or serial!=request_serial: return
	var resource_started: int = Time.get_ticks_usec()
	if not cached_entries.has(id):
		var path: String = "res://tracks/%s/entry.tres" % id
		var request_error: Error = ResourceLoader.load_threaded_request(path)
		if request_error!=OK:
			cancel_selection()
			error = "Course resource could not be loaded: "+id
			refresh()
			return
		var status: int = ResourceLoader.load_threaded_get_status(path)
		while status==ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await tree.process_frame
			status = ResourceLoader.load_threaded_get_status(path)
		# Drain completed requests even when superseded, without committing them.
		var resource: Resource = ResourceLoader.load_threaded_get(path) if status==ResourceLoader.THREAD_LOAD_LOADED else null
		if not is_instance_valid(race) or serial!=request_serial: return
		if resource==null:
			cancel_selection()
			error = "Course resource unavailable: "+id
			refresh()
			return
		cache_entry(id,resource)
	var resource_ms: float = (Time.get_ticks_usec()-resource_started)/1000.0
	var queued_at: int = Time.get_ticks_usec()
	var vehicle: String = race.profile.data.quick_race.vehicle_id if race.race_mode=="freestyle" else CATALOG.mode_vehicle(id,race.race_mode)
	var freestyle: bool = race.race_mode=="freestyle"
	var drift: bool = race.race_mode=="drift"
	# Validate immutable resources on one worker; never touch scene nodes there.
	# New selections wait for the previous worker to drain, then only the latest runs.
	while validation_worker!=null:
		await tree.process_frame
		if serial!=request_serial: return
	if serial!=request_serial: return
	var worker: Thread = Thread.new()
	validation_worker = worker
	var validation_start: int = Time.get_ticks_usec()
	var queue_ms: float = (validation_start-queued_at)/1000.0
	var staged: Dictionary
	if worker.start(CATALOG.validate_entry.bind(cached_entries[id],id,vehicle,freestyle,drift))==OK:
		while worker.is_alive(): await tree.process_frame
		if not worker.is_started(): return # Shutdown already joined this worker.
		staged = worker.wait_to_finish()
	else:
		staged = CATALOG.validate_entry(cached_entries[id],id,vehicle,freestyle,drift)
	validation_worker = null
	if serial!=request_serial: return
	var validation_ms: float = (Time.get_ticks_usec()-validation_start)/1000.0
	# Retain source scenes, not live vehicle nodes/materials. An uncached class
	# loads off the main thread before the course/vehicle commit begins.
	var visuals: Script = preload("res://scripts/vehicles/imported_visual.gd")
	var vehicle_started: int = Time.get_ticks_usec()
	if not staged.has("error"):
		var vehicle_path: String = visuals.scene_path(vehicle)
		if not visuals.scene_cache.has(vehicle_path):
			var vehicle_error: Error = ResourceLoader.load_threaded_request(vehicle_path)
			var vehicle_scene: PackedScene
			if vehicle_error == OK:
				var vehicle_status: int = ResourceLoader.load_threaded_get_status(vehicle_path)
				while vehicle_status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
					await tree.process_frame
					vehicle_status = ResourceLoader.load_threaded_get_status(vehicle_path)
				if vehicle_status == ResourceLoader.THREAD_LOAD_LOADED:
					vehicle_scene = ResourceLoader.load_threaded_get(vehicle_path)
			if not is_instance_valid(race) or serial != request_serial: return
			if vehicle_scene == null:
				cancel_selection()
				error = "Vehicle scene unavailable: "+vehicle
				refresh()
				return
			visuals.retain_scene(vehicle_path,vehicle_scene)
	var vehicle_load_ms: float = (Time.get_ticks_usec()-vehicle_started)/1000.0
	if select(id,vehicle,staged):
		last_load_metrics["vehicle_resource_load_ms"] = vehicle_load_ms
		last_load_metrics["resource_load_ms"] = resource_ms
		last_load_metrics["validation_queue_ms"] = queue_ms
		last_load_metrics["background_validation_ms"] = validation_ms
		last_load_metrics["request_to_ready_ms"] = (Time.get_ticks_usec()-requested_at)/1000.0
		race.save_preferences()

func select(id: String, vehicle: String = "", prepared: Dictionary = {}) -> bool:
	cancel_selection()
	id = CATALOG.canonical_id(id)
	if vehicle.is_empty(): vehicle = race.profile.data.quick_race.vehicle_id if race.race_mode=="freestyle" else CATALOG.mode_vehicle(id,race.race_mode)
	var begun: int = Time.get_ticks_usec()
	var mark: int = begun
	last_load_metrics = {"course":id}
	# Stage and validate before touching the active course or its collision support.
	var staged: Dictionary = prepared
	if staged.is_empty():
		staged = CATALOG.validate_entry(cached_entries[id],id,vehicle,race.race_mode=="freestyle",race.race_mode=="drift") if cached_entries.has(id) else CATALOG.load_entry(id,vehicle,race.race_mode=="freestyle",race.race_mode=="drift")
	last_load_metrics["resource_validation_ms"] = (Time.get_ticks_usec()-mark)/1000.0
	mark = Time.get_ticks_usec()
	if staged.has("error"):
		error = staged.error
		race.show_menu()
		refresh()
		return false
	var next: Resource = staged.entry
	cache_entry(id,next)
	if entry!=null and entry.id==next.id:
		error = ""
		race.set_vehicle(vehicle)
		refresh()
		return true
	var sampled: Node3D = load("res://showcase_track.gd").new()
	sampled.definition = next.route
	sampled.build(true)
	last_load_metrics["sample_validation_ms"] = (Time.get_ticks_usec()-mark)/1000.0
	mark = Time.get_ticks_usec()
	if not sampled.validation_errors.is_empty():
		error = sampled.validation_errors[0]
		sampled.free()
		race.show_menu()
		refresh()
		return false
	var environment: Node = next.environment.instantiate()
	last_load_metrics["instantiate_ms"] = (Time.get_ticks_usec()-mark)/1000.0
	mark = Time.get_ticks_usec()
	if not environment is Node3D:
		environment.free()
		sampled.free()
		error = "Invalid environment scene"
		race.show_menu()
		refresh()
		return false
	race.session.change_phase(race.session.Phase.SETUP)
	race.cleanup()
	race.camera_driver.clear()
	var previous: Node = race.get_node_or_null("CourseEnvironment")
	if previous!=null:
		race.remove_child(previous)
		previous.free()
	environment.name = "CourseEnvironment"
	race.add_child(environment)
	if next.presentation == "bedroom":
		var display: Node3D = preload("res://scripts/tracks/bedroom_display.gd").new()
		display.configure(environment,race.get_node("Environment"))
		environment.add_child(display)
	race.track.definition = next.route
	# Transfer the already checked sampling result, instead of building it twice.
	# The staging node has no children/art and is freed immediately after transfer.
	for property: String in ["points","lengths","starts","ends","section_ids","total_length","half_width","validation_errors","gates","anchors","corridor_polygons","corridor_bounds","span_origins","span_vectors","span_denominators","span_bounds","corridor_heights","corridor_triangles"]:
		race.track.set(property,sampled.get(property))
	sampled.free()
	race.track.rebuild_art()
	last_load_metrics["replace_and_build_ms"] = (Time.get_ticks_usec()-mark)/1000.0
	mark = Time.get_ticks_usec()
	preload("res://scripts/tracks/blackjack_art.gd").standardize_cards(environment)
	preload("res://scripts/tracks/blackjack_art.gd").standardize_cards(race.track)
	entry = next
	error = ""
	race.track_id = next.id
	var configure_mark: int = Time.get_ticks_usec()
	race.set_vehicle(vehicle)
	last_load_metrics["vehicle_configure_ms"] = (Time.get_ticks_usec()-configure_mark)/1000.0
	configure_mark = Time.get_ticks_usec()
	race.camera_driver.configure(race)
	last_load_metrics["camera_configure_ms"] = (Time.get_ticks_usec()-configure_mark)/1000.0
	configure_mark = Time.get_ticks_usec()
	# set_vehicle -> garage.select -> apply_stats has already refreshed the
	# signature using this entry, route, vehicle and final composed stats.
	last_load_metrics["record_signature_ms"] = (Time.get_ticks_usec()-configure_mark)/1000.0
	configure_mark = Time.get_ticks_usec()
	race.garage.refresh_course_preview(race)
	last_load_metrics["course_preview_ms"] = (Time.get_ticks_usec()-configure_mark)/1000.0
	# Lighting runs last: the course environment and the vehicle visuals are final here.
	preload("res://scripts/race/race_lighting.gd").sync(race,next.id)
	last_load_metrics["preview_and_configure_ms"] = (Time.get_ticks_usec()-mark)/1000.0
	race.show_menu()
	refresh()
	last_load_metrics["total_ms"] = (Time.get_ticks_usec()-begun)/1000.0
	return true

func refresh() -> void:
	if race==null: return
	var choice: OptionButton = race.menu.get_node("TrackSelect")
	choice.select(CATALOG.IDS.find(requested_id if loading else race.track_id))
	choice.disabled = race.race_mode in ["cup","tournament"]
	for index: int in range(CATALOG.IDS.size()):
		choice.set_item_disabled(index,not CATALOG.validate_mode(CATALOG.IDS[index],race.race_mode).is_empty())
		choice.set_item_text(index,("DRIFT / " if race.race_mode=="drift" and CATALOG.IDS[index] in CATALOG.DRIFT_COURSES else "")+CATALOG.choice_title(index))
	if entry!=null:
		race.menu.get_node("Subtitle").text = entry.title.to_upper()+" · CHOOSE YOUR DRIVER"
		var vehicle_title: String = preload("res://scripts/vehicles/vehicle_catalog.gd").title(race.player_car.base_tuning.id)
		race.menu.get_node("CourseInfo").text = entry.description+"\n"+("FREESTYLE · " if race.race_mode=="freestyle" else "ASSIGNED · ")+vehicle_title+"\nMISSED GATE: 5s TO RETURN / THEN +5s"
		race.menu.get_node("CourseMap").texture = entry.preview
		race.get_node("HUD/Title").text = preload("res://scripts/race/game_brand.gd").NAME+" · "+entry.title.to_upper()
	if error!="":
		race.menu.get_node("CourseInfo").text = "COURSE UNAVAILABLE · "+error+"\nSelect another course to continue."
	if loading:
		race.menu.get_node("CourseInfo").text = "LOADING · "+CATALOG.TITLES[CATALOG.IDS.find(requested_id)]+"\nYou can choose another course or go back."
	race.menu.get_node("Start").text = "LOADING…" if loading else race.start_button_text()
	race.menu.get_node("Start").disabled = loading or error!="" or not race.track.validation_errors.is_empty() or (race.race_mode=="tournament" and race.stats_test_mode!=0)
	preload("res://scripts/race/arcade_presentation.gd").refresh(race)


