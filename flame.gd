extends Node2D
func _draw() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(-13,-5),Vector2(-36,0),Vector2(-13,5)]),Color("#e69b46"))
	draw_colored_polygon(PackedVector2Array([Vector2(-13,-3),Vector2(-27,0),Vector2(-13,3)]),Color("#fff4b0"))
