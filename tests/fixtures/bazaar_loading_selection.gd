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
	production_registered = "bazaar" in preload("res://scripts/tracks/content_catalog.gd").IDS
	receipt = {"catalogue_source_sha256":FileAccess.get_sha256(catalog_path),"selector_source_sha256":FileAccess.get_sha256(selector_path),"candidate":"bazaar","production_registered":production_registered}
	# Once registered, the probes exercise the unmodified production selector.
	if production_registered: return OK
	var source: String = FileAccess.get_file_as_string(catalog_path)
	if not source.contains('["game_table"') or not source.contains('["Roulette Grand Prix"'): return ERR_INVALID_DATA
	source = source.replace('["game_table"','["bazaar","game_table"')
	source = source.replace('["Roulette Grand Prix"','["Bazaar","Roulette Grand Prix"')
	source = source.replace('const CLASSIFICATION: Dictionary = {','const CLASSIFICATION: Dictionary = {\n\t"bazaar":{"group":"ROAD","vehicle":"racing_car","surface":"Market road"},')
	source = source.replace('\tfor required: String in [','\tif id=="bazaar": theme = "tabletop"\n\tfor required: String in [')
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
	receipt = {"catalogue_source_sha256":FileAccess.get_sha256(catalog_path),"selector_source_sha256":FileAccess.get_sha256(selector_path),"candidate":"bazaar","production_registered":false}
	return error

func attach(node: Node) -> void:
	if production_registered: return
	if node.name != "Race" or node.get("course") == null: return
	var selection: RefCounted = selector.new()
	selection.CATALOG = catalogue
	node.course = selection
