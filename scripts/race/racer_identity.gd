extends Node
# Rank is transient race state; identity and livery are separate choices.
var race: Node3D
var labels: Dictionary = {}
var racers: Dictionary = {}
const CHARACTERS: Script = preload("res://scripts/profiles/character_catalog.gd")

func portrait_for_slot(slot: int) -> int:
	var selected: int = int(race.profile.data.identity.portrait_id)
	return CHARACTERS.portrait_for_slot(selected,slot)

func refresh_identity() -> void:
	for car: CharacterBody3D in race.all_cars:
		var portrait_id: int = portrait_for_slot(car.player-1)
		racers[car.player] = {"profile_id":race.active_profile_id if car.player==1 else "ai-%d" % portrait_id,"display_name":race.names[car.player-1],"portrait_id":portrait_id,"bio":CHARACTERS.BIOS[portrait_id],"colour":car.get_meta("vehicle_colour",CHARACTERS.COLOURS[portrait_id])}

func _ready() -> void:
	refresh_identity()
	for car: CharacterBody3D in race.all_cars:
		var label: Label3D = Label3D.new()
		label.name = "LivePosition"
		label.font = preload("res://assets/arcade/arcade_font.fnt")
		label.font_size = 36
		label.outline_size = 8
		label.outline_modulate = Color("102422")
		label.modulate = Color("f6d65b") if car==race.player_car else Color.WHITE
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = false
		label.position = Vector3(0,0.8,0)
		label.pixel_size = 0.005
		car.add_child(label)
		labels[car] = label
		car.visual.get_node("DriverNumber").hide()
		label.position.y = car.visual.get_node("DriverNumber").position.y+0.18

func _process(_delta: float) -> void:
	for car: CharacterBody3D in race.all_cars:
		var label: Label3D = labels[car]
		car.visual.get_node("DriverNumber").hide()
		label.visible = car in race.cars and car.visible and race.phase in [1,2,3,5] and race.cars.size()>1 and not race.menu.visible
		if label.visible:
			var rank: int = race.session.rank_of(car)
			label.text = str(rank) if rank>0 else "-"
