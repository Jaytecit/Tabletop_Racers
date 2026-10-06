extends Node
# Local release benchmark entry point; never starts without an explicit output.
func _ready() -> void:
	boot.call_deferred()

func boot() -> void:
	var output: String = OS.get_environment("TABLETOP_VERIFY_OUTPUT")
	if output.is_empty() or not output.is_absolute_path():
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var receipt: FileAccess = FileAccess.open(output.path_join("bootstrap.json"),FileAccess.WRITE)
	receipt.store_string(JSON.stringify({"pid":OS.get_process_id(),"release":OS.has_feature("release"),"editor":OS.has_feature("editor"),"benchmark":OS.has_feature("loading_benchmark")}))
	receipt.close()
	get_tree().create_timer(150.0).timeout.connect(func() -> void: get_tree().quit(3))
	RenderingServer.viewport_set_update_mode(get_tree().root.get_viewport_rid(),RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	var probe_path: String = "res://tests/probes/loading_responsiveness_verification.gd" if OS.get_environment("TABLETOP_VERIFY_RESPONSIVENESS")=="1" else "res://tests/probes/course_loading_verification.gd"
	var probe: Node = load(probe_path).new()
	probe.summer_out_dir = output
	probe.summer_max_seconds = 120
	get_tree().root.add_child(probe)
	var app: Node = load("res://scenes/app.tscn").instantiate()
	get_tree().root.add_child(app)
	get_tree().current_scene = app
