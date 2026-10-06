extends "res://tests/autopilot/probe_base.gd"
var failures: Array[String] = []
func check(label: String, value: bool) -> void:
	report(label,value)
	if not value: failures.append(label)
func tap_a() -> void:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.device = 0
	event.button_index = JOY_BUTTON_A
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await settle(2)
func _ready() -> void:
	await super._ready()
	await settle()
	var race: Node = get_tree().current_scene.get_node("Race")
	race.garage.cards[2].grab_focus()
	await tap_a()
	check("a_selects_focused_driver",race.garage.selected==2 and race.phase==0)
	var difficulty: OptionButton = race.menu.get_node("Difficulty")
	difficulty.grab_focus()
	await tap_a()
	check("a_opens_difficulty",difficulty.get_popup().visible)
	if difficulty.get_popup().visible:
		difficulty.get_popup().set_focused_item(2)
		await tap_a()
	check("a_confirms_difficulty",race.difficulty==2 and not difficulty.get_popup().visible)
	difficulty.get_popup().hide()
	var track: OptionButton = race.menu.get_node("TrackSelect")
	track.grab_focus()
	await tap_a()
	check("a_opens_track",track.get_popup().visible)
	track.get_popup().hide()
	race.menu.get_node("Start").grab_focus()
	await tap_a()
	check("a_activates_start",race.phase==1)
	report("failures",failures)
	report("passed",failures.is_empty())
	finish()
