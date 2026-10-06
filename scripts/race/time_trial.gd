extends RefCounted
# Content-addressed visual replay; no physics bodies, progress or input ownership.
const STORE: Script = preload("res://scripts/profile_store.gd")
const SAMPLE_INTERVAL: float = 0.1
const MAX_SAMPLES: int = 36002
const MAX_BYTES: int = 8388608
# This exact presentation-only car revision retains the pre-polish handling hash.
# Paired seeded races and enabled/disabled physical traces prove equivalence.
# Any subsequent car edit falls back to its own hash and invalidates comparisons.
const COSMETIC_CAR_HASH: String = "92336554348a3835fdd5e64e1c3405f9de1d95e406f5ca388f906003c89d1edc"
const COMPATIBLE_CAR_HASH: String = "384fe01fd7404da07d6d410aa7b2627bf8e5463ea812b964c1ffe410cf777ebf"
# Selection validates once and direction queries cache exact values for one tick.
# Sample/query parity and seeded full races preserve the original physics.
const VALIDATED_TRACK_HASH: String = "ffdfb7e971e8fc04f32ea1a70b2d289988c3dc335a42746f84e060c43f96b104"
const COMPATIBLE_TRACK_HASH: String = "02ae94bcfc0d557cee1de8b1246763680b3ce13ec8f5c23c84281849bc79fb51"
# Exact projection-cache revision: 74,508 query comparisons and the seeded
# Bazaar race preserve the immediately preceding route implementation.
const CACHED_PROJECTION_HASH: String = "6bc9ffcf97b5b0df39c6ea00bd72105825530328c2e9e6313494d4aa2d520375"
const UNCACHED_PROJECTION_HASH: String = "d5baafd5741dfc7b3ff6626e7d214f6609054f76f88d091a33c07c57e08d51bf"
# Exact window/bounds/cache parity retains the previous route record identity.
const TUNED_TRACK_HASH: String = "98e7d6a9f72a64ec933bbf3218636d19f15997d4f67dbf87166b58aa66f4bb10"
var race: Node3D
var ghost: Node3D
var recording: Array = []
var playback: Array = []
var cursor: int = 0
var next_sample: float = 0.0
var signature: String = ""
var key: String = ""
var last_lap: float = 0.0
var best_lap: float = INF
var previous_penalty: float = 0.0
var result_note: String = ""
var ghost_notice: String = ""
var completed: bool = false
var exhausted: bool = false

func configure(owner: Node3D) -> void:
	race = owner
	refresh_signature()
	ghost = Node3D.new()
	ghost.name = "BestRunGhost"
	race.add_child(ghost)
	rebuild_ghost()

func rebuild_ghost() -> void:
	for child: Node in ghost.get_children(): child.free()
	copy_meshes(race.player_car.visual,ghost)
	var label: Label3D = Label3D.new()
	label.text = "GHOST · PB"
	label.position.y = 0.9
	label.font_size = 28
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	ghost.add_child(label)
	ghost.visible = false

func refresh_signature() -> void:
	# Hash actual course, handling and rules so stale times cannot compete.
	var text: String = "records-v1|"+preload("res://scripts/vehicles/vehicle_definition.gd").HANDLING_VERSION+"|"+race.track.definition.id
	for path: String in [race.track.definition.resource_path,race.player_car.base_tuning.resource_path,"res://scripts/tracks/track_builder.gd","res://scripts/tracks/track_definition.gd","res://scripts/tracks/route_section.gd","res://scripts/tracks/surface_definition.gd","res://showcase_track.gd","res://scripts/race/race_progress.gd","res://scripts/race/race_session.gd","res://scripts/race/race_recovery.gd","res://scripts/vehicles/arcade_car.gd","res://scripts/vehicles/player_input.gd","res://scripts/vehicles/vehicle_definition.gd","res://scenes/vehicles/buggy_definition.tres"]:
		var digest: String = FileAccess.get_sha256(path)
		if path=="res://scripts/vehicles/arcade_car.gd" and digest==COSMETIC_CAR_HASH: digest = COMPATIBLE_CAR_HASH
		if path=="res://showcase_track.gd" and digest==TUNED_TRACK_HASH: digest = CACHED_PROJECTION_HASH
		if path=="res://showcase_track.gd" and digest==VALIDATED_TRACK_HASH: digest = COMPATIBLE_TRACK_HASH
		if path=="res://showcase_track.gd" and digest==CACHED_PROJECTION_HASH: digest = UNCACHED_PROJECTION_HASH
		text += digest
	# Imported collision is embedded in the authored environment, independently
	# of route coordinates. A changed wall/support shape invalidates old times.
	if race.course!=null and race.course.entry!=null:
		text += FileAccess.get_sha256(race.course.entry.environment.resource_path)
	text += FileAccess.get_sha256("res://scripts/vehicles/player_stats.gd")
	if race.race_mode=="time_attack": text += FileAccess.get_sha256("res://scripts/race/time_attack_rules.gd")+FileAccess.get_sha256("res://tracks/"+race.track_id+"/entry.tres")
	if race.race_mode=="elimination": text += FileAccess.get_sha256("res://scripts/race/elimination_rules.gd")
	text += preload("res://scripts/vehicles/player_stats.gd").VERSION+stats_code()
	signature = text.sha256_text()

func copy_meshes(source: Node3D, parent: Node3D) -> void:
	for child: Node in source.get_children():
		if not child is Node3D: continue
		var copy: Node3D
		if child is MeshInstance3D:
			var mesh: MeshInstance3D = MeshInstance3D.new()
			mesh.mesh = child.mesh
			var material: StandardMaterial3D = StandardMaterial3D.new()
			material.albedo_color = Color(0.75,0.95,1.0,0.35)
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mesh.material_override = material
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			copy = mesh
		else:
			copy = Node3D.new()
		copy.transform = child.transform
		copy.name = child.name
		# PB playback belongs to standard Time Trial, so off-environment Freestyle
		# aids are never part of its visual, including a newly selected boat.
		copy.visible = child.visible and child.name not in [&"WaterAssist",&"LandAssist"]
		parent.add_child(copy)
		copy_meshes(child,copy)

func reset() -> void:
	recording.clear()
	playback.clear()
	cursor = 0
	next_sample = 0.0
	last_lap = 0.0
	best_lap = INF
	previous_penalty = 0.0
	result_note = ""
	ghost_notice = ""
	completed = false
	exhausted = false
	if is_instance_valid(ghost): ghost.visible = false

func begin() -> void:
	reset()
	refresh_signature()
	key = STORE.record_key(race.race_mode,race.session.laps_required,race.cars.size()-1,race.difficulty,race.track_id,stats_code(),race.player_car.base_tuning.id)
	var record: Dictionary = race.profile.data.records.get(key,{})
	if not record.is_empty() and record.signature!=signature:
		ghost_notice = "Course or handling changed · previous record retired"
	elif race.race_mode=="trial" and not record.is_empty() and record.replay!="":
		playback = load_replay(record.replay,record.total)
		if playback.is_empty(): ghost_notice = "Ghost unavailable · your time is still saved"
	sample(0.0)

func sample(clock: float) -> void:
	if recording.size()>=MAX_SAMPLES:
		exhausted = true
		return
	var car: CharacterBody3D = race.player_car
	recording.append([clock,car.position.x,car.position.y,car.position.z,car.rotation.y])

func observe() -> void:
	if completed or race.paused_race or race.phase not in [2,5]: return
	if race.race_time>=next_sample:
		sample(race.race_time)
		next_sample = race.race_time+SAMPLE_INTERVAL
	tick_playback(race.race_time)

func lap(clock: float) -> void:
	var penalty: float = race.session.progress.records[1].penalty
	best_lap = minf(best_lap,clock-last_lap+penalty-previous_penalty)
	last_lap = clock
	previous_penalty = penalty

func finish_run() -> void:
	if race.experimental():
		result_note = "EXPERIMENTAL / RECORDS DISABLED"
		return
	if completed: return
	completed = true
	ghost.visible = false
	if race.race_mode in ["cup","tournament","challenge","drift"]: return
	var total: float = race.player_car.finish_time
	if not STORE.valid_time(total) or not STORE.valid_time(best_lap): return
	var old: Dictionary = race.profile.data.records.get(key,{})
	var compatible: bool = not old.is_empty() and old.signature==signature
	if not old.is_empty() and not compatible: race.profile.preserve_legacy(key,old)
	var personal_best: bool = not compatible or total<float(old.total)
	if not personal_best and best_lap>=float(old.best_lap):
		result_note = "PERSONAL BEST %.2fs · BEST LAP %.2fs" % [old.total,old.best_lap]
		return
	var record: Dictionary = {"signature":signature,"total":total if personal_best else old.total,"best_lap":minf(best_lap,float(old.best_lap)) if compatible else best_lap,"replay":"" if personal_best else old.replay}
	# Penalty time has no matching driving samples; preserve its time without a ghost.
	if personal_best and race.race_mode=="trial" and race.session.progress.records[1].penalty==0.0 and not exhausted:
		if not recording.is_empty() and float(recording.back()[0])>=last_lap: recording.pop_back()
		sample(last_lap)
		record.replay = save_replay(total)
	race.profile.data.records[key] = record
	race.save_preferences()
	if not profile_save_failed(): prune_replays()
	result_note = ("NEW PERSONAL BEST %.2fs" % total if personal_best else "PERSONAL BEST %.2fs" % old.total)+" · BEST LAP %.2fs" % record.best_lap
	if personal_best and race.race_mode=="trial" and record.replay=="" and race.session.progress.records[1].penalty==0.0:
		result_note += "\nGhost could not be saved" if not exhausted else "\nGhost recording limit reached"
	if profile_save_failed(): result_note += "\n"+race.profile.status

func profile_save_failed() -> bool:
	return race.profile.read_only or race.profile.status!=""

func replay_path(id: String) -> String:
	return race.profile.path+".ghost."+id+".json"

func save_replay(total: float) -> String:
	if race.experimental(): return ""
	if race.profile.read_only: return ""
	var payload: String = JSON.stringify({"version":1,"signature":signature,"key":key,"total":total,"samples":recording},"",true,true)
	var id: String = payload.sha256_text()
	var path: String = replay_path(id)
	var file: FileAccess = FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null: return ""
	file.store_string(payload)
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error!=OK or FileAccess.get_sha256(path+".tmp")!=id: return ""
	if DirAccess.rename_absolute(path+".tmp",path)!=OK: return ""
	return id

func load_replay(id: String, total: float) -> Array:
	if not STORE.valid_hash(id): return []
	var path: String = replay_path(id)
	var file: FileAccess = FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>MAX_BYTES: return []
	var payload: String = file.get_as_text()
	if payload.sha256_text()!=id: return []
	var parser: JSON = JSON.new()
	if parser.parse(payload)!=OK or not parser.data is Dictionary: return []
	var raw: Dictionary = parser.data
	if raw.get("version")!=1 or raw.get("signature")!=signature or raw.get("key")!=key or not STORE.valid_time(raw.get("total")) or absf(float(raw.total)-total)>0.000001: return []
	var samples: Variant = raw.get("samples")
	if not samples is Array or samples.size()<2 or samples.size()>MAX_SAMPLES: return []
	var previous: float = -1.0
	for entry: Variant in samples:
		if not entry is Array or entry.size()!=5: return []
		for value: Variant in entry:
			if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or absf(float(value))>10000.0: return []
		if float(entry[0])<=previous or float(entry[0])>total+0.001: return []
		previous = float(entry[0])
	if float(samples[0][0])!=0.0 or absf(previous-total)>0.001: return []
	return samples

func tick_playback(clock: float) -> void:
	if playback.is_empty() or clock>float(playback.back()[0]):
		ghost.visible = false
		return
	while cursor<playback.size()-2 and float(playback[cursor+1][0])<clock: cursor += 1
	var a: Array = playback[cursor]
	var b: Array = playback[cursor+1]
	var ratio: float = clampf((clock-float(a[0]))/(float(b[0])-float(a[0])),0.0,1.0)
	ghost.position = Vector3(a[1],a[2],a[3]).lerp(Vector3(b[1],b[2],b[3]),ratio)
	ghost.rotation.y = lerp_angle(float(a[4]),float(b[4]),ratio)
	ghost.visible = true

func summary() -> String:
	var selected_key: String = STORE.record_key(race.race_mode,race.race_laps,0 if race.track_id=="practice_patch" else race.rival_count,race.difficulty,race.track_id,stats_code(),race.player_car.base_tuning.id)
	var record: Dictionary = race.profile.data.records.get(selected_key,{})
	if record.is_empty(): return "No local record · finish a race to set one"
	if record.signature!=signature: return "Course or handling changed · set a new record"
	return "PB %.2fs · LAP %.2fs%s" % [record.total,record.best_lap," · GHOST" if race.race_mode=="trial" and record.replay!="" else ""]

func prune_replays() -> void:
	if race.profile.read_only: return
	# Retain immutable replays referenced by primary or backup, for corruption recovery.
	var keep: Array[String] = []
	for data: Dictionary in [race.profile.data,STORE.validate(race.profile.read_raw(race.profile.path+".bak"))]:
		for record: Dictionary in data.get("records",{}).values():
			if record.replay!="": keep.append(record.replay)
		for records: Array in data.get("legacy_records",{}).values():
			for record: Dictionary in records:
				if record.replay!="": keep.append(record.replay)
	var directory: DirAccess = DirAccess.open(race.profile.path.get_base_dir())
	if directory==null: return
	var prefix: String = race.profile.path.get_file()+".ghost."
	for file: String in directory.get_files():
		if not file.begins_with(prefix) or not file.ends_with(".json"): continue
		var id: String = file.substr(prefix.length(),file.length()-prefix.length()-5)
		if STORE.valid_hash(id) and id not in keep: directory.remove(file)

func stats_code() -> String:
	return preload("res://scripts/vehicles/player_stats.gd").code(race.active_stats())
