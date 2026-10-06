shader_type spatial;
render_mode cull_disabled;
uniform sampler2D source_texture : source_color, filter_linear_mipmap;
uniform vec4 player_colour : source_color = vec4(0.937,0.396,0.275,1.0);
void fragment() {
	vec4 stock = texture(source_texture, UV);
	float red = stock.r-max(stock.g,stock.b);
	float paint = smoothstep(0.07,0.22,red)*smoothstep(0.14,0.35,stock.r);
	vec3 recoloured = player_colour.rgb*(max(stock.r,max(stock.g,stock.b))/0.937);
	ALBEDO = mix(stock.rgb,recoloured,paint);
	ROUGHNESS = 0.8;
}
