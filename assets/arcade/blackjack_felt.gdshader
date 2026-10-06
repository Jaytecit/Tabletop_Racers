shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
varying vec3 world_pos;
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
    vec2 thread = floor(world_pos.xz * 20.0);
    float weave = mod(thread.x + thread.y, 4.0) < 2.0 ? 0.94 : 1.06;
    float tuft = floor(hash(floor(thread / 3.0)) * 4.0) / 3.0;
    ALBEDO = vec3(0.025, 0.32, 0.12) * (weave + tuft * 0.12);
    ROUGHNESS = 1.0;
}
