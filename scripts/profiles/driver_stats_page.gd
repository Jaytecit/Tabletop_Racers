extends Control
const SKIN: Script = preload("res://scripts/race/arcade_presentation.gd")
const STATS: Script = preload("res://scripts/vehicles/player_stats.gd")
const VEHICLES: Script = preload("res://scripts/vehicles/vehicle_catalog.gd")
const CHARACTERS: Script = preload("res://scripts/profiles/character_catalog.gd")
var race: Node3D
var portrait: TextureRect
var driver_name: Label
var bio: Label
var vehicle_title: Label
var budget: Label
var progress: Label
var rows: Dictionary = {}
var bars: Dictionary = {}

func setup(owner: Node3D) -> void:
	race = owner
	name = "DriverStatsPage"
	position = Vector2(52,246)
	size = Vector2(1048,370)
	var panel: Panel = Panel.new()
	panel.size = size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel",SKIN.box(Color("13286ae6"),SKIN.GOLD,1))
	add_child(panel)
	portrait = SKIN.image_rect(self,"SavedPortrait",SKIN.portrait(0),Vector2(70,18),Vector2(180,180))
	driver_name = SKIN.label(self,"SavedName","",Vector2(20,208),Vector2(310,32),24,SKIN.GOLD)
	driver_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bio = SKIN.label(self,"Biography","",Vector2(24,250),Vector2(300,106),14)
	bio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vehicle_title = SKIN.label(self,"VehicleTitle","",Vector2(362,20),Vector2(660,28),18,SKIN.GOLD)
	for i: int in range(STATS.FIELDS.size()):
		var field: String = STATS.FIELDS[i]
		rows[field] = SKIN.label(self,field,"",Vector2(362,64+i*36),Vector2(310,26),14)
		var bar: ProgressBar = ProgressBar.new()
		bar.position = Vector2(692,66+i*36)
		bar.size = Vector2(326,20)
		bar.max_value = 24
		bar.step = 1
		bar.show_percentage = false
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bar)
		bars[field] = bar
	budget = SKIN.label(self,"UpgradePoints","",Vector2(362,256),Vector2(660,44),16,SKIN.GOLD)
	progress = SKIN.label(self,"Progression","",Vector2(362,310),Vector2(660,44),14)
	refresh()

func refresh() -> void:
	var identity: Dictionary = race.profile.data.identity
	driver_name.text = identity.name.to_upper()
	portrait.texture = SKIN.portrait(int(identity.portrait_id))
	var character: int = CHARACTERS.id(int(identity.portrait_id))
	bio.text = CHARACTERS.NAMES[character].to_upper()+"\n"+CHARACTERS.BIOS[character]
	var build: Dictionary = race.profile.vehicle()
	vehicle_title.text = VEHICLES.title(race.player_car.base_tuning.id).to_upper()+" / SAVED SKILLS"
	for field: String in STATS.FIELDS:
		var level: int = roundi((float(build.stats[field])-STATS.MINIMUM)/STATS.STEP)
		rows[field].text = "%s  %d / 24" % [field.to_upper(),level]
		bars[field].value = level
	budget.text = "%d DRIVER UPGRADE POINTS / %d BLING\nSPEND ON ANY VEHICLE" % [race.profile.wallet().points,race.profile.wallet().bling]
	progress.text = "%d CUP WINS / %d TOURNAMENT WINS\n%d SAVED RECORDS" % [race.profile.data.cup_wins,race.profile.data.tournament_wins,race.profile.data.records.size()]
