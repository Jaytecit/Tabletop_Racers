extends RefCounted
const SKIN: Script = preload("res://scripts/race/arcade_presentation.gd")

static func show_results(race: Node3D, rows: Array) -> void:
	var panel: Control = race.results_panel
	var previous: Node = panel.get_node_or_null("Podium")
	if previous!=null:
		panel.remove_child(previous)
		previous.queue_free()
	var podium: Control = Control.new()
	podium.name = "Podium"
	podium.position = Vector2(28,76)
	podium.size = Vector2(704,258)
	panel.add_child(podium)
	var expanded: bool = rows.size()>4
	for index: int in range(rows.size()):
		var row: Dictionary = rows[index]
		var height: float = 72.0 if expanded else 144.0-float(index)*18.0
		var x: float = float(index%4)*176.0
		var y: float = float(index/4)*129.0+56.0 if expanded else 258-height
		var face_size: float = 52.0 if expanded else 104.0
		var face: TextureRect = SKIN.image_rect(podium,"Driver%d" % index,SKIN.portrait(race.identities.portrait_for_slot(int(row.player)-1)),Vector2(x+(166-face_size)*0.5,y-face_size-4),Vector2(face_size,face_size))
		face.tooltip_text = race.names[row.player-1]
		var block: Panel = Panel.new()
		block.name = "Place%d" % row.rank
		block.position = Vector2(x,y)
		block.size = Vector2(166,height)
		block.add_theme_stylebox_override("panel",SKIN.box(SKIN.PURPLE,SKIN.GOLD if row.player==1 else SKIN.BLUE,4 if row.player==1 else 2))
		podium.add_child(block)
		var title: Label = SKIN.label(block,"Driver",race.names[row.player-1],Vector2(4,8),Vector2(158,18),12)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var place: Label = SKIN.label(block,"Rank",str(row.rank),Vector2(4,26 if expanded else 28),Vector2(158,26 if expanded else 38),22 if expanded else 32,SKIN.GOLD)
		place.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var time_text: String = "%.2fs" % row.time if row.finished else "DNF %dL" % row.laps
		if row.get("status","") in ["OUT","RACING"]: time_text = row.status
		if race.race_mode=="drift": time_text = "%d PTS" % floori(race.drift.rules.score)
		if row.penalty>0: time_text += " +%.0fs" % row.penalty
		var time: Label = SKIN.label(block,"Time",time_text,Vector2(4,height-22),Vector2(158,18),12)
		time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		face.modulate.a = 0.0
		block.modulate.a = 0.0
		var reveal: Tween = podium.create_tween()
		reveal.tween_interval(float(index)*0.08)
		reveal.tween_property(face,"modulate:a",1.0,0.18)
		reveal.parallel().tween_property(block,"modulate:a",1.0,0.18)
