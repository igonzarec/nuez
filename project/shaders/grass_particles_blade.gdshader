// Material de la hoja para el pasto vivo por particulas.
//
// Derivado del ejemplo grass.gdshader de Terrain3D (c) 2023-2026 Cory Petkovsek,
// Roope Palmroos y colaboradores. La diferencia respecto al original es que el
// color, el degradado de punta a raiz, el brillo y el viento dejan de estar
// escritos a mano en el codigo y se exponen como uniforms editables.
//
// Las hojas son cintas (RibbonTrailMesh) que el shader de particulas coloca y
// escala. Aqui solo se decide como se ven y como se doblan con el viento.

shader_type spatial;

render_mode skip_vertex_transform, cull_disabled, blend_mix;

group_uniforms color;
// Color de la base de la hoja, el mas oscuro.
uniform vec3 root_color : source_color = vec3(0.13, 0.20, 0.06);
// Color de la punta de la hoja, normalmente mas claro y amarillento.
uniform vec3 tip_color : source_color = vec3(0.38, 0.52, 0.16);
// Cuanto se aclara el extremo final de la punta. 0 lo desactiva.
uniform float tip_highlight : hint_range(0.0, 1.0, 0.01) = 0.35;
// Cuanto se oscurece la base de la hoja. 0 deja la base con su color pleno.
uniform float root_shading : hint_range(0.0, 1.0, 0.01) = 0.25;
// Variacion de tono aleatoria entre hojas. 0 las deja a todas identicas.
uniform float color_variation : hint_range(0.0, 1.0, 0.01) = 0.3;

group_uniforms lighting;
// Rugosidad base. Valores altos la vuelven mate; bajos le dan brillo especular.
uniform float base_roughness : hint_range(0.0, 1.0, 0.01) = 1.0;
// Reflejo especular maximo que puede alcanzar una hoja movida por el viento.
uniform float specular_amount : hint_range(0.0, 0.5, 0.01) = 0.15;
// Luz que atraviesa la hoja desde atras. Da el aspecto translucido a contraluz.
uniform vec3 backlight_color : source_color = vec3(0.33, 0.33, 0.33);

group_uniforms shape;
// Cuanto se afila la hoja hacia la punta. 1 la cierra en punta, 0 la deja recta.
uniform float pinch : hint_range(0.0, 1.0, 0.01) = 1.0;

group_uniforms wind;
// Direccion del viento en el plano XZ. Debe coincidir con la del shader de particulas.
uniform vec2 wind_direction = vec2(1.0, 1.0);
// Amplitud del bamboleo lateral, independiente del empuje del viento.
uniform float wobble_amount : hint_range(0.0, 1.0, 0.01) = 0.25;
// Velocidad del bamboleo lateral.
uniform float wobble_speed : hint_range(0.0, 8.0, 0.1) = 2.0;

varying vec4 data;
// INSTANCE_CUSTOM solo existe en vertex(), asi que su escala en Y viaja aqui.
varying float grow_factor;

void vertex() {
	// Altura normalizada a lo largo de la cinta, 0 en la base y 1 en la punta.
	data[2] = (VERTEX.y + 0.55);
	data[2] *= data[2]; // no lineal: concentra el efecto hacia la punta

	// Afila la cinta hacia arriba para que parezca una hoja y no una tira.
	VERTEX.xz *= (1.0 - data[2] * pinch);

	// Guarda los dos valores aleatorios por instancia para el fragment.
	data.rg = INSTANCE_CUSTOM.rg;
	grow_factor = INSTANCE_CUSTOM[3];

	vec3 w_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// INSTANCE_CUSTOM[3] es la escala en Y antes de rotar: durante el "crecer"
	// al aparecer vale poco, y entonces no conviene doblar la hoja.
	float scale = pow(INSTANCE_CUSTOM[3] * INSTANCE_CUSTOM[3], 0.707);
	float force = INSTANCE_CUSTOM[2] * data[2] * scale;
	force -= fract(force * 256.0) * force * 0.05; // ruido barato con viento fuerte
	force = pow(force, 0.707);

	// Desplazamiento lateral mas empuje en la direccion del viento.
	float lateral_wobble = sin(TIME * wobble_speed * (1.0 + data.r + data.g))
		* wobble_amount * (1.0 - INSTANCE_CUSTOM[2]);
	vec2 direction = normalize(wind_direction);
	w_vertex.xz -= (vec2(-direction.y, direction.x) * lateral_wobble + direction) * force;
	// Al doblarse, la hoja tambien baja.
	w_vertex.y -= INSTANCE_CUSTOM[2] * force * data[2];

	data[3] = force;

	VERTEX = (VIEW_MATRIX * vec4(w_vertex, 1.0)).xyz;
	NORMAL = MODELVIEW_NORMAL_MATRIX * NORMAL;
	BINORMAL = MODELVIEW_NORMAL_MATRIX * BINORMAL;
	TANGENT = MODELVIEW_NORMAL_MATRIX * TANGENT;
}

void fragment() {
	// Degradado de raiz a punta a lo largo de la hoja.
	vec3 albedo = mix(root_color, tip_color, clamp(data[2], 0.0, 1.0));
	// Aclara el extremo final para despegar la punta del fondo.
	albedo = mix(albedo, vec3(1.0), smoothstep(0.9, 1.0, data[2]) * tip_highlight);
	// Oscurece la base, salvo mientras la hoja esta creciendo al aparecer.
	albedo *= grow_factor < 0.35
		? 1.0
		: mix(1.0, 1.0 - root_shading, smoothstep(0.35, 0.0, data[2]));
	// Variacion aleatoria por instancia en rojo y verde.
	albedo.rg *= (data.rg - 0.5) * color_variation + 1.0;
	// COLOR viene del mapa de color pintado en Terrain3D.
	albedo *= pow(COLOR.rgb, vec3(2.2));
	ALBEDO = albedo;

	// Las hojas alzadas o agitadas brillan un poco mas.
	float spec_rough = clamp(max(data[2], data[3]), 0.0, 1.0);
	ROUGHNESS = clamp(base_roughness - spec_rough * base_roughness, 0.0, 1.0);
	SPECULAR = clamp(spec_rough * specular_amount, 0.0, specular_amount);

	BACKLIGHT = backlight_color;
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	ALBEDO = pow(ALBEDO, vec3(0.4));
	#endif
}
