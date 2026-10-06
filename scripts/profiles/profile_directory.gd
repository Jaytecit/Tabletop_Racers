extends RefCounted
# Names are display data. Only opaque IDs may resolve to payload paths.
const STORE: Script = preload("res://scripts/profile_store.gd")
const VERSION: int = 1
var root: String = "user://profiles"
var legacy_path: String = "user://profile.json"
var read_only: bool = false
var status: String = ""
var index: Dictionary = {"schema_version":VERSION,"last_selected":"","entries":[]}

static func valid_name(value: Variant) -> bool:
	if not value is String or value.length()<1 or value.length()>9: return false
	for letter: String in value:
		if letter not in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz": return false
	return true

static func valid_id(value: Variant) -> bool:
	if not value is String or value.length()!=32: return false
	for letter: String in value:
		if letter not in "0123456789abcdef": return false
	return true

static func validate(raw: Variant) -> Dictionary:
	if not raw is Dictionary or raw.get("schema_version")!=VERSION or not raw.get("entries") is Array: return {}
	var ids: Array = []
	var names: Array = []
	for entry: Variant in raw.entries:
		if not entry is Dictionary or not valid_id(entry.get("id")) or not valid_name(entry.get("name")): return {}
		var portrait: Variant = entry.get("portrait_id")
		if typeof(portrait) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(portrait)) or float(portrait)!=int(portrait) or int(portrait)<0 or int(portrait)>7: return {}
		if entry.id in ids or entry.name.to_lower() in names: return {}
		ids.append(entry.id)
		names.append(entry.name.to_lower())
	if raw.get("last_selected","")!="" and raw.last_selected not in ids: return {}
	return raw.duplicate(true)

func list_profiles() -> Array:
	return index.entries.duplicate(true)

func entry_for(id: String) -> Dictionary:
	for entry: Dictionary in index.entries:
		if entry.id==id: return entry.duplicate(true)
	return {}

func payload_path(id: String) -> String:
	return root+"/"+id+".json" if valid_id(id) else ""

func load_directory() -> Error:
	status = ""
	var reader: RefCounted = STORE.new()
	var raw: Variant = reader.read_raw(root+"/index.json")
	if raw is Dictionary and typeof(raw.get("schema_version")) in [TYPE_INT,TYPE_FLOAT] and float(raw.schema_version)>VERSION:
		read_only = true
		status = "Unsupported profile directory version; saving disabled."
		return ERR_UNAVAILABLE
	var loaded: Dictionary = validate(raw)
	if loaded.is_empty(): loaded = validate(reader.read_raw(root+"/index.json.bak"))
	if loaded.is_empty() and (FileAccess.file_exists(root+"/index.json") or FileAccess.file_exists(root+"/index.json.bak")):
		read_only = true
		status = "Profile list is unreadable. Existing saves have been preserved."
		return ERR_FILE_CORRUPT
	if not loaded.is_empty():
		index = loaded
		return OK
	return migrate_legacy()

func publish(next: Dictionary) -> Error:
	if read_only: return ERR_UNAVAILABLE
	var error: Error = DirAccess.make_dir_recursive_absolute(root)
	if error!=OK: return error
	var target: String = root+"/index.json"
	var file: FileAccess = FileAccess.open(target+".tmp",FileAccess.WRITE)
	if file==null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(next,"\t"))
	file.flush()
	error = file.get_error()
	file.close()
	if error!=OK: return error
	var reader: RefCounted = STORE.new()
	if validate(reader.read_raw(target+".tmp")).is_empty(): return ERR_FILE_CORRUPT
	if not validate(reader.read_raw(target)).is_empty():
		error = DirAccess.copy_absolute(target,target+".bak.tmp")
		if error!=OK: return error
		error = DirAccess.rename_absolute(target+".bak.tmp",target+".bak")
		if error!=OK: return error
	error = DirAccess.rename_absolute(target+".tmp",target)
	if error==OK: index = next
	return error

func migrate_legacy() -> Error:
	if read_only or (not FileAccess.file_exists(legacy_path) and not FileAccess.file_exists(legacy_path+".bak")): return OK
	var legacy: RefCounted = STORE.new()
	legacy.path = legacy_path
	legacy.load_profile()
	if legacy.read_only or legacy.status.begins_with("Unreadable"):
		read_only = true
		status = legacy.status+"; original save preserved."
		return ERR_FILE_CORRUPT
	# Stable ID makes a crash between payload staging and index publication resumable.
	var id: String = legacy_path.sha256_text().substr(0,32)
	var target: RefCounted = STORE.new()
	target.path = payload_path(id)
	var error: Error = DirAccess.make_dir_recursive_absolute(root)
	if error!=OK: return error
	if FileAccess.file_exists(target.path):
		target.load_profile()
		if target.read_only or target.status.begins_with("Unreadable"): return ERR_FILE_CORRUPT
	else:
		target.data = legacy.data.duplicate(true)
		target.data.identity = {"name":"Player","portrait_id":legacy.data.quick_race.driver}
		error = target.save_profile()
		if error!=OK: return error
	var entry: Dictionary = {"id":id,"name":target.data.identity.name,"portrait_id":target.data.identity.portrait_id,"needs_identity":true}
	return publish({"schema_version":VERSION,"last_selected":id,"entries":[entry]})

func create_profile(name: String, portrait_id: int) -> Dictionary:
	name = name.strip_edges()
	if read_only: return {"error":ERR_UNAVAILABLE}
	if not valid_name(name) or portrait_id not in [0,1,2,3,4,5,6,7]: return {"error":ERR_INVALID_PARAMETER}
	for entry: Dictionary in index.entries:
		if entry.name.to_lower()==name.to_lower(): return {"error":ERR_ALREADY_EXISTS}
	var id: String = Crypto.new().generate_random_bytes(16).hex_encode()
	if FileAccess.file_exists(payload_path(id)): return {"error":ERR_ALREADY_EXISTS}
	var error: Error = DirAccess.make_dir_recursive_absolute(root)
	if error!=OK: return {"error":error}
	var store: RefCounted = STORE.new()
	store.path = payload_path(id)
	store.data.identity = {"name":name,"portrait_id":portrait_id}
	store.data.quick_race.driver = portrait_id%4
	STORE.reset_rewards(store.data)
	error = store.save_profile()
	if error!=OK: return {"error":error}
	var next: Dictionary = index.duplicate(true)
	var entry: Dictionary = {"id":id,"name":name,"portrait_id":portrait_id}
	next.entries.append(entry)
	next.last_selected = id
	error = publish(next)
	return {"error":error,"id":id}

func select_profile(id: String, store: RefCounted) -> Error:
	if read_only: return ERR_UNAVAILABLE
	var entry: Dictionary = entry_for(id)
	if entry.is_empty(): return ERR_DOES_NOT_EXIST
	var candidate: RefCounted = STORE.new()
	candidate.path = payload_path(id)
	candidate.load_profile()
	if candidate.read_only or candidate.status.begins_with("Unreadable") or (not FileAccess.file_exists(candidate.path) and not FileAccess.file_exists(candidate.path+".bak")): return ERR_FILE_CORRUPT
	var next: Dictionary = index.duplicate(true)
	next.last_selected = id
	var error: Error = publish(next)
	if error!=OK: return error
	store.path = candidate.path
	store.data = candidate.data
	store.read_only = false
	store.status = candidate.status
	return OK

func rename_legacy(id: String, name: String, portrait_id: int) -> Error:
	if read_only: return ERR_UNAVAILABLE
	name = name.strip_edges()
	var entry: Dictionary = entry_for(id)
	if not entry.get("needs_identity",false) or not valid_name(name) or portrait_id not in [0,1,2,3,4,5,6,7]: return ERR_INVALID_PARAMETER
	for other: Dictionary in index.entries:
		if other.id!=id and other.name.to_lower()==name.to_lower(): return ERR_ALREADY_EXISTS
	var store: RefCounted = STORE.new()
	store.path = payload_path(id)
	store.load_profile()
	if store.read_only or store.status.begins_with("Unreadable"): return ERR_FILE_CORRUPT
	store.data.identity = {"name":name,"portrait_id":portrait_id}
	store.data.quick_race.driver = portrait_id%4
	var error: Error = store.save_profile()
	if error!=OK: return error
	var next: Dictionary = index.duplicate(true)
	for item: Dictionary in next.entries:
		if item.id==id:
			item.name = name
			item.portrait_id = portrait_id
			item.erase("needs_identity")
	return publish(next)
