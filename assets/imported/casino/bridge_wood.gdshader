shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_disabled;
varying vec3 deck_pos;
void vertex() { deck_pos = VERTEX; }
void fragment() {
	vec2 p = floor(deck_pos.xz * 24.0) / 24.0;
	float line = sin(p.y * 22.0 + sin(p.x * 1.5 + p.y * 0.7) * 3.0);
	float band = floor((line * 0.5 + 0.5) * 4.0) / 3.0;
	ALBEDO = mix(vec3(0.30,0.13,0.045),vec3(0.62,0.34,0.12),band);
	ROUGHNESS = 0.95;
}
