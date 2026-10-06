extends RefCounted
# Owns series setup and persistence; the shared session remains the race authority.
const RULES: Script = preload("res://scripts/race/tournament_rules.gd")
const SKIN: Script = preload("res://scripts/race/arcade_presentation.gd")
var race: Node3D
var selector: OptionButton
var abandon: Button
var round_index: int = -1
var run_signature: String = ""
var scored: bool = true

func configure(owner: Node3D) -> void:
	race = owner

func state() -> Dictionary:
	return race.profile.data.tournament

func selected_id() -> String:
	return state().series if not state().is_empty() else race.profile.data.tournament_series

func next_course() -> String:
	return RULES.series(selected_id()).courses[0] if state().is_empty() or RULES.complete(state()) else RULES.course_id(state())

func setup_ui() -> void:
	selector = OptionButton.new()
	selector.name = "TournamentSeries"
	selector.position = Vector2(50,484)
	selector.size = Vector2(530,40)
	selector.add_theme_font_size_override("font_size",18)
	for series: Dictionary in RULES.SERIES: selector.add_item(series.title)
	selector.item_selected.connect(func(index: int) -> void:
		if RULES.complete(state()): race.profile.data.tournament = {}
		race.profile.data.tournament_series = RULES.SERIES[index].id
		race.save_preferences()
		prepare_course())
	race.menu.add_child(selector)
	abandon = Button.new()
	abandon.name = "AbandonTournament"
	abandon.text = "ABANDON SERIES"
	abandon.position = Vector2(236,648)
	abandon.size = Vector2(300,48)
	abandon.add_theme_font_size_override("font_size",16)
	abandon.pressed.connect(func() -> void:
		race.profile.data.tournament = {}
		race.save_preferences()
		prepare_course())
	race.menu.add_child(abandon)
	refresh()

func enter() -> void:
	if not state().is_empty() and not RULES.complete(state()): race.garage.select(race,int(state().driver))
	prepare_course()

func prepare_course() -> void:
	var id: String = next_course()
	if race.track_id!=id or race.course.loading: race.course.request_select(id)
	refresh()

func refresh() -> void:
	if selector==null or race.menu_flow==null: return
	var active: bool = race.race_mode=="tournament"
	var course_page: bool = active and race.menu_flow.step==3
	selector.visible = course_page
	abandon.visible = course_page and not state().is_empty() and not RULES.complete(state())
	selector.disabled = not state().is_empty() and not RULES.complete(state())
	for index: int in range(RULES.SERIES.size()):
		if RULES.SERIES[index].id==selected_id(): selector.select(index)
	for card: Button in race.garage.cards:
		card.disabled = active and not state().is_empty() and not RULES.complete(state())
	if course_page:
		race.menu.get_node("QuickRace").hide()
		race.menu.get_node("Record").text = summary()
		if race.experimental():
			race.menu.get_node("Start").disabled = true
			race.menu.get_node("Record").text = "SELECT EARNED STATS TO ENTER A TOURNAMENT"

func summary() -> String:
	var definition: Dictionary = RULES.series(selected_id())
	var completed: int = state().get("rounds",[]).size()
	return "%d / %d ROUNDS · 3 LAPS · ASSIGNED CLASS\nNORMAL AI (PROVISIONAL) · POINTS 10 / 6 / 4 / 2" % [completed,definition.courses.size()]

func begin() -> bool:
	if race.experimental(): return false
	if race.track_id!=next_course():
		race.show_menu()
		race.menu_flow.show_step(3)
		prepare_course()
		return false
	if state().is_empty() or RULES.complete(state()):
		race.profile.data.tournament = RULES.fresh(selected_id(),race.garage.selected)
	race.garage.select(race,int(state().driver))
	round_index = state().rounds.size()
	race.trial.refresh_signature()
	run_signature = race.trial.signature
	scored = false
	return true

func score(rows: Array) -> String:
	if not scored and not race.experimental():
		scored = true
		if RULES.append_round(state(),round_index,race.track_id,race.player_car.base_tuning.id,run_signature,rows):
			if RULES.complete(state()) and not state().awarded:
				state().awarded = true
				if RULES.standings(state())[0].player==1 and player_finished_all():
					race.profile.data.tournament_wins = mini(race.profile.data.tournament_wins+1,999999)
					race.profile.data.cup_wins = mini(race.profile.data.cup_wins+1,999999)
			race.save_preferences()
	var totals: Array = RULES.standings(state())
	var text: String = RULES.series(selected_id()).title+" · ROUND %d / %d\n" % [state().rounds.size(),RULES.series(selected_id()).courses.size()]
	for row: Dictionary in totals: text += "%s %d  " % ["YOU" if row.player==1 else race.names[row.player-1].split(" ")[0],row.points]
	if RULES.complete(state()):
		text += "\nSERIES WINNER · "+race.names[totals[0].player-1]
		if totals[0].player==1 and player_finished_all(): text += " · GOLD UNLOCKED"
	else: text += "\nNEXT · "+preload("res://scripts/tracks/content_catalog.gd").TITLES[preload("res://scripts/tracks/content_catalog.gd").IDS.find(next_course())]
	return text

func player_finished_all() -> bool:
	for round_data: Dictionary in state().rounds:
		for row: Dictionary in round_data.rows:
			if row.player==1 and not row.finished: return false
	return true

func results_action() -> void:
	race.show_menu()
	if RULES.complete(state()): race.profile.data.tournament = {}
	race.menu_flow.show_step(3)
	race.save_preferences()
	prepare_course()
