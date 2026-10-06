extends Node
# Session ownership and transitions; both scenes remain directly playable.
var race: Node3D
func _ready() -> void:
	race = get_node("Race")
	play_opening()

func play_opening() -> void:
	if "--skip-opening" in OS.get_cmdline_user_args():
		race.music.play()
		race.open_profiles.call_deferred()
		return
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "Opening"
	layer.layer = 100
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var sequence: Control = preload("res://scripts/race/opening_sequence.gd").new()
	sequence.name = "Sequence"
	sequence.race = race
	sequence.finished.connect(race.open_profiles)
	layer.add_child(sequence)

func open_2d() -> void:
	var error: Error = get_tree().change_scene_to_file("res://main.tscn")
	if error!=OK: race.fail_safe("Cannot open original game: "+str(error))
