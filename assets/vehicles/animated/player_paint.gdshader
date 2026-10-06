shader_type spatial;
render_mode cull_disabled;
uniform sampler2D source_texture : source_color, filter_linear_mipmap;
uniform vec4 player_colour : source_color = vec4(0.937,0.396,0.275,1.0);
varying vec3 local_position;
varying vec3 local_normal;
uniform bool protect_windows = false;
uniform float source_hue = 0.0;
uniform float hue_width = 0.12;
uniform float paint_metallic = 0.0;
uniform float paint_roughness = 0.8;
vec3 hsv(vec3 colour) {
	vec4 k = vec4(0.0,-1.0/3.0,2.0/3.0,-1.0);
	vec4 p = mix(vec4(colour.bg,k.wz),vec4(colour.gb,k.xy),step(colour.b,colour.g));
	vec4 q = mix(vec4(p.xyw,colour.r),vec4(colour.r,p.yzx),step(p.x,colour.r));
	float d = q.x-min(q.w,q.y);
	return vec3(abs(q.z+(q.w-q.y)/(6.0*d+0.00001)),d/(q.x+0.00001),q.x);
}
void vertex() {
	local_position = VERTEX;
	local_normal = NORMAL;
}
void fragment() {
	vec3 stock = texture(source_texture,UV).rgb;
	vec3 colour = hsv(stock);
	float distance = abs(colour.x-source_hue);
	distance = min(distance,1.0-distance);
	float mask = (1.0-smoothstep(hue_width*0.5,hue_width,distance))*smoothstep(0.25,0.55,colour.y)*smoothstep(0.04,0.16,colour.z);
	if (protect_windows && local_position.x>-0.25 && local_position.x<0.32 && local_position.y>0.24 && local_position.y<0.35 && abs(local_position.z)<0.22 && abs(local_normal.y)<0.96) { mask = 0.0; }
	ALBEDO = mix(stock,player_colour.rgb*colour.z,mask);
	METALLIC = paint_metallic*mask;
	ROUGHNESS = mix(0.8,paint_roughness,mask);
}
