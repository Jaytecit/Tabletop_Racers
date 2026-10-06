extends Node2D
const CAPACITY: int = 512
var starts: PackedVector2Array = PackedVector2Array()
var ends: PackedVector2Array = PackedVector2Array()
var lives: PackedFloat32Array = PackedFloat32Array()
var cursor: int = 0
var race: Node2D
func _ready() -> void:
	starts.resize(CAPACITY)
	ends.resize(CAPACITY)
	lives.resize(CAPACITY)
	race = get_parent()
func stamp(pos: Vector2, heading: float) -> void:
	var f: Vector2 = Vector2.RIGHT.rotated(heading)
	var side: Vector2 = f.orthogonal()*7
	for i in range(2):
		starts[cursor] = pos+(side if i==0 else -side)-f*8
		ends[cursor] = starts[cursor]-f*7
		lives[cursor] = 4.0
		cursor = (cursor+1)%CAPACITY
func _physics_process(delta: float) -> void:
	if race.paused_race: return
	for i in range(CAPACITY): lives[i] = maxf(0.0,lives[i]-delta)
	queue_redraw()
func _draw() -> void:
	for i in range(CAPACITY):
		if lives[i]>0.0: draw_line(starts[i],ends[i],Color(0.15,0.17,0.16,minf(lives[i],1.0)*0.55),2,true)

func clear() -> void:
	lives.fill(0.0)
	queue_redraw()
