class_name SquirrelAnimator
extends Node

@export_group("Ritmo y transiciones")
## Distancia recorrida por cada ciclo completo de carrera, en unidades. El ciclo se basa en movimiento real, no en tiempo fijo.
## Ejemplo: 1,6 mueve las patas más rápido; 2,8 más despacio a igual velocidad. Ajusta junto con Step Reach para reducir el deslizamiento visual.
@export_range(0.5, 4.0) var stride_length := 2.1
## Multiplicador del ritmo de patas, brazos y sonidos de pasos; no cambia la velocidad del jugador.
## Ejemplo: 0,8 reduce un 20 % la frecuencia; 1,2 la aumenta un 20 %. Valores extremos pueden descoordinar patas y suelo.
@export_range(0.5, 1.5) var cadence_multiplier := 1.0
## Rapidez de transición entre poses y de seguimiento de varios movimientos del cuerpo. No son segundos.
## Ejemplo: 8 mezcla de forma más lenta y suave; 22 responde más rápido. No añade retraso al control físico.
@export_range(1.0, 30.0) var blend_speed := 14.0
@export_group("Patas y apoyo")
## Elevación de la pata durante el arco de recuperación, en unidades; las rodillas se flexionan para acompañarla.
## Ejemplo: 0,06 da pasos bajos; 0,14 levanta más las patas. Cerca de 0,20 puede exagerar o deformar las piernas cortas.
@export_range(0.01, 0.2) var step_height := 0.10
## Alcance hacia delante y atrás de cada pata respecto al cuerpo, en unidades; no mueve el controlador.
## Ejemplo: 0,12 da zancadas cortas; 0,22 más amplias. Combina con Stride Length y evita extremos que estiren demasiado la malla.
@export_range(0.05, 0.3) var step_reach := 0.19
## Fracción de cada ciclo dedicada al apoyo de la pata; el resto es su recuperación en el aire.
## Ejemplo: 0,50 reparte ambas fases por igual; 0,65 deja más tiempo de apoyo y una recuperación más rápida.
@export_range(0.4, 0.7) var stance_ratio := 0.56
## Cuánto baja visualmente el cuerpo al correr, en unidades; no cambia la cápsula de colisión.
## Ejemplo: 0 elimina el descenso; 0,04 flexiona suavemente; 0,09 es marcado. Comprueba que las patas no atraviesen el suelo.
@export_range(0.0, 0.09) var run_crouch := 0.045
## Amplitud de inclinación de las patas al despegar y recuperarse, en grados.
## Ejemplo: 0 mantiene las patas más planas; 6 da articulación sutil; 12 exagera el despegue.
@export_range(0.0, 15.0) var foot_roll_degrees := 6.0
## Multiplicador de alcance y altura del paso de la pata izquierda; no modifica la velocidad física.
## Ejemplo: 1 es simétrico; 0,95 frente a 1 en la derecha añade una diferencia leve. 1,4 puede parecer cojera.
@export_range(0.5, 1.5) var left_leg_multiplier := 1.0
## Multiplicador de alcance y altura del paso de la pata derecha; no modifica la velocidad física.
## Ejemplo: 1 mantiene la amplitud normal; 0,95 frente a 1 en la izquierda añade asimetría leve. Evita diferencias grandes.
@export_range(0.5, 1.5) var right_leg_multiplier := 1.0
@export_group("Brazos y codos")
## Amplitud del balanceo hacia delante y atrás de los brazos al correr, en grados; alterna con las patas.
## Ejemplo: 18 es discreto; 34 más expresivo; 0 elimina este balanceo, pero conserva salto e interacción.
@export_range(0.0, 60.0) var arm_swing_degrees := 28.0
## Separación lateral de los brazos respecto al cuerpo durante la carrera, en grados.
## Ejemplo: 3 mantiene los brazos cerca del torso; 12 los abre más. No controla la elevación durante el salto.
@export_range(0.0, 25.0) var arm_spread_degrees := 5.0
## Flexión base de los codos durante la carrera, en grados, añadida al balanceo del brazo.
## Ejemplo: 8 deja los brazos más rectos; 25 los mantiene más doblados. Elbow Swing Degrees añade flexión variable.
@export_range(0.0, 60.0) var elbow_bend_degrees := 18.0
## Flexión adicional de los codos en la parte del ciclo en que el brazo avanza, en grados.
## Ejemplo: 0 conserva la flexión base; 16 articula el movimiento; 30 lo hace más marcado.
@export_range(0.0, 45.0) var elbow_swing_degrees := 16.0
## Desfase del ciclo de brazos respecto a las patas, expresado como fracción de una vuelta completa.
## Ejemplo: 0 sincroniza las fases de referencia; 0,06 añade un pequeño retraso; -0,06 adelanta el movimiento.
@export_range(-0.2, 0.2) var arm_phase_offset := 0.06
## Intensidad del balanceo y flexión de carrera del brazo izquierdo. No multiplica su separación lateral ni el movimiento de salto/interacción.
## Ejemplo: 0 suprime su ciclo de balanceo; 1 es normal; 1,2 aumenta un 20 % su amplitud.
@export_range(0.0, 1.5) var left_arm_multiplier := 1.0
## Intensidad del balanceo y flexión de carrera del brazo derecho. No multiplica su separación lateral ni el movimiento de salto/interacción.
## Ejemplo: 0 suprime su ciclo de balanceo; 1 es normal; 0,95 frente a 1 en el izquierdo añade asimetría sutil.
@export_range(0.0, 1.5) var right_arm_multiplier := 1.0
@export_group("Cuerpo y cabeza")
## Amplitud del rebote vertical del cuerpo al correr, en unidades; acompaña los apoyos y puede crecer durante el sprint.
## Ejemplo: 0 elimina el rebote; 0,02 es sutil; 0,06 es muy visible. Revisa los pies para evitar sensación de flotar.
@export_range(0.0, 0.06) var body_bounce := 0.022
## Desplazamiento lateral del cuerpo al alternar pasos, en unidades; no modifica la trayectoria del jugador.
## Ejemplo: 0 elimina ese cambio de peso; 0,014 es suave; 0,035 produce un balanceo evidente.
@export_range(0.0, 0.05) var body_sway := 0.014
## Inclinación lateral alterna del torso durante los pasos, en grados; no es desplazamiento lateral.
## Ejemplo: 1 casi no se nota; 4 marca el peso de cada apoyo. Body Sway mueve el cuerpo de lado y este valor lo inclina.
@export_range(0.0, 10.0) var body_roll_degrees := 2.5
## Giro alterno del pecho respecto a las caderas al correr, en grados, reforzado durante el sprint.
## Ejemplo: 2 es contenido; 6 da más torsión; 12 es muy expresivo. La cabeza puede compensarlo con Head Stabilization.
@export_range(0.0, 12.0) var torso_twist_degrees := 4.0
## Inclinación visual hacia delante durante la carrera, en grados; no modifica la velocidad ni la colisión.
## Ejemplo: 0 corre erguida; 3 se inclina levemente; 7 da una postura más atlética. Se suma a Acceleration Lean.
@export_range(0.0, 10.0) var run_lean_degrees := 3.0
## Fracción de compensación de la cabeza frente a inclinaciones y giros del torso; no cambia la cámara.
## Ejemplo: 0 deja que acompañe al cuerpo; 0,75 estabiliza gran parte; 1 busca la compensación completa de los movimientos contemplados.
@export_range(0.0, 1.0) var head_stabilization := 0.75
## Intensidad de compresión y estiramiento del cuerpo durante el ciclo de carrera, como fracción de escala.
## Ejemplo: 0 desactiva el efecto; 0,012 cambia la altura aproximadamente un 1,2 %; 0,03 da una sensación más elástica.
@export_range(0.0, 0.05) var run_squash := 0.012
## Refuerzo progresivo de varias amplitudes de carrera al pasar de Walk Speed a Sprint Speed; no aumenta la velocidad física.
## Ejemplo: 1 conserva la intensidad; 1,18 refuerza brazos, torsión, elevación de patas y rebote; 1,4 es más caricaturesco.
@export_range(1.0, 1.5) var sprint_exaggeration := 1.18
@export_group("Salto y aterrizaje")
## Duración de la reacción de aterrizaje, en segundos. Se superpone sin bloquear movimiento ni salto.
## Ejemplo: 0,10 es rápida; 0,20 tarda más en recuperar la forma. No modifica el tiempo físico en el aire.
@export_range(0.05, 0.3) var landing_duration := 0.16
## Compresión máxima de altura al aterrizar, graduada por la velocidad del impacto; el cuerpo se ensancha ligeramente.
## Ejemplo: 0 elimina la compresión; 0,09 permite hasta un 9 %; 0,15 es más elástico. No cambia la cápsula de colisión.
@export_range(0.0, 0.2) var landing_squash := 0.09
@export_group("Inclinacion y cola")
## Inclinación adicional del cuerpo al acelerar y frenar, en radianes. Al frenar se inclina en sentido contrario.
## Ejemplo: 0 desactiva el efecto; 0,045 equivale a unos 2,6° máximos; 0,10 a unos 5,7°.
@export_range(0.0, 0.2) var acceleration_lean := 0.045
## Límite de inclinación lateral del cuerpo durante giros en carrera, en radianes. No cambia la rapidez de giro.
## Ejemplo: 0 elimina esa inclinación; 0,055 son unos 3,2°; 0,10 unos 5,7°. Para cambiar la respuesta usa Turn Speed en el nodo raíz.
@export_range(0.0, 0.2) var turn_lean := 0.055
## Fuerza del resorte que devuelve la cola a su objetivo de giro y flexión lateral. Más alto responde más rápido.
## Ejemplo: 40 da una cola más perezosa; 90 más firme. Ajusta con Tail Damping: rigidez alta y poco amortiguamiento producen más oscilación.
@export_range(1.0, 150.0) var tail_stiffness := 65.0
## Freno de las oscilaciones de giro y desplazamiento lateral de la cola. No controla el estiramiento vertical del salto.
## Ejemplo: 8 deja más rebote; 16 asienta suavemente con rigidez 65; 28 amortigua más y puede retrasar el regreso.
@export_range(1.0, 40.0) var tail_damping := 16.0
## Límite en radianes de los componentes principales de giro secundario de la cola; no limita su desplazamiento lateral o vertical.
## Ejemplo: 0,10 permite unos 5,7°; 0,25 unos 14,3°. Para flexión lateral usa Tail Turn Pull; para salto, Tail Air Drop.
@export_range(0.0, 0.4) var tail_limit := 0.18
## Amplitud del balanceo de cola asociado al ciclo de pasos, en grados, antes del resorte y del límite de giro.
## Ejemplo: 0 elimina solo el balanceo de carrera; 2,5 es sutil; 6 es más juguetón. La respuesta a giros continúa activa.
@export_range(0.0, 10.0) var tail_run_sway_degrees := 2.5
## Desplazamiento lateral máximo del extremo grande al girar, en unidades: se retrasa hacia el lado contrario al giro real del cuerpo.
## Ejemplo: 0 elimina esta flexión; 0,08 es discreto; 0,22 es marcado. No se activa por orbitar la cámara estando quieto.
@export_range(0.0, 0.3) var tail_turn_pull := 0.16
@export_group("Cola elastica en salto")
## Desplazamiento vertical elástico del extremo grande: baja al subir en el salto y se eleva al caer, en unidades.
## Ejemplo: 0 elimina el desplazamiento, no el giro; 0,08 es sutil; 0,22 es amplio. Ambas fases comparten esta intensidad.
@export_range(0.0, 0.3) var tail_air_drop := 0.16
## Intensidad de deformación de la espiral: se alarga hacia atrás y comprime verticalmente al subir; se invierte al caer.
## Ejemplo: 0 elimina el cambio de escala; 0,10 es suave; 0,25 es muy elástico. No cambia la altura del salto ni su colisión.
@export_range(0.0, 0.3) var tail_air_stretch := 0.16
## Rapidez de seguimiento de la velocidad vertical para la deformación de cola; no son segundos.
## Ejemplo: 6 deja más retraso; 12 responde suavemente; 22 sigue más de cerca la subida y caída. No afecta la rigidez lateral.
@export_range(1.0, 25.0) var tail_air_response := 12.0
@export_group("Brazos elasticos en salto")
## Elevación lateral objetivo durante la caída, en grados desde los brazos hacia abajo. Se mantiene hasta recuperar apoyo.
## Ejemplo: 70 los abre por debajo de los hombros; 90 los deja horizontales; 110 los levanta por encima. La transición es suave.
@export_range(0.0, 150.0) var arm_air_lift_degrees := 110.0
## Flexión de los codos en la postura de caída, en grados; menor valor deja los brazos más extendidos.
## Ejemplo: 0 los estira; 5 conserva una curva natural; 25 los dobla. No modifica los codos al correr.
@export_range(0.0, 45.0) var arm_fall_elbow_degrees := 5.0
## Desplazamiento vertical elástico de los antebrazos, en unidades; bajan al subir y se elevan al caer, sin desplazar los hombros.
## Ejemplo: 0 elimina el desplazamiento; 0,02 es sutil; 0,06 es más visible. El giro y el estiramiento se ajustan aparte.
@export_range(0.0, 0.08) var arm_air_drop := 0.035
## Estiramiento suave de los antebrazos en subida y caída, compensando el grosor para conservar volumen.
## Ejemplo: 0 conserva su escala; 0,08 permite aproximadamente un 8 % de cambio máximo; 0,14 es más caricaturesco.
@export_range(0.0, 0.15) var arm_air_stretch := 0.08
## Rapidez de respuesta elástica de brazos a la velocidad vertical; los antebrazos siguen un poco más tarde que los hombros.
## Ejemplo: 6 da más retraso; 12 es suave; 22 responde rápido. La amplitud se controla con Lift Degrees, Drop y Stretch.
@export_range(1.0, 25.0) var arm_air_response := 12.0

var actor: ExplorerPlayer
@export_group("Postura de planeo")
## Elevación de brazos al desplegar las membranas, independiente de la caída normal.
## Ejemplo: 90 los abre horizontalmente; 105 los eleva ligeramente. No modifica tus ajustes de salto.
@export_range(65.0, 120.0) var glide_arm_degrees := 95.0
## Apertura de piernas durante planeo, en grados; amplía la superficie de la membrana.
## Ejemplo: 15 es discreto; 28 forma una postura de ardilla voladora más clara.
@export_range(0.0, 40.0) var glide_leg_degrees := 28.0
## Inclinación hacia delante del cuerpo al planear, en grados.
## Ejemplo: 0 conserva la postura erguida; 20 inclina suavemente el cuerpo en dirección de avance.
@export_range(0.0, 40.0) var glide_lean_degrees := 20.0
## Rapidez de apertura y recogida de la postura y las membranas; no son segundos.
## Ejemplo: 6 abre despacio; 12 se despliega con rapidez sin cambio brusco de modelo.
@export_range(3.0, 25.0) var glide_blend_speed := 12.0
var glide_blend := 0.0
var clock := 0.0
var gait_phase := 0.0
var run_blend := 0.0
var air_blend := 0.0
var sprint_blend := 0.0
var jump_start := 0.0
var tail_velocity := Vector2.ZERO
var tail_angle := Vector2.ZERO
var tail_flex := 0.0
var tail_lateral := 0.0
var tail_lateral_velocity := 0.0
var arm_flex := 0.0
var forearm_flex := 0.0
var arms_falling := false
var arm_fall_blend := 0.0
var locomotion_state := "idle"
var foot_offsets := [Vector3(-0.16, 0.06, 0), Vector3(0.16, 0.06, 0)]

func jump_started() -> void:
	jump_start = 0.10

func reset() -> void:
	glide_blend = 0
	actor.model.glide_amount = 0
	jump_start = 0
	run_blend = 0
	air_blend = 0
	sprint_blend = 0
	tail_velocity = Vector2.ZERO
	tail_angle = Vector2.ZERO
	tail_flex = 0
	tail_lateral = 0
	tail_lateral_velocity = 0
	arm_flex = 0
	forearm_flex = 0
	arms_falling = false
	arm_fall_blend = 0
	actor.model.deform_tail(0, tail_air_drop, tail_air_stretch)
	actor.model.deform_arms(0, arm_air_drop, arm_air_stretch)
	actor.model.position = Vector3.ZERO
	actor.model.scale = Vector3.ONE
	actor.model.rotation.x = 0
	actor.model.rotation.z = 0
	actor.model.reset_interpolation()

func tick(delta: float, speed: float) -> void:
	clock += delta
	var grounded := actor.is_on_floor() or actor.is_sliding
	glide_blend = lerpf(glide_blend, 1.0 if actor.is_gliding else 0.0, 1.0 - exp(-glide_blend_speed * delta))
	actor.model.glide_amount = glide_blend
	# Distance, not commanded velocity: never run in midair or against a wall.
	if grounded and not actor.is_sliding: gait_phase += actor.previous_motion.length() * delta * TAU * cadence_multiplier / maxf(0.1, stride_length)
	var blend := 1.0 - exp(-blend_speed * delta)
	run_blend = lerpf(run_blend, clampf(speed / 2.0, 0, 1) if grounded and not actor.is_sliding else 0.0, blend)
	air_blend = lerpf(air_blend, 0.0 if grounded else 1.0, blend)
	sprint_blend = lerpf(sprint_blend, clampf((speed - actor.walk_speed) / maxf(0.1, actor.sprint_speed - actor.walk_speed), 0, 1), blend)
	var energy := lerpf(1.0, sprint_exaggeration, sprint_blend)
	jump_start = maxf(0, jump_start - delta)
	actor.reaction_time = maxf(0, actor.reaction_time - delta)
	actor.landing_time = maxf(0, actor.landing_time - delta)
	if actor.is_gliding: locomotion_state = "glide"
	elif actor.is_sliding: locomotion_state = "slide"
	elif jump_start > 0 and not grounded: locomotion_state = "jump_start"
	elif not grounded: locomotion_state = "rise" if actor.velocity.y > 0.5 else "fall"
	elif actor.landing_time > 0: locomotion_state = "land"
	elif speed > 0.12: locomotion_state = "run"
	else: locomotion_state = "idle"
	actor.animation_state = actor.reaction_kind if actor.reaction_time > 0 else locomotion_state
	var landing_phase := 1.0 - actor.landing_time / maxf(0.01, landing_duration)
	var squash := sin(landing_phase * PI) * landing_squash * actor.landing_strength if actor.landing_time > 0 else 0.0
	squash += cos(gait_phase * 2) * run_squash * run_blend
	actor.model.scale = actor.model.scale.lerp(Vector3(1 + squash * 0.4, 1 - squash, 1 + squash * 0.4), blend)
	var forward := Vector3.FORWARD.rotated(Vector3.UP, actor.model.rotation.y)
	var accel := clampf(actor.motion_acceleration.dot(forward) / actor.acceleration, -1, 1)
	var lean := -accel * acceleration_lean - deg_to_rad(run_lean_degrees) * run_blend * energy
	if actor.is_sliding: lean += 0.06
	lean = lerpf(lean, -deg_to_rad(glide_lean_degrees), glide_blend)
	actor.model.rotation.x = lerp_angle(actor.model.rotation.x, lean + clampf(actor.velocity.y * 0.009, -0.07, 0.07) * air_blend, blend)
	actor.model.rotation.z = lerp_angle(actor.model.rotation.z, clampf(-actor.angular_velocity * 0.018, -turn_lean, turn_lean) * run_blend, blend)
	# Occasional weight shifts rather than an always-on breathing/bouncing loop.
	var idle_shift := sin(clock * 0.65) * pow(maxf(0, sin(clock * 0.23)), 4) * 0.012 * (1 - run_blend)
	actor.model.position.x = lerpf(actor.model.position.x, idle_shift + sin(gait_phase) * body_sway * run_blend, blend)
	var bounce := (0.5 - 0.5 * cos(gait_phase * 2)) * body_bounce * energy * run_blend
	actor.model.position.y = lerpf(actor.model.position.y, -run_crouch * run_blend + bounce, blend)
	var wave := sin((1.0 - actor.reaction_time / 0.45) * PI) if actor.reaction_time > 0 else 0.0
	actor.model.begin_pose()
	# Latch after the apex: hold the extended pose until real support returns,
	# even if a small vertical-velocity fluctuation occurs before landing.
	if grounded: arms_falling = false
	elif actor.velocity.y <= 0: arms_falling = true
	arm_fall_blend = lerpf(arm_fall_blend, 1.0 if arms_falling else 0.0, 1.0 - exp(-arm_air_response * delta))
	var desired_arm_flex := clampf(actor.velocity.y / actor.jump_velocity, -1.0, 1.0) * air_blend if not grounded else 0.0
	arm_flex = lerpf(arm_flex, desired_arm_flex, 1.0 - exp(-arm_air_response * delta))
	# Elbows/hands follow the shoulders slightly later, with no spring overshoot.
	forearm_flex = lerpf(forearm_flex, desired_arm_flex, 1.0 - exp(-arm_air_response * 0.7 * delta))
	actor.model.deform_arms(forearm_flex, arm_air_drop, arm_air_stretch)
	var twist := sin(gait_phase - 0.25) * deg_to_rad(torso_twist_degrees) * run_blend * energy
	var roll := sin(gait_phase) * deg_to_rad(body_roll_degrees) * run_blend
	actor.model.smooth_pose("spine", Vector3(0, twist, roll), blend)
	for i in 2:
		var phase := fposmod((gait_phase + i * PI) / TAU, 1.0)
		var swing_ratio := 1.0 - stance_ratio
		var swing := phase < swing_ratio
		var u := phase / swing_ratio if swing else (phase - swing_ratio) / stance_ratio
		# Recovery follows an eased arc; the planted phase travels backward steadily.
		var stride := 1.0 - 2.0 * smoothstep(0, 1, u) if swing else -1.0 + 2.0 * u
		var limb_scale := left_leg_multiplier if i == 0 else right_leg_multiplier
		var lift := pow(sin(u * PI), 0.8) * step_height * run_blend * energy * limb_scale if swing else 0.0
		var desired := Vector3((-1 if i == 0 else 1) * 0.16, 0.06 + lift, stride * step_reach * run_blend * limb_scale)
		desired.y += 0.09 * air_blend
		desired.z += 0.06 * air_blend
		# Sample terrain under each paw; bounded correction prevents stretching at ledges.
		if grounded:
			var foot_world := actor.model.global_transform * Vector3(desired.x, 0.06, desired.z)
			var query := PhysicsRayQueryParameters3D.create(foot_world + Vector3.UP * 0.5, foot_world - Vector3.UP * 0.45, 1, [actor.get_rid()])
			var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty():
				var local_ground := actor.model.to_local(hit.position as Vector3)
				desired.y += clampf(local_ground.y, -0.08, 0.12)
		foot_offsets[i] = (foot_offsets[i] as Vector3).lerp(desired, 1.0 - exp(-24.0 * delta))
		var toe_roll := -sin(u * PI) * deg_to_rad(foot_roll_degrees) * run_blend if swing else smoothstep(0.7, 1, u) * deg_to_rad(foot_roll_degrees) * run_blend
		actor.model.leg_pose(i, foot_offsets[i], -actor.model.rotation.x + toe_roll)
		var hip := 4 if i == 0 else 7
		actor.model.current_rotations[hip] = Quaternion(Vector3.BACK, deg_to_rad(glide_leg_degrees) * (-1 if i == 0 else 1) * glide_blend) * actor.model.current_rotations[hip]
		var side := 1.0 if i == 0 else -1.0
		var arm_phase := cos(gait_phase + i * PI - arm_phase_offset * TAU)
		var arm_scale := left_arm_multiplier if i == 0 else right_arm_multiplier
		# Opposite arm/leg swing, bent elbows and a delayed shoulder response.
		var arm_angle := arm_phase * deg_to_rad(arm_swing_degrees) * run_blend * energy * arm_scale
		var elbow := (deg_to_rad(elbow_bend_degrees) + maxf(0, arm_phase) * deg_to_rad(elbow_swing_degrees)) * run_blend * arm_scale
		var air_spread := lerpf(0.04 * air_blend, deg_to_rad(arm_air_lift_degrees), arm_fall_blend)
		air_spread = lerpf(air_spread, deg_to_rad(glide_arm_degrees), glide_blend)
		# Opposite signs preserve the model's authored open-arms flight pose.
		actor.model.smooth_pose("arm_left" if i == 0 else "arm_right", Vector3(arm_angle - wave * 0.65, -twist * 0.25, side * (deg_to_rad(arm_spread_degrees) * run_blend - air_spread + wave * 0.06)), blend)
		var air_elbow := lerpf(air_blend * 0.25 - forearm_flex * 0.18, deg_to_rad(arm_fall_elbow_degrees), arm_fall_blend)
		air_elbow = lerpf(air_elbow, deg_to_rad(3.0), glide_blend)
		actor.model.smooth_pose("forearm_left" if i == 0 else "forearm_right", Vector3(elbow + air_elbow + wave * 0.3, 0, 0), blend)
	var tail_sway := sin(gait_phase - 0.65) * deg_to_rad(tail_run_sway_degrees) * run_blend
	var target_tail := Vector2(clampf(-accel * 0.07 + actor.velocity.y * 0.007 + sin(clock * 1.1) * 0.018 - bounce * 0.8, -tail_limit, tail_limit), clampf(-actor.angular_velocity * 0.035 + sin(clock * 0.85) * 0.025 + tail_sway, -tail_limit, tail_limit))
	# Bounded substeps keep the spring stable under hitches and parameter changes.
	var remaining := minf(delta, 0.1)
	var lateral_target := clampf(-actor.angular_velocity / 6.0, -1.0, 1.0) * tail_turn_pull
	while remaining > 0:
		var dt := minf(remaining, 1.0 / 120.0)
		tail_velocity += ((target_tail - tail_angle) * tail_stiffness - tail_velocity * tail_damping) * dt
		tail_angle += tail_velocity * dt
		tail_angle = tail_angle.clamp(Vector2.ONE * -tail_limit, Vector2.ONE * tail_limit)
		tail_lateral_velocity += ((lateral_target - tail_lateral) * tail_stiffness - tail_lateral_velocity * tail_damping) * dt
		tail_lateral += tail_lateral_velocity * dt
		if absf(tail_lateral) > tail_turn_pull:
			tail_lateral = clampf(tail_lateral, -tail_turn_pull, tail_turn_pull)
			if tail_lateral * tail_lateral_velocity > 0: tail_lateral_velocity = 0
		remaining -= dt
	actor.model.tail_rotation = Vector3(tail_angle.x, tail_angle.y, tail_angle.y * 0.25)
	actor.model.pose("tail", actor.model.tail_rotation)
	actor.model.pose("tail_tip", actor.model.tail_rotation * 0.45 + Vector3(0, 0, -tail_lateral * 0.35))
	var desired_flex := clampf(actor.velocity.y / actor.jump_velocity, -1.0, 1.0) * air_blend
	tail_flex = lerpf(tail_flex, desired_flex, 1.0 - exp(-tail_air_response * delta))
	actor.model.deform_tail(tail_flex, tail_air_drop, tail_air_stretch, tail_lateral)
	actor.model.smooth_pose("head", Vector3(-wave * 0.045 - actor.model.rotation.x * head_stabilization, idle_shift * 1.5 - twist * head_stabilization, -(actor.model.rotation.z + roll) * head_stabilization), blend)
