shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform float clock = 0.0;
uniform float lifetime = 7.0;
varying float born;
void vertex() { born = UV2.x; }
void fragment() {
	float edge = smoothstep(0.0, 0.18, UV.x) * smoothstep(0.0, 0.18, 1.0-UV.x);
	float tread = 0.82 + 0.18*sin(UV.y*75.0);
	ALBEDO = vec3(0.055, 0.065, 0.075);
	ALPHA = COLOR.a * edge * tread * (1.0-smoothstep(lifetime*0.45,lifetime,clock-born));
}
