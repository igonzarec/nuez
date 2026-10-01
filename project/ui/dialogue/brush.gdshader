shader_type canvas_item;
render_mode unshaded;
uniform vec2 panel_size = vec2(960,240);
uniform vec4 paint_color : source_color = vec4(1,1,0.8,1);
uniform int brush_style = 0;
uniform int stroke_count = 5;
uniform float thickness = 65.0;
uniform float spacing = 40.0;
uniform float length_variation = 0.12;
uniform float horizontal_variation = 35.0;
uniform float second_stroke_offset = 0.0;
uniform float softness = 12.0;
uniform float texture_strength = 0.45;
uniform float seed = 7.0;
uniform bool shadow_enabled = true;
uniform vec4 shadow_color : source_color = vec4(0.2,0.14,0.09,0.22);
uniform vec2 shadow_offset = vec2(5,7);
uniform float shadow_softness = 12.0;
uniform float padding = 60.0;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
	vec2 i=floor(p), f=smoothstep(vec2(0),vec2(1),fract(p));
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
float mask(vec2 p,float feather) {
	float result=0.0;
	for(int i=0;i<12;i++) {
		if(i>=stroke_count) { break; }
		float index=float(i), radius=thickness*0.5;
		float half_length=max(radius,panel_size.x*0.5*(1.0-hash(vec2(index+seed,2))*length_variation));
		vec2 center=vec2(panel_size.x*0.5+(hash(vec2(index,seed))-0.5)*horizontal_variation,
			panel_size.y*0.5+(index-float(stroke_count-1)*0.5)*spacing);
		vec2 q=p-center;
		if(i==1) { q.x-=second_stroke_offset; }
		q.x-=clamp(q.x,-half_length+radius,half_length-radius);
		float d=length(q)-radius;
		if(brush_style==1) { d+=(noise(p*0.3+seed)-0.5)*5.0; }
		if(brush_style==2) { d+=(noise(p*0.045+seed)-0.5)*12.0; }
		if(brush_style==3) { d+=(noise(vec2(p.x*0.025,p.y*0.7)+seed)-0.5)*14.0; }
		result=max(result,1.0-smoothstep(-feather,max(1.0,feather),d));
	}
	return result;
}
void fragment() {
	vec2 p=UV*(panel_size+vec2(padding*2.0))-vec2(padding);
	float alpha=mask(p,softness);
	if(brush_style==1) { alpha*=1.0-texture_strength*smoothstep(0.25,0.85,noise(p*0.8+seed)); }
	if(brush_style==2) { alpha*=1.0-texture_strength*0.6*noise(p*0.035+seed); }
	if(brush_style==3) { alpha*=1.0-texture_strength*smoothstep(0.3,0.7,noise(vec2(p.x*0.035,p.y*1.5)+seed)); }
	alpha*=paint_color.a;
	float shade=shadow_enabled ? mask(p-shadow_offset,shadow_softness)*shadow_color.a : 0.0;
	float combined=alpha+shade*(1.0-alpha);
	COLOR=vec4((paint_color.rgb*alpha+shadow_color.rgb*shade*(1.0-alpha))/max(combined,0.0001),combined);
}
