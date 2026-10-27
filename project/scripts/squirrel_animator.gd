class_name SquirrelAnimator
extends Node
## Estado visual común del jugador. Las extremidades se animan en playertest2.

@export_group("Ritmo y transiciones")
## Mantiene la frecuencia de pasos lógicos y de los sonidos ya existentes.
@export_range(0.5, 4.0) var stride_length := 2.1
@export_range(0.5, 1.5) var cadence_multiplier := 1.0
@export_range(1.0, 30.0) var blend_speed := 14.0

@export_group("Cuerpo")
@export_range(0.0, 0.06) var body_bounce := 0.022
@export_range(0.0, 0.05) var body_sway := 0.014
@export_range(0.0, 10.0) var run_lean_degrees := 3.0
@export_range(0.0, 0.2) var acceleration_lean := 0.045
@export_range(0.0, 0.2) var turn_lean := 0.055
@export_range(0.0, 0.05) var run_squash := 0.012

@export_group("Salto y aterrizaje")
@export_range(0.05, 0.3) var landing_duration := 0.16
@export_range(0.0, 0.2) var landing_squash := 0.09

@export_group("Salto procedural · postura")
## Activa poses graduales de salto, caída y contracción al aterrizar. Se actualiza en vivo; al apagarlo el aire usa la pose base, sin Run.
@export var air_pose_enabled := true
## Apertura lateral de cada pierna al despegar, en grados. Más alto abre más las patas. Se actualiza en vivo.
@export_range(0.0, 40.0, 0.5) var air_leg_spread_degrees := 40.0
## Segundos desde el despegue hasta cerrar las piernas. Mayor valor mantiene la apertura más tiempo. Se actualiza en vivo.
@export_range(0.05, 1.5, 0.01, "suffix:s") var air_leg_close_duration := 1.5
## Apertura lateral máxima de cada pierna durante una caída prolongada, en grados. Mayor valor abre más las patas; 0 desactiva esta apertura sin alterar el despegue. Se actualiza en vivo y se mezcla al abandonar la zancada de avance.
@export_range(0.0, 70.0, 0.5) var air_fall_leg_spread_degrees := 25.0
## Segundos cayendo antes de empezar a abrir las piernas lateralmente. Mayor valor reserva el efecto para caídas más largas. Se actualiza en vivo; no cuenta el tiempo de subida, planeo ni escalada.
@export_range(0.0, 2.0, 0.01, "suffix:s") var air_fall_leg_spread_delay := 0.18
## Segundos desde que empieza la apertura hasta alcanzar Fall Leg Spread Degrees. Mayor valor abre las piernas más despacio; menor responde antes. Se actualiza en vivo y la mezcla general Air Pose Response también suaviza el resultado.
@export_range(0.05, 3.0, 0.01, "suffix:s") var air_fall_leg_spread_duration := 0.6
## Inclinación del cuerpo completo hacia delante durante caída prolongada, en grados: 0 conserva vertical, 45 inclina a medio camino y 90 aproxima postura horizontal con cabeza al frente. Comparte Fall Leg Spread Delay/Duration para entrar gradualmente; se mezcla al desaparecer la zancada y requiere Air Pose Enabled. Se guarda con la escena y responde en vivo. No inclina la cápsula ni afecta Glide, trepa o suelo.
@export_range(0.0, 120.0, 0.5, "suffix:°") var air_fall_body_lean_degrees := 70.0
## Elevación de cada brazo respecto al reposo al despegar, en grados. Mayor valor separa más los brazos del cuerpo. Se actualiza en vivo.
@export_range(0.0, 150.0, 0.5) var air_arm_start_degrees := 5.0
## Elevación de brazos al llegar al punto más alto, en grados. Mayor valor eleva más las manos. Se actualiza en vivo.
@export_range(0.0, 150.0, 0.5) var air_arm_apex_degrees := 56.0
## Límite de elevación de brazos en caída, en grados. Mayor valor acerca las manos a la cabeza. Se actualiza en vivo.
@export_range(0.0, 170.0, 0.5) var air_arm_fall_degrees := 93.5
## Desplazamiento máximo de cada hombro hacia el centro del torso, en metros, al elevar el brazo. 0 desactiva la corrección; mayor valor oculta más la unión redondeada. Se actualiza en vivo y vuelve a la posición original al bajar los brazos.
@export_range(0.0, 0.15, 0.005, "suffix:m") var air_arm_inset := 0.08
## Elevación de brazos, en grados desde reposo, a la que se alcanza todo Arm Inset. Menor valor mete los hombros antes; mayor lo reparte a lo largo del giro. Se actualiza en vivo; no afecta el ángulo de los brazos.
@export_range(5.0, 170.0, 0.5) var air_arm_inset_full_angle := 90.0
## Rapidez de caída en m/s que alcanza la postura y el temblor máximos. Menor valor los activa antes. Se actualiza en vivo.
@export_range(0.1, 20.0, 0.1, "suffix:m/s") var air_full_fall_speed := 5.0
## Amplitud máxima de temblor de brazos en grados, escalada con la caída. 0 lo desactiva. Se actualiza en vivo.
@export_range(0.0, 15.0, 0.1) var air_tremor_degrees := 10.6
## Oscilaciones de brazos por segundo. Mayor valor vibra más rápido; 0 desactiva el temblor. Se actualiza en vivo.
@export_range(0.0, 20.0, 0.1, "suffix:Hz") var air_tremor_frequency := 7.0
## Rapidez de mezcla de huesos por segundo al entrar y salir de la pose. Mayor valor responde antes; menor suaviza. Se actualiza en vivo.
@export_range(1.0, 40.0, 0.5) var air_pose_response := 18.0

@export_group("Salto en movimiento · zancada aérea")
## Activa una pose fija de zancada al saltar avanzando. Cambia de lado sólo al iniciar otro salto; al caer se mezcla con la postura normal. Se actualiza en vivo.
@export var air_stride_enabled := true
## Giro del brazo adelantado en grados. Mayor valor lo adelanta más; 0 elimina su giro longitudinal. Cambia de lado con cada salto. Se actualiza en vivo, independiente de Backward Degrees.
@export_range(0.0, 150.0, 0.5) var air_stride_arm_forward_degrees := 67.5
## Giro del brazo retrasado en grados. Mayor valor lo lleva más atrás; 0 elimina su giro longitudinal. Cambia de lado con cada salto. Se actualiza en vivo; ángulos extremos pueden cruzar las mallas del hombro.
@export_range(0.0, 150.0, 0.5) var air_stride_arm_backward_degrees := 96.0
## Giro máximo de cada pierna, opuesto al brazo del mismo lado, en grados. Mayor valor abre más la zancada longitudinal. Se actualiza en vivo.
@export_range(0.0, 70.0, 0.5) var air_stride_leg_degrees := 70.0
## Desplazamiento de la pierna adelantada hacia el frente del personaje, en metros, además de su giro. Mayor valor adelanta más la pata; 0 desactiva sólo este desplazamiento. Se actualiza en vivo y se reduce con la zancada al caer. Valores grandes pueden separar la unión de la cadera.
@export_range(0.0, 0.2, 0.005, "suffix:m") var air_stride_leg_forward_offset := 0.125
## Desplazamiento de la pierna retrasada hacia atrás, en metros, independiente de Forward Offset. Mayor valor retrasa más la pata; 0 desactiva sólo este desplazamiento. Se actualiza en vivo y cambia de pierna en el siguiente salto. Valores grandes pueden separar la unión de la cadera.
@export_range(0.0, 0.2, 0.005, "suffix:m") var air_stride_leg_backward_offset := 0.13
## Inclinación del torso hacia el frente en la pose de salto avanzando, en grados. Mayor valor inclina más pecho y hombros; 0 conserva el torso erguido. Se actualiza en vivo y se desvanece al recuperar la postura de caída.
@export_range(0.0, 40.0, 0.5) var air_stride_torso_lean_degrees := 15.5
## Avance adicional de la cabeza respecto al torso durante la zancada aérea, en metros. Mayor valor adelanta más la cabeza; 0 elimina sólo este avance. Se actualiza en vivo; valores extremos pueden separar la unión del cuello.
@export_range(0.0, 0.15, 0.005, "suffix:m") var air_stride_head_forward_offset := 0.025
## Velocidad horizontal en m/s para toda la zancada al despegar. La intensidad se captura al entrar al aire y se conserva en ese salto; la intención de movimiento también activa la postura. Menor valor admite velocidades menores. Afecta el siguiente salto.
@export_range(0.2, 12.0, 0.1, "suffix:m/s") var air_stride_full_speed := 3.0
## Segundos cayendo antes de recuperar la postura normal. Mayor valor mantiene más tiempo la pose fija. Se actualiza en vivo; después se aplican Fall Start/End Speed.
@export_range(0.0, 1.0, 0.01, "suffix:s") var air_stride_fall_delay := 0.12
## Rapidez descendente en m/s a la que empieza a recuperar la postura de caída normal. Mayor valor conserva más tiempo la zancada. Debe ser menor que Fall End Speed. Se actualiza en vivo.
@export_range(0.0, 15.0, 0.1, "suffix:m/s") var air_stride_fall_start_speed := 1.0
## Rapidez descendente en m/s a la que termina de apagar la zancada, aunque siga avanzando horizontalmente. Mayor valor retrasa la postura normal de caída. Se actualiza en vivo.
@export_range(0.1, 25.0, 0.1, "suffix:m/s") var air_stride_fall_end_speed := 6.0
## Rapidez de mezcla por segundo entre salto quieto, zancada y caída. Menor valor suaviza y retrasa la transición; mayor responde antes. Se actualiza en vivo.
@export_range(1.0, 30.0, 0.5) var air_stride_blend_speed := 10.0

@export_group("Aterrizaje procedural")
## Descenso máximo del torso respecto a las piernas en metros, graduado por el impacto. Mayor valor contrae más el cuerpo; valores extremos pueden cruzar mallas. Se actualiza en vivo.
@export_range(0.0, 0.25, 0.005, "suffix:m") var landing_body_drop := 0.10
## Retracción adicional de cabeza hacia el torso en metros. Mayor valor esconde más el cuello; valores extremos cruzan mallas. Se actualiza en vivo.
@export_range(0.0, 0.10, 0.005, "suffix:m") var landing_head_retract := 0.035
## Inclinación de cabeza hacia delante al contraerse, en grados. Mayor valor hace más marcado el asentimiento. Se actualiza en vivo.
@export_range(0.0, 25.0, 0.5) var landing_head_pitch_degrees := 6.0
## Segundos desde el impacto hasta máxima contracción. Mayor valor hace la absorción más lenta. Se consulta al aterrizar.
@export_range(0.02, 0.3, 0.01, "suffix:s") var landing_compress_duration := 0.07
## Segundos para recuperar la postura después de contraerse. Mayor valor alarga la recuperación. Se consulta al aterrizar.
@export_range(0.05, 0.8, 0.01, "suffix:s") var landing_recover_duration := 0.22
## Rapidez por segundo para recuperar brazos y piernas de caminar/correr al tocar suelo. Mayor valor recupera antes la zancada terrestre; menor suaviza la mezcla. La contracción de torso y cabeza continúa encima del clip. Se actualiza en vivo.
@export_range(1.0, 60.0, 0.5) var landing_locomotion_response := 30.0

@export_group("Postura de planeo")
## Inclinación base hacia delante durante Glide, incluso sin entrada de movimiento.
## Ejemplo: 20° es planeo tranquilo; 45° es marcado; cerca de 85° es una postura extrema.
@export_range(0.0, 85.0, 0.5) var glide_lean_degrees := 20.0
@export_range(3.0, 25.0) var glide_blend_speed := 12.0
## Inclinación añadida mientras mantienes una dirección durante Glide.
## Ejemplo: 0 conserva la misma postura; 6° da intención de avance; 15° es una picada clara.
@export_range(0.0, 40.0, 0.5) var glide_movement_extra_lean_degrees := 6.0
## Inclinación adicional al mantener L1/Shift y moverse durante el planeo.
@export_range(0.0, 50.0, 0.5) var glide_sprint_extra_lean_degrees := 12.0

@export_group("Banking de planeo")
## Inclinación lateral máxima al cambiar de dirección mientras planea.
## Ejemplo: 10° es apenas visible; 22° es natural; 40° se siente como un giro agresivo de ave.
@export_range(0.0, 75.0, 0.5) var glide_bank_degrees := 22.0
## Diferencia de rumbo pedida que alcanza el bank máximo.
## Ejemplo: 35° reacciona con fuerza en curvas breves; 70° es más gradual; 120° reserva el máximo para cambios cerrados.
@export_range(10.0, 180.0, 1.0) var glide_bank_full_turn_angle_degrees := 65.0
## Rapidez de giro real (grados/s) que refuerza el banking iniciado por la palanca. Menor valor lo refuerza antes.
## Ejemplo: 150 refuerza curvas suaves; 300 es equilibrado; 600 reserva ese refuerzo para curvas muy cerradas.
@export_range(45.0, 1080.0, 1.0) var glide_bank_full_turn_rate_degrees := 300.0
## Rapidez con que el cuerpo entra y sale de la inclinación lateral.
## Ejemplo: 4 se siente pesado y suave; 10 es equilibrado; 20 responde casi de inmediato.
@export_range(1.0, 30.0, 0.1) var glide_bank_blend_speed := 10.0
## Actívalo si el rig se inclina hacia el exterior de la curva en vez de hacia el interior.
## Ejemplo: déjalo apagado normalmente; actívalo solo para corregir una orientación de ejes invertida del modelo importado.
@export var glide_bank_invert := false

@export_group("Planeo · modelo artesanal")
## Velocidad de la vibración incluida en la acción Glide de Blender.
@export_range(0.1, 3.0, 0.01) var handmade_glide_flutter_speed := 1.0
## Velocidad de la animación de despliegue GlideStart de Blender.
@export_range(0.1, 3.0, 0.01) var handmade_glide_start_speed := 1.0
## Amplitud adicional de vibración de brazos y piernas mientras planea.
@export_range(0.0, 20.0, 0.1) var handmade_glide_tremor_degrees := 2.5
## Frecuencia de esa vibración. Cero la deja quieta.
@export_range(0.0, 30.0, 0.1) var handmade_glide_tremor_speed := 12.0

@export_group("Recoil de planeo")
## Activa la pose de contracción; desactivar conserva el estado físico y caída. Se consulta en vivo.
@export var recoil_pose_enabled := true
## Segundos hasta máxima contracción, limitados a la duración física del estado. Mayor encoge más lentamente. En vivo.
@export_range(0.01, 0.4, 0.01, "suffix:s") var recoil_compress_duration := 0.08
## Segundos finales dedicados a abrir la pose hacia caída. Mayor suaviza y anticipa recuperación; se limita al tiempo tras compresión. En vivo.
@export_range(0.01, 0.8, 0.01, "suffix:s") var recoil_recover_duration := 0.16
## Contracción máxima de escala vertical del modelo, como fracción. Mayor encoge más; 0 conserva escala. No altera cápsula. En vivo.
@export_range(0.0, 0.5, 0.01) var recoil_squash := 0.2
## Inclinación hacia atrás del cuerpo en grados. Mayor comunica un golpe más fuerte; negativa inclina hacia delante. En vivo.
@export_range(-60.0, 60.0, 0.5, "suffix:°") var recoil_body_pitch_degrees := 22.0
## Descenso del torso en metros. Mayor recoge el cuerpo hacia las piernas; valores altos pueden cruzar piezas. En vivo.
@export_range(0.0, 0.3, 0.005, "suffix:m") var recoil_body_drop := 0.12
## Retracción de cabeza hacia el torso en metros. Mayor encoge más el cuello; valores altos pueden cruzar mallas. En vivo.
@export_range(0.0, 0.15, 0.005, "suffix:m") var recoil_head_retract := 0.05
## Giro de cabeza hacia el pecho, en grados. Mayor marca más la contracción. En vivo.
@export_range(0.0, 60.0, 0.5, "suffix:°") var recoil_head_pitch_degrees := 20.0
## Elevación lateral de brazos, en grados. Mayor abre más los brazos; 0 los recoge a los lados. En vivo.
@export_range(0.0, 120.0, 0.5, "suffix:°") var recoil_arm_lift_degrees := 25.0
## Giro de ambos brazos hacia delante, en grados. Mayor los lleva hacia el pecho. En vivo.
@export_range(0.0, 120.0, 0.5, "suffix:°") var recoil_arm_tuck_degrees := 55.0
## Giro de ambas piernas hacia delante, en grados. Mayor recoge las patas hacia la panza. En vivo.
@export_range(0.0, 110.0, 0.5, "suffix:°") var recoil_leg_tuck_degrees := 45.0
## Rapidez de mezcla de huesos y cuerpo, en s⁻¹. Mayor responde antes al impacto; menor conserva más la pose de llegada. En vivo.
@export_range(1.0, 60.0, 0.5) var recoil_pose_response := 28.0

@export_group("Splat por caída")
## Activa la pose de pansazo; desactivar conserva el bloqueo físico y el sonido. En vivo.
@export var splat_pose_enabled := true
## Inicia la inclinación del pansazo desde la orientación visual real al impactar, sin volver primero a erguido. Incluye pitch y balanceo existentes; mezcla hacia la pose de suelo durante Compress Duration. Apagar recupera la entrada anterior. Se captura al entrar al siguiente splat; no cambia escala, duración ni física.
@export var splat_inherit_entry_tilt_enabled := true
## Segundos para pasar de la pose de llegada al pansazo. Mayor suaviza el golpe; se limita a la duración del estado. En vivo.
@export_range(0.01, 0.5, 0.01, "suffix:s") var splat_compress_duration := 0.10
## Segundos finales para levantarse antes de recuperar control. Mayor alarga la incorporación y reduce el tiempo inmóvil; se limita al estado. En vivo.
@export_range(0.05, 2.0, 0.01, "suffix:s") var splat_recover_duration := 0.45
## Inclinación hacia el suelo, en grados. 90 deja el cuerpo horizontal de panza; menor conserva más altura. No gira la cápsula. En vivo.
@export_range(0.0, 100.0, 0.5, "suffix:°") var splat_body_pitch_degrees := 90.0
## Escala visual en máxima compresión: X anchura, Y grosor vertical, Z longitud. Y menor aplasta más; X/Z mayores ensanchan la silueta. No afecta colisión. En vivo.
@export var splat_flat_scale := Vector3(1.12, 0.65, 1.12)
## Altura visual relativa al jugador, en metros, en máxima compresión. Más negativa acerca la panza al suelo; Clearance puede elevarla si cruza torso o cabeza. En vivo.
@export_range(-1.0, 0.5, 0.01, "suffix:m") var splat_visual_height := -0.50
## Apertura de brazos en grados. 90 los extiende a los lados; menor los acerca al cuerpo. En vivo.
@export_range(0.0, 140.0, 0.5, "suffix:°") var splat_arm_spread_degrees := 90.0
## Apertura de piernas en grados. Mayor abre más las patas; valores altos pueden separar visualmente las caderas. En vivo.
@export_range(0.0, 80.0, 0.5, "suffix:°") var splat_leg_spread_degrees := 32.0
## Giro de cabeza respecto al torso, en grados. 0 conserva reposo; ajusta para levantar o bajar el hocico. Clearance protege sus límites. En vivo.
@export_range(-45.0, 45.0, 0.5, "suffix:°") var splat_head_pitch_degrees := 0.0
## Rapidez de mezcla de huesos y cuerpo, en s⁻¹. Mayor marca el impacto; menor suaviza y retrasa la pose. En vivo.
@export_range(1.0, 60.0, 0.5) var splat_pose_response := 30.0
## Adapta la postura al plano de apoyo. Evita un pansazo horizontal atravesando pendientes. Sólo visual; en vivo.
@export var splat_surface_follow_enabled := true
## Eleva el modelo si torso o cabeza cruzan el plano del suelo. Usa sus cajas de malla, no colisión por vértice. Coste constante de 16 esquinas por frame durante splat. En vivo.
@export var splat_clearance_enabled := true
## Separación mínima respecto al plano de apoyo, en metros. Mayor evita penetración pero puede dejar la panza flotando. Requiere Clearance Enabled. En vivo.
@export_range(0.0, 0.2, 0.005, "suffix:m") var splat_clearance_margin := 0.015
## Elevación visual máxima para corregir cruces, en metros. Mayor protege poses más extremas; al llegar al límite aún puede haber penetración. Requiere Clearance Enabled. En vivo.
@export_range(0.0, 1.0, 0.01, "suffix:m") var splat_clearance_max_lift := 0.6

@export_group("Splat · movimiento antes de levantarse")
## Activa el pataleo previo y el movimiento automático de brazos al iniciar la incorporación. Las pulsaciones pueden mover los brazos antes. Requiere Splat Pose Enabled. No añade tiempo al bloqueo ni cambia la física. En vivo.
@export var splat_wiggle_enabled := true
## Mueve automáticamente brazos, piernas, cabeza, torso y cola después de la compresión, sin exigir pulsaciones. Apagar conserva las ventanas anteriores de pataleo previo e incorporación. Requiere Wiggle Enabled y Pose Enabled; no cambia la duración del estado. En vivo.
@export var splat_wiggle_auto_full_state_enabled := true
## Multiplicador de rapidez automática respecto a Wiggle Frequency. 1 conserva la base; 1,5 es un 50 % más rápido. Respeta Wiggle Max Hz. Las pulsaciones parten de esta rapidez para acelerar sin frenar el movimiento automático. En vivo.
@export_range(1.0, 3.0, 0.05) var splat_wiggle_auto_speed_multiplier := 1.5
## Con Auto Full State Enabled, segundos de entrada suave al forcejeo tras comprimir (mínimo interno 0,01 s). Sin esa opción, duración de las ventanas previas de pataleo/incorporación. No limita las pulsaciones manuales. En vivo.
@export_range(0.0, 1.5, 0.01, "suffix:s") var splat_wiggle_duration := 0.35
## Ciclos de movimiento por segundo, con lados alternados. Mayor produce un pataleo más rápido; 0 lo deja quieto. Frecuencias altas pueden perder amplitud con Pose Response bajo. En vivo.
@export_range(0.0, 15.0, 0.25, "suffix:Hz") var splat_wiggle_frequency := 7.0
## Límite global de ciclos por segundo para el wiggle automático y por pulsaciones. Mayor permite más rapidez; 0 detiene las oscilaciones. Se impone aunque Wiggle Frequency o Tap Max Frequency sean mayores, sin sobrescribirlos. Cabeza y torso derivan su frecuencia del valor ya limitado. 20 conserva el rango previo. En vivo.
@export_range(0.0, 20.0, 0.25, "or_greater", "suffix:Hz") var splat_wiggle_max_hz := 20.0
## Giro adicional máximo de brazos hacia delante y atrás, en grados. Mayor agita más los brazos; 0 elimina sólo su movimiento. Mantiene la apertura de Splat Arm Spread. Valores altos pueden cruzar el suelo. En vivo.
@export_range(0.0, 50.0, 0.5, "suffix:°") var splat_wiggle_arm_degrees := 14.0
## Giro adicional máximo de piernas alternadas, en grados. Mayor refuerza el pataleo; 0 deja las patas quietas. Mantiene Splat Leg Spread. Valores altos pueden cruzar el suelo. En vivo.
@export_range(0.0, 50.0, 0.5, "suffix:°") var splat_wiggle_leg_degrees := 20.0
## Rapidez de respuesta de huesos durante el pataleo, en s⁻¹. Mayor conserva mejor movimientos rápidos; menor los amortigua. Sólo afecta este intervalo; la incorporación conserva Splat Pose Response. En vivo.
@export_range(1.0, 90.0, 0.5) var splat_wiggle_pose_response := 50.0

@export_group("Splat · cabeza y torso")
## Activa el giro lateral de cabeza como diciendo «no» durante el pataleo automático o por pulsaciones. Requiere Wiggle Enabled y Pose Enabled. No cambia la orientación del jugador ni la cámara. En vivo.
@export var splat_head_shake_enabled := true
## Giro máximo a cada lado del cuello, en grados. Mayor marca el gesto de «no»; 0 deja la cabeza sin giro adicional. Se suma a Head Pitch y al movimiento heredado del torso. En vivo.
@export_range(0.0, 45.0, 0.5, "suffix:°") var splat_head_shake_degrees := 12.0
## Fracción de la frecuencia del pataleo para la cabeza. 0,35 produce 2,45 Hz con Wiggle Frequency 7 Hz; menor hace un «no» más pausado. También sigue la aceleración por pulsaciones. En vivo.
@export_range(0.05, 1.0, 0.05) var splat_head_shake_frequency_multiplier := 0.35
## Límite propio de ciclos por segundo del gesto de «no», después de aplicar Head Shake Frequency Multiplier a la frecuencia de wiggle ya limitada. Mayor permite girar más rápido; 0 detiene sólo el giro de cabeza. Se respeta también con pulsaciones y no sobrescribe el multiplicador. 20 conserva el rango previo de controles. En vivo.
@export_range(0.0, 20.0, 0.1, "or_greater", "suffix:Hz") var splat_head_shake_max_hz := 20.0
## Activa inclinación lateral suave del torso respecto a las caderas durante el pataleo. Requiere Wiggle Enabled y Pose Enabled. Sólo mueve huesos: no balancea la cápsula ni la cámara. En vivo.
@export var splat_torso_sway_enabled := true
## Inclinación máxima del torso a izquierda y derecha, en grados. Mayor refuerza el forcejeo; valores altos pueden separar o cruzar piezas. La cabeza y los brazos acompañan al ser hijos del torso. En vivo.
@export_range(0.0, 20.0, 0.5, "suffix:°") var splat_torso_sway_degrees := 4.0
## Fracción de la frecuencia del pataleo para el balanceo. 0,25 produce 1,75 Hz con Wiggle Frequency 7 Hz; menor balancea más despacio. También sigue la aceleración por pulsaciones. En vivo.
@export_range(0.05, 1.0, 0.05) var splat_torso_sway_frequency_multiplier := 0.25

@export_group("Splat · extremidades por pulsaciones")
## Permite agitar brazos y piernas desde cada pulsación de salto durante splat: Cruz en PlayStation, A en Xbox y Espacio. Comparten rapidez y alternan lados. Mantener pulsado no repite. No adelanta recuperación, salta ni reproduce el sonido de salto. Requiere Wiggle Enabled y Pose Enabled. En vivo.
@export var splat_tap_enabled := true
## Segundos de movimiento tras cada pulsación. Pulsar de nuevo renueva la ventana sin reiniciar el ciclo; mayor mantiene brazos y piernas activos más tiempo. Se desvanece al dejar de pulsar. La amplitud se ajusta por separado en Wiggle Arm/Leg Degrees. En vivo.
@export_range(0.05, 1.5, 0.01, "suffix:s") var splat_tap_duration := 0.35
## Frecuencia máxima en Hz al acumular pulsaciones. La base es Wiggle Frequency; nunca se usa un máximo inferior a ella. Mayor permite agitar más rápido. En vivo.
@export_range(1.0, 20.0, 0.25, "suffix:Hz") var splat_tap_max_frequency := 14.0
## Aumento de energía por pulsación, como fracción de 0 a 1. Mayor alcanza la frecuencia máxima con menos pulsaciones. Sólo cambia rapidez, no amplitud ni duración del splat. En vivo.
@export_range(0.05, 1.0, 0.05) var splat_tap_speed_gain := 0.3
## Energía perdida por segundo sin nuevas pulsaciones, en fracción/s. Mayor exige pulsar más seguido para mantener rapidez; menor conserva más el impulso. La ventana Duration sigue limitando el movimiento. En vivo.
@export_range(0.0, 5.0, 0.1) var splat_tap_speed_decay := 0.6
## Rapidez por segundo para entrar y salir del refuerzo de pulsaciones. Mayor acelera y desacelera antes; menor suaviza el cambio. Conserva los relojes y posiciones del movimiento automático, sin reiniciar ciclos al pulsar. No cambia duración ni límites de Hz. En vivo.
@export_range(1.0, 60.0, 0.5) var splat_tap_transition_response := 12.0

@export_group("Splat · movimiento de cola")
## Activa el balanceo lateral de cola durante el forcejeo automático y las pulsaciones. Sin Auto Full State Enabled, sólo se mueve durante Tap Duration. Requiere Wiggle Enabled y Pose Enabled. No modifica movimiento ni duración del estado. En vivo.
@export var splat_tail_sway_enabled := true
## Giro máximo de cola a cada lado desde su base, en grados. Mayor amplía el barrido; 0 deja la cola quieta. Valores altos pueden cruzar suelo o cuerpo. En vivo.
@export_range(0.0, 60.0, 0.5, "suffix:°") var splat_tail_sway_degrees := 18.0
## Fracción de la frecuencia efectiva del pataleo usada por la cola. Menor da un barrido más pausado; las pulsaciones aceleran ambos respetando Tail Sway Max Hz y el límite global de wiggle. En vivo.
@export_range(0.05, 1.0, 0.05) var splat_tail_sway_frequency_multiplier := 0.5
## Límite independiente de ciclos por segundo de la cola después de su multiplicador. Mayor permite barrer más rápido; 0 detiene sólo la oscilación de cola. No afecta cabeza, torso ni extremidades. En vivo.
@export_range(0.0, 20.0, 0.1, "suffix:Hz") var splat_tail_sway_max_hz := 3.0

@export_group("Splat · apoyo para levantarse")
## Añade preparación de manos, empuje de pecho e incorporación final dentro de Recover Duration. Apagar recupera la transición anterior. Requiere Splat Pose Enabled; no cambia duración total ni física. En vivo.
@export var splat_support_enabled := true
## Fracción inicial de Recover Duration dedicada a recoger los brazos y apoyar las manos antes de levantar el pecho. Mayor prolonga la preparación y deja menos tiempo para empujar. 0,25 equivale al primer 25 %. En vivo.
@export_range(0.05, 0.5, 0.01) var splat_support_plant_fraction := 0.25
## Fracción de Recover Duration donde termina el empuje y empieza la incorporación final soltando las manos. Mayor conserva el apoyo más tiempo. Debe superar Plant Fraction; se limita a al menos 0,05 más. En vivo.
@export_range(0.15, 0.95, 0.01) var splat_support_push_end_fraction := 0.72
## Inclinación del cuerpo hacia el suelo al acabar el empuje, en grados: 0 erguido, 90 tumbado. Menor levanta más el pecho antes de soltar manos. Se limita a Body Pitch de la pose de splat. En vivo.
@export_range(0.0, 90.0, 0.5, "suffix:°") var splat_support_body_pitch_degrees := 35.0
## Apertura lateral de brazos durante el apoyo, en grados. Menor acerca las manos al pecho; mayor las separa. Sustituye temporalmente Arm Spread de la pose aplastada. En vivo.
@export_range(0.0, 70.0, 0.5, "suffix:°") var splat_support_arm_spread_degrees := 22.0
## Corrección de giro de brazos respecto a la inclinación actual del cuerpo, en grados. 0 los orienta aproximadamente hacia el suelo mientras sube el pecho; positivo/negativo adelanta o retrasa el apoyo. Es pose visual, sin IK ni fijación exacta de manos. En vivo.
@export_range(-45.0, 45.0, 0.5, "suffix:°") var splat_support_arm_pitch_offset_degrees := 0.0
## Rapidez mínima de respuesta de los huesos mientras prepara y empuja, en s⁻¹. Mayor permite colocar manos en recuperaciones cortas; menor suaviza. La inclinación del cuerpo conserva Splat Pose Response. En vivo.
@export_range(1.0, 90.0, 0.5) var splat_support_pose_response := 55.0

var actor: ExplorerPlayer
var glide_blend := 0.0
var clock := 0.0
var gait_phase := 0.0
var run_blend := 0.0
var jump_start := 0.0
var locomotion_state := "idle"
var body_pitch := 0.0
var body_roll := 0.0
var body_bank := 0.0
var was_glide_landing := false
var glide_landing_entry_angles := Vector3.ZERO
var glide_landing_entry_rotation := Quaternion.IDENTITY
var air_elapsed := 0.0
var air_launch_speed := 1.0
var landing_elapsed := -1.0
var landing_compress_time := 0.07
var landing_recover_time := 0.22
var air_stride_side := -1.0
var air_stride_weight := 0.0
var air_stride_fall_weight := 0.0
var air_stride_launch_weight := 0.0
var air_stride_capture_pending := true
var air_was_airborne := false
var air_stride_fall_elapsed := 0.0
var splat_tap_left := 0.0
var splat_tap_energy := 0.0
var splat_tap_phase := 0.0
var splat_tap_blend := 0.0
var splat_head_shake_phase := 0.0
var splat_torso_sway_phase := 0.0
var splat_tail_sway_phase := 0.0
var splat_entry_rotation := Quaternion.IDENTITY
var splat_entry_angles := Vector3.ZERO
var splat_inherit_entry_tilt := true

func splat_started() -> void:
	splat_tap_blend = 0.0
	splat_tail_sway_phase = 0.0
	splat_entry_rotation = actor.model.body_pivot.quaternion
	splat_entry_angles = Vector3(body_pitch, body_roll, body_bank)
	splat_inherit_entry_tilt = splat_inherit_entry_tilt_enabled
	splat_head_shake_phase = 0.0
	splat_torso_sway_phase = 0.0
	splat_tap_left = 0.0
	splat_tap_energy = 0.0
	splat_tap_phase = 0.0
	recoil_started()
	air_was_airborne = false
	air_elapsed = 0.0


func recoil_started() -> void:
	jump_start = 0.0
	landing_elapsed = -1.0
	glide_blend = 0.0
	run_blend = 0.0
	air_stride_weight = 0.0
	air_stride_launch_weight = 0.0
	air_stride_capture_pending = false
	air_was_airborne = true
	air_stride_fall_weight = 1.0
	air_stride_fall_elapsed = air_stride_fall_delay
	actor.model.update_handmade_glide(0.0, handmade_glide_flutter_speed)


func landed() -> void:
	landing_elapsed = 0.0
	landing_compress_time = landing_compress_duration
	landing_recover_time = landing_recover_duration

func jump_started() -> void:
	jump_start = 0.10
	air_elapsed = 0.0
	air_launch_speed = maxf(0.1, actor.velocity.y)
	air_stride_side = -air_stride_side
	air_stride_capture_pending = true
	air_stride_fall_elapsed = 0.0
	air_stride_fall_weight = 0.0
	landing_elapsed = -1.0

func reset() -> void:
	splat_tap_blend = 0.0
	splat_tail_sway_phase = 0.0
	splat_entry_rotation = Quaternion.IDENTITY
	splat_entry_angles = Vector3.ZERO
	splat_head_shake_phase = 0.0
	splat_torso_sway_phase = 0.0
	splat_tap_left = 0.0
	splat_tap_energy = 0.0
	splat_tap_phase = 0.0
	was_glide_landing = false
	glide_blend = 0.0
	run_blend = 0.0
	jump_start = 0.0
	air_elapsed = 0.0
	landing_elapsed = -1.0
	air_stride_side = -1.0
	air_stride_weight = 0.0
	air_stride_fall_weight = 0.0
	air_stride_launch_weight = 0.0
	air_stride_capture_pending = true
	air_was_airborne = false
	air_stride_fall_elapsed = 0.0
	actor.model.glide_amount = 0.0
	actor.model.position = Vector3.ZERO
	actor.model.scale = Vector3.ONE
	body_pitch = 0.0
	body_roll = 0.0
	body_bank = 0.0
	actor.model.reset_body_tilt()
	actor.model.reset_interpolation()

func tick(delta: float, speed: float) -> void:
	clock += delta
	if actor.is_splat:
		_tick_splat(delta)
		return
	if actor.is_glide_recoiling:
		_tick_recoil(delta)
		return
	if actor.is_glide_landing:
		# El aterrizaje usa el ángulo normal de Glide, sin intención ni Sprint.
		locomotion_state = "glide_land"
		actor.animation_state = locomotion_state
		if not was_glide_landing:
			glide_landing_entry_angles = Vector3(body_pitch, body_roll, body_bank)
			glide_landing_entry_rotation = actor.model.body_pivot.quaternion
		was_glide_landing = true
		var pose_mix := smoothstep(actor.glide_landing_pose_delay, actor.glide_landing_pose_delay + actor.glide_landing_pose_blend_duration, actor.glide_landing_elapsed)
		body_pitch = lerp_angle(glide_landing_entry_angles.x, -deg_to_rad(glide_lean_degrees), pose_mix)
		body_roll = lerp_angle(glide_landing_entry_angles.y, 0.0, pose_mix)
		body_bank = lerp_angle(glide_landing_entry_angles.z, 0.0, pose_mix)
		actor.model.set_body_tilt(body_pitch, body_roll, body_bank)
		actor.model.align_glide_landing_surface(delta, pose_mix, glide_landing_entry_rotation, Quaternion(Vector3.RIGHT, -deg_to_rad(glide_lean_degrees)))
		actor.model.hold_glide_landing_pose()
		return
	was_glide_landing = false
	var grounded := actor.is_on_floor() or actor.is_sliding
	var blend := 1.0 - exp(-blend_speed * delta)
	glide_blend = lerpf(glide_blend, 1.0 if actor.is_gliding else 0.0, 1.0 - exp(-glide_blend_speed * delta))
	run_blend = lerpf(run_blend, 1.0 if speed > 0.12 and grounded and not actor.is_sliding else 0.0, blend)
	if grounded and not actor.is_sliding:
		gait_phase += actor.previous_motion.length() * delta * TAU * cadence_multiplier / maxf(0.1, stride_length)
	jump_start = maxf(0.0, jump_start - delta)
	actor.reaction_time = maxf(0.0, actor.reaction_time - delta)
	actor.landing_time = maxf(0.0, actor.landing_time - delta)
	if actor.is_gliding:
		locomotion_state = "glide"
	elif actor.is_sliding:
		locomotion_state = "slide"
	elif jump_start > 0.0 and not grounded:
		locomotion_state = "jump_start"
	elif not grounded:
		locomotion_state = "rise" if actor.velocity.y > 0.5 else "fall"
	elif actor.landing_time > 0.0:
		locomotion_state = "land"
	elif speed > 0.12:
		locomotion_state = "run"
	else:
		locomotion_state = "idle"
	actor.animation_state = actor.reaction_kind if actor.reaction_time > 0.0 else locomotion_state

	var landing_phase := 1.0 - actor.landing_time / maxf(0.01, landing_duration)
	var squash := sin(landing_phase * PI) * landing_squash * actor.landing_strength if actor.landing_time > 0.0 and not air_pose_enabled else 0.0
	squash += cos(gait_phase * 2.0) * run_squash * run_blend
	actor.model.scale = actor.model.scale.lerp(Vector3(1.0 + squash * 0.4, 1.0 - squash, 1.0 + squash * 0.4), blend)
	var forward := Vector3.FORWARD.rotated(Vector3.UP, actor.model.rotation.y)
	var acceleration := clampf(actor.motion_acceleration.dot(forward) / maxf(0.01, actor.acceleration), -1.0, 1.0)
	var lean := -acceleration * acceleration_lean - deg_to_rad(run_lean_degrees) * run_blend
	# Conserva una postura base de planeo. La entrada y Sprint añaden inclinación
	# para comunicar intención de avanzar y ganar velocidad.
	var glide_intent := clampf(actor.glide_movement_intent, 0.0, 1.0)
	var glide_lean := glide_lean_degrees + glide_movement_extra_lean_degrees * glide_intent + (glide_sprint_extra_lean_degrees if actor.is_glide_sprinting else 0.0) * glide_intent
	lean = lerpf(lean, -deg_to_rad(glide_lean), glide_blend)
	if air_pose_enabled and not grounded and not actor.is_gliding and not actor.is_climbing and actor.velocity.y < 0.0:
		# Usa el mismo reloj de caída prolongada que la apertura de patas,
		# sin añadir otro temporizador ni cambiar la pose fija del salto.
		var fall_elapsed := air_stride_fall_elapsed + delta
		var long_fall := smoothstep(air_fall_leg_spread_delay, air_fall_leg_spread_delay + air_fall_leg_spread_duration, fall_elapsed)
		var falling := smoothstep(0.0, air_full_fall_speed, -actor.velocity.y)
		lean -= deg_to_rad(air_fall_body_lean_degrees) * long_fall * falling * (1.0 - air_stride_weight)
	body_pitch = lerp_angle(body_pitch, lean, blend)
	var run_roll := clampf(-actor.angular_velocity * 0.018, -turn_lean, turn_lean) * run_blend
	var bank_direction := 1.0 if glide_bank_invert else -1.0
	var glide_turn_rate := rad_to_deg(actor.angular_velocity)
	var max_glide_roll := deg_to_rad(glide_bank_degrees) * glide_blend
	# El yaw sigue el rumbo en Player. Aquí el roll es puramente visual: toma el
	# ángulo firmado de la curva y, al soltar la palanca, conserva solo el giro
	# que aún ocurra de verdad. Cuando vuela recto ambos valores llegan a cero.
	var requested_bank := clampf(actor.glide_signed_turn_angle / deg_to_rad(glide_bank_full_turn_angle_degrees), -1.0, 1.0)
	var turning_bank := clampf(glide_turn_rate / maxf(1.0, glide_bank_full_turn_rate_degrees), -1.0, 1.0)
	var bank_signal := requested_bank
	if absf(bank_signal) < 0.01:
		bank_signal = turning_bank
	elif signf(turning_bank) == signf(bank_signal):
		bank_signal = signf(bank_signal) * maxf(absf(bank_signal), absf(turning_bank))
	var glide_roll := clampf(bank_signal * max_glide_roll * bank_direction, -max_glide_roll, max_glide_roll)
	var roll_blend := 1.0 - exp(-(glide_bank_blend_speed if glide_blend > 0.001 else blend_speed) * delta)
	body_roll = lerp_angle(body_roll, run_roll, roll_blend)
	body_bank = lerp_angle(body_bank, glide_roll, roll_blend)
	actor.model.set_body_tilt(body_pitch, body_roll, body_bank)
	actor.model.position.x = lerpf(actor.model.position.x, sin(gait_phase) * body_sway * run_blend, blend)
	actor.model.position.y = lerpf(actor.model.position.y, (0.5 - 0.5 * cos(gait_phase * 2.0)) * body_bounce * run_blend, blend)
	actor.model.glide_amount = glide_blend
	actor.model.update_handmade_glide(glide_blend, handmade_glide_flutter_speed, handmade_glide_start_speed, handmade_glide_tremor_degrees, handmade_glide_tremor_speed)
	_tick_air_pose(delta, grounded)


func _tick_splat(delta: float) -> void:
	locomotion_state = "splat"
	actor.animation_state = locomotion_state
	was_glide_landing = false
	var duration := actor.splat_state_duration
	var compress_time := minf(splat_compress_duration, duration)
	var recover_time := minf(splat_recover_duration, maxf(0.001, duration - compress_time))
	var elapsed := actor.splat_elapsed
	var recover_start := duration - recover_time
	var recover_progress := clampf((elapsed - recover_start) / maxf(0.001, recover_time), 0.0, 1.0)
	var compress_weight := smoothstep(0.0, compress_time, elapsed)
	var weight := compress_weight * (1.0 - smoothstep(0.0, 1.0, recover_progress))
	var body_weight := weight
	var support_weight := 0.0
	if splat_support_enabled and splat_pose_enabled and elapsed >= recover_start:
		var plant_end := splat_support_plant_fraction
		var push_end := maxf(plant_end + 0.05, splat_support_push_end_fraction)
		var chest_weight := clampf(splat_support_body_pitch_degrees / maxf(0.01, splat_body_pitch_degrees), 0.0, 1.0)
		# Primero coloca las manos manteniendo la panza baja; luego empuja.
		weight = compress_weight * (1.0 - smoothstep(plant_end, 1.0, recover_progress))
		body_weight = lerpf(1.0, chest_weight, smoothstep(plant_end, push_end, recover_progress))
		body_weight *= compress_weight * (1.0 - smoothstep(push_end, 1.0, recover_progress))
		support_weight = smoothstep(0.0, plant_end, recover_progress) * (1.0 - smoothstep(push_end, 1.0, recover_progress))
	if not splat_pose_enabled:
		weight = 0.0
		body_weight = 0.0
	var blend := 1.0 - exp(-splat_pose_response * delta)
	body_pitch = lerp_angle(body_pitch, -deg_to_rad(splat_body_pitch_degrees) * body_weight, blend)
	body_roll = lerp_angle(body_roll, 0.0, blend)
	body_bank = lerp_angle(body_bank, 0.0, blend)
	actor.model.set_body_tilt(body_pitch, body_roll, body_bank)
	if splat_surface_follow_enabled:
		var normal := (actor.model.global_basis.orthonormalized().inverse() * actor.splat_floor_normal).normalized()
		actor.model.body_pivot.quaternion = Quaternion.IDENTITY.slerp(Quaternion(Vector3.UP, normal), weight) * actor.model.body_pivot.quaternion
	if splat_inherit_entry_tilt and splat_pose_enabled and elapsed < compress_time:
		# El objetivo de entrada es la pose completa, nunca una pose erguida
		# multiplicada por un peso que empieza en cero.
		var target_rotation := Quaternion(Vector3.RIGHT, -deg_to_rad(splat_body_pitch_degrees))
		if splat_surface_follow_enabled:
			var normal := (actor.model.global_basis.orthonormalized().inverse() * actor.splat_floor_normal).normalized()
			target_rotation = Quaternion(Vector3.UP, normal) * target_rotation
		actor.model.body_pivot.quaternion = splat_entry_rotation.slerp(target_rotation, compress_weight)
		body_pitch = lerp_angle(splat_entry_angles.x, -deg_to_rad(splat_body_pitch_degrees), compress_weight)
		body_roll = lerp_angle(splat_entry_angles.y, 0.0, compress_weight)
		body_bank = lerp_angle(splat_entry_angles.z, 0.0, compress_weight)
	actor.model.scale = actor.model.scale.lerp(Vector3.ONE.lerp(splat_flat_scale.clamp(Vector3.ONE * 0.05, Vector3.ONE * 3.0), weight), blend)
	actor.model.position = actor.model.position.lerp(Vector3.UP * splat_visual_height * weight, blend)
	# Automático y pulsaciones comparten oscilador: X cambia rapidez,
	# nunca el punto del ciclo ni la posición objetivo de cada miembro.
	var wiggle_start := maxf(compress_time, recover_start - splat_wiggle_duration)
	var arm_pitches := Vector2.ZERO
	var arm_wiggle := Vector2.ZERO
	var leg_pitches := Vector2.ZERO
	var pose_response := splat_pose_response
	var wiggle_limit := maxf(0.0, splat_wiggle_max_hz)
	var base_frequency := clampf(splat_wiggle_frequency, 0.0, wiggle_limit)
	var auto_frequency := clampf(base_frequency * splat_wiggle_auto_speed_multiplier, 0.0, wiggle_limit)
	var gesture_frequency := 0.0
	var gesture_envelope := 0.0
	var tail_sway := 0.0
	var arm_envelope := 0.0
	var leg_envelope := 0.0
	var arms_enabled := splat_wiggle_enabled and splat_pose_enabled
	var recover_fade := 1.0 - smoothstep(0.8, 1.0, recover_progress)
	if arms_enabled:
		if splat_wiggle_auto_full_state_enabled:
			var ramp_duration := maxf(0.01, minf(splat_wiggle_duration, recover_start - compress_time))
			arm_envelope = smoothstep(compress_time, compress_time + ramp_duration, elapsed) * recover_fade
			leg_envelope = arm_envelope
		else:
			if elapsed > wiggle_start and elapsed < recover_start:
				var progress := clampf((elapsed - wiggle_start) / maxf(0.001, recover_start - wiggle_start), 0.0, 1.0)
				leg_envelope = pow(sin(PI * progress), 2.0)
			var auto_end := minf(duration, recover_start + splat_wiggle_duration)
			if elapsed > recover_start and elapsed < auto_end:
				var progress := (elapsed - recover_start) / maxf(0.001, auto_end - recover_start)
				arm_envelope = pow(sin(PI * progress), 2.0)
	splat_tap_left = maxf(0.0, splat_tap_left - delta)
	splat_tap_energy = maxf(0.0, splat_tap_energy - splat_tap_speed_decay * delta)
	if arms_enabled and splat_tap_enabled and not actor.interaction_press_consumed and actor.action_just_pressed("jump"):
		splat_tap_left = splat_tap_duration
		splat_tap_energy = minf(1.0, splat_tap_energy + splat_tap_speed_gain)
	var tap_target := 0.0
	if arms_enabled and splat_tap_enabled and splat_tap_left > 0.0 and wiggle_limit > 0.0:
		tap_target = smoothstep(0.0, minf(0.1, splat_tap_duration), splat_tap_left)
	splat_tap_blend = lerpf(splat_tap_blend, tap_target, 1.0 - exp(-splat_tap_transition_response * delta))
	if arms_enabled:
		var tap_max := clampf(splat_tap_max_frequency, auto_frequency, wiggle_limit)
		var boosted_frequency := lerpf(auto_frequency, tap_max, splat_tap_energy)
		gesture_frequency = lerpf(auto_frequency, boosted_frequency, splat_tap_blend)
		if not splat_wiggle_auto_full_state_enabled:
			# Sin automático continuo, las pulsaciones despiertan la pose
			# progresivamente, conservando igualmente el reloj existente.
			arm_envelope = lerpf(arm_envelope, recover_fade, splat_tap_blend)
			leg_envelope = lerpf(leg_envelope, recover_fade, splat_tap_blend)
		gesture_envelope = maxf(arm_envelope, leg_envelope)
		if gesture_frequency > 0.0:
			var wave := sin(splat_tap_phase)
			arm_wiggle = Vector2(wave, -wave) * arm_envelope * splat_wiggle_arm_degrees
			leg_pitches = Vector2(-wave, wave) * leg_envelope * splat_wiggle_leg_degrees
			splat_tap_phase = fmod(splat_tap_phase + delta * TAU * gesture_frequency, TAU)
		if gesture_envelope > 0.0:
			pose_response = splat_wiggle_pose_response
	var tail_active := splat_wiggle_auto_full_state_enabled or splat_tap_blend > 0.001
	if arms_enabled and splat_tail_sway_enabled and tail_active and gesture_frequency > 0.0:
		var tail_frequency := clampf(gesture_frequency * splat_tail_sway_frequency_multiplier, 0.0, maxf(0.0, splat_tail_sway_max_hz))
		if tail_frequency > 0.0:
			tail_sway = sin(splat_tail_sway_phase) * gesture_envelope * splat_tail_sway_degrees
			splat_tail_sway_phase = fmod(splat_tail_sway_phase + delta * TAU * tail_frequency, TAU)
	var upper_motion := Vector2.ZERO
	if gesture_frequency > 0.0:
		# Relojes independientes para que cabeza y torso no vibren tan rápido
		# como las patas ni salten de fase al acelerar con las pulsaciones.
		var head_frequency := clampf(gesture_frequency * splat_head_shake_frequency_multiplier, 0.0, maxf(0.0, splat_head_shake_max_hz))
		splat_head_shake_phase = fmod(splat_head_shake_phase + delta * TAU * head_frequency, TAU)
		splat_torso_sway_phase = fmod(splat_torso_sway_phase + delta * TAU * gesture_frequency * splat_torso_sway_frequency_multiplier, TAU)
		if splat_head_shake_enabled and head_frequency > 0.0:
			upper_motion.x = sin(splat_head_shake_phase) * gesture_envelope * splat_head_shake_degrees
		if splat_torso_sway_enabled:
			upper_motion.y = sin(splat_torso_sway_phase) * gesture_envelope * splat_torso_sway_degrees
	if support_weight > 0.0:
		pose_response = maxf(pose_response, splat_support_pose_response)
	var support_pitch := rad_to_deg(body_pitch) + splat_support_arm_pitch_offset_degrees
	actor.model.update_splat_pose(weight, splat_arm_spread_degrees, splat_leg_spread_degrees, splat_head_pitch_degrees, pose_response, arm_pitches, leg_pitches, support_weight, splat_support_arm_spread_degrees, support_pitch, arm_wiggle, upper_motion, tail_sway)


func _tick_recoil(delta: float) -> void:
	locomotion_state = "glide_recoil"
	actor.animation_state = locomotion_state
	was_glide_landing = false
	var duration := actor.glide_recoil_state_duration
	var compress_time := minf(recoil_compress_duration, duration)
	var recover_time := minf(recoil_recover_duration, maxf(0.001, duration - compress_time))
	var elapsed := actor.glide_recoil_elapsed
	var weight := smoothstep(0.0, compress_time, elapsed) * (1.0 - smoothstep(duration - recover_time, duration, elapsed))
	if not recoil_pose_enabled:
		weight = 0.0
	var blend := 1.0 - exp(-recoil_pose_response * delta)
	body_pitch = lerp_angle(body_pitch, deg_to_rad(recoil_body_pitch_degrees) * weight, blend)
	body_roll = lerp_angle(body_roll, 0.0, blend)
	body_bank = lerp_angle(body_bank, 0.0, blend)
	actor.model.set_body_tilt(body_pitch, body_roll, body_bank)
	actor.model.position = actor.model.position.lerp(Vector3.ZERO, blend)
	var squash := recoil_squash * weight
	actor.model.scale = actor.model.scale.lerp(Vector3(1.0 + squash * 0.4, 1.0 - squash, 1.0 + squash * 0.4), blend)
	actor.model.update_recoil_pose(weight, recoil_arm_lift_degrees, recoil_arm_tuck_degrees, recoil_leg_tuck_degrees, recoil_body_drop, recoil_head_retract, recoil_head_pitch_degrees, recoil_pose_response)


func _tick_air_pose(delta: float, grounded: bool) -> void:
	var airborne := not grounded and not actor.is_gliding and not actor.is_climbing
	var compression := 0.0
	if airborne:
		air_elapsed += delta
		landing_elapsed = -1.0
	else:
		air_elapsed = 0.0
	if actor.is_gliding or actor.is_climbing or actor.is_sliding:
		landing_elapsed = -1.0
	if landing_elapsed >= 0.0:
		landing_elapsed += delta
		if landing_elapsed < landing_compress_time:
			compression = smoothstep(0.0, landing_compress_time, landing_elapsed)
		else:
			compression = 1.0 - smoothstep(0.0, landing_recover_time, landing_elapsed - landing_compress_time)
		if landing_elapsed >= landing_compress_time + landing_recover_time:
			landing_elapsed = -1.0
	compression *= actor.landing_strength
	var rise_progress := 1.0 - clampf(actor.velocity.y / maxf(0.1, air_launch_speed), 0.0, 1.0)
	var fall_progress := smoothstep(0.0, air_full_fall_speed, maxf(0.0, -actor.velocity.y))
	var lift := lerpf(air_arm_start_degrees, air_arm_apex_degrees, smoothstep(0.0, 1.0, rise_progress))
	lift = lerpf(lift, air_arm_fall_degrees, fall_progress) if airborne else 0.0
	var spread := air_leg_spread_degrees * (1.0 - smoothstep(0.0, air_leg_close_duration, air_elapsed)) if airborne and actor.velocity.y > 0.0 else 0.0
	var tremor := air_tremor_degrees * fall_progress if airborne and air_tremor_frequency > 0.0 else 0.0
	var stride_target := 0.0
	if airborne:
		if air_stride_capture_pending or not air_was_airborne:
			# La intensidad y el lado quedan fijos durante este salto, aunque
			# cambie su velocidad horizontal. No existe un ciclo de piernas.
			air_stride_launch_weight = maxf(smoothstep(0.0, air_stride_full_speed, actor.horizontal_speed), actor.glide_movement_intent)
			air_stride_capture_pending = false
			air_stride_fall_weight = 0.0
			air_stride_fall_elapsed = 0.0
		air_stride_fall_elapsed = air_stride_fall_elapsed + delta if actor.velocity.y < 0.0 else 0.0
		var fall_end := maxf(air_stride_fall_start_speed + 0.01, air_stride_fall_end_speed)
		# Una caída larga no vuelve a activar la zancada al rozar una pared.
		if air_stride_fall_elapsed >= air_stride_fall_delay:
			air_stride_fall_weight = maxf(air_stride_fall_weight, smoothstep(air_stride_fall_start_speed, fall_end, maxf(0.0, -actor.velocity.y)))
		if air_stride_enabled:
			stride_target = air_stride_launch_weight * (1.0 - air_stride_fall_weight)
	else:
		air_stride_fall_weight = 0.0
		air_stride_fall_elapsed = 0.0
	air_was_airborne = airborne
	air_stride_weight = lerpf(air_stride_weight, stride_target, 1.0 - exp(-air_stride_blend_speed * delta))
	var stride := air_stride_side * air_stride_weight if airborne else 0.0
	# +X lleva el extremo del brazo hacia atrás; -X hacia delante.
	var arm_pitches := Vector2(-air_stride_arm_forward_degrees, air_stride_arm_backward_degrees) if stride >= 0.0 else Vector2(air_stride_arm_backward_degrees, -air_stride_arm_forward_degrees)
	arm_pitches *= absf(stride)
	var leg_swing := -stride * air_stride_leg_degrees
	# En el esqueleto importado el frente es +Z. Un giro +X lleva la pata
	# hacia -Z: se desplaza cada cadera en el mismo sentido de su giro.
	var leg_offsets := Vector2(-air_stride_leg_backward_offset, air_stride_leg_forward_offset) if stride >= 0.0 else Vector2(air_stride_leg_forward_offset, -air_stride_leg_backward_offset)
	leg_offsets *= absf(stride)
	var lateral_weight := 1.0 - air_stride_weight if airborne else 1.0
	lift *= lateral_weight
	spread *= lateral_weight
	if airborne and actor.velocity.y < 0.0:
		var leg_fall_progress := smoothstep(air_fall_leg_spread_delay, air_fall_leg_spread_delay + air_fall_leg_spread_duration, air_stride_fall_elapsed)
		spread += air_fall_leg_spread_degrees * leg_fall_progress * lateral_weight
	tremor *= lateral_weight
	var arm_inset := air_arm_inset * smoothstep(0.0, air_arm_inset_full_angle, maxf(absf(lift), maxf(absf(arm_pitches.x), absf(arm_pitches.y))))
	var stride_amount := absf(stride)
	var torso_lean := air_stride_torso_lean_degrees * stride_amount
	var head_forward := air_stride_head_forward_offset * stride_amount
	actor.model.update_air_pose(airborne, air_pose_enabled, lift, spread, tremor, air_tremor_frequency, compression, landing_body_drop, landing_head_retract, landing_head_pitch_degrees, air_pose_response, arm_inset, Vector2(0.0, leg_swing), leg_offsets, torso_lean, head_forward, landing_locomotion_response, arm_pitches)
