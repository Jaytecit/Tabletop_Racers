extends RefCounted
# Compile the current selector with a process-local candidate catalogue. No
# production catalogue file is edited, and the candidate is not preloaded.
var catalogue: GDScript
var selector: GDScript
var receipt: Dictionary = {}
var production_registered: bool = false

func prepare() -> Error:
	var catalog_path: String = "res://scripts/tracks/content_catalog.gd"
	var selector_path: String = "res://scripts/tracks/selected_course.gd"
	production_registered = "town_square" in preload("res://scripts/tracks/content_catalog.gd").IDS
	receipt = {"catalogue_source_sha256":FileAccess.get_sha256(catalog_path),"selector_source_sha256":FileAccess.get_sha256(selector_path),"candidate":"town_square","production_registered":production_registered}
	# Once registered, the probes exercise the unmodified production selector.
	if production_registered: return OK
	var source: String = FileAccess.get_file_as_string(catalog_path)
	if not source.contains('["game_table"') or not source.contains('["Roulette Grand Prix"'): return ERR_INVALID_DATA
	source = source.replace('["game_table"','["town_square","game_table"')
	source = source.replace('["Roulette Grand Prix"','["Town Square","Roulette Grand Prix"')
	source = source.replace('const CLASSIFICATION: Dictionary = {','const CLASSIFICATION: Dictionary = {\n\t"town_square":{"group":"ROAD","vehicle":"racing_car","surface":"Cobblestone road"},')
	source = source.replace('\tfor required: String in [','\tif id=="town_square": theme = "tabletop"\n\tfor required: String in [')
	source = source.replace('return CAPABILITIES.validate(canonical_id(id),mode,vehicle)','return "" if id=="town_square" and mode in ["quick","trial","freestyle"] else CAPABILITIES.validate(canonical_id(id),mode,vehicle)')
	catalogue = GDScript.new()
	catalogue.source_code = source
	var error: Error = catalogue.reload()
	if error != OK: return error
	var selection_source: String = FileAccess.get_file_as_string(selector_path)
	var binding: String = 'const CATALOG: Script = preload("res://scripts/tracks/content_catalog.gd")'
	if selection_source.count(binding) != 1: return ERR_INVALID_DATA
	selector = GDScript.new()
	selector.source_code = selection_source.replace(binding,'var CATALOG: Script')
	error = selector.reload()
	receipt = {"catalogue_source_sha256":FileAccess.get_sha256(catalog_path),"selector_source_sha256":FileAccess.get_sha256(selector_path),"candidate":"town_square","production_registered":false}
	return error

func attach(node: Node) -> void:
	if node.name != "Race" or node.get("course") == null: return
	node.profile_selected = true # Disposable read-only fixture only.
	if production_registered: return
	var selection: RefCounted = selector.new()
	selection.CATALOG = catalogue
	node.course = selection
