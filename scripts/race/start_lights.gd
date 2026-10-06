extends Control
const SKIN: Script = preload("res://scripts/race/arcade_presentation.gd")
var stage: int = -1
var pulse: float = 0.0

func _ready() -> void:
	position = Vector2(470,20)
	size = Vector2(260,76)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()

func update(race: Node3D) -> void:
	visible = not race.paused_race and (race.phase==1 or (race.phase==2 and race.race_time<0.8))
	var next: int = 4 if race.phase==2 else clampi(4-int(ceil(maxf(race.countdown-0.8,0.0))),1,3)
	if next!=stage:
		stage = next
		pulse = 1.0
		queue_redraw()
	if not race.paused_race and pulse>0.0:
		pulse = maxf(0.0,pulse-race.get_physics_process_delta_time()*5.0)
		queue_redraw()

func _draw() -> void:
	draw_style_box(SKIN.box(SKIN.INK,SKIN.BLUE,3),Rect2(Vector2.ZERO,size))
	for index: int in range(3):
		var centre: Vector2 = Vector2(56+index*74,38)
		var color: Color = Color("31e58c") if stage==4 else (Color("ff4646") if index<stage else Color("30223d"))
		var active: bool = stage==4 or index==stage-1
		draw_circle(centre,23+(2.0*pulse if active else 0.0),color)
		draw_arc(centre,25,0,TAU,32,SKIN.PAPER if stage==4 else SKIN.BLUE,2)
