shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D smoke_texture : source_color;
void vertex() {
	// Camera-facing quads retain each CPU particle's animated world scale.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(INV_VIEW_MATRIX[0].xyz * length(MODEL_MATRIX[0].xyz), 0.0),
		vec4(INV_VIEW_MATRIX[1].xyz * length(MODEL_MATRIX[1].xyz), 0.0),
		vec4(INV_VIEW_MATRIX[2].xyz * length(MODEL_MATRIX[2].xyz), 0.0),
		MODEL_MATRIX[3]);
}
void fragment() {
	// The sprite's greyscale RGB darkens dense overlapping puffs. Its alpha
	// carries the soft detail; colour comes from the tyre/dust event instead.
	ALBEDO = COLOR.rgb;
	ALPHA = texture(smoke_texture, UV).a * COLOR.a;
}
