class_name ExplorerPlayer
extends CharacterBody3D

signal feedback(kind: String)
signal respawned
signal gliding_changed(active: bool)

@export_group("Mirada al interactuar")
## Orienta el modelo hacia el interlocutor al iniciar una conversación, sin cambiar velocidad, controles, postura ni cámara. Apagar conserva su orientación normal. Se consulta al iniciar la interacción.
@export var interaction_facing_enabled := true
## Segundos de seguimiento inicial fuera de un diálogo; 0 completa sólo el giro gradual solicitado. El giro siempre puede terminar aunque este tiempo expire. Durante una conversación mantiene la mirada hasta cerrar. Mayor prolonga el seguimiento; no pausa física ni animaciones. Se captura al iniciar.
@export_range(0.0, 2.0, 0.05, "suffix:s") var interaction_facing_duration := 0.35
## Velocidad máxima del giro hacia el interlocutor, en grados por segundo. Menor produce un giro más lento y suave; mayor gira más rápido. 240 tarda 0,75 s en dar media vuelta. Ambos actores usan su propio ajuste; se actualiza en vivo sin mover su posición ni girar la cámara.
@export_range(1.0, 1080.0, 1.0, "suffix:°/s") var interaction_facing_speed_degrees := 240.0

var _interaction_partner: WeakRef
var _interaction_facing_left := 0.0
var _interaction_turn_pending := false
var _dialogue_owners: Dictionary = {}

func is_in_dialogue() -> bool:
	return not _dialogue_owners.is_empty()

func begin_dialogue(owner: Node) -> void:
	_dialogue_owners[owner.get_instance_id()] = true
	velocity.x = 0.0
	velocity.z = 0.0
	horizontal_speed = 0.0
	previous_motion = Vector3.ZERO
	motion_acceleration = Vector3.ZERO
	consume_interaction_press()

func end_dialogue(owner: Node) -> void:
	_dialogue_owners.erase(owner.get_instance_id())
	if not is_in_dialogue():
		_interaction_turn_pending = false
		_interaction_facing_left = 0.0
		_interaction_partner = null
	# La pulsación que cierra el globo tampoco debe producir un salto.
	consume_interaction_press()
	input_grace = 0.16

var _snow_step_side := -1.0

@export_group("Audio de pasos")
## Volumen general de pasos en dB: caminar, correr y Mantle Surface Assist, incluida nieve. -14 conserva la mezcla anterior; -10 aumenta 4 dB. La nieve conserva su mezcla local y recibe esa diferencia. Mayor suena más; no afecta trepa normal ni aterrizajes. Se guarda con la escena y se consulta en vivo para nuevos pasos.
@export_range(-60.0, 6.0, 0.5, "suffix:dB") var step_volume_db := -14.0
## Ganancia adicional en dB al correr con pasos genéricos. 3 conserva el refuerzo actual; 0 iguala caminar y correr. La nieve usa SnowStepAudio > Mezcla > Run Gain Db. Se guarda con la escena y responde en vivo; se suma a Step Volume Db y a SFX/Master.
@export_range(0.0, 12.0, 0.5, "suffix:dB") var running_step_gain_db := 3.0
@export_group("Audio de reacciones")
## Definición del salto: muestra, volumen en dB, tono, prioridad y límite de voces. Editar el recurso afecta nuevos saltos en vivo. Hacer único para personalizar sólo esta escena; SFX/Master siguen aplicándose.
@export var jump_sound: TrailSoundCue = preload("res://resources/audio/player_jump.tres")
## Definición compartida por choque de pared y splat. Editar el recurso afecta nuevos impactos en vivo; desactivar Enabled silencia ambas reacciones. Hacer único para separar ajustes por escena.
@export var hurt_sound: TrailSoundCue = preload("res://resources/audio/player_hurt.tres")
@export_group("Splat por caída")
## Activa pansazo y bloqueo temporal de movimiento al aterrizar fuerte. Desactivar durante el estado permite recuperarse inmediatamente. En vivo.
@export var splat_enabled := true
## Desnivel mínimo desde el punto más alto en el aire hasta el apoyo, en metros. Mayor reserva splat para caídas más altas. Requiere también Min Impact Speed; planeo lento no produce splat. En vivo.
@export_range(0.5, 50.0, 0.5, "suffix:m") var splat_min_fall_height := 6.0
## Velocidad vertical descendente mínima antes del impacto, en m/s. Mayor exige un golpe más fuerte; debe superar la velocidad de un salto normal. Requiere Min Fall Height. En vivo.
@export_range(1.0, 60.0, 0.5, "suffix:m/s") var splat_min_impact_speed := 18.0
## Segundos totales mínimos de pansazo y recuperación; con Height Duration Enabled apagado es la duración fija. Mayor prolonga el aturdimiento. Conserva los ajustes existentes. Se captura al aterrizar; la pose limita sus transiciones al tiempo calculado.
@export_range(0.2, 4.0, 0.05, "suffix:s") var splat_duration := 1.25
## Aumenta linealmente la duración con el desnivel de caída: Duration al alcanzar Min Fall Height y Max Duration en Full Duration Height. Apagar recupera duración fija. Se consulta en cada nuevo impacto, sin alterar un splat en curso.
@export var splat_height_duration_enabled := true
## Segundos máximos totales para caídas altas. Mayor prolonga la pausa máxima; nunca se usa menos que Duration aunque se configure un valor inferior. Requiere Height Duration Enabled. Se captura al impactar.
@export_range(0.2, 10.0, 0.05, "suffix:s") var splat_max_duration := 4.0
## Desnivel en metros que alcanza Max Duration; caídas mayores conservan ese límite. Mayor reparte el aumento entre más metros. Debe superar Min Fall Height; se limita internamente a ese mínimo más 0,01 m. Requiere Height Duration Enabled. Se captura al impactar.
@export_range(0.5, 150.0, 0.5, "or_greater", "suffix:m") var splat_full_duration_height := 20.0
## Fracción de velocidad horizontal conservada al impactar. 0 se detiene; mayor desliza brevemente durante el pansazo sin permitir dirigirlo. Se captura al aterrizar.
@export_range(0.0, 1.0, 0.01) var splat_speed_retention := 0.0
## Frenado del deslizamiento residual, en m/s². Mayor detiene antes; sin efecto con Speed Retention 0. En vivo.
@export_range(0.0, 80.0, 0.5, "suffix:m/s²") var splat_braking := 20.0
@export_group("Ground movement")
## Velocidad normal máxima sobre el suelo, en unidades por segundo; no cambia el ritmo visual por sí sola.
## Ejemplo: 4 permite explorar despacio; 6 recorre más terreno. Sprint Speed debe ser mayor para notar la carrera rápida.
@export_range(0.1, 20.0) var walk_speed := 5.6
## Velocidad máxima al mantener Shift o L1 y moverse, en unidades por segundo.
## Ejemplo: 7 da un sprint moderado; 10 uno más rápido. Las patas adaptan su ritmo a la velocidad real.
@export_range(0.1, 25.0) var sprint_speed := 8.0
@export_group("Animación del modelo artesanal")
## Rapidez del ciclo Run cuando el personaje camina. No modifica el movimiento ni la distancia recorrida.
@export_range(0.1, 3.0, 0.01) var walk_member_animation_speed := 0.72
## Rapidez del ciclo RunFast al mantener sprint. No modifica la velocidad física del personaje.
@export_range(0.1, 3.0, 0.01) var run_member_animation_speed := 1.35
@export_group("Ground movement")
## Rapidez para alcanzar la velocidad deseada en el suelo, en unidades/s². La entrada empieza a actuar de inmediato.
## Ejemplo: 20 tarda aproximadamente 0,28 s en alcanzar 5,6 desde reposo; 40 tarda 0,14 s. Menor valor da más peso.
@export_range(1.0, 100.0) var acceleration := 32.0
## Fuerza de frenado al soltar, invertir dirección o reducir velocidad, en unidades/s². No detiene en un solo frame.
## Ejemplo: desde 5,6, un valor de 28 frena en unos 0,20 s; 56 en 0,10 s. Muy bajo puede sentirse resbaloso.
@export_range(1.0, 100.0) var deceleration := 44.0
## Rapidez del suavizado con que el cuerpo mira hacia su desplazamiento real; no es un ángulo ni controla la cámara.
## Ejemplo: 8 produce giros más lentos; 22 responde con más rapidez. No gira al mover la cámara mientras estás quieto.
@export_range(1.0, 30.0) var turn_speed := 16.0
@export_group("Jump and air")
## Impulso vertical inicial del salto, en unidades/s. Un valor mayor aumenta altura y tiempo en el aire.
## Ejemplo: con Gravity 22, 8,52 alcanza unos 1,65 de altura; 10 alcanza 2,27, sin obstáculos.
@export_range(1.0, 30.0) var jump_velocity := 8.52
## Aceleración hacia abajo, en unidades/s². Más gravedad acorta y hace más firme el salto con el mismo impulso.
## Ejemplo: con Jump Velocity 8,52, Gravity 18 alcanza unos 2,02 de altura; 28 alcanza 1,30.
@export_range(1.0, 60.0) var gravity := 22.0
## Fracción de aceleración y frenado horizontal disponible en el aire; no modifica la gravedad.
## Ejemplo: 0 conserva la inercia horizontal sin dirigirla; 0,5 permite correcciones moderadas; 1 responde como en tierra.
@export_range(0.0, 1.0) var air_control := 0.52
## Segundos de tolerancia para saltar después de abandonar un borde. No permite un segundo salto.
## Ejemplo: 0,10 acepta un salto pulsado 100 ms tarde; 0 exige tener apoyo. No cambia la animación.
@export_range(0.0, 0.3) var coyote_time := 0.10
## Segundos durante los que se recuerda una pulsación anticipada de salto para ejecutarla al obtener apoyo.
## Ejemplo: 0,12 acepta pulsar hasta 120 ms antes de aterrizar. Mantener el botón no repite saltos. Usa un valor positivo: 0 desactiva la solicitud en este controlador.
@export_range(0.0, 0.3) var jump_buffer := 0.12
## Velocidad descendente mínima que activa la reacción de aterrizaje, en unidades/s; no mide altura ni limita el control.
## Ejemplo: 2 reacciona a caídas pequeñas; 5 ignora impactos suaves. Mantén Hard Landing Speed por encima.
@export_range(0.1, 15.0) var landing_threshold := 2.5
## Velocidad de impacto que alcanza la intensidad máxima de compresión al aterrizar, en unidades/s; no causa daño.
## Ejemplo: 12 alcanza la reacción fuerte antes; 24 la reserva para caídas mayores. La amplitud se ajusta con Landing Squash en Animation.
@export_range(5.0, 40.0) var hard_landing_speed := 18.0
@export_group("Ground contact")
## Distancia de búsqueda de suelo para conservar contacto al bajar por pendientes y pequeñas irregularidades.
## Ejemplo: 0,20 sigue desniveles pequeños; 0,45 tolera más cambios. Demasiado alto puede pegar al personaje a bordes. Se aplica al iniciar la escena.
@export_range(0.05, 0.8) var snap_distance := 0.35
## Inclinación máxima caminable, en grados desde el suelo horizontal. Las pendientes superiores con apoyo válido activan deslizamiento.
## Ejemplo: 40 vuelve resbaladizas más laderas; 55 permite subir laderas mayores. Responde también al cambiarlo en Remote durante el juego.
@export_range(10.0, 85.0) var walkable_slope_degrees := 48.0:
	set(value):
		walkable_slope_degrees = value
		floor_max_angle = deg_to_rad(value)
@export_group("Deslizamiento en pendientes")
## Aceleración cuesta abajo en pendientes no caminables, en m/s². 4 hace gradual el resbalamiento; 10 alcanza antes Slide Max Speed. No afecta caminar ni trepar. Se guarda con la escena y se consulta en vivo.
@export_range(0.1, 50.0, 0.1, "suffix:m/s²") var slide_acceleration := 7.0
## Límite de velocidad tangencial al resbalar, en unidades/s, incluyendo dirección lateral.
## Ejemplo: 2 baja despacio; 4 es más rápido. No cambia Walk Speed ni Sprint Speed.
@export_range(0.0, 25.0, 0.1, "suffix:m/s") var slide_max_speed := 3.0
## Intensidad del control lateral mientras resbala, como fracción de Walk Speed. No permite forzar la subida.
## Ejemplo: 0 no permite dirigir de lado; 0,2 da una corrección leve; 0,4 ofrece más control.
@export_range(0.0, 0.5) var slide_steering := 0.2
## Activa el mismo polvo de carrera al resbalar por pendientes sin trepar, sin exigir Sprint. Requiere Movement Dust Enabled. Comparte tamaño, color, densidad y ajustes de superficie de Polvo de movimiento. Se consulta en vivo.
@export var slide_dust_enabled := true
## Velocidad tangencial mínima de resbalamiento para emitir polvo, en m/s. Mayor evita polvo al deslizar muy despacio; menor lo muestra antes. No cambia la velocidad física y no usa el umbral de carrera. Se guarda con la escena y se consulta en vivo.
@export_range(0.0, 10.0, 0.05, "suffix:m/s") var slide_dust_min_speed := 0.3
@export_group("Planeo")
## Permite desplegar membranas al pulsar Brincar una vez que la ardilla ya está en el aire.
## Mantener Brincar desde el salto no activa el planeo; al soltarlo, las membranas se recogen inmediatamente.
@export var glide_enabled := true
@export_group("Choque de planeo")
## Activa recoil al contactar paredes planeando. Desactivar conserva la colisión física normal. Se consulta en vivo.
@export var glide_recoil_enabled := true
## Ángulo máximo entre avance horizontal y dirección hacia la pared, en grados. 0 sólo frontal; 65 incluye impactos oblicuos; 90 incluye roces. En vivo.
@export_range(0.0, 90.0, 0.5, "suffix:°") var glide_recoil_max_angle_degrees := 65.0
## Inclinación mínima desde suelo horizontal, en grados. Mayor reserva recoil para paredes más verticales; siempre excluye suelo caminable. En vivo.
@export_range(45.0, 90.0, 0.5, "suffix:°") var glide_recoil_min_wall_slope_degrees := 65.0
## Velocidad horizontal mínima previa al contacto, en m/s. Mayor ignora golpes lentos. En vivo.
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var glide_recoil_min_speed := 1.5
## Anticipación de la cápsula hacia el avance, en metros. 0 exige contacto real; mayor cierra antes la pose para evitar intersección visual. Una consulta física extra al planear; no mide cada vértice. En vivo.
@export_range(0.0, 0.8, 0.01, "suffix:m") var glide_recoil_probe_distance := 0.18
## Segundos de contracción antes de caer. Mayor prolonga reacción y bloqueo de planeo/escalada. Se captura al chocar.
@export_range(0.08, 1.5, 0.01, "suffix:s") var glide_recoil_duration := 0.38
## Retroceso horizontal alejándose de la pared, en m/s. Mayor separa más; 0 cae junto a ella. Se captura al chocar.
@export_range(0.0, 10.0, 0.1, "suffix:m/s") var glide_recoil_push_speed := 2.5
## Fracción de inercia lateral conservada. Mayor desliza más por la pared; 0 sólo conserva retroceso. Se captura al chocar.
@export_range(0.0, 1.0, 0.01) var glide_recoil_tangent_retention := 0.2
## Multiplicador de gravedad durante recoil. 0 suspende brevemente; 1 usa gravedad normal. Al terminar recupera gravedad normal. En vivo.
@export_range(0.0, 2.0, 0.05) var glide_recoil_gravity_scale := 0.0
## Frenado horizontal durante recoil, en m/s². Mayor acorta retroceso. Sin dirección hasta terminar el estado. En vivo.
@export_range(0.0, 40.0, 0.5, "suffix:m/s²") var glide_recoil_braking := 4.0
@export_group("Aterrizaje de planeo")
## Conserva brevemente la postura Glide al tocar suelo caminable y desliza con la inercia de llegada. Se actualiza en vivo; desactivarlo termina el deslizamiento actual.
@export var glide_landing_enabled := true
## Orienta la pose de aterrizaje según la normal del suelo, tanto longitudinal como lateralmente. No modifica la cápsula ni la física. Se combina con la transición de pose existente; desactivar recupera la orientación horizontal. Se guarda con la escena y responde en vivo.
@export var glide_landing_surface_follow_enabled := true
## Intensidad de adaptación a pendientes: 0 conserva la pose horizontal, 1 sigue completamente el plano hasta Max Tilt. Mayor reduce cruces con la ladera. Se consulta en vivo.
@export_range(0.0, 1.0, 0.01) var glide_landing_surface_follow_strength := 1.0
## Rapidez de adaptación visual al suelo, en s⁻¹. Mayor sigue antes las irregularidades; menor suaviza, pero puede atravesar temporalmente pendientes. En vivo; no altera Pose Delay ni Blend Duration.
@export_range(1.0, 40.0, 0.5) var glide_landing_surface_follow_response := 18.0
## Inclinación máxima añadida por el plano de suelo, en grados. Mayor permite acompañar pendientes más fuertes; menor limita inclinaciones visuales extremas. Sólo aterrizaje de planeo; en vivo.
@export_range(0.0, 85.0, 0.5, "suffix:°") var glide_landing_surface_max_tilt_degrees := 55.0
## Elevación visual máxima adicional permitida al corregir intersecciones en pendiente, en metros. Requiere Clearance Enabled y Surface Follow Enabled; 0 desactiva esta ampliación. No cambia el máximo de suelo plano ni Belly Sink. Mayor separa más si la malla cruza el plano. En vivo; usa límites de mallas, no colisión exacta.
@export_range(0.0, 1.0, 0.01, "suffix:m") var glide_landing_slope_clearance_max_lift := 0.3
## Segundos máximos de postura y deslizamiento tras aterrizar planeando. Mayor valor prolonga el efecto; 0 lo desactiva. Se consulta al aterrizar. Saltar o perder el suelo lo cancela.
@export_range(0.0, 1.5, 0.01, "suffix:s") var glide_landing_duration := 0.35
## Segundos conservando la inclinación de llegada antes de adoptar la de aterrizaje. Mayor valor retrasa el cambio visual; la física y el polvo empiezan al tocar suelo. Se actualiza en vivo.
@export_range(0.0, 0.5, 0.01, "suffix:s") var glide_landing_pose_delay := 0.06
## Segundos de transición suave hacia la inclinación normal de Glide después de Pose Delay. Mayor valor suaviza más; si supera Duration la transición puede quedar incompleta. Se actualiza en vivo.
@export_range(0.01, 1.0, 0.01, "suffix:s") var glide_landing_pose_blend_duration := 0.16
## Segundos de pérdida de contacto tolerados antes de abandonar el aterrizaje. Evita cambios de estado por pequeñas irregularidades; la gravedad sigue actuando sin apoyo. 0 cancela inmediatamente. Se actualiza en vivo.
@export_range(0.0, 0.2, 0.01, "suffix:s") var glide_landing_contact_grace := 0.06
## Fracción de velocidad horizontal conservada al aterrizar. Mayor valor desliza más lejos; 0 conserva sólo la postura. Se consulta al aterrizar.
@export_range(0.0, 1.0, 0.01) var glide_landing_speed_retention := 0.8
## Frenado durante el deslizamiento en m/s². Mayor valor lo detiene antes; no modifica la duración de la pose. Se actualiza en vivo. Las colisiones y pendientes siguen siendo físicas.
@export_range(0.0, 60.0, 0.5, "suffix:m/s²") var glide_landing_braking := 10.0
## Evita que las cajas visuales de torso y cabeza atraviesen el plano del suelo durante el aterrizaje de Glide. Eleva sólo el modelo, sin cambiar la cápsula. Se actualiza en vivo; es una aproximación conservadora para piezas rígidas, no colisión exacta de malla.
@export var glide_landing_clearance_enabled := true
## Separación mínima entre torso/cabeza y el plano de apoyo, en metros. Mayor valor deja más espacio; 0 permite contacto. Se actualiza en vivo.
@export_range(0.0, 0.15, 0.005, "suffix:m") var glide_landing_clearance_margin := 0.0
## Profundidad visual permitida para la panza, en metros, restada del Clearance Margin sólo para el torso. Mayor valor permite hundir más la panza; 0 conserva el margen anterior. La cabeza mantiene su protección. Requiere Clearance Enabled y se actualiza en vivo.
@export_range(0.0, 1.0, 0.005, "or_greater", "suffix:m") var glide_landing_belly_sink := 0.25
## Elevación visual máxima permitida para evitar penetración, en metros. Mayor valor admite correcciones mayores pero puede hacer flotar al personaje. Se actualiza en vivo; si se alcanza el límite aún puede existir penetración.
@export_range(0.0, 1.0, 0.01, "suffix:m") var glide_landing_clearance_max_lift := 0.0
## Rapidez por segundo de retorno de la elevación visual al terminar el roce. Mayor valor recupera antes la altura normal. Se actualiza en vivo; la corrección hacia arriba es inmediata para evitar penetración.
@export_range(1.0, 40.0, 0.5) var glide_landing_clearance_recovery := 12.0
## Emite el mismo polvo de carrera durante el deslizamiento. Requiere Polvo de movimiento > Movement Dust Enabled. Se actualiza en vivo.
@export var glide_landing_dust_enabled := true
## Centro local del polvo respecto al jugador, en metros. X desplaza a un lado, Y eleva y +Z queda detrás. Se actualiza en vivo, independiente de la fuente de carrera.
@export var glide_landing_dust_source_offset := Vector3(0.0, 0.1, 0.0)
## Anchura total de emisión en X, en metros. Mayor valor reparte el polvo bajo ambos lados del cuerpo en lugar de un punto. Se actualiza en vivo para nuevas partículas.
@export_range(0.0, 3.0, 0.01, "suffix:m") var glide_landing_dust_width := 0.9
## Profundidad total de emisión en Z, en metros. Mayor valor reparte el polvo a lo largo del contacto con suelo. Se actualiza en vivo para nuevas partículas.
@export_range(0.0, 2.0, 0.01, "suffix:m") var glide_landing_dust_depth := 0.25
## Altura total de emisión en metros desde Source Offset. Mayor valor eleva la nube al nacer. Se actualiza en vivo para nuevas partículas.
@export_range(0.0, 1.0, 0.01, "suffix:m") var glide_landing_dust_height := 0.05
## Densidad nominal del polvo de aterrizaje. Mayor valor emite más bolas; comparte la capacidad reservada del emisor de carrera, sin crear otro sistema. Se actualiza en vivo.
@export_range(1, 96, 1) var glide_landing_dust_density := 48
## Multiplicador del tamaño inicial y final del polvo de carrera durante este aterrizaje. Mayor valor crea bolas más grandes. Se actualiza en vivo.
@export_range(0.1, 2.0, 0.05) var glide_landing_dust_size_multiplier := 0.8
@export_group("Polvo de movimiento")
## Activa el polvo de Sprint y el de aterrizaje de planeo (si su opción Dust Enabled también está activa). Al detenerse, las bolas existentes terminan su vida. Se actualiza en vivo.
@export var movement_dust_enabled := true
## Ajusta fuente y dirección de nuevas partículas al plano del suelo real, tanto en carrera como al aterrizar planeando. Evita emitir detrás de la ardilla dentro de una pendiente al bajar. Desactivar recupera la fuente horizontal anterior. En vivo; no mueve partículas ya emitidas ni modifica colisiones.
@export var movement_dust_surface_follow_enabled := true
## Separación adicional del centro de emisión respecto al suelo, en metros, sumada a Source Offset Y. Mayor reduce enterramiento; demasiado alto hace flotar la fuente. Sigue la normal local. En vivo; no garantiza que bolas grandes no intersecten la superficie.
@export_range(0.0, 0.5, 0.005, "suffix:m") var movement_dust_surface_clearance := 0.03
## Alcance en cada dirección de la consulta de suelo bajo la fuente, en metros. Mayor cubre cambios de relieve más fuertes; menor evita encontrar superficies lejanas. Una consulta física por frame mientras emite, independiente de la cantidad de partículas. Si falla usa el plano bajo los pies. En vivo.
@export_range(0.1, 3.0, 0.05, "suffix:m") var movement_dust_surface_probe_distance := 1.0
## Velocidad inicial alejándose del suelo en m/s, además de Drift Speed tangente a la pendiente. Mayor mantiene la estela fuera del relieve; 0 sólo sigue la pendiente. Requiere Surface Follow Enabled. En vivo para nuevas partículas; Spread alto aún puede dirigir algunas hacia el suelo.
@export_range(0.0, 4.0, 0.05, "suffix:m/s") var movement_dust_surface_lift_speed := 0.6
## Velocidad horizontal mínima, en metros por segundo, para emitir mientras mantienes Sprint sobre suelo caminable. Reducirlo permite emitir antes al acelerar. Se actualiza en vivo.
@export_range(0.1, 20.0, 0.1, "suffix:m/s") var movement_dust_run_speed := 5.6
## Densidad nominal de partículas por ciclo de vida. Mayor valor produce una nube más tupida; el emisor reserva 288 partículas para cambiar densidad sin reinicios. Se actualiza en vivo.
@export_range(1, 96, 1) var movement_dust_density := 96
## Duración de cada bola, en segundos. Mayor valor alarga la estela; con Density fijo también reduce la frecuencia de emisión. Se actualiza en vivo.
@export_range(0.1, 3.0, 0.05, "suffix:s") var movement_dust_lifetime := 1.2
## Diámetro inicial mínimo en metros, antes de la variación de forma. Cada bola elige entre Size Min y Max; no depende del tamaño final. Se actualiza en vivo.
@export_range(0.01, 2.0, 0.01, "suffix:m") var movement_dust_size_min := 0.07
## Diámetro inicial máximo en metros. Bájalo para que las bolas nazcan pequeñas; sus proporciones dependen de Shape Variation. Se actualiza en vivo.
@export_range(0.01, 2.0, 0.01, "suffix:m") var movement_dust_size_max := 0.33
## Diámetro final mínimo en metros, independiente del inicial. Cada bola interpola suavemente entre su diámetro inicial y el final. Se actualiza en vivo.
@export_range(0.01, 4.0, 0.01, "suffix:m") var movement_dust_final_size_min := 0.88
## Diámetro final máximo en metros. Subirlo forma una nube mayor antes de desaparecer, sin cambiar el tamaño al nacer. Se actualiza en vivo.
@export_range(0.01, 4.0, 0.01, "suffix:m") var movement_dust_final_size_max := 1.31
## Opacidad inicial de las bocanadas, de 0 invisible a 1 sólida. Se desvanece automáticamente durante su vida. Se actualiza en vivo.
@export_range(0.0, 1.0, 0.01) var movement_dust_opacity := 1.0
## Color de la zona iluminada de las bolas. Se combina con Shadow Color para un sombreado caricaturesco independiente de las luces de escena. Se actualiza en vivo.
@export var movement_dust_light_color := Color(0.98039216, 0.98039216, 0.92156863, 1.0)
## Color de la banda en sombra sobre las bolas (no una sombra proyectada al suelo). Más oscuro aumenta el contraste. Se actualiza en vivo.
@export var movement_dust_shadow_color := Color(0.790625, 0.790625, 0.7431875, 1.0)
## Intensidad de la sombra caricaturesca: 0 usa sólo Light Color, 1 usa Shadow Color completo. Se actualiza en vivo.
@export_range(0.0, 1.0, 0.01) var movement_dust_shadow_strength := 1.0
## Umbral de la banda de sombra: subirlo aumenta la parte sombreada de la bola. Se actualiza en vivo.
@export_range(-1.0, 1.0, 0.01) var movement_dust_shadow_threshold := 0.55
## Suavidad del borde de la sombra: 0 da dos tonos con borde duro; valores mayores suavizan la transición. Se actualiza en vivo.
@export_range(0.0, 0.5, 0.01) var movement_dust_shadow_softness := 0.0
## Dirección hacia la luz artística en ejes del mundo. Y positivo ilumina desde arriba. No crea una luz real; vector cero usa arriba. Se actualiza en vivo.
@export var movement_dust_light_direction := Vector3(-0.4, 1.0, 0.3)
## Fracción de vida que permanece completamente sólida antes de empezar a desvanecerse. 0,2 conserva el primer 20 %; mayor valor retrasa la desaparición. Se actualiza en vivo.
@export_range(0.0, 0.9, 0.01) var movement_dust_fade_start := 0.2
## Variación de proporciones entre bolas: 0 mantiene esferas; 1 permite hasta un 30 % de estiramiento o achatamiento por eje. Cada forma queda fija al nacer; no gira. Se actualiza en vivo.
@export_range(0.0, 1.0, 0.01) var movement_dust_shape_variation := 0.55
## Variación aleatoria de duración: 0 conserva Lifetime; 0,25 permite bolas hasta un 25 % más breves. Rompe el ritmo uniforme de desaparición. Afecta nuevas partículas en vivo.
@export_range(0.0, 0.75, 0.01) var movement_dust_lifetime_randomness := 0.2
## Velocidad, en metros por segundo, con la que las bocanadas se alejan detrás de la ardilla. Mayor valor estira visualmente la estela. Se actualiza en vivo.
@export_range(0.0, 8.0, 0.1, "suffix:m/s") var movement_dust_drift_speed := 2.4
## Desplazamiento local de la única fuente de polvo respecto al centro del personaje, en metros. +Z queda detrás de la ardilla; ajusta Y para mantenerla sobre el suelo. No mueve el modelo ni la colisión. Se actualiza en vivo.
@export var movement_dust_source_offset := Vector3(0.0, 0.1, 0.555)
## Apertura angular de la nube detrás del personaje. 0 concentra las bolitas; valores mayores las dispersan lateralmente. Se actualiza en vivo.
@export_range(0.0, 90.0, 1.0, "suffix:°") var movement_dust_spread_degrees := 10.0
## Anchura total en metros de la única fuente. Distribuye al azar las bolas hacia izquierda y derecha al nacer, independientemente de Drift Speed y sin dispersarlas en Z. 0 concentra en el centro. Afecta nuevas partículas en vivo.
@export_range(0.0, 2.0, 0.01, "suffix:m") var movement_dust_scatter_width := 0.2
## Altura total en metros de la fuente, desde Source Offset hacia arriba. Las bolas nacen a alturas aleatorias para romper la línea recta sin aumentar la separación longitudinal. Afecta nuevas partículas en vivo.
@export_range(0.0, 2.0, 0.01, "suffix:m") var movement_dust_scatter_height := 0.08
## Aceleración ascendente de las bolas en m/s², independiente de Drift Speed. 0 elimina flotación; mayor valor eleva la nube durante su vida. Se actualiza en vivo.
@export_range(0.0, 3.0, 0.05, "suffix:m/s²") var movement_dust_rise_acceleration := 0.3
@export_group("Audio del planeo")
## Volumen de deploy: 0 = silencio, 1 = original, 2 = doble amplitud.
## Se combina con Sonidos y Volumen general del menú de ajustes.
@export_range(0.0, 2.0, 0.01) var deploy_volume := 1.0
## Pitch de deploy: 1 = original, 0,5 = más grave, 2 = más agudo.
## También cambia la velocidad y duración de reproducción.
@export_range(0.25, 4.0, 0.01) var deploy_pitch := 1.0
## Volumen objetivo de los fades: 0 = silencio, 1 = original, 2 = doble amplitud.
## Se combina con Sonidos y Volumen general del menú de ajustes.
@export_range(0.0, 2.0, 0.01) var gliding_volume := 1.0
## Pitch del bucle: 1 = original. Valores menores lo hacen más grave y lento.
## No modifica la duración configurada de los fades.
@export_range(0.25, 4.0, 0.01) var gliding_pitch := 1.0
## Empieza cada planeo en un punto aleatorio de gliding; conserva el fade in.
## También elige un punto aleatorio para cada repetición con solapamiento.
@export var gliding_random_start := true
## Segundos de solapamiento: la siguiente voz entra mientras la anterior se apaga.
## Se limita automáticamente para dejar suficiente audio con el pitch elegido.
@export_range(0.05, 5.0, 0.01, "suffix:s") var gliding_loop_crossfade := 0.6
## Segundos desde la entrada en Glide hasta deploy. 0 lo reproduce inmediatamente.
## Si termina el planeo antes del retraso, se cancela el sonido pendiente.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var deploy_delay := 0.0
## Segundos para subir gliding desde silencio hasta Gliding Volume.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var gliding_fade_in := 0.3
## Segundos para bajar gliding hasta silencio al terminar el planeo.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var gliding_fade_out := 0.4
@export_group("Planeo")
## Límite de caída durante planeo, en unidades/s. Nunca añade impulso hacia arriba.
## Ejemplo: 2 prolonga el descenso; 4 baja más rápido. No cambia el salto normal.
@export_range(1.0, 8.0) var glide_fall_speed := 2.6
## Fracción de gravedad durante el descenso planeando; la subida mantiene gravedad normal.
## Ejemplo: 0,25 entra suavemente en el descenso; 0,5 alcanza antes su límite de caída.
@export_range(0.1, 1.0) var glide_gravity_scale := 0.3
## Frenado vertical al desplegar durante una caída rápida, en unidades/s².
## Ejemplo: 18 frena progresivamente; 35 estabiliza antes, sin detenerse en seco.
@export_range(5.0, 60.0) var glide_braking := 30.0
## Control horizontal y de rumbo físico mientras planea.
## Ejemplo: 0,1 casi no permite corregir; 0,7 conserva la curvatura configurada; 1 hace que la trayectoria siga la palanca de inmediato.
@export_range(0.1, 1.0) var glide_air_control := 0.7
@export_group("Curvatura del planeo")
## Reducción adicional del control al intentar girar a mucha velocidad durante Glide.
## Ejemplo: 0 conserva el control actual; 0,35 suaviza las curvas; 1 produce curvas muy amplias a velocidad máxima.
@export_range(0.0, 1.0, 0.01) var glide_high_speed_turn_reduction := 0.35
## Máximo cambio de rumbo durante Glide, en grados por segundo.
## Ejemplo: 60 da vueltas amplias; 105 es equilibrado; 240 permite cambios de rumbo mucho más rápidos.
## Un valor menor obliga a describir curvas más amplias, incluso al mantener la dirección contraria o al comenzar desde reposo.
@export_range(10.0, 360.0, 1.0) var glide_turn_rate_degrees := 105.0
## Multiplicador del giro máximo al alcanzar la velocidad objetivo de Glide.
## Ejemplo: 1 conserva el mismo giro a cualquier velocidad; 0,55 da una trayectoria más amplia al ir rápido; 0,25 es muy pesado.
@export_range(0.1, 1.0, 0.01) var glide_high_speed_turn_rate_multiplier := 0.55
## Relación entre la orientación visual y el rumbo físico durante Glide.
## Ejemplo: 0 hace que el modelo siga solo la trayectoria; 0,35 da respuesta inmediata sin desconectarse; 1 reproduce un giro visual instantáneo.
@export_range(0.0, 1.0, 0.01) var glide_visual_turn_follow := 0.35
## Rapidez con que el modelo gira visualmente durante Glide; no cambia la trayectoria física.
## Ejemplo: 4 hace que el cuerpo acompañe con calma; 10 es fluido; 20 hace que mire al nuevo rumbo casi de inmediato.
@export_range(1.0, 30.0, 0.1) var glide_visual_turn_speed := 10.0
## Fracción de la velocidad horizontal que se conserva al describir una curva durante Glide.
## Ejemplo: 0 permite que el giro reduzca velocidad de forma normal; 0,85 se siente fluido; 1 conserva toda la velocidad al cambiar de rumbo.
@export_range(0.0, 1.0, 0.01) var glide_turn_speed_retention := 0.85
@export_group("Planeo con sprint · L1")
## Multiplica la velocidad horizontal de planeo mientras mantienes L1/Shift, además de R1 para planear.
@export_range(1.0, 2.5, 0.01) var glide_sprint_speed_multiplier := 1.15
## Aumenta el límite de caída durante el planeo rápido, en unidades/s.
@export_range(0.0, 6.0, 0.1) var glide_sprint_fall_speed_bonus := 0.8
## Gravedad adicional durante el planeo rápido. Súbela para que caiga antes.
@export_range(0.0, 1.0, 0.01) var glide_sprint_gravity_scale_bonus := 0.12

@export_group("Escalada")
## Mantener Brincar agarra roca escalable si está cerca y enfrente.
@export var climb_enabled := true
## Permite el prototipo de escalada sobre cualquier superficie empinada sin una etiqueta climbable. Activo sirve para probar rutas esculpidas en Terrain3D; desactívalo cuando haya edificios, árboles u otros objetos verticales que no deban poder treparse. Se consulta en vivo.
@export var climb_untagged_steep_surfaces_enabled := true
## Ángulo mínimo, desde suelo horizontal, que una superficie sin etiqueta debe tener para agarrarse. 65° separa las laderas resbaladizas de las paredes trepables; bajarlo permite trepar antes y subirlo exige caras más verticales. Se consulta en vivo.
@export_range(45.0, 89.0, 0.5, "suffix:°") var climb_untagged_min_slope_degrees := 65.0
## Ángulo máximo, desde suelo horizontal, de una superficie sin etiqueta que puede agarrarse. 89° admite paredes casi verticales; Terrain3D no genera caras por encima de 90°. Se consulta en vivo y debe ser igual o mayor que Untagged Min Slope Degrees.
@export_range(45.0, 89.0, 0.5, "suffix:°") var climb_untagged_max_slope_degrees := 89.0
## Metros por segundo sobre la pared. Ejemplo: 2 es pausado; 4 sube rápido.
@export_range(0.5, 8.0, 0.1) var climb_speed := 3.0
## Alcance del agarre desde el centro del cuerpo. Ejemplo: 0,9 requiere acercarse; 1,3 es permisivo.
@export_range(0.6, 1.5, 0.05) var climb_grab_distance := 1.15
## Desviación máxima mirando hacia la roca. 25 exige entrar de frente; 45 permite entradas diagonales.
@export_range(5.0, 60.0, 1.0) var climb_facing_angle_degrees := 30.0
## Distancia del centro a la pared; debe superar el radio de la cápsula (0,42).
@export_range(0.46, 0.6, 0.01) var climb_wall_distance := 0.5
## Adapta inclinación y separación a la pendiente de la superficie agarrada. Desactivado recupera la postura y distancia fijas anteriores. Se actualiza en vivo; no modifica los umbrales de agarre.
@export var climb_surface_follow_enabled := true
## Intensidad de adaptación a la pendiente: 0 conserva la postura fija y 1 sigue toda la inclinación. Afecta también la separación física en pendientes suaves. Se actualiza en vivo.
@export_range(0.0, 1.0, 0.05) var climb_surface_follow_strength := 1.0
## Rapidez por segundo de adaptación visual a cambios de inclinación. Mayor valor sigue antes los cambios; menor suaviza el paso entre triángulos. La colisión siempre usa la superficie real. Se actualiza en vivo.
@export_range(1.0, 30.0, 0.5) var climb_surface_follow_response := 10.0
## Inclinación adicional máxima para seguir la superficie, en grados. Mayor valor permite tumbar más el cuerpo sobre pendientes suaves. Body Lean se suma como ajuste artístico. Se actualiza en vivo.
@export_range(0.0, 85.0, 0.5) var climb_surface_max_lean_degrees := 80.0
## Separación objetivo de los pies al acercarse la pendiente a horizontal, en metros. Se interpola desde Climb Wall Distance de la pared vertical para no mantener la cápsula flotando sobre una ladera. Mayor valor separa más; se consulta en vivo.
@export_range(0.01, 0.15, 0.005, "suffix:m") var climb_surface_floor_distance := 0.02
## Impulso hacia fuera al soltar Brincar. Ejemplo: 2 facilita separarse y después planear.
@export_range(0.5, 5.0, 0.1) var climb_detach_speed := 2.0
@export_group("Escalada · continuidad y cima")
## Permite pendientes más suaves una vez agarrado, sin facilitar el agarre inicial. Conserva las zonas Disabled y las reglas del collider. Se consulta en vivo.
@export var climb_sustain_enabled := true
## Pendiente mínima desde horizontal para conservar un agarre existente, en grados. Menor valor permite seguir sobre la transición hacia la cima. Sólo relaja el umbral de entrada, no lo endurece. Se consulta en vivo.
@export_range(5.0, 85.0, 0.5) var climb_sustain_min_slope_degrees := 40.0
## Activa la salida asistida opcional sobre repisas, con avance y elevación automáticos. Desactivado sigue la superficie mediante el movimiento del jugador y se incorpora sólo con apoyo real. En vivo; no atraviesa colisiones.
@export var climb_mantle_enabled := false
## Usa salida automática siguiendo contactos reales en vez de la trayectoria antigua subir/avanzar/bajar. Requiere Mantle Enabled. En vivo antes de iniciar; no crea rampas ni salva huecos. Activado por defecto para la nueva salida.
@export var climb_mantle_surface_assist_enabled := true
## Reproduce los sonidos de pasos durante Surface Assist en vez de los golpes de trepa. Conserva Climb Sound Phase y la cadencia del ciclo; usa el audio de pasos de la superficie cuando existe. Desactivado silencia los contactos de la asistencia. En vivo; no cambia el sonido de trepa normal.
@export var climb_mantle_surface_steps_enabled := true
## Velocidad de avance automático sobre la superficie, en m/s. Mayor termina antes sin acelerar las vueltas de miembros. Se consulta en vivo durante la salida.
@export_range(0.1, 6.0, 0.05, "suffix:m/s") var climb_mantle_surface_speed := 1.5
## Recorrido máximo permitido de la asistencia, en metros. Mayor permite cimas más anchas; al agotarse sin apoyo firme devuelve control de trepa sin teletransportar. En vivo.
@export_range(0.2, 8.0, 0.1, "suffix:m") var climb_mantle_surface_max_distance := 3.0
## Tiempo máximo de asistencia en segundos. Evita quedarse avanzando contra una irregularidad; al agotarse devuelve control de trepa. En vivo.
@export_range(0.5, 12.0, 0.1, "suffix:s") var climb_mantle_surface_timeout := 4.0
## Presión hacia la superficie durante asistencia, en m/s. Mayor conserva contacto, pero puede frenar en esquinas. No añade elevación ni modifica la colisión. En vivo.
@export_range(0.1, 5.0, 0.1, "suffix:m/s") var climb_mantle_surface_contact_speed := 1.0
## Separación visual desde la superficie al empezar la asistencia, en metros. Negativo acerca/hunde y positivo separa. Se mezcla hasta Offset End durante la incorporación; no mueve la cápsula. En vivo.
@export_range(-0.4, 0.3, 0.005, "suffix:m") var climb_mantle_surface_offset_start := -0.11
## Separación visual al terminar la asistencia, en metros. Negativo hunde ligeramente. Se conserva como altura visual en suelo tras la salida, hasta volver al aire. En vivo; no evita penetraciones visuales.
@export_range(-0.4, 0.3, 0.005, "suffix:m") var climb_mantle_surface_offset_end := -0.11
## Pendiente máxima desde horizontal para considerar tierra firme al terminar de trepar, en grados. Menor valor exige una cima más llana; mayor permite incorporarse antes. Nunca supera Walkable Slope Degrees. Se consulta al buscar apoyo y al finalizar.
@export_range(0.0, 60.0, 0.5) var climb_finish_max_slope_degrees := 25.0
## Segundos continuos de apoyo físico en tierra firme antes de incorporarse en la salida natural. Mayor evita transiciones por contactos fugaces; menor responde antes. En vivo; pierde la confirmación si desaparece el apoyo.
@export_range(0.0, 1.0, 0.01, "suffix:s") var climb_finish_support_time := 0.12
## Segundos para recuperar la postura erguida después de confirmar apoyo. Mayor suaviza; menor incorpora antes. Sólo salida natural, sin elevar ni avanzar automáticamente la cápsula. En vivo.
@export_range(0.05, 2.0, 0.01, "suffix:s") var climb_finish_stand_duration := 0.3
## Altura visual al terminar la salida natural, en metros respecto al origen habitual. Negativo hunde el modelo sin mover su colisión; positivo lo levanta. Se mezcla durante la incorporación y se conserva mientras siga en suelo. -0.11 evita retirar de golpe el offset actual de escalada. En vivo; valores muy negativos pueden atravesar el terreno.
@export_range(-0.4, 0.2, 0.005, "suffix:m") var climb_finish_visual_height := -0.11
## Rapidez de ajuste del offset visual después de salir de escalada, en s⁻¹. Mayor responde antes; menor suaviza. Al quedar en el aire recupera altura visual normal. En vivo; no modifica la cápsula ni la física.
@export_range(1.0, 40.0, 0.5) var climb_finish_visual_response := 12.0
## Vueltas mínimas adicionales antes de incorporarse al salir. En Surface Assist avanza mientras completa estas vueltas, sujeto a Max Distance y Timeout; no garantiza avanzar más allá de esos límites. Se captura al iniciar; 0 permite incorporarse al confirmar apoyo.
@export_range(0, 6, 1) var climb_mantle_extra_cycles := 2
## Progreso de la salida (0–1) donde empieza a seguir la inclinación del suelo superior en lugar de la pared. Menor valor adapta antes. Se captura al iniciar y sólo actúa con Surface Follow Enabled.
@export_range(0.0, 0.8, 0.01) var climb_mantle_surface_blend_start := 0.1
## Progreso de la salida (0–1) donde termina la adaptación al suelo superior. Mayor valor la reparte durante más recorrido; debe superar Blend Start. Después se incorpora en el último tramo. Se captura al iniciar.
@export_range(0.05, 0.95, 0.01) var climb_mantle_surface_blend_end := 0.7
## Distancia horizontal de búsqueda de apoyo sobre el borde, en metros. Mayor valor alcanza repisas más profundas, pero requiere todo el trayecto libre. Se consulta al buscar la cima.
@export_range(0.5, 2.5, 0.05, "suffix:m") var climb_mantle_forward_reach := 1.0
## Distancia mínima de búsqueda, en metros, limitada internamente a Forward Reach si es mayor. Menor incluye apoyos cercanos. Se exploran Samples hasta Forward Reach + Search Extension. Se consulta en cada búsqueda.
@export_range(0.25, 2.5, 0.05, "suffix:m") var climb_mantle_search_min_reach := 0.5
## Distancia adicional de búsqueda más allá de Forward Reach, en metros. Mayor valor detecta apoyos más lejanos, sin omitir comprobaciones de colisión. Se consulta en cada búsqueda.
@export_range(0.0, 1.5, 0.05, "suffix:m") var climb_mantle_search_extension := 0.5
## Número de distancias donde se busca suelo. Mayor valor detecta más opciones pero cuesta más rayos y barridos de cápsula. Se consulta en cada búsqueda.
@export_range(2, 12, 1) var climb_mantle_search_samples := 5
## Segundos entre búsquedas fallidas de cima. Mayor valor reduce el coste; menor reacciona antes. Se actualiza en vivo; una búsqueda exitosa no espera más.
@export_range(0.0, 0.3, 0.01, "suffix:s") var climb_mantle_retry_interval := 0.05
## Segundos de tolerancia al perder contacto mientras busca la cima. Mantiene brevemente el avance de subida con colisiones; después suelta. 0 conserva la salida inmediata. No tolera zonas Disabled ni soltar Brincar. Se actualiza en vivo.
@export_range(0.0, 0.5, 0.01, "suffix:s") var climb_mantle_contact_grace := 0.18
## Diagnóstico de la última búsqueda/salida, visible durante el juego en Remote. Informa falta de suelo, pendiente o tramo bloqueado. Se actualiza automáticamente; editar este texto no modifica el comportamiento.
@export_multiline var climb_mantle_status := "Sin búsqueda de cima"
## Altura máxima de búsqueda del suelo superior respecto a los pies, en metros. Mayor valor admite bordes más altos. Se consulta al buscar la cima.
@export_range(0.3, 2.5, 0.05, "suffix:m") var climb_mantle_max_height := 1.4
## Profundidad de búsqueda bajo los pies, en metros. Permite encontrar suelo ligeramente más bajo al terminar la transición. Se consulta al buscar la cima.
@export_range(0.0, 1.0, 0.05, "suffix:m") var climb_mantle_max_drop := 0.3
## Altura adicional durante los tramos de subir y pasar sobre el borde, en metros. Positivo eleva, 0 no añade altura y negativo baja el trayecto. Se consulta al iniciar; si la cápsula choca, ese candidato se descarta sin atravesar el suelo.
@export_range(-0.5, 0.5, 0.005, "suffix:m") var climb_mantle_clearance := 0.08
## Separación final de los pies respecto al suelo superior, en metros. Positivo deja margen, 0 busca contacto y negativo propone un destino más bajo. Se consulta al iniciar; las colisiones pueden rechazar destinos bajo el suelo. No es un offset sólo visual.
@export_range(-0.25, 0.25, 0.005, "suffix:m") var climb_mantle_floor_margin := 0.03
## Ritmo máximo de las vueltas extra al salir a la cima, en ciclos por segundo, independiente de Climb Member Speed. Mayor valor completa antes las vueltas y reduce la sensación de trepar en el aire. Se captura al iniciar; Mantle Duration sigue fijando la duración mínima.
@export_range(0.2, 6.0, 0.1, "suffix:Hz") var climb_mantle_cycle_speed := 2.4
## Duración mínima de la subida a la cima, en segundos. Se amplía si las vueltas extra necesitan más tiempo según Mantle Cycle Speed. Mayor valor hace más pausado el recorrido. Se captura al iniciar; las colisiones siguen activas.
@export_range(0.2, 1.5, 0.01, "suffix:s") var climb_mantle_duration := 0.55
## Inclinación adicional del cuerpo hacia la superficie durante el esfuerzo de subida, en grados. 0 conserva la inclinación base de trepar. Se actualiza en vivo y vuelve a cero al incorporarse.
@export_range(0.0, 65.0, 0.5) var climb_mantle_body_lean_degrees := 35.0
## Elevación adicional de brazos durante el alcance superior, en grados. Mayor valor levanta más las manos. Se actualiza en vivo durante la salida.
@export_range(0.0, 60.0, 0.5) var climb_mantle_arm_reach_degrees := 25.0
## Elevación adicional de piernas durante el esfuerzo, en grados. Mayor valor recoge más los pies desde la cadera, sin doblar rodillas inexistentes. Se actualiza en vivo.
@export_range(0.0, 60.0, 0.5) var climb_mantle_leg_tuck_degrees := 20.0
# Ajustes anteriores conservados como datos serializados; ya no intervienen.
@export_storage var climb_member_degrees := 14.0
@export_storage var climb_sound_spacing := 0.7
@export_storage var climb_depth_enabled := true
@export_storage var climb_orbit_enabled := true
@export_storage var climb_arm_orbit_degrees := 18.0
@export_storage var climb_arm_orbit_tilt_degrees := 25.0
@export_storage var climb_leg_orbit_degrees := 10.0
@export_storage var climb_leg_orbit_tilt_degrees := 15.0
@export_storage var climb_translation_enabled := false
@export_storage var climb_arm_forward_degrees := 12.0
@export_storage var climb_arm_backward_degrees := 6.0
@export_storage var climb_arm_forward_offset := 0.025
@export_storage var climb_arm_backward_offset := 0.015
@export_storage var climb_arm_depth_phase := 0.0
@export_storage var climb_leg_forward_degrees := 8.0
@export_storage var climb_leg_backward_degrees := 4.0
@export_storage var climb_leg_forward_offset := 0.02
@export_storage var climb_leg_backward_offset := 0.01
@export_storage var climb_leg_depth_phase := 0.5

@export_group("Escalada procedural")
## Activa la pose y el ciclo procedural. Desactivado conserva la pose base del rig mientras trepa; nunca reproduce Climb de Blender. Se actualiza en vivo.
@export var climb_procedural_enabled := true
## Invierte el sentido de las órbitas de brazos y piernas, conservando poses base, amplitudes y ritmo. Activado usa el sentido corregido de trepada; desactivado recupera el anterior. Se actualiza en vivo.
@export var climb_reverse_cycle := true
## Ciclos por metro recorrido sobre la pared. Mayor valor acelera la alternancia; 0 congela el ciclo. Se actualiza en vivo y sincroniza los sonidos.
@export_range(0.0, 3.0, 0.05) var climb_member_speed := 0.4
## Rapidez de mezcla de huesos por segundo al agarrarse y durante el gesto. Mayor valor responde antes; menor suaviza. Se actualiza en vivo.
@export_range(1.0, 40.0, 0.5) var climb_pose_response := 14.0
## Inclinación visual del cuerpo hacia la pared en grados. Mayor valor acerca la cabeza a la pared; valores negativos la alejan. Se actualiza en vivo, sin cambiar la cápsula.
@export_range(-30.0, 30.0, 0.5) var climb_body_lean_degrees := 5.0
## Desplazamiento visual respecto al controlador en metros. Positivo aleja el modelo de la pared, negativo lo acerca. No cambia Climb Wall Distance ni las colisiones. Se actualiza en vivo.
@export_range(-0.25, 0.25, 0.005, "suffix:m") var climb_visual_wall_offset := 0.0
## Elevación base de brazos desde la postura hacia abajo, en grados. 90 los deja horizontales; mayor valor eleva las manos. Se actualiza en vivo.
@export_range(0.0, 180.0, 0.5) var climb_arm_base_elevation_degrees := 81.0
## Apertura de brazos desde el frente hacia los lados, en grados. 0 apunta hacia la pared; mayor valor separa las manos lateralmente. Se actualiza en vivo.
@export_range(0.0, 90.0, 0.5) var climb_arm_base_spread_degrees := 42.5
## Amplitud angular de subida y bajada de brazos, en grados. Mayor valor alarga el arco vertical; 0 deja sólo el recorrido de profundidad. Se actualiza en vivo.
@export_range(0.0, 60.0, 0.5) var climb_arm_vertical_degrees := 20.0
## Amplitud de giro entre alcance frontal/interior y retorno exterior de brazos, en grados. Mayor valor acentúa el círculo; 0 deja sólo subida y bajada. Se actualiza en vivo.
@export_range(0.0, 60.0, 0.5) var climb_arm_depth_degrees := 45.0
## Inclinación del recorrido orbital de brazos, en grados. Rota la combinación de subida y profundidad; cambia la orientación del arco, no el pivote. Se actualiza en vivo.
@export_range(-85.0, 85.0, 0.5) var climb_arm_path_tilt_degrees := 20.0
## Desfase de los brazos respecto al ciclo, en fracciones de vuelta. Cambiar 0,5 invierte alcance y retorno. Se actualiza en vivo.
@export_range(0.0, 1.0, 0.01) var climb_arm_phase := 0.0
## Elevación base de piernas desde la postura hacia abajo, en grados. Mayor valor adelanta y levanta los pies. Se actualiza en vivo.
@export_range(0.0, 100.0, 0.5) var climb_leg_base_elevation_degrees := 50.5
## Apertura de piernas desde el frente hacia los lados, en grados. Mayor valor separa lateralmente los pies. Se actualiza en vivo.
@export_range(0.0, 90.0, 0.5) var climb_leg_base_spread_degrees := 28.0
## Amplitud angular de subida y bajada de piernas, en grados. Mayor valor eleva más los pies durante el ciclo. Se actualiza en vivo.
@export_range(0.0, 50.0, 0.5) var climb_leg_vertical_degrees := 15.0
## Amplitud del alcance frontal/interior y retorno exterior de piernas, en grados. Mayor valor marca más el círculo del pie. Se actualiza en vivo.
@export_range(0.0, 50.0, 0.5) var climb_leg_depth_degrees := 12.0
## Inclinación del recorrido orbital de piernas, en grados. Cambia la orientación del arco manteniendo fija la cadera. Se actualiza en vivo.
@export_range(-85.0, 85.0, 0.5) var climb_leg_path_tilt_degrees := 15.0
## Desfase de piernas respecto a brazos, en fracciones de ciclo. 0,5 alterna brazo y pierna del mismo lado; 0 los mueve juntos. Se actualiza en vivo.
@export_range(0.0, 1.0, 0.01) var climb_leg_phase := 0.5
## Desfase entre lados izquierdo y derecho para brazos y piernas. 0,5 los alterna; 0 los sincroniza. Se actualiza en vivo.
@export_range(0.0, 1.0, 0.01) var climb_opposite_side_phase := 0.5
## Activa el sonido único de entrada y los dos apoyos por ciclo procedural. Se actualiza en vivo.
@export var climb_sound_enabled := true
## Datos anteriores conservados para no perder ajustes serializados; ya no controlan los apoyos.
@export_storage var climb_sound_phases := Vector2(0.0, 0.5)
## Punto del recorrido local de cada brazo donde suena su apoyo, de 0 a 1. El mismo valor se aplica a ambos respetando Arm Phase, Opposite Side Phase y Reverse Cycle. 0/1 es el inicio, 0,25 un cuarto y 0,5 media vuelta. Se actualiza en vivo; no desplaza el sonido independiente de entrada.
@export_range(0.0, 1.0, 0.005) var climb_sound_phase := 0.23
## Activa la inclinación lateral alternada de la cabeza durante la escalada. Se actualiza en vivo; al detenerse conserva la pose del ciclo actual.
@export var climb_head_sway_enabled := true
## Inclinación máxima de la cabeza a cada lado, en grados. Mayor valor marca más el balanceo; 0 lo desactiva. Se actualiza en vivo y se suaviza con Climb Pose Response.
@export_range(0.0, 25.0, 0.5) var climb_head_sway_degrees := 8.0
## Desfase de cabeza respecto al brazo izquierdo, en fracciones de ciclo. Cambiar 0,5 invierte el lado de la inclinación. Se actualiza en vivo y respeta Reverse Cycle.
@export_range(0.0, 1.0, 0.01) var climb_head_sway_phase := 0.5
## Activa el balanceo lateral de la cola desde tail_base durante la escalada. No deforma su longitud. Se actualiza en vivo; se congela con el ciclo al detenerse.
@export var climb_tail_sway_enabled := true
## Giro máximo de cola hacia cada lado, en grados, alrededor del eje vertical del cuerpo. Mayor valor amplía el vaivén; 0 lo desactiva. Se actualiza en vivo y se suaviza con Climb Pose Response.
@export_range(0.0, 40.0, 0.5) var climb_tail_sway_degrees := 14.5
## Desfase del balanceo de cola respecto al brazo izquierdo, en fracciones de ciclo. 0,5 invierte el movimiento respecto a 0. Se actualiza en vivo y respeta Reverse Cycle.
@export_range(0.0, 1.0, 0.01) var climb_tail_sway_phase := 0.0
## Activa los tres giros del tronco desde spine. Cabeza y brazos acompañan por jerarquía; las piernas permanecen independientes. Se actualiza en vivo.
@export var climb_torso_motion_enabled := true
## Torsión del tronco a cada lado en grados, alrededor del eje cadera-cabeza (+Y del cuerpo). Acerca un hombro a la pared mientras aleja el otro. Mayor valor exagera la torsión; 0 la desactiva. Se actualiza en vivo.
@export_range(0.0, 30.0, 0.5) var climb_torso_twist_degrees := 8.0
## Desfase de la torsión respecto al brazo izquierdo, en fracciones de ciclo. 0,5 invierte qué hombro se acerca. Se actualiza en vivo y respeta Reverse Cycle.
@export_range(0.0, 1.0, 0.01) var climb_torso_twist_phase := 0.0
## Inclinación lateral del tronco a cada lado en grados, alrededor del eje espalda-pecho (+Z del cuerpo). Ladea cabeza y hombros a izquierda/derecha para sugerir transferencia de peso. 0 la desactiva. Se actualiza en vivo.
@export_range(0.0, 25.0, 0.5) var climb_torso_side_lean_degrees := 0.0
## Desfase de la inclinación lateral respecto al brazo izquierdo, en fracciones de ciclo. 0,5 invierte el lado del apoyo. Se actualiza en vivo y respeta Reverse Cycle.
@export_range(0.0, 1.0, 0.01) var climb_torso_side_lean_phase := 0.0
## Cabeceo del tronco en grados, alrededor del eje hombro-hombro (+X del cuerpo). Acerca y aleja la parte alta del cuerpo de la pared. Se suma a Body Lean constante; 0 lo desactiva. Se actualiza en vivo.
@export_range(0.0, 25.0, 0.5) var climb_torso_forward_lean_degrees := 0.0
## Desfase del cabeceo respecto al brazo izquierdo, en fracciones de ciclo. 0,5 invierte cuándo se acerca a la pared. Se actualiza en vivo y respeta Reverse Cycle.
@export_range(0.0, 1.0, 0.01) var climb_torso_forward_lean_phase := 0.0

var is_climbing := false
var climb_motion := 0.0
var climb_surface_normal := Vector3.BACK
var climb_mantle_progress := -1.0
var climb_stand_progress := -1.0
var climb_surface_assist_active := false
var climb_mantle_cycle_start := 0.0
var climb_mantle_cycle_count := 0
var climbing: Node
var control_enabled := true
var spawn_position := Vector3.ZERO
var camera_rig: TrailCamera
var model: SquirrelRig
var animator: SquirrelAnimator
var animation_state := "idle"
var reaction_kind := ""
var reaction_time := 0.0
var landing_time := 0.0
var is_glide_recoiling := false
var is_splat := false
var splat_elapsed := 0.0
var splat_state_duration := 1.25
var splat_floor_normal := Vector3.UP
var splat_floor_point := Vector3.ZERO
var fall_peak_y := 0.0
var glide_recoil_elapsed := 0.0
var glide_recoil_state_duration := 0.38
var glide_recoil_requires_release := false
var is_glide_landing := false
var glide_landing_left := 0.0
var glide_landing_elapsed := 0.0
var glide_landing_contact_lost := 0.0
var glide_landing_velocity := Vector3.ZERO
var glide_landing_floor_point := Vector3.ZERO
var glide_landing_floor_normal := Vector3.UP
var landing_strength := 0.0
var last_landing_speed := 0.0
var coyote_left := 0.0
var buffer_left := 0.0
var step_time := 0.0
## Surface-specific contact cadence; movement and animation remain independent.
var step_frequency_multiplier := 1.0
var input_grace := 0.0
var horizontal_speed := 0.0
var motion_acceleration := Vector3.ZERO
var angular_velocity := 0.0
var jump_consumed := false
var interaction_press_consumed := false

func consume_interaction_press() -> void:
	interaction_press_consumed = true
	buffer_left = 0.0
	glide_button_pressed_in_air = false
var previous_motion := Vector3.ZERO
var is_sliding := false
var slide_velocity := Vector3.ZERO
var slide_surface_normal := Vector3.UP
var is_gliding := false:
	set(value):
		if is_gliding == value:
			return
		is_gliding = value
		gliding_changed.emit(value)
var is_glide_sprinting := false
var glide_button_pressed_in_air := false
## Intensidad de entrada horizontal actual para que la postura de Glide sepa
## si la ardilla está intentando avanzar o simplemente está cayendo.
var glide_movement_intent := 0.0
## Rumbo visual e intensidad lateral solicitados durante Glide. Se separan de
## la trayectoria física para dar respuesta inmediata sin giros instantáneos.
var glide_facing_direction := Vector3.ZERO
var glide_turn_intent := 0.0
## Ángulo horizontal firmado entre el rumbo actual y el pedido. Solo lo usa
## el modelo para hacer bank/roll; nunca modifica la trayectoria física.
var glide_signed_turn_angle := 0.0
var glide_motion_heading := Vector3.ZERO

## Fuente opcional de órdenes para NPC. Sin fuente, el jugador sigue usando Input.
var command_source: Node

func action_pressed(action: StringName) -> bool:
	return bool(command_source.call("action_pressed", action)) if is_instance_valid(command_source) else Input.is_action_pressed(action)

func action_just_pressed(action: StringName) -> bool:
	return bool(command_source.call("action_just_pressed", action)) if is_instance_valid(command_source) else Input.is_action_just_pressed(action)

func movement_input() -> Vector2:
	return command_source.call("movement_input") if is_instance_valid(command_source) else Input.get_vector("move_left", "move_right", "move_forward", "move_back")

func _steep_support() -> Vector3:
	# Sample beneath the feet, never a forward wall. Leave a real jump untouched.
	if jump_consumed and velocity.y > 0.0: return Vector3.ZERO
	# A capsule can span a steep triangle while actually supported by a walkable
	# neighbor. Respect that real contact rather than braking at terrain seams.
	if is_on_floor() and get_floor_normal().y >= cos(floor_max_angle): return Vector3.ZERO
	var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.45, global_position - Vector3.UP * 0.48, collision_mask, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty(): return Vector3.ZERO
	var normal: Vector3 = hit.normal
	if normal.y > 0.15 and normal.y < cos(floor_max_angle + deg_to_rad(0.25)):
		return normal
	return Vector3.ZERO

func _ready() -> void:
	spawn_position = global_position
	fall_peak_y = global_position.y
	process_mode = Node.PROCESS_MODE_PAUSABLE
	collision_layer = 2
	collision_mask = 1 if is_in_group("npc_actors") else 9
	floor_snap_length = snap_distance
	floor_max_angle = deg_to_rad(walkable_slope_degrees)
	floor_constant_speed = true
	floor_stop_on_slope = true
	safe_margin = 0.02
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.42
	shape.height = 1.42
	collider.shape = shape
	collider.position.y = 0.72
	add_child(collider)
	model = SquirrelRig.new()
	model.name = "AnimatedSquirrel"
	add_child(model)
	animator = get_node("Animation") as SquirrelAnimator
	animator.actor = self
	climbing = preload("res://scripts/climbing.gd").new()
	climbing.actor = self
	add_child(climbing)

func react(kind: String) -> void:
	reaction_kind = kind
	reaction_time = 0.45

func face_interaction_partner(partner: Node3D) -> void:
	if not interaction_facing_enabled or not is_instance_valid(partner) or not is_instance_valid(model):
		return
	_interaction_partner = weakref(partner)
	_interaction_facing_left = interaction_facing_duration
	_interaction_turn_pending = true

func _face_partner(partner: Node3D, delta: float) -> void:
	var direction := partner.global_position - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.000001:
		_interaction_turn_pending = false
		return
	var local_direction := global_basis.orthonormalized().inverse() * direction
	var target_yaw := atan2(-local_direction.x, -local_direction.z)
	model.rotation.y = rotate_toward(model.rotation.y, target_yaw, deg_to_rad(interaction_facing_speed_degrees) * delta)
	_interaction_turn_pending = absf(wrapf(target_yaw - model.rotation.y, -PI, PI)) > 0.001

func _process(delta: float) -> void:
	if (_interaction_facing_left <= 0.0 and not is_in_dialogue() and not _interaction_turn_pending) or not _interaction_partner:
		return
	var partner := _interaction_partner.get_ref() as Node3D
	if is_instance_valid(partner):
		_face_partner(partner, delta)
	else:
		_interaction_turn_pending = false
	_interaction_facing_left = maxf(0.0, _interaction_facing_left - delta)

func set_controls(enabled: bool) -> void:
	control_enabled = enabled
	if not enabled:
		glide_movement_intent = 0.0
		glide_facing_direction = Vector3.ZERO
		glide_turn_intent = 0.0
		glide_signed_turn_angle = 0.0
		glide_motion_heading = Vector3.ZERO
	input_grace = 0.16 if enabled else 0.0
	buffer_left = 0
	# The paused tree freezes the body. Preserve momentum and the jump arc:
	# clearing velocity here used to make airborne dialogue/resume drop vertically.
	previous_motion = Vector3(velocity.x, 0, velocity.z)
	motion_acceleration = Vector3.ZERO
	angular_velocity = 0

func respawn() -> void:
	_npc_bounce_airborne = false
	npc_bounce_in_progress = false
	_npc_slip_speed = 0.0
	_interaction_facing_left = 0.0
	_interaction_partner = null
	_interaction_turn_pending = false
	is_splat = false
	splat_elapsed = 0.0
	is_glide_recoiling = false
	glide_recoil_elapsed = 0.0
	glide_recoil_requires_release = false
	is_glide_landing = false
	glide_landing_left = 0.0
	glide_landing_elapsed = 0.0
	glide_landing_contact_lost = 0.0
	glide_landing_velocity = Vector3.ZERO
	if climbing:
		climbing.reset()
	model.end_climb()
	global_position = spawn_position + Vector3.UP * 0.12
	fall_peak_y = global_position.y
	velocity = Vector3.ZERO
	previous_motion = Vector3.ZERO
	horizontal_speed = 0
	motion_acceleration = Vector3.ZERO
	angular_velocity = 0
	buffer_left = 0
	coyote_left = 0
	jump_consumed = false
	is_sliding = false
	is_gliding = false
	is_glide_sprinting = false
	glide_button_pressed_in_air = false
	glide_movement_intent = 0.0
	glide_facing_direction = Vector3.ZERO
	glide_turn_intent = 0.0
	glide_signed_turn_angle = 0.0
	glide_motion_heading = Vector3.ZERO
	slide_velocity = Vector3.ZERO
	reaction_time = 0
	landing_time = 0
	animator.reset()
	reset_physics_interpolation()
	if camera_rig: camera_rig.snap()
	respawned.emit()

func _physics_process(delta: float) -> void:
	if not control_enabled: return
	var npc_support := get_npc_support()
	if npc_support:
		_start_npc_slip(npc_support)
	if is_in_dialogue():
		# Bloqueo de locomoción, no de procesamiento: gravedad, Idle y rig siguen vivos.
		velocity.x = 0.0
		velocity.z = 0.0
		_apply_npc_slip()
		velocity.y = 0.0 if is_on_floor() else velocity.y - gravity * delta
		move_and_slide()
		horizontal_speed = 0.0
		previous_motion = Vector3.ZERO
		angular_velocity = 0.0
		buffer_left = 0.0
		animator.tick(delta, 0.0)
		model.update_handmade_run(0.0, walk_member_animation_speed, run_member_animation_speed, false)
		return
	if interaction_press_consumed:
		if not action_pressed("jump"):
			interaction_press_consumed = false
	input_grace = maxf(0, input_grace - delta)
	if not action_pressed("glide"):
		glide_recoil_requires_release = false
	if is_splat and _tick_splat(delta):
		return
	if _try_npc_support_bounce():
		animator.tick(delta, horizontal_speed)
		return
	fall_peak_y = global_position.y if is_on_floor() else maxf(fall_peak_y, global_position.y)
	if is_glide_recoiling and _tick_glide_recoil(delta):
		return
	if is_glide_landing and _tick_glide_landing(delta):
		return
	if not interaction_press_consumed and climbing.tick(delta):
		fall_peak_y = global_position.y
		return
	var grounded := is_on_floor() and not _npc_bounce_airborne
	var steep_normal := _steep_support()
	is_sliding = steep_normal != Vector3.ZERO
	if is_sliding:
		fall_peak_y = global_position.y
	slide_surface_normal = steep_normal if is_sliding else Vector3.UP
	if grounded or is_sliding:
		is_gliding = false
		glide_button_pressed_in_air = false
		jump_consumed = false
		coyote_left = coyote_time
	else:
		coyote_left = maxf(0, coyote_left - delta)
	buffer_left = maxf(0, buffer_left - delta)
	var jump_pressed_this_frame := action_just_pressed("jump") and not interaction_press_consumed
	# Planeo tiene acción independiente: R1 en mando, otra pulsación de
	# Espacio en teclado. Mantener salto desde tierra no activa el planeo.
	if action_just_pressed("glide") and not interaction_press_consumed and not grounded and not is_sliding and not glide_recoil_requires_release:
		glide_button_pressed_in_air = true
	if not action_pressed("glide"):
		glide_button_pressed_in_air = false
	# Un botón pulsado en el aire ahora sirve para iniciar planeo, no para
	# convertir accidentalmente una caída en un salto de coyote.
	if jump_pressed_this_frame and input_grace <= 0 and not glide_button_pressed_in_air:
		buffer_left = jump_buffer
	is_gliding = glide_enabled and not grounded and not is_sliding and glide_button_pressed_in_air and action_pressed("glide") and not interaction_press_consumed
	is_glide_sprinting = is_gliding and action_pressed("sprint")
	if grounded:
		velocity.y = 0
	elif is_gliding and velocity.y <= 0:
		var glide_fall_limit := glide_fall_speed + (glide_sprint_fall_speed_bonus if is_glide_sprinting else 0.0)
		var glide_gravity := glide_gravity_scale + (glide_sprint_gravity_scale_bonus if is_glide_sprinting else 0.0)
		if velocity.y < -glide_fall_limit:
			velocity.y = move_toward(velocity.y, -glide_fall_limit, glide_braking * delta)
		else:
			velocity.y = maxf(-glide_fall_limit, velocity.y - gravity * glide_gravity * delta)
	else:
		velocity.y -= gravity * delta
	if buffer_left > 0 and coyote_left > 0 and not jump_consumed:
		velocity.y = jump_velocity
		jump_consumed = true
		is_sliding = false
		coyote_left = 0
		buffer_left = 0
		landing_time = 0
		feedback.emit("jump")
		animator.jump_started()
	var direction := movement_input()
	glide_movement_intent = direction.length()
	# Movement follows the visible orbit, not its unsmoothed target yaw.
	var yaw := camera_rig.rotation.y if camera_rig else 0.0
	var desired := Vector3(direction.x, 0, direction.y).rotated(Vector3.UP, yaw)
	var target_speed := sprint_speed if action_pressed("sprint") else walk_speed
	if is_glide_sprinting:
		target_speed *= glide_sprint_speed_multiplier
	var planar := Vector3(velocity.x, 0, velocity.z)
	var planar_speed_before_turn := planar.length()
	var glide_turn_amount := 0.0
	if grounded and planar.length_squared() > 0.0001:
		# Recover surface speed before accelerating; otherwise projecting to a slope
		# repeatedly shrinks the horizontal speed on every physics tick.
		planar = planar.normalized() * previous_motion.length()
	if not is_gliding:
		glide_motion_heading = Vector3.ZERO
	elif glide_motion_heading.length_squared() <= 0.0001:
		glide_motion_heading = planar.normalized() if planar.length_squared() > 0.0001 else Vector3.FORWARD.rotated(Vector3.UP, model.rotation.y)
	if is_gliding and desired.length_squared() > 0.0001:
		# Limita el cambio de dirección real, no solo la aceleración. Así mantener
		# la dirección opuesta dibuja una curva y nunca voltea instantáneamente.
		# Si apenas se mueve, usa el frente actual del modelo para impedir también
		# un giro instantáneo desde reposo durante Glide.
		var speed_ratio := clampf(planar.length() / maxf(0.1, target_speed), 0.0, 1.0)
		var turn_rate_scale := lerpf(1.0, glide_high_speed_turn_rate_multiplier, speed_ratio)
		# Hasta 0,7 se dosifica el giro configurado. De 0,7 a 1 el rumbo
		# gana seguimiento directo, para que 1 signifique control físico total.
		var direct_control := smoothstep(0.7, 1.0, glide_air_control)
		var turn_rate_control := minf(glide_air_control / 0.7, 1.0)
		var max_turn_angle := deg_to_rad(glide_turn_rate_degrees) * turn_rate_scale * turn_rate_control * delta
		var current_heading := planar.normalized() if planar.length_squared() > 0.0001 else glide_motion_heading
		var requested_heading := desired.normalized()
		var requested_turn := current_heading.signed_angle_to(requested_heading, Vector3.UP)
		glide_signed_turn_angle = requested_turn
		# La animación responde al rumbo pedido al instante, aunque la trayectoria
		# se limite abajo para conservar una curva física amplia.
		glide_facing_direction = requested_heading
		glide_turn_intent = clampf(requested_turn / (PI * 0.5), -1.0, 1.0) * glide_visual_turn_follow
		var limited_heading := current_heading.rotated(Vector3.UP, clampf(requested_turn, -max_turn_angle, max_turn_angle))
		var controlled_heading := limited_heading.slerp(requested_heading, direct_control).normalized()
		desired = controlled_heading * desired.length()
	else:
		glide_facing_direction = Vector3.ZERO
		glide_turn_intent = 0.0
		glide_signed_turn_angle = 0.0
	var braking := direction.length_squared() < 0.0025 or planar.length() > target_speed * direction.length() + 0.1
	# En tierra, invertir dirección desacelera antes de avanzar. Durante Glide,
	# el rumbo ya se curva arriba: no aplicar ese freno extra mantiene la inercia.
	if not is_gliding:
		braking = braking or planar.dot(desired) < -0.05
	var rate := deceleration if braking else acceleration
	var air_steering := glide_air_control if is_gliding else air_control
	if is_gliding and planar.length_squared() > 0.0001 and desired.length_squared() > 0.0001:
		# A alta velocidad, cambiar mucho de rumbo requiere una curva más amplia.
		# Avanzar recto conserva el control completo; solo se atenúan los giros.
		var speed_ratio := clampf(planar.length() / maxf(0.1, target_speed), 0.0, 1.0)
		var direction_change := clampf(1.0 - planar.normalized().dot(desired.normalized()), 0.0, 1.0)
		glide_turn_amount = direction_change
		var direct_control := smoothstep(0.7, 1.0, glide_air_control)
		air_steering *= 1.0 - glide_high_speed_turn_reduction * (1.0 - direct_control) * speed_ratio * direction_change
	planar = planar.move_toward(desired * target_speed, rate * (1.0 if grounded else air_steering) * delta)
	if is_gliding and glide_turn_amount > 0.001 and planar.length_squared() > 0.0001:
		var retained_speed := planar_speed_before_turn * glide_turn_speed_retention
		planar = planar.normalized() * maxf(planar.length(), retained_speed)
	velocity.x = planar.x
	velocity.z = planar.z
	if grounded and not jump_consumed and planar.length_squared() > 0.0001:
		var normal := get_floor_normal()
		# Enter the next triangle along the floor tangent, not horizontally into it.
		# Resetting Y to zero each tick made convex seams act like tiny walls.
		var tangent := Vector3(planar.x, -(normal.x * planar.x + normal.z * planar.z) / maxf(normal.y, 0.01), planar.z)
		velocity = tangent.normalized() * planar.length()
	if is_sliding:
		var downhill := Vector3.DOWN.slide(steep_normal).normalized()
		slide_velocity = slide_velocity.slide(steep_normal).move_toward(downhill * slide_max_speed, slide_acceleration * delta)
		# Steering is across the slope only: pushing uphill cannot defeat the slide.
		var steering := desired.slide(steep_normal)
		steering -= downhill * steering.dot(downhill)
		velocity = (slide_velocity + steering * walk_speed * slide_steering).limit_length(slide_max_speed) - steep_normal * 0.35
	else:
		slide_velocity = Vector3.ZERO
	var landing_from_glide := is_gliding
	var incoming_velocity := velocity
	var incoming_glide_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var impact_speed := maxf(0, -velocity.y)
	var position_before_move := global_position
	_apply_npc_slip()
	move_and_slide()
	_npc_bounce_airborne = false
	if _try_npc_bounce(incoming_velocity):
		animator.tick(delta, horizontal_speed)
		return
	if is_on_floor() and has_world_ground_contact() and not get_npc_support():
		if npc_bounce_in_progress:
			_npc_dust_block_frame = Engine.get_physics_frames()
		npc_bounce_in_progress = false
		_npc_slip_speed = 0.0
	if landing_from_glide and not is_on_floor() and _try_glide_recoil(incoming_velocity):
		animator.tick(delta, horizontal_speed)
		return
	if is_on_floor(): is_gliding = false
	if grounded and not jump_consumed and not is_sliding:
		# Tangential uphill velocity is positive Y. Explicit snapping keeps contact
		# across a shallower triangle, without cancelling an intentional jump.
		apply_floor_snap()
	var actual := (global_position - position_before_move) / delta
	var actual_planar := Vector3(actual.x, 0, actual.z)
	if is_gliding and actual_planar.length_squared() > 0.0001:
		glide_motion_heading = actual_planar.normalized()
	horizontal_speed = actual_planar.length()
	motion_acceleration = motion_acceleration.lerp((actual_planar - previous_motion) / delta, 1.0 - exp(-12.0 * delta))
	previous_motion = actual if is_on_floor() else actual_planar
	angular_velocity = 0
	var facing_planar := actual_planar
	if is_gliding and glide_facing_direction.length_squared() > 0.0001:
		var motion_heading := glide_motion_heading if glide_motion_heading.length_squared() > 0.0001 else Vector3.FORWARD.rotated(Vector3.UP, model.rotation.y)
		var visual_turn := motion_heading.signed_angle_to(glide_facing_direction, Vector3.UP) * glide_visual_turn_follow
		facing_planar = motion_heading.rotated(Vector3.UP, visual_turn)
	if facing_planar.length_squared() > 0.0001:
		var old_yaw := model.rotation.y
		var target_angle := atan2(-facing_planar.x, -facing_planar.z)
		var visual_turn_speed := glide_visual_turn_speed if is_gliding else turn_speed
		var angle_step := wrapf(target_angle - old_yaw, -PI, PI) * (1.0 - exp(-visual_turn_speed * delta))
		model.rotation.y = wrapf(old_yaw + angle_step, -PI, PI)
		angular_velocity = angle_step / delta
	if not grounded and is_on_floor():
		last_landing_speed = impact_speed
		if _try_start_splat(impact_speed):
			animator.tick(delta, 0.0)
			return
		if landing_from_glide and glide_landing_enabled and glide_landing_duration > 0.0 and not is_sliding:
			is_glide_landing = true
			glide_landing_left = glide_landing_duration
			glide_landing_elapsed = 0.0
			glide_landing_contact_lost = 0.0
			glide_landing_velocity = incoming_glide_velocity * glide_landing_speed_retention
			_update_glide_landing_floor()
			landing_time = 0.0
			animator.landing_elapsed = -1.0
			feedback.emit("land")
		elif impact_speed >= landing_threshold:
			landing_strength = lerpf(0.25, 1.0, clampf((impact_speed - landing_threshold) / maxf(0.1, hard_landing_speed - landing_threshold), 0, 1))
			landing_time = animator.landing_duration
			animator.landed()
			feedback.emit("land")
	if is_on_floor() and not is_sliding and not is_glide_landing and horizontal_speed > 0.3:
		step_time += delta * horizontal_speed
		var step_distance := animator.stride_length * 0.5 / maxf(0.1, animator.cadence_multiplier) / maxf(0.1, step_frequency_multiplier)
		if step_time > step_distance:
			step_time = fmod(step_time, step_distance)
			feedback.emit("step")
			get_tree().call_group("snow_surface_receivers","record_snow_step",self,_snow_step_side)
			_snow_step_side = -_snow_step_side
	if global_position.y < -12.0:
		respawn()
		return
	animator.tick(delta, horizontal_speed)
	if not is_gliding and not is_glide_landing:
		model.update_handmade_run(horizontal_speed, walk_member_animation_speed, run_member_animation_speed, action_pressed("sprint"))


var _npc_bounce_airborne := false
var npc_bounce_in_progress := false
var _npc_slip_direction := Vector3.ZERO
var _npc_slip_speed := 0.0
var _npc_dust_block_frame := -1

func is_npc_dust_blocked() -> bool:
	return npc_bounce_in_progress or _npc_dust_block_frame == Engine.get_physics_frames()

## Permiso de la superficie corporal, independiente de Climb Enabled (capacidad del actor).
func allows_climb(_world_point: Vector3) -> bool:
	if not is_in_group("npc_actors"):
		return true
	return is_instance_valid(command_source) and command_source.get("climbable") == true

## Apoyo real en escenario; la cápsula de un NPC nunca cuenta como suelo para polvo o diálogo.
func has_world_ground_contact(walkable_only: bool = true) -> bool:
	var reach := maxf(0.12, snap_distance + safe_margin)
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.1, global_position - Vector3.UP * reach, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.normal.y >= (cos(floor_max_angle) if walkable_only else 0.05)

func get_npc_support() -> ExplorerPlayer:
	if is_instance_valid(command_source) or velocity.y > 0.0:
		return null
	var hit := KinematicCollision3D.new()
	if test_move(global_transform, Vector3.DOWN * (safe_margin + 0.04), hit):
		for index in hit.get_collision_count():
			var other := hit.get_collider(index) as ExplorerPlayer
			if other and other.is_in_group("npc_actors") and hit.get_normal(index).y > 0.1:
				return other
	return null

func can_start_npc_dialogue() -> bool:
	return control_enabled and is_on_floor() and velocity.y <= 0.0 and not npc_bounce_in_progress and not is_splat and not is_climbing and not get_npc_support() and has_world_ground_contact()

func _start_npc_slip(other: ExplorerPlayer) -> void:
	if not npc_bounce_in_progress:
		_npc_slip_direction = (global_position - other.global_position) * Vector3(1.0, 0.0, 1.0)
		if _npc_slip_direction.is_zero_approx():
			_npc_slip_direction = Vector3(velocity.x, 0.0, velocity.z)
		if _npc_slip_direction.is_zero_approx():
			_npc_slip_direction = Vector3.FORWARD.rotated(Vector3.UP, model.rotation.y)
		_npc_slip_direction = _npc_slip_direction.normalized()
	var spring := other.command_source.get_node_or_null("StompReaction") if is_instance_valid(other.command_source) else null
	_npc_slip_speed = float(spring.slip_speed) if spring else 2.0
	npc_bounce_in_progress = true
	_npc_dust_block_frame = Engine.get_physics_frames()
	if is_instance_valid(model.movement_dust):
		model.movement_dust.stop_emission()

func _apply_npc_slip() -> void:
	if npc_bounce_in_progress and _npc_slip_speed > 0.0:
		var outward_speed := velocity.dot(_npc_slip_direction)
		velocity += _npc_slip_direction * maxf(0.0, _npc_slip_speed - outward_speed)

func _try_npc_support_bounce() -> bool:
	if is_instance_valid(command_source) or not is_on_floor() or _npc_bounce_airborne or velocity.y > 0.0:
		return false
	# Incluye apoyo quieto, que puede no producir slide collisions al moverse 0 m.
	var hit := KinematicCollision3D.new()
	if not test_move(global_transform, Vector3.DOWN * (safe_margin + 0.02), hit):
		return false
	var other := hit.get_collider() as ExplorerPlayer
	if not other or not is_instance_valid(other.command_source):
		return false
	var spring := other.command_source.get_node_or_null("StompReaction")
	return spring != null and spring.try_stomp(self, hit, maxf(0.0, -velocity.y))

func _try_npc_bounce(incoming: Vector3) -> bool:
	if is_instance_valid(command_source) or incoming.y > 0.0 or is_in_dialogue():
		return false
	for index in get_slide_collision_count():
		var hit := get_slide_collision(index)
		var other := hit.get_collider() as ExplorerPlayer
		if not other or not is_instance_valid(other.command_source):
			continue
		if hit.get_normal().y > 0.1:
			_start_npc_slip(other)
		var spring := other.command_source.get_node_or_null("StompReaction")
		if spring and spring.try_stomp(self, hit, -incoming.y):
			return true
	return false

## Impulso externo de un NPC: consume coyote/buffer y evita tratar el contacto como aterrizaje.
func bounce_from_npc(speed: float) -> void:
	velocity.y = speed
	_npc_bounce_airborne = true
	npc_bounce_in_progress = true
	_npc_dust_block_frame = Engine.get_physics_frames()
	if is_instance_valid(model.movement_dust):
		model.movement_dust.stop_emission()
	_apply_npc_slip()
	jump_consumed = true
	coyote_left = 0.0
	buffer_left = 0.0
	landing_time = 0.0
	is_gliding = false
	is_glide_landing = false
	is_glide_recoiling = false
	is_sliding = false
	glide_button_pressed_in_air = false
	glide_recoil_requires_release = true
	fall_peak_y = global_position.y
	animator.jump_started()

func _allows_impact_reaction(collider: Object) -> bool:
	var npc := collider as ExplorerPlayer
	if not npc or not npc.is_in_group("npc_actors"):
		return true
	return is_instance_valid(npc.command_source) and npc.command_source.get("player_impact_reaction_enabled") == true

func _try_glide_recoil(incoming: Vector3) -> bool:
	if not glide_recoil_enabled:
		return false
	var planar := Vector3(incoming.x, 0.0, incoming.z)
	if planar.length() < maxf(0.001, glide_recoil_min_speed):
		return false
	var normals: Array[Vector3] = []
	for index in get_slide_collision_count():
		var contact := get_slide_collision(index)
		for contact_index in contact.get_collision_count():
			if _allows_impact_reaction(contact.get_collider(contact_index)):
				normals.append(contact.get_normal(contact_index))
	if glide_recoil_probe_distance > 0.0:
		var probe := KinematicCollision3D.new()
		if test_move(global_transform, planar.normalized() * glide_recoil_probe_distance, probe):
			for contact_index in probe.get_collision_count():
				if _allows_impact_reaction(probe.get_collider(contact_index)):
					normals.append(probe.get_normal(contact_index))
	for normal in normals:
		if normal.y < -0.01 or normal.y >= cos(floor_max_angle) or normal.y > cos(deg_to_rad(glide_recoil_min_wall_slope_degrees)):
			continue
		var outward := Vector3(normal.x, 0.0, normal.z).normalized()
		if planar.normalized().dot(-outward) + 0.00001 < cos(deg_to_rad(glide_recoil_max_angle_degrees)):
			continue
		is_glide_recoiling = true
		glide_recoil_elapsed = 0.0
		glide_recoil_state_duration = glide_recoil_duration
		glide_recoil_requires_release = true
		is_gliding = false
		is_glide_sprinting = false
		glide_button_pressed_in_air = false
		glide_movement_intent = 0.0
		glide_facing_direction = Vector3.ZERO
		glide_motion_heading = Vector3.ZERO
		glide_signed_turn_angle = 0.0
		glide_turn_intent = 0.0
		buffer_left = 0.0
		coyote_left = 0.0
		landing_time = 0.0
		velocity = planar.slide(outward) * glide_recoil_tangent_retention + outward * glide_recoil_push_speed
		horizontal_speed = Vector2(velocity.x, velocity.z).length()
		previous_motion = Vector3(velocity.x, 0.0, velocity.z)
		motion_acceleration = Vector3.ZERO
		angular_velocity = 0.0
		animator.recoil_started()
		feedback.emit("wall_recoil")
		return true
	return false


func _tick_glide_recoil(delta: float) -> bool:
	if not glide_recoil_enabled or glide_recoil_elapsed >= glide_recoil_state_duration or is_on_floor():
		is_glide_recoiling = false
		return false
	glide_recoil_elapsed += delta
	var planar := Vector3(velocity.x, 0.0, velocity.z).move_toward(Vector3.ZERO, glide_recoil_braking * delta)
	velocity = planar + Vector3.UP * (velocity.y - gravity * glide_recoil_gravity_scale * delta)
	var impact_speed := maxf(0.0, -velocity.y)
	var before := global_position
	var incoming_velocity := velocity
	move_and_slide()
	if _try_npc_bounce(incoming_velocity):
		animator.tick(delta, horizontal_speed)
		return true
	previous_motion = (global_position - before) / maxf(delta, 0.001)
	horizontal_speed = Vector2(previous_motion.x, previous_motion.z).length()
	if is_on_floor():
		is_glide_recoiling = false
		last_landing_speed = impact_speed
		if _try_start_splat(impact_speed):
			animator.tick(delta, 0.0)
			return true
		if impact_speed >= landing_threshold:
			landing_strength = lerpf(0.25, 1.0, clampf((impact_speed - landing_threshold) / maxf(0.1, hard_landing_speed - landing_threshold), 0.0, 1.0))
			landing_time = animator.landing_duration
			animator.landed()
			feedback.emit("land")
	if global_position.y < -12.0:
		respawn()
		return true
	animator.tick(delta, horizontal_speed)
	if not is_glide_recoiling:
		model.update_handmade_run(horizontal_speed, walk_member_animation_speed, run_member_animation_speed, action_pressed("sprint"))
	return true


func _try_start_splat(impact_speed: float) -> bool:
	var fall_height := maxf(0.0, fall_peak_y - global_position.y)
	if not splat_enabled or impact_speed < splat_min_impact_speed or fall_height < splat_min_fall_height:
		return false
	is_splat = true
	splat_elapsed = 0.0
	splat_state_duration = splat_duration
	if splat_height_duration_enabled:
		var full_height := maxf(splat_min_fall_height + 0.01, splat_full_duration_height)
		var height_weight := clampf((fall_height - splat_min_fall_height) / (full_height - splat_min_fall_height), 0.0, 1.0)
		splat_state_duration = lerpf(splat_duration, maxf(splat_duration, splat_max_duration), height_weight)
	splat_floor_normal = get_floor_normal()
	splat_floor_point = global_position
	is_glide_recoiling = false
	is_glide_landing = false
	is_gliding = false
	is_glide_sprinting = false
	is_sliding = false
	glide_button_pressed_in_air = false
	glide_movement_intent = 0.0
	glide_facing_direction = Vector3.ZERO
	glide_motion_heading = Vector3.ZERO
	glide_signed_turn_angle = 0.0
	glide_turn_intent = 0.0
	velocity = Vector3(velocity.x, 0.0, velocity.z) * splat_speed_retention
	horizontal_speed = 0.0
	previous_motion = Vector3.ZERO
	motion_acceleration = Vector3.ZERO
	angular_velocity = 0.0
	buffer_left = 0.0
	coyote_left = 0.0
	landing_time = 0.0
	step_time = 0.0
	animator.splat_started()
	feedback.emit("splat")
	return true


func _tick_splat(delta: float) -> bool:
	if not splat_enabled or splat_elapsed >= splat_state_duration or not is_on_floor():
		is_splat = false
		buffer_left = 0.0
		return false
	splat_elapsed = minf(splat_elapsed + delta, splat_state_duration)
	var planar := Vector3(velocity.x, 0.0, velocity.z).move_toward(Vector3.ZERO, splat_braking * delta)
	velocity = planar.slide(get_floor_normal()) - Vector3.UP * gravity * delta
	move_and_slide()
	apply_floor_snap()
	if is_on_floor():
		splat_floor_normal = get_floor_normal()
		splat_floor_point = global_position
	else:
		# Un apoyo que desaparece devuelve la caída sin congelar al personaje.
		is_splat = false
	horizontal_speed = Vector2(velocity.x, velocity.z).length()
	previous_motion = Vector3(velocity.x, 0.0, velocity.z)
	animator.tick(delta, horizontal_speed)
	return true


func _tick_glide_landing(delta: float) -> bool:
	# Una nueva pulsación de salto recupera inmediatamente el controlador normal.
	var lost_support := not is_on_floor() and glide_landing_contact_lost >= glide_landing_contact_grace
	if not glide_landing_enabled or glide_landing_left <= 0.0 or lost_support or _steep_support() != Vector3.ZERO or (action_just_pressed("jump") and not interaction_press_consumed):
		is_glide_landing = false
		glide_landing_left = 0.0
		animator.glide_blend = 0.0
		return false
	glide_landing_left = maxf(0.0, glide_landing_left - delta)
	glide_landing_elapsed += delta
	glide_landing_velocity = glide_landing_velocity.move_toward(Vector3.ZERO, glide_landing_braking * delta)
	if is_on_floor():
		var tangent := glide_landing_velocity.slide(get_floor_normal())
		velocity = tangent.normalized() * glide_landing_velocity.length() if not tangent.is_zero_approx() else Vector3.ZERO
	else:
		velocity = glide_landing_velocity + Vector3.UP * (velocity.y - gravity * delta)
	var before := global_position
	move_and_slide()
	apply_floor_snap()
	if is_on_floor():
		_update_glide_landing_floor()
	var actual := (global_position - before) / maxf(delta, 0.001)
	horizontal_speed = Vector2(actual.x, actual.z).length()
	# No conservar inercia contra una pared ni atravesar obstáculos.
	glide_landing_velocity = Vector3(velocity.x, 0.0, velocity.z)
	previous_motion = actual
	motion_acceleration = Vector3.ZERO
	angular_velocity = 0.0
	glide_landing_contact_lost = 0.0 if is_on_floor() else glide_landing_contact_lost + delta
	if not is_on_floor() and glide_landing_contact_lost >= glide_landing_contact_grace:
		is_glide_landing = false
		glide_landing_left = 0.0
		animator.glide_blend = 0.0
	animator.tick(delta, horizontal_speed)
	return true


func _update_glide_landing_floor() -> void:
	glide_landing_floor_point = global_position
	glide_landing_floor_normal = get_floor_normal() if is_on_floor() else Vector3.UP
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.5, global_position - Vector3.UP * 1.5, collision_mask, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		glide_landing_floor_point = hit.position
		glide_landing_floor_normal = hit.normal
