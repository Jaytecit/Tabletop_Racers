shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
varying vec3 local_pos;
void vertex() { local_pos = VERTEX; }
void fragment() {
    vec2 p = floor(local_pos.xz * 24.0) / 24.0;
    float line = sin(p.y * 22.0 + sin(p.x * 1.5 + p.y * 0.7) * 3.0);
    float band = floor((line * 0.5 + 0.5) * 4.0) / 3.0;
    ALBEDO = mix(vec3(0.24,0.085,0.025),vec3(0.55,0.26,0.07),band);
    ROUGHNESS = 0.95;
}
