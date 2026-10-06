@tool
extends EditorScript

# Run audit_assets.py first. This refreshes the in-place catalogue without moving source files.
func _run() -> void:
	var entries: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://docs/asset-catalogue/manager-entries.json"))
	assert(entries is Array, "Generate manager-entries.json first.")
	var workspace := ProjectSettings.globalize_path("res://").trim_suffix("/")
	DirAccess.make_dir_recursive_absolute(workspace.path_join(".assetmanager"))
	var marker := FileAccess.open(workspace.path_join(".assetmanager/marker"), FileAccess.WRITE)
	marker.store_var({"version": 1})
	marker.close()
	var database := AssetDatabase.new()
	database.workspace_path = workspace
	database.sync()
	var typed_entries: Array[Dictionary] = []
	for entry in entries:
		assert(FileAccess.file_exists(entry["path"]), entry["path"])
		typed_entries.append(entry)
	assert(database.rebuild(typed_entries), "Catalogue write failed.")
	var verify := AssetDatabase.new()
	verify.workspace_path = workspace
	assert(verify.sync() and verify.assets.size() == typed_entries.size())
	AssetManagerConfig.set_value("workspace", "path", workspace)
	print("Asset Manager catalogue verified: ", verify.assets.size(), " files.")
