@tool
extends Resource
# One directed span. X/Z is straight or Catmull-Rom; height is linear or sampled.
@export var id: String = ""
@export var next_id: String = ""
@export var start: Vector3 = Vector3.ZERO
@export var end: Vector3 = Vector3.ZERO
@export var before: Vector3 = Vector3.ZERO
@export var after: Vector3 = Vector3.ZERO
@export var curved: bool = false
@export var width: float = 6.0
@export var layer: int = 0
@export var surface: String = "felt"
@export_enum("shoulder", "raised", "guarded", "water") var edge: String = "shoulder"
@export var jump_exit: bool = false
@export var anchor: bool = true
# Optional sampled heights for imported ramps; X/Z retain the authored curve.
@export var height_samples: PackedFloat32Array = []

# Optional measured corridor, sampled uniformly in section parameter space.
# Its two edges are independent: imported artwork is not a constant-width spline.
@export var center_samples: PackedVector3Array = []
@export var left_samples: PackedVector3Array = []
@export var right_samples: PackedVector3Array = []

func has_measured_edges() -> bool:
	return left_samples!=null and right_samples!=null and left_samples.size()>1 and left_samples.size()==right_samples.size()

func sample_vector(values: PackedVector3Array, t: float) -> Vector3:
	var f: float = clampf(t,0.0,1.0)*float(values.size()-1)
	var i: int = mini(int(f),values.size()-2)
	return values[i].lerp(values[i+1],f-float(i))

func width_at(t: float) -> float:
	if not has_measured_edges(): return width
	var a: Vector3 = sample_vector(left_samples,t)
	var b: Vector3 = sample_vector(right_samples,t)
	return Vector2(a.x-b.x,a.z-b.z).length()

func point(t: float) -> Vector3:
	if center_samples!=null and center_samples.size()>1:
		return sample_vector(center_samples,t)
	var p: Vector3 = start.lerp(end,t)
	if curved:
		p = 0.5*((2.0*start)+(-before+end)*t+(2.0*before-5.0*start+4.0*end-after)*t*t+(-before+3.0*start-3.0*end+after)*t*t*t)
	p.y = lerpf(start.y,end.y,t)
	if height_samples!=null and height_samples.size()>1:
		var sample: float = clampf(t,0.0,1.0)*float(height_samples.size()-1)
		var index: int = mini(int(sample),height_samples.size()-2)
		p.y = lerpf(height_samples[index],height_samples[index+1],sample-float(index))
	return p
