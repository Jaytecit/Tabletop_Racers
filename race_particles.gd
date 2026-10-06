extends Node2D
# Fixed storage: no particle nodes, tweens or per-frame arrays.
const CAPACITY: int = 640
@export var screen_space: bool = false
var positions: PackedVector2Array = PackedVector2Array()
var velocities: PackedVector2Array = PackedVector2Array()
var lives: PackedFloat32Array = PackedFloat32Array()
var durations: PackedFloat32Array = PackedFloat32Array()
var sizes: PackedFloat32Array = PackedFloat32Array()
var colors: PackedColorArray = PackedColorArray()
var kinds: PackedByteArray = PackedByteArray()
var cursor: int = 0
var emitted: int = 0
var race: Node
func _ready() -> void:
	race = get_parent().get_parent() if screen_space else get_parent()
	positions.resize(CAPACITY)
	velocities.resize(CAPACITY)
	lives.resize(CAPACITY)
	durations.resize(CAPACITY)
	sizes.resize(CAPACITY)
	colors.resize(CAPACITY)
	kinds.resize(CAPACITY)
func clear() -> void:
	lives.fill(0.0)
	queue_redraw()
func burst(pos: Vector2, heading: float, kind: int, count: int, tint: Color = Color.WHITE) -> void:
	for _i in range(mini(count,CAPACITY)):
		var angle: float = randf()*TAU
		var speed: float = randf_range(30.0,110.0)
		var life: float = randf_range(0.35,0.8)
		var size: float = randf_range(1.5,3.0)
		var color: Color = tint
		if kind==0:
			speed *= 0.3
			life = randf_range(0.45,0.85)
			size = randf_range(2.0,4.0)
			color = Color(0.82,0.85,0.80,0.32)
		elif kind==1:
			angle = heading+PI+randf_range(-0.45,0.45)
			speed = randf_range(60.0,145.0)
			color = Color("#ffd785")
			life = 0.25
		elif kind==2:
			color = tint.lerp(Color("#fff0af"),randf()*0.7)
		elif kind==3:
			speed = randf_range(12.0,55.0)
			color = Color("#8af0e4")
			life = 0.6
		elif kind==4:
			speed = randf_range(80.0,210.0)
			life = randf_range(1.2,2.3)
			color = Color.from_hsv(randf(),0.65,1.0)
			size = randf_range(2.0,4.0)
		positions[cursor] = pos+Vector2.RIGHT.rotated(angle)*randf_range(0.0,6.0)
		velocities[cursor] = Vector2.RIGHT.rotated(angle)*speed
		lives[cursor] = life
		durations[cursor] = life
		sizes[cursor] = size
		colors[cursor] = color
		kinds[cursor] = kind
		cursor = (cursor+1)%CAPACITY
		emitted += 1
func _physics_process(delta: float) -> void:
	if race.paused_race or race.phase==4: return
	var changed: bool = false
	for i in range(CAPACITY):
		if lives[i]<=0.0: continue
		changed = true
		lives[i] = maxf(0.0,lives[i]-delta)
		positions[i] += velocities[i]*delta
		if kinds[i]==4: velocities[i].y += 90.0*delta
		else: velocities[i] *= 1.0-minf(delta*2.5,1.0)
	if changed: queue_redraw()
func _draw() -> void:
	for i in range(CAPACITY):
		if lives[i]<=0.0: continue
		var t: float = lives[i]/durations[i]
		var tint: Color = colors[i]
		tint.a *= minf(t*3.0,1.0)
		if kinds[i]==0:
			draw_circle(positions[i],sizes[i]*(2.0-t),tint)
		elif kinds[i]==1:
			draw_line(positions[i],positions[i]-velocities[i]*0.035,tint,1.5,true)
		elif kinds[i]==3:
			draw_arc(positions[i],sizes[i]*(3.0-t),0,TAU,10,tint,1.0,true)
		else:
			draw_set_transform(positions[i],lives[i]*7.0,Vector2.ONE)
			draw_rect(Rect2(-sizes[i],-sizes[i]*0.5,sizes[i]*2.0,sizes[i]),tint)
	draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)
func diagnostic_state() -> Dictionary:
	var alive: int = 0
	for life in lives:
		if life>0.0: alive += 1
	return {"alive":alive,"emitted":emitted,"capacity":CAPACITY}
