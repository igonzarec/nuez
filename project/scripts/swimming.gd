class_name PlayerSwimming
extends Node
## Nado y buceo del ExplorerPlayer en cualquier WaterRiver / WaterLake (grupo water_bodies). Vive en player.tscn como nodo
## Swimming; sus ajustes se editan en el Inspector y se consultan en vivo. La pose se ajusta en Animation (SquirrelAnimator)
## › Nado. Guia: docs/swimming.md.
##
## Controles: el stick nada en la direccion de la camara; Sprint (L1 / Shift) nada mas rapido; Brincar (A) salta fuera del
## agua desde la superficie. Planear (R1) mantenido bucea; al soltarlo la ardilla sube flotando. Bajo el agua, Brincar da
## una brazada hacia arriba (mantenido sube sin parar). En teclado Espacio es a la vez Brincar y Planear: pulsacion corta
## salta y mantenida bucea (Key Hold Time).

## Se emite al entrar o salir del agua (true = nadando).
signal swimming_changed(active: bool)

@export_group("Nado")
## Activa el nado. Apagado, el agua no afecta al personaje (camina por el fondo). En vivo.
@export var swim_enabled := true
## Metros de agua sobre los pies para empezar a nadar. Menor = nada antes en aguas poco hondas; mayor = vadea mas. En vivo.
@export_range(0.2, 2.0, 0.05, "suffix:m") var enter_depth := 0.85
## Metros de agua sobre los pies por debajo de los cuales, tocando el fondo, vuelve a caminar. Debe ser menor que Enter
## Depth y que Float Depth para no alternar estados. En vivo.
@export_range(0.1, 1.5, 0.05, "suffix:m") var exit_depth := 0.55
## Metros que los pies quedan bajo la superficie al flotar. Mayor hunde mas el cuerpo; la cabeza se ajusta en
## SquirrelAnimator › Nado · postura (Swim Visual Height). En vivo.
@export_range(0.2, 1.5, 0.05, "suffix:m") var float_depth := 0.7
## Rapidez con que vuelve a la altura de flotacion, en s⁻¹. Mayor = flotacion firme; menor = mece mas al caer al agua.
@export_range(0.5, 20.0, 0.1) var float_response := 4.0
## Vaiven vertical al flotar, en metros. 0 = flotacion quieta. En vivo.
@export_range(0.0, 0.3, 0.005, "suffix:m") var bob_height := 0.05
## Ciclos por segundo del vaiven. En vivo.
@export_range(0.05, 3.0, 0.05, "suffix:Hz") var bob_speed := 0.6

@export_group("Nado · movimiento")
## Velocidad nadando en superficie con el stick a fondo, en m/s (relativa al agua: la corriente se suma aparte). En vivo.
@export_range(0.2, 15.0, 0.1, "suffix:m/s") var swim_speed := 3.2
## Velocidad nadando con Sprint, en m/s. Tambien acelera el ritmo de brazadas. En vivo.
@export_range(0.2, 20.0, 0.1, "suffix:m/s") var swim_sprint_speed := 5.0
## Aceleracion al nadar, en m/s². Menor da sensacion de agua pesada; mayor responde como en tierra. En vivo.
@export_range(0.5, 40.0, 0.1, "suffix:m/s²") var swim_acceleration := 6.0
## Frenado al soltar el stick, en m/s². Menor sigue deslizando mas. En vivo.
@export_range(0.1, 40.0, 0.1, "suffix:m/s²") var swim_drag := 3.0
## Rapidez con que el cuerpo mira hacia donde nada (mismo uso que Turn Speed del jugador). Menor = giros mas lentos. En vivo.
@export_range(0.5, 30.0, 0.1) var swim_turn_speed := 6.0
## Brazadas por segundo nadando a fondo. Mas = ritmo mas nervioso. En vivo; tambien marca el sonido de brazada.
@export_range(0.1, 5.0, 0.05, "suffix:Hz") var stroke_rate := 1.5
## Brazadas por segundo flotando sin moverse (pataleo para mantenerse). En vivo.
@export_range(0.0, 3.0, 0.05, "suffix:Hz") var tread_stroke_rate := 0.6
## Multiplicador del ritmo de brazadas con Sprint. En vivo.
@export_range(1.0, 3.0, 0.05) var sprint_stroke_multiplier := 1.4

@export_group("Nado · corriente")
## Fraccion de la corriente del rio que arrastra al nadador (la velocidad la da Flow Speed del estilo por Current Strength
## del rio). 0 = sin arrastre; 1 = flota con el agua. Nadar contra corriente rapida puede no avanzar. En vivo.
@export_range(0.0, 2.0, 0.05) var current_push := 0.85
## Al flotar sin tocar el stick, el cuerpo gira para mirar rio abajo. 0 = conserva su orientacion. En vivo.
@export_range(0.0, 1.0, 0.05) var face_current := 0.3

@export_group("Nado · entrada y salida")
## Frenado vertical del agua al caer dentro, en s⁻¹. Mayor = se hunde menos tras un salto o una caida alta. En vivo.
@export_range(0.5, 20.0, 0.1) var entry_drag := 4.0
## Impulso vertical al saltar fuera del agua desde la superficie, en m/s. Con Gravity 22, 7,5 sube ~1,3 m: suficiente para
## una orilla cortada baja. En vivo.
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var jump_velocity := 7.5
## Segundos tras saltar del agua durante los que no vuelve a entrar al nadar (evita atraparlo al despegar). En vivo.
@export_range(0.0, 1.0, 0.01, "suffix:s") var reentry_delay := 0.25

@export_group("Clavado")
## En el aire sobre agua, pulsar Brincar otra vez hace un clavado: cabeza abajo y brazos estirados hasta entrar al agua,
## con entrada limpia que hunde al jugador un momento. En teclado (Espacio compartido con Planear) una pulsacion corta
## (menos de Key Hold Time) hace el clavado y mantenerla planea. En vivo.
@export var dive_jump_enabled := true
## Metros minimos entre los pies y el agua para poder hacer el clavado. Evita clavados a ras de agua. En vivo.
@export_range(0.0, 10.0, 0.05, "suffix:m") var dive_jump_min_height := 1.2
## Metros maximos hasta el agua de debajo. Mas lejos no cuenta como "estar sobre agua". En vivo.
@export_range(1.0, 200.0, 0.5, "suffix:m") var dive_jump_reach := 60.0
## Velocidad horizontal extra al iniciar el clavado, en m/s, hacia donde mira (impulso del salto de cabeza). 0 = ninguna.
## En vivo.
@export_range(0.0, 10.0, 0.1, "suffix:m/s") var dive_jump_forward_boost := 1.5
## Segundos que sigue bajando bajo el agua tras un clavado, como si buceara, antes de flotar. En vivo.
@export_range(0.0, 3.0, 0.05, "suffix:s") var dive_jump_plunge_time := 0.7
## Multiplicador del frenado al entrar de cabeza (Entry Drag). Menor = entra mas hondo. En vivo.
@export_range(0.05, 2.0, 0.05) var dive_jump_entry_drag_scale := 0.45
## Tamano de la salpicadura de un clavado respecto a una caida normal. Menor = entrada mas limpia. En vivo.
@export_range(0.0, 2.0, 0.05) var dive_jump_splash_scale := 0.45
## Si el clavado acaba en suelo en vez de agua, siempre hay pansazo (Splat del jugador), sin importar la altura. En vivo.
@export var dive_jump_splat_on_ground := true

@export_group("Buceo")
## Permite bucear manteniendo Planear (R1). Apagado, Planear no hace nada en el agua. En vivo.
@export var dive_enabled := true
## Velocidad de descenso manteniendo Planear, en m/s. En vivo.
@export_range(0.2, 10.0, 0.1, "suffix:m/s") var dive_speed := 2.6
## Velocidad horizontal bajo el agua con el stick a fondo, en m/s. En vivo.
@export_range(0.2, 15.0, 0.1, "suffix:m/s") var dive_swim_speed := 3.6
## Velocidad de subida al soltar Planear (flotabilidad), en m/s. Mayor = vuelve antes a la superficie. En vivo.
@export_range(0.1, 10.0, 0.1, "suffix:m/s") var rise_speed := 1.8
## Velocidad de subida manteniendo Brincar bajo el agua, en m/s. En vivo.
@export_range(0.1, 10.0, 0.1, "suffix:m/s") var swim_up_speed := 3.4
## Impulso hacia arriba de cada pulsacion de Brincar bajo el agua, en m/s. En vivo.
@export_range(0.0, 8.0, 0.1, "suffix:m/s") var up_stroke_impulse := 2.0
## Rapidez con que la velocidad vertical alcanza la pedida bajo el agua, en s⁻¹. Menor = mas inercia. En vivo.
@export_range(0.5, 20.0, 0.1) var vertical_response := 4.0
## Solo teclado (Espacio comparte Brincar y Planear): segundos que hay que mantener Espacio para bucear; soltarlo antes
## salta. Con mando (A y R1 separados) no hay espera. En vivo.
@export_range(0.05, 0.6, 0.01, "suffix:s") var key_hold_time := 0.2

@export_group("Buceo · aire")
## Limita el tiempo bajo el agua. Al agotarse, sube sola a respirar (sin dano). Apagado, se puede bucear sin limite. En vivo.
@export var air_enabled := true
## Segundos de aire bajo el agua. En vivo.
@export_range(1.0, 120.0, 0.5, "suffix:s") var air_seconds := 20.0
## Segundos en superficie para recuperar todo el aire. En vivo.
@export_range(0.1, 10.0, 0.1, "suffix:s") var air_refill_time := 1.5

@export_group("Ondas reales")
## El jugador crea ondas en la superficie del agua al caer, nadar y caminar por agua poco honda (su aspecto se ajusta en
## WaterStyle › Ondas del jugador). Desactivalo si hay problemas de rendimiento: sin ondas activas el agua no las calcula.
## Coste: hasta 16 ondas a la vez por pixel de agua. Apagado por defecto (en pruebas los anillos bastan). En vivo.
@export var real_waves_enabled := false
## Fuerza de las ondas al caer al agua (multiplica la del impacto, que crece con la velocidad de caida). En vivo.
@export_range(0.0, 3.0, 0.01) var real_wave_entry_strength := 1.0
## Fuerza de cada onda al nadar en superficie. En vivo.
@export_range(0.0, 2.0, 0.01) var real_wave_swim_strength := 0.55
## Fuerza de cada onda al caminar por agua poco honda. En vivo.
@export_range(0.0, 2.0, 0.01) var real_wave_wade_strength := 0.4
## Segundos entre ondas al moverse a velocidad maxima; mas despacio salen mas espaciadas. Menor = estela mas continua
## (usa mas de las 16 ondas disponibles). En vivo.
@export_range(0.05, 2.0, 0.01, "suffix:s") var real_wave_interval := 0.28
## Velocidad minima, en m/s, para dejar ondas al moverse. En vivo.
@export_range(0.0, 3.0, 0.05, "suffix:m/s") var real_wave_min_speed := 0.4
## Onda pequena tambien flotando quieto (al ritmo del balanceo). 0 = sin ondas en reposo. En vivo.
@export_range(0.0, 1.0, 0.01) var real_wave_idle_strength := 0.08

@export_group("Salpicaduras y ondas")
## Activa salpicaduras, ondas y burbujas. Apagado no crea efectos. En vivo.
@export var effects_enabled := true
## Anillos dibujados en la superficie al nadar y al salpicar. Apagado = sin anillos (las salpicaduras y burbujas siguen).
## En vivo.
@export var ripples_enabled := true
## Velocidad vertical minima al entrar en el agua para salpicar, en m/s. En vivo.
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var splash_min_speed := 2.0
## Velocidad de entrada con la que la salpicadura alcanza su tamano maximo, en m/s. En vivo.
@export_range(1.0, 40.0, 0.5, "suffix:m/s") var splash_full_speed := 16.0
## Multiplicador del tamano de la salpicadura (gotas, altura y anillo). En vivo.
@export_range(0.1, 3.0, 0.05) var splash_scale := 1.0
## Numero maximo de gotas de una salpicadura completa. Coste: particulas de CPU solo durante la salpicadura. En vivo.
@export_range(4, 128, 1) var splash_droplets := 40
## Color de gotas, anillos y burbujas. En vivo para nuevos efectos.
@export var splash_color := Color(0.93, 0.98, 1.0)
## Segundos entre ondas en la superficie al nadar a fondo; parado se espacian el triple. 0 = sin ondas. En vivo.
@export_range(0.0, 3.0, 0.05, "suffix:s") var ripple_interval := 0.45
## Radio final de cada onda, en metros. En vivo.
@export_range(0.2, 6.0, 0.05, "suffix:m") var ripple_radius := 1.6
## Segundos que tarda cada onda en abrirse y desaparecer. En vivo.
@export_range(0.2, 5.0, 0.05, "suffix:s") var ripple_lifetime := 1.4
## Opacidad de las ondas (0-1). En vivo.
@export_range(0.0, 1.0, 0.01) var ripple_opacity := 0.75
## Burbujas bajo el agua mientras bucea. En vivo.
@export var bubbles_enabled := true

@export_group("Mojado")
## Al mojarse el jugador se oscurece (pelaje mojado) y vuelve a su color poco a poco despues de salir. Afecta solo a
## este personaje: sus materiales se duplican al empezar. En vivo.
@export var wet_enabled := true
## Color por el que se multiplica el del modelo cuando esta empapado. Mas oscuro = pelaje mas mojado; puede llevar un
## leve tono (azulado, frio...). Blanco = sin cambio. En vivo.
@export var wet_color := Color(0.62, 0.6, 0.62)
## 0-1: cuanto se oscurece caminando por agua poco honda (1 = como nadando). En vivo.
@export_range(0.0, 1.0, 0.01) var wet_wade_amount := 0.45
## Segundos en oscurecerse al entrar al agua. En vivo.
@export_range(0.0, 3.0, 0.05, "suffix:s") var wet_in_time := 0.3
## Segundos que sigue igual de mojado tras salir, antes de empezar a secarse. En vivo.
@export_range(0.0, 10.0, 0.1, "suffix:s") var wet_hold_time := 1.5
## Segundos en volver a su color normal una vez empieza a secarse. En vivo.
@export_range(0.1, 20.0, 0.1, "suffix:s") var wet_dry_time := 3.5

@export_group("Empapado")
## Al salir del agua el jugador gotea un rato: gotitas que caen del cuerpo y se van espaciando hasta parar. En vivo.
@export var drip_enabled := true
## Encendido (por defecto): gotea mientras dure el secado del grupo Mojado, cada vez menos segun se seca, haga lo que
## haga (caminar, correr, planear...). Apagado: gotea solo Drip Duration segundos al salir. En vivo.
@export var drip_while_wet := true
## Segundos que sigue goteando tras salir del agua, si Drip While Wet esta apagado (o Mojado desactivado). En vivo.
@export_range(0.2, 10.0, 0.1, "suffix:s") var drip_duration := 2.5
## Gotas por segundo justo al salir; bajan hasta 0 al final de Drip Duration. Coste: particulas de CPU, muy pocas.
## En vivo.
@export_range(1.0, 80.0, 1.0) var drip_rate := 22.0
## Tamano de cada gota, en metros (radio). En vivo.
@export_range(0.005, 0.1, 0.001, "suffix:m") var drip_size := 0.022
## Radio en metros de la zona del cuerpo de la que caen las gotas. Mayor = gotean tambien brazos y cola. En vivo.
@export_range(0.05, 1.0, 0.01, "suffix:m") var drip_spread := 0.28
## Altura en metros del centro del goteo sobre los pies (el cuerpo de la ardilla). En vivo.
@export_range(0.0, 1.5, 0.01, "suffix:m") var drip_height := 0.5
## Color de las gotas. En vivo.
@export var drip_color := Color(0.82, 0.93, 1.0, 0.9)

@export_subgroup("Cabeza")
## Gotas que caen tambien de la zona del hocico mientras dura el goteo, siguiendo la cabeza. Usa el mismo ritmo de secado
## y el mismo Drip Color que el cuerpo; apagar Drip Enabled tambien las apaga. En vivo.
@export var drip_head_enabled := true
## Nombre del hueso que siguen las gotas. Si no existe en el esqueleto, el hocico no gotea. En vivo.
@export var drip_head_bone := "head"
## Gotas por segundo de la cabeza justo al salir; bajan a la vez que las del cuerpo. Mayor = cabeza mas chorreante.
## Coste: particulas de CPU, muy pocas. En vivo.
@export_range(0.0, 60.0, 0.5) var drip_head_rate := 8.0
## Tamano de cada gota de la cabeza, en metros (radio). Independiente de Drip Size. En vivo.
@export_range(0.005, 0.1, 0.001, "suffix:m") var drip_head_size := 0.035
## Tamano en metros de la caja de la que nacen las gotas: X ancho, Y alto, Z fondo. Mayor = gotas mas repartidas por la
## cara; menor = concentradas junto a la nariz. En vivo.
@export var drip_head_zone_size := Vector3(0.18, 0.12, 0.08)
## Centro de esa caja respecto al hueso, en metros y ejes del personaje: X derecha, Y arriba, Z negativa hacia delante.
## Gira con la cabeza. Colocala con Drip Head Show Zone. En vivo.
@export var drip_head_offset := Vector3(0.0, 0.12, -0.2)
## Muestra en juego la zona como una caja roja translucida, visible a traves del modelo, para colocarla sobre el hocico.
## Solo para ajustar; dejala apagada al terminar. En vivo.
@export var drip_head_show_zone := false

@export_group("Audio del agua")
## Sonido del chapuzon al caer al agua y, mas suave y agudo, al saltar fuera. Vacio = chapuzon generado por codigo. En vivo.
@export var splash_sound: AudioStream = preload("res://audio/water/diving_splash.wav")
## Volumen de chapuzones y salpicaduras, en dB (bus SFX). Las caidas suaves suenan mas bajo y agudo. En vivo.
@export_range(-40.0, 6.0, 0.5, "suffix:dB") var splash_volume_db := -6.0
## Sonidos de brazada en superficie. Se reproducen uno por brazada segun Stroke Order. Vacio = brazada generada por
## codigo. Anade o quita sonidos libremente. En vivo.
@export var stroke_sounds: Array[AudioStream] = [
	preload("res://audio/water/swim_1.wav"), preload("res://audio/water/swim_2.wav"),
	preload("res://audio/water/swim_3.wav"), preload("res://audio/water/swim_4.wav"),
	preload("res://audio/water/swim_5.wav"),
]
## Secuencial: recorre la lista en orden y vuelve a empezar. Aleatorio: elige uno al azar sin repetir el anterior.
## Aleatorio (puede repetir): al azar entre todos, hasta Stroke Max Repeats veces seguidas el mismo. En vivo.
@export_enum("Secuencial", "Aleatorio", "Aleatorio (puede repetir)") var stroke_order := 0
## Con Aleatorio (puede repetir): veces seguidas que puede sonar el mismo sonido. 1 = nunca repite (como Aleatorio);
## mayor = rachas mas largas posibles. En vivo.
@export_range(1, 6, 1) var stroke_max_repeats := 2
## Apagado: un sonido por ciclo completo de brazadas. Encendido: uno por cada brazo (el doble de seguido; los sonidos
## largos se solapan). En vivo.
@export var stroke_sound_each_arm := false
## Volumen de cada brazada en superficie, en dB. Menor que el chapuzon para no cansar. En vivo.
@export_range(-40.0, 6.0, 0.5, "suffix:dB") var stroke_volume_db := -12.0
## Variacion aleatoria de tono de cada brazada (0 = siempre igual; 0,1 = +-10 %). Evita que el ciclo suene mecanico.
## En vivo.
@export_range(0.0, 0.3, 0.01) var stroke_pitch_variation := 0.06
## Brazadas que pueden sonar a la vez. Si se llenan, la nueva corta la mas antigua. En vivo (al siguiente sonido).
@export_range(1, 6, 1) var stroke_voices := 3

@export_group("Audio del buceo")
## Sonido al empezar a bucear (mantener Planear). Vacio = sin sonido. En vivo.
@export var dive_start_sound: AudioStream = preload("res://audio/water/dive_start_underwater.wav")
## Volumen del inicio del buceo, en dB (bus SFX). En vivo.
@export_range(-40.0, 6.0, 0.5, "suffix:dB") var dive_start_volume_db := -8.0
## Encendido: suena solo al hundirse desde la superficie. Apagado: tambien al volver a pulsar Planear ya bajo el agua.
## En vivo.
@export var dive_start_from_surface_only := true
## Segundos minimos entre dos sonidos de inicio, para que pulsar seguido no lo repita. En vivo.
@export_range(0.0, 3.0, 0.05, "suffix:s") var dive_start_cooldown := 0.8
## Brazadas con sonido bajo el agua. Apagado = bajo el agua solo suenan el inicio del buceo y el ambiente. En vivo.
@export var dive_stroke_sounds_enabled := true
## Sonidos de brazada bajo el agua (braza), pasados por el efecto submarino (grupo Audio del buceo · efecto). Uno por
## ciclo de brazadas mientras bucea o nada sumergida. Por defecto, las brazadas de superficie 1, 2, 3 y 5; en
## audio/water/ quedan tambien dive_stroke_1/2. Vacio = sin sonido. Anade o quita sonidos libremente. En vivo.
@export var dive_stroke_sounds: Array[AudioStream] = [
	preload("res://audio/water/swim_1.wav"), preload("res://audio/water/swim_2.wav"),
	preload("res://audio/water/swim_3.wav"), preload("res://audio/water/swim_5.wav"),
]
## Secuencial: alterna en orden. Aleatorio: al azar sin repetir el anterior (con dos sonidos alterna 1, 2, 1, 2).
## Aleatorio (puede repetir): al azar entre todos, hasta Dive Stroke Max Repeats veces seguidas el mismo. En vivo.
@export_enum("Secuencial", "Aleatorio", "Aleatorio (puede repetir)") var dive_stroke_order := 0
## Con Aleatorio (puede repetir): veces seguidas que puede sonar el mismo sonido. 1 = nunca repite (como Aleatorio);
## mayor = rachas mas largas posibles. En vivo.
@export_range(1, 6, 1) var dive_stroke_max_repeats := 2
## Volumen de cada brazada bajo el agua, en dB. En vivo.
@export_range(-40.0, 6.0, 0.5, "suffix:dB") var dive_stroke_volume_db := -12.0
## Variacion aleatoria de tono de cada brazada bajo el agua (0 = siempre igual). En vivo.
@export_range(0.0, 0.3, 0.01) var dive_stroke_pitch_variation := 0.05
## Aceleracion aleatoria de cada brazada bajo el agua, sin cambiar su tono: a veces el sonido va mas rapido (mas corto),
## nunca mas lento. 0 = siempre a velocidad normal; 0,2 = entre normal y un 20 % mas rapido. Combinable con Dive Stroke
## Pitch Variation. Coste: un efecto de cambio de tono por voz, solo mientras suena. En vivo.
@export_range(0.0, 0.5, 0.01) var dive_stroke_speed_variation := 0.2
## Variacion del ritmo entre brazadas bajo el agua (0 = ritmo fijo; 0,2 = cada brazada llega hasta un 20 % antes o
## despues). Cambia tambien la animacion de la braza. Se sortea al empezar cada brazada. En vivo.
@export_range(0.0, 0.5, 0.01) var dive_stroke_rhythm_variation := 0.0

@export_group("Audio del buceo · efecto")
## Efecto submarino sobre las brazadas de buceo (filtro, tono y eco). Apagalo para oir los sonidos tal cual. En vivo.
@export var underwater_effect_enabled := true
## Intensidad del efecto en las brazadas de buceo (0-1). 1 = los valores de abajo tal cual; 0,3 = solo un toque (corte
## mas alto, tono casi igual, poco eco). Util con sonidos que ya son submarinos. En vivo.
@export_range(0.0, 1.0, 0.01) var dive_stroke_effect_amount := 1.0
## Pasa tambien el sonido de inicio del buceo por el efecto submarino. En vivo.
@export var dive_start_effect_enabled := false
## Intensidad del efecto en el inicio del buceo (0-1), si Dive Start Effect Enabled esta encendido. En vivo.
@export_range(0.0, 1.0, 0.01) var dive_start_effect_amount := 0.4
## Frecuencia en Hz por encima de la cual se apaga el sonido, como al oir bajo el agua. Menor = mas sordo y lejano
## (300-600); mayor = mas claro (1500+). En vivo.
@export_range(100.0, 8000.0, 10.0, "suffix:Hz") var underwater_cutoff_hz := 700.0
## Resonancia del filtro junto al corte (0-1). Mayor da un tono mas "burbujeante" y hueco. En vivo.
@export_range(0.0, 1.0, 0.01) var underwater_resonance := 0.5
## Tono bajo el agua (1 = igual; 0,85 = mas grave y algo mas lento). En vivo.
@export_range(0.5, 1.5, 0.01) var underwater_pitch := 0.85
## Eco (0-1): cuanto suena la reverberacion de agua cerrada. 0 = seco. En vivo.
@export_range(0.0, 1.0, 0.01) var underwater_reverb := 0.25
## Tamano del espacio del eco (0-1). Mayor = cola mas larga, como un lago hondo. En vivo.
@export_range(0.0, 1.0, 0.01) var underwater_reverb_size := 0.45

@export_group("Ambiente submarino")
## Sonido ambiente en bucle mientras el jugador esta bajo el agua (solo el jugador, no los NPC). En vivo.
@export var underwater_ambience_enabled := true
## Bucle de ambiente submarino. Debe estar importado con Loop Mode = Forward (underwater_ambience_loop.wav ya lo esta).
## Vacio = sin ambiente. En vivo.
@export var underwater_ambience: AudioStream = preload("res://audio/water/underwater_ambience_loop.wav")
## Volumen del ambiente en dB (bus SFX). En vivo.
@export_range(-40.0, 12.0, 0.5, "suffix:dB") var underwater_ambience_volume_db := 0.0
## Segundos para aparecer al sumergirse. En vivo.
@export_range(0.0, 5.0, 0.05, "suffix:s") var underwater_ambience_fade_in := 0.6
## Segundos para desaparecer al salir a la superficie. En vivo.
@export_range(0.0, 5.0, 0.05, "suffix:s") var underwater_ambience_fade_out := 0.9
## Empieza el bucle en un punto al azar cada vez, para que no suene siempre igual al sumergirse. En vivo.
@export var underwater_ambience_random_start := true

const RIPPLE_SHADER := preload("res://shaders/water/water_ripple.gdshader")
const RIPPLE_POOL := 14

var actor: ExplorerPlayer
## Nadando (en superficie o bajo el agua).
var active := false
## Cabeza bajo la superficie.
var submerged := false
## Planear mantenido en el agua (bajando).
var diving := false
## Altura de la superficie del agua actual.
var surface_y := 0.0
## Corriente que arrastra al nadador, m/s.
var flow := Vector3.ZERO
## Fase 0-1 del ciclo de brazadas.
var stroke_phase := 0.0
## 0-1: intensidad de las brazadas (stick).
var stroke_weight := 0.0
## Velocidad vertical, para inclinar el cuerpo al bucear.
var vertical_speed := 0.0
## Segundos de aire restantes.
var air_left := 20.0
## 0-1 para una futura interfaz.
var air_ratio := 1.0
## Cuerpo de agua actual (WaterBody) o null.
var water_body: Node

var _clock := 0.0
var _press_time := -1.0
var _shared_press := false
var _dive_hold := false
var _out_of_air := false
var _reentry_left := 0.0
var _ripple_left := 0.0
var _saved_snap := 0.35
var _effects: Node3D
var _ripples: Array[MeshInstance3D] = []
var _ripple_ages: PackedFloat32Array = []
var _ripple_life: PackedFloat32Array = []
var _next_ripple := 0
var _bubbles: CPUParticles3D
var _voices: Array[AudioStreamPlayer] = []
var _stroke_voices: Array[AudioStreamPlayer] = []
var _next_stroke_voice := 0
var _stroke_index := -1
var _dive_stroke_index := -1
# Times in a row the current stroke sound has played (surface, underwater).
var _stroke_streak := 0
var _dive_stroke_streak := 0
var _stroke_tempo := 1.0
var _dive_voices: Array[AudioStreamPlayer] = []
var _dive_start_voice: AudioStreamPlayer
var _ambience_player: AudioStreamPlayer
# 0-1 fade of the underwater ambience.
var _ambience_level := 0.0
var _next_dive_voice := 0
var _was_diving := false
var _drips: CPUParticles3D
var _head_drips: CPUParticles3D
var _head_zone_preview: MeshInstance3D
## 0-1: cuanto de mojado esta el pelaje ahora.
var wetness := 0.0
var _wet_target := 0.0
var _wet_hold_left := 0.0
var _wet_materials: Array[BaseMaterial3D] = []
var _wet_base_colors: Array[Color] = []
var _wet_applied := -1.0
var _drip_left := 0.0
var _plunge_left := 0.0
var _wave_left := 0.0
var _air_tap_time := -1.0
var _dive_start_left := 0.0
var _fallback_splash: AudioStreamWAV
var _fallback_stroke: AudioStreamWAV

func _ready() -> void:
	_fallback_splash = _make_splash(0.55, 11)
	_fallback_stroke = _make_splash(0.16, 23)
	for i in 3:
		var voice := AudioStreamPlayer.new()
		voice.bus = "SFX"
		add_child(voice)
		_voices.append(voice)

func _process(delta: float) -> void:
	_tick_ripples(delta)
	_tick_drips(delta)
	_tick_head_zone_preview()
	_tick_wet(delta)
	_tick_ambience(delta)

## Underwater ambience loop: fades in while the player is under the surface and out when it comes up, then stops.
func _tick_ambience(delta: float) -> void:
	var wanted := underwater_ambience_enabled and underwater_ambience != null and active and submerged 		and actor != null and not is_instance_valid(actor.command_source) and DisplayServer.get_name() != "headless"
	var fade := underwater_ambience_fade_in if wanted else underwater_ambience_fade_out
	_ambience_level = move_toward(_ambience_level, 1.0 if wanted else 0.0, delta / maxf(fade, 0.001))
	if _ambience_level <= 0.0:
		if _ambience_player != null and _ambience_player.playing:
			_ambience_player.stop()
		return
	if _ambience_player == null:
		_ambience_player = AudioStreamPlayer.new()
		_ambience_player.bus = "SFX"
		add_child(_ambience_player)
	if _ambience_player.stream != underwater_ambience:
		_ambience_player.stream = underwater_ambience
	if not _ambience_player.playing:
		var start := 0.0
		if underwater_ambience_random_start and underwater_ambience != null:
			start = randf() * maxf(underwater_ambience.get_length() - 1.0, 0.0)
		_ambience_player.play(start)
	_ambience_player.volume_db = underwater_ambience_volume_db + linear_to_db(maxf(_ambience_level, 0.0001))

func reset() -> void:
	if active:
		_set_active(false)
	_drip_left = 0.0
	_end_dive_jump()
	_plunge_left = 0.0
	_air_tap_time = -1.0
	diving = false
	_was_diving = false
	submerged = false
	_press_time = -1.0
	_dive_hold = false
	_out_of_air = false
	_reentry_left = 0.0
	air_left = air_seconds
	air_ratio = 1.0
	if is_instance_valid(_bubbles):
		_bubbles.emitting = false

## True si un punto del mundo esta bajo la superficie de un agua nadable.
## Air dive (clavado). Called by ExplorerPlayer every airborne frame with this frame's Brincar / Planear presses. Gamepad:
## Brincar in the air over water dives at once. Keyboard (one key for both): a tap shorter than Key Hold Time dives, a
## longer hold keeps gliding.
func tick_air_dive(delta: float, grounded: bool, jump_pressed: bool, glide_pressed: bool) -> void:
	if grounded or active or actor.is_climbing or not dive_jump_enabled or not swim_enabled:
		_end_dive_jump()
		_air_tap_time = -1.0
		return
	if actor.is_water_diving:
		return
	if jump_pressed and glide_pressed:
		_air_tap_time = 0.0
	elif jump_pressed:
		_start_dive_jump()
		return
	if _air_tap_time >= 0.0:
		_air_tap_time += delta
		if not actor.action_pressed("jump"):
			if _air_tap_time < key_hold_time:
				_start_dive_jump()
			_air_tap_time = -1.0
		elif _air_tap_time >= key_hold_time:
			_air_tap_time = -1.0

## True when there is swimmable water below the feet, at least Min Height down and with nothing solid in between.
func water_below() -> bool:
	var feet := actor.global_position
	var water := WaterBody.find_water(actor.get_tree(), feet, dive_jump_reach)
	if water.is_empty() or feet.y - water.surface < dive_jump_min_height:
		return false
	var query := PhysicsRayQueryParameters3D.create(feet, Vector3(feet.x, water.surface + 0.05, feet.z), 1, [actor.get_rid()])
	return actor.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _start_dive_jump() -> void:
	if not water_below():
		return
	actor.is_water_diving = true
	actor.is_gliding = false
	actor.glide_button_pressed_in_air = false
	var facing := Vector3.FORWARD.rotated(Vector3.UP, actor.model.rotation.y) if actor.model else Vector3.FORWARD
	actor.velocity += facing * dive_jump_forward_boost

func _end_dive_jump() -> void:
	if actor and actor.is_water_diving:
		actor.is_water_diving = false

func is_in_water_at(point: Vector3) -> bool:
	if not swim_enabled or not actor or not actor.is_inside_tree():
		return false
	var water := WaterBody.find_water(actor.get_tree(), point, 0.0)
	return not water.is_empty()

## Fisica del nado. Devuelve true si este frame lo controla el nado (el jugador no ejecuta su movimiento normal).
func tick(delta: float) -> bool:
	_clock += delta
	_reentry_left = maxf(0.0, _reentry_left - delta)
	if not swim_enabled or actor.is_climbing:
		if active:
			_set_active(false)
		return false
	var feet := actor.global_position
	var water := WaterBody.find_water(actor.get_tree(), feet + Vector3.UP * 0.05, 0.5)
	if water.is_empty():
		if active:
			_set_active(false)
		_refill_air(delta)
		return false
	surface_y = water.surface
	water_body = water.body
	var depth := surface_y - feet.y
	if not active:
		if depth < enter_depth or (_reentry_left > 0.0 and actor.velocity.y > 0.0):
			_refill_air(delta)
			if depth > 0.03 and actor.is_on_floor():
				_wade_waves(Vector3(feet.x, surface_y, feet.z), delta)
			return false
		_enter()
	elif actor.is_on_floor() and depth < exit_depth and not diving:
		_set_active(false)
		return false
	flow = water.flow * current_push
	submerged = feet.y < surface_y - float_depth - 0.4
	var at_surface := feet.y > surface_y - float_depth - 0.25
	var jump_request := _read_buttons(delta)
	if jump_request and at_surface and not submerged:
		_leap()
		return false
	_tick_air(delta)
	_plunge_left = maxf(0.0, _plunge_left - delta)
	diving = dive_enabled and (_dive_hold or _plunge_left > 0.0) and not _out_of_air
	_dive_start_left = maxf(0.0, _dive_start_left - delta)
	if diving and not _was_diving and (not submerged or not dive_start_from_surface_only) and _dive_start_left <= 0.0:
		_dive_start_left = dive_start_cooldown
		if dive_start_sound != null:
			_play_dive_start()
	_was_diving = diving

	var stick := actor.movement_input()
	var intent := minf(stick.length(), 1.0)
	var yaw := actor.camera_rig.rotation.y if actor.camera_rig else 0.0
	var desired := Vector3(stick.x, 0.0, stick.y).rotated(Vector3.UP, yaw)
	var sprint := actor.action_pressed("sprint")
	var top_speed := dive_swim_speed if submerged or diving else (swim_sprint_speed if sprint else swim_speed)
	# Swimming happens relative to the water: the current is added on top.
	var planar := Vector3(actor.velocity.x, 0.0, actor.velocity.z)
	var relative := planar - flow
	relative = relative.move_toward(desired * top_speed, (swim_acceleration if intent > 0.05 else swim_drag) * delta)
	planar = relative + flow

	var float_y := surface_y - float_depth + sin(_clock * TAU * bob_speed) * bob_height
	# Ride the swell when the water surface moves (WaterStyle › Movimiento de la superficie).
	if is_instance_valid(water_body):
		float_y += WaterBody.swell_at(Vector2(feet.x, feet.z), water_body.style)
	var vy := actor.velocity.y
	var target_vy: float
	if diving:
		target_vy = -dive_speed
	elif submerged and actor.action_pressed("jump") and not _shared_press:
		target_vy = swim_up_speed
	else:
		target_vy = clampf((float_y - feet.y) * float_response, -rise_speed, rise_speed)
	if jump_request and not at_surface:
		vy = maxf(vy, 0.0) + up_stroke_impulse
	# Falling in: water brakes the plunge quickly instead of stopping it dead.
	var drag := entry_drag * (dive_jump_entry_drag_scale if _plunge_left > 0.0 else 1.0)
	var response := drag if vy < target_vy - 1.0 else vertical_response
	vy = lerpf(vy, target_vy, 1.0 - exp(-response * delta))
	# Never pop out of the water by buoyancy alone.
	if not diving and feet.y + vy * delta > float_y + 0.2 and vy > 0.0:
		vy = (float_y + 0.2 - feet.y) / delta
	vertical_speed = vy

	actor.velocity = Vector3(planar.x, vy, planar.z)
	var before := actor.global_position
	actor.move_and_slide()
	var actual := (actor.global_position - before) / maxf(delta, 0.001)
	var actual_planar := Vector3(actual.x, 0.0, actual.z)
	var relative_planar := actual_planar - flow
	actor.horizontal_speed = relative_planar.length()
	actor.motion_acceleration = Vector3.ZERO
	actor.previous_motion = actual_planar
	actor.fall_peak_y = actor.global_position.y
	_face(desired if intent > 0.05 else relative_planar, intent, delta)
	_advance_strokes(intent, sprint, delta)
	_tick_effects(actual_planar, delta)
	actor.animator.tick(delta, actor.horizontal_speed)
	return true

func _enter() -> void:
	var impact := maxf(0.0, -actor.velocity.y)
	var headfirst := actor.is_water_diving
	_end_dive_jump()
	_set_active(true)
	_press_time = -1.0
	_shared_press = false
	_dive_hold = false
	_plunge_left = dive_jump_plunge_time if headfirst else 0.0
	if real_waves_enabled:
		var wave := clampf(impact / maxf(splash_full_speed, 0.1), 0.2, 1.0) * real_wave_entry_strength * (0.75 if headfirst else 1.0)
		WaterBody.add_wave(Vector3(actor.global_position.x, surface_y, actor.global_position.z), wave)
		_wave_left = 0.35
	if impact >= splash_min_speed:
		var strength := clampf(impact / splash_full_speed, 0.15, 1.0) * (dive_jump_splash_scale if headfirst else 1.0)
		_splash(Vector3(actor.global_position.x, surface_y, actor.global_position.z), strength)
		_play(_splash_stream(), splash_volume_db + linear_to_db(lerpf(0.4, 1.0, strength)), lerpf(1.2, 0.9, strength))

func _set_active(value: bool) -> void:
	if active == value:
		return
	active = value
	actor.is_swimming = value
	if value:
		_saved_snap = actor.floor_snap_length
		actor.floor_snap_length = 0.0
		actor.is_gliding = false
		actor.is_glide_sprinting = false
		actor.glide_button_pressed_in_air = false
		actor.is_sliding = false
		actor.is_skating = false
		actor.jump_consumed = false
		actor.buffer_left = 0.0
		actor.coyote_left = 0.0
		actor.landing_time = 0.0
		stroke_weight = 0.0
	else:
		actor.floor_snap_length = _saved_snap
		diving = false
		_was_diving = false
		submerged = false
		_dive_hold = false
		_press_time = -1.0
		if is_instance_valid(_bubbles):
			_bubbles.emitting = false
		_drip_left = drip_duration if drip_enabled else 0.0
	swimming_changed.emit(value)

func _leap() -> void:
	var feet := actor.global_position
	_set_active(false)
	_reentry_left = reentry_delay
	actor.velocity.y = jump_velocity
	actor.jump_consumed = true
	actor.coyote_left = 0.0
	actor.buffer_left = 0.0
	actor.feedback.emit("jump")
	actor.animator.jump_started()
	_splash(Vector3(feet.x, surface_y, feet.z), 0.35)
	if real_waves_enabled:
		WaterBody.add_wave(Vector3(feet.x, surface_y, feet.z), 0.5 * real_wave_entry_strength)
	_play(_splash_stream(), splash_volume_db - 8.0, 1.25)

## Reads Brincar / Planear. Returns true on a jump request (tap). Keeps _dive_hold for a held Planear.
func _read_buttons(delta: float) -> bool:
	if actor.interaction_press_consumed:
		_press_time = -1.0
		_dive_hold = false
		return false
	var jump_pressed := actor.action_just_pressed("jump")
	var glide_pressed := actor.action_just_pressed("glide")
	var request := false
	if glide_pressed:
		# Same frame = same physical key (keyboard Space): tap jumps, hold dives.
		_shared_press = jump_pressed
		_press_time = 0.0
	elif jump_pressed:
		request = true
	if _press_time >= 0.0:
		if actor.action_pressed("glide"):
			_press_time += delta
			_dive_hold = not _shared_press or _press_time >= key_hold_time
		else:
			if _shared_press and _press_time < key_hold_time:
				request = true
			_press_time = -1.0
			_dive_hold = false
			_shared_press = false
	else:
		_dive_hold = false
	return request

func _tick_air(delta: float) -> void:
	if submerged and air_enabled:
		air_left = maxf(0.0, air_left - delta)
		if air_left <= 0.0:
			_out_of_air = true
	else:
		_refill_air(delta)
	air_ratio = air_left / maxf(air_seconds, 0.01)

func _refill_air(delta: float) -> void:
	air_left = minf(air_seconds, air_left + air_seconds / maxf(air_refill_time, 0.01) * delta)
	if air_left >= air_seconds * 0.5:
		_out_of_air = false
	air_ratio = air_left / maxf(air_seconds, 0.01)

func _face(direction: Vector3, intent: float, delta: float) -> void:
	var model := actor.model
	var facing := direction
	if intent <= 0.05 and flow.length() > 0.2:
		# Floating free: slowly turn to face downstream.
		facing = flow.normalized() * face_current
	if facing.length_squared() < 0.0004:
		actor.angular_velocity = 0.0
		return
	var target := atan2(-facing.x, -facing.z)
	var step := wrapf(target - model.rotation.y, -PI, PI) * (1.0 - exp(-swim_turn_speed * delta))
	model.rotation.y = wrapf(model.rotation.y + step, -PI, PI)
	actor.angular_velocity = step / maxf(delta, 0.001)

func _advance_strokes(intent: float, sprint: bool, delta: float) -> void:
	stroke_weight = lerpf(stroke_weight, intent, 1.0 - exp(-6.0 * delta))
	var rate := lerpf(tread_stroke_rate, stroke_rate * (sprint_stroke_multiplier if sprint else 1.0), stroke_weight)
	# Underwater each breaststroke keeps its own random tempo, picked when the previous one ends.
	if submerged:
		rate *= _stroke_tempo
	var previous := stroke_phase
	stroke_phase += rate * delta
	if floor(stroke_phase) > floor(previous):
		_stroke_tempo = 1.0 + randf_range(-dive_stroke_rhythm_variation, dive_stroke_rhythm_variation)
	var beats := 2.0 if stroke_sound_each_arm else 1.0
	if not submerged and not diving and stroke_weight > 0.3 and floor(stroke_phase * beats) > floor(previous * beats):
		_play_stroke(false)
	# Underwater the breaststroke moves both arms together: one sound per cycle, also while diving without the stick.
	elif dive_stroke_sounds_enabled and submerged and (stroke_weight > 0.3 or diving) and floor(stroke_phase) > floor(previous):
		_play_stroke(true)
	stroke_phase = fposmod(stroke_phase, 1.0)

# --- Effects ---------------------------------------------------------------------------------------------------------

func _ensure_effects() -> bool:
	if not effects_enabled or not actor.is_inside_tree():
		return false
	if is_instance_valid(_effects):
		return true
	_effects = Node3D.new()
	_effects.name = "SwimEffects"
	_effects.top_level = true
	add_child(_effects)
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	for i in RIPPLE_POOL:
		var ring := MeshInstance3D.new()
		ring.mesh = plane
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := ShaderMaterial.new()
		material.shader = RIPPLE_SHADER
		# After the water surfaces (lakes 0, rivers 1) and the swimmer reveal (2).
		material.render_priority = 3
		ring.material_override = material
		ring.visible = false
		_effects.add_child(ring)
		_ripples.append(ring)
		_ripple_ages.append(1.0)
		_ripple_life.append(1.0)
	_bubbles = CPUParticles3D.new()
	_bubbles.emitting = false
	_bubbles.amount = 10
	_bubbles.lifetime = 1.6
	_bubbles.local_coords = false
	var bubble_mesh := SphereMesh.new()
	bubble_mesh.radius = 0.035
	bubble_mesh.height = 0.07
	bubble_mesh.radial_segments = 8
	bubble_mesh.rings = 4
	bubble_mesh.material = _droplet_material(0.75)
	_bubbles.mesh = bubble_mesh
	_bubbles.direction = Vector3.UP
	_bubbles.spread = 25.0
	_bubbles.gravity = Vector3(0.0, 1.5, 0.0)
	_bubbles.initial_velocity_min = 0.3
	_bubbles.initial_velocity_max = 0.8
	_bubbles.scale_amount_min = 0.6
	_bubbles.scale_amount_max = 1.4
	_bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_bubbles.emission_sphere_radius = 0.12
	_effects.add_child(_bubbles)
	return true

## Pelaje mojado: oscurece los materiales del modelo mientras esta en el agua y los devuelve a su color al secarse.
func _tick_wet(delta: float) -> void:
	if actor == null or actor.model == null:
		return
	var soaking := 0.0
	if wet_enabled:
		if active:
			soaking = 1.0
		elif is_in_water_at(actor.global_position + Vector3.UP * 0.05):
			soaking = wet_wade_amount
	if soaking > 0.0:
		wetness = move_toward(wetness, maxf(wetness, soaking), delta / maxf(wet_in_time, 0.01))
		_wet_hold_left = wet_hold_time
	elif _wet_hold_left > 0.0:
		_wet_hold_left -= delta
	else:
		wetness = move_toward(wetness, 0.0, delta / maxf(wet_dry_time, 0.01))
	if not wet_enabled:
		wetness = 0.0
	if absf(wetness - _wet_applied) < 0.002 and wetness > 0.0:
		return
	if wetness <= 0.0 and _wet_applied <= 0.0:
		return
	_ensure_wet_materials()
	for i in _wet_materials.size():
		var base := _wet_base_colors[i]
		var tint := Color.WHITE.lerp(wet_color, wetness)
		_wet_materials[i].albedo_color = Color(base.r * tint.r, base.g * tint.g, base.b * tint.b, base.a)
	_wet_applied = wetness

## Duplicates the model's materials once, so darkening this character never changes others that share them.
func _ensure_wet_materials() -> void:
	if not _wet_materials.is_empty():
		return
	for mesh in actor.model.find_children("*", "MeshInstance3D", true, false):
		var instance := mesh as MeshInstance3D
		if instance.mesh == null:
			continue
		if instance.material_override is BaseMaterial3D:
			var own := (instance.material_override as BaseMaterial3D).duplicate() as BaseMaterial3D
			instance.material_override = own
			_wet_materials.append(own)
			_wet_base_colors.append(own.albedo_color)
			continue
		for surface in instance.mesh.get_surface_count():
			var material := instance.get_active_material(surface) as BaseMaterial3D
			if material == null:
				continue
			var own := material.duplicate() as BaseMaterial3D
			instance.set_surface_override_material(surface, own)
			_wet_materials.append(own)
			_wet_base_colors.append(own.albedo_color)

## Goteo tras salir del agua: emite desde el cuerpo, cada vez menos, durante Drip Duration. Se corta al volver al agua.
func _tick_drips(delta: float) -> void:
	if active or not drip_enabled:
		_drip_left = 0.0
	_drip_left = maxf(0.0, _drip_left - delta)
	# Tied to drying: drips keep falling while the fur is wet, fewer as it dries.
	var by_wetness := drip_while_wet and wet_enabled
	var ratio := 0.0
	if active or not drip_enabled:
		ratio = 0.0
	elif by_wetness:
		ratio = wetness
	else:
		ratio = clampf(_drip_left / maxf(drip_duration, 0.01), 0.0, 1.0)
	if ratio <= 0.0:
		_stop_drips(_drips)
		_stop_drips(_head_drips)
		return
	if actor == null or not actor.is_inside_tree():
		return
	_drips = _drip_emitter(_drips, "Drips", CPUParticles3D.EMISSION_SHAPE_SPHERE)
	_apply_drip_look(_drips, drip_size, drip_rate)
	_drips.emission_sphere_radius = drip_spread
	_drips.position = Vector3(0.0, drip_height, 0.0)
	# Cada vez menos gotas hasta parar: el emisor se enciende en una fraccion de los frames que baja con el tiempo, lo que
	# ademas da el goteo irregular de un pelaje mojado. Las gotas ya sueltas terminan su caida.
	_drips.emitting = randf() < ratio
	_tick_head_drips(ratio)

## Gotas del hocico: el emisor sigue a la cabeza cada frame y las gotas, en coordenadas de mundo, caen por su cuenta.
func _tick_head_drips(ratio: float) -> void:
	var bone := _head_drip_bone() if drip_head_enabled and drip_head_rate > 0.0 else -1
	if bone < 0:
		_stop_drips(_head_drips)
		return
	_head_drips = _drip_emitter(_head_drips, "HeadDrips", CPUParticles3D.EMISSION_SHAPE_BOX)
	_apply_drip_look(_head_drips, drip_head_size, drip_head_rate)
	_head_drips.emission_box_extents = drip_head_zone_size.abs() * 0.5
	var zone := _head_drip_zone(bone)
	_head_drips.global_transform = zone
	# The zone turns with the face, but the drops must still fall straight down.
	_head_drips.direction = zone.basis.inverse() * Vector3.DOWN
	_head_drips.emitting = randf() < ratio

func _head_drip_bone() -> int:
	if actor == null or not actor.is_inside_tree() or not is_instance_valid(actor.model):
		return -1
	var skeleton := actor.model.playertest2_skeleton
	return skeleton.find_bone(drip_head_bone) if skeleton != null else -1

## Transform de la zona de goteo: posicion del hueso mas el offset, girado con el personaje y con lo que la cabeza se
## aparte de su pose de reposo.
func _head_drip_zone(bone: int) -> Transform3D:
	var skeleton := actor.model.playertest2_skeleton
	var pose := skeleton.get_bone_global_pose(bone)
	var rest := skeleton.get_bone_global_rest(bone)
	var rig := skeleton.global_basis.orthonormalized()
	var head_turn := rig * (pose.basis.orthonormalized() * rest.basis.orthonormalized().inverse()) * rig.inverse()
	var axes := head_turn * actor.model.global_basis.orthonormalized()
	return Transform3D(axes, skeleton.global_transform * pose.origin + axes * drip_head_offset)

func _tick_head_zone_preview() -> void:
	var bone := _head_drip_bone() if drip_head_show_zone else -1
	if bone < 0:
		if is_instance_valid(_head_zone_preview):
			_head_zone_preview.visible = false
		return
	if not is_instance_valid(_head_zone_preview):
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(1.0, 0.1, 0.1, 0.45)
		material.no_depth_test = true
		var box := BoxMesh.new()
		box.material = material
		_head_zone_preview = MeshInstance3D.new()
		_head_zone_preview.name = "HeadDripZonePreview"
		_head_zone_preview.mesh = box
		_head_zone_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		actor.add_child(_head_zone_preview)
	var box_mesh := _head_zone_preview.mesh as BoxMesh
	var wanted_size := drip_head_zone_size.abs()
	if box_mesh.size != wanted_size:
		box_mesh.size = wanted_size
	_head_zone_preview.visible = true
	_head_zone_preview.global_transform = _head_drip_zone(bone)

func _stop_drips(emitter: CPUParticles3D) -> void:
	if is_instance_valid(emitter):
		emitter.emitting = false

## Devuelve el emisor de goteo indicado, creandolo si aun no existe.
func _drip_emitter(current: CPUParticles3D, node_name: String, shape: CPUParticles3D.EmissionShape) -> CPUParticles3D:
	if is_instance_valid(current):
		return current
	var emitter := CPUParticles3D.new()
	emitter.name = node_name
	emitter.local_coords = false
	emitter.lifetime = 0.55
	emitter.emission_shape = shape
	emitter.direction = Vector3.DOWN
	emitter.spread = 25.0
	emitter.initial_velocity_min = 0.1
	emitter.initial_velocity_max = 0.5
	emitter.gravity = Vector3(0.0, -9.8, 0.0)
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(0.8, 0.9))
	shrink.add_point(Vector2(1.0, 0.0))
	emitter.scale_amount_curve = shrink
	actor.add_child(emitter)
	return emitter

## Valores en vivo comunes: tamano, color y ritmo.
func _apply_drip_look(emitter: CPUParticles3D, size: float, rate: float) -> void:
	var mesh := emitter.mesh as SphereMesh
	if mesh == null:
		mesh = SphereMesh.new()
		mesh.radial_segments = 8
		mesh.rings = 4
		emitter.mesh = mesh
	mesh.radius = size
	mesh.height = size * 2.6
	var material := mesh.material as StandardMaterial3D
	if material == null:
		material = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh.material = material
	material.albedo_color = drip_color
	var wanted := maxi(1, ceili(rate * emitter.lifetime))
	if emitter.amount != wanted:
		emitter.amount = wanted

func _droplet_material(alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(splash_color, alpha)
	if alpha < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material

func _tick_effects(motion: Vector3, delta: float) -> void:
	if not _ensure_effects():
		return
	var feet := actor.global_position
	var at_surface := not submerged
	if at_surface and real_waves_enabled:
		_wave_left -= delta
		var speed := motion.length()
		if _wave_left <= 0.0:
			var ratio := clampf(speed / maxf(swim_speed, 0.1), 0.0, 1.0)
			if speed >= real_wave_min_speed:
				WaterBody.add_wave(Vector3(feet.x, surface_y, feet.z), real_wave_swim_strength * lerpf(0.6, 1.0, ratio))
				_wave_left = real_wave_interval * lerpf(2.0, 1.0, ratio)
			elif real_wave_idle_strength > 0.0:
				WaterBody.add_wave(Vector3(feet.x, surface_y, feet.z), real_wave_idle_strength)
				_wave_left = 1.0 / maxf(bob_speed, 0.1)
	if at_surface and ripple_interval > 0.0:
		var speed_ratio := clampf(motion.length() / maxf(swim_speed, 0.1), 0.0, 1.0)
		_ripple_left -= delta
		if _ripple_left <= 0.0:
			_ripple_left = ripple_interval * lerpf(3.0, 1.0, speed_ratio)
			var ahead := Vector3.FORWARD.rotated(Vector3.UP, actor.model.rotation.y) * 0.5
			_ripple(Vector3(feet.x, surface_y, feet.z) + ahead, lerpf(0.7, 1.0, speed_ratio), 1.0)
	if is_instance_valid(_bubbles):
		var head := feet + Vector3.UP * 0.6 + Vector3.FORWARD.rotated(Vector3.UP, actor.model.rotation.y) * 0.5
		_bubbles.global_position = head
		_bubbles.emitting = bubbles_enabled and submerged

## Waves while walking through shallow water (not swimming).
func _wade_waves(point: Vector3, delta: float) -> void:
	if not real_waves_enabled:
		return
	_wave_left -= delta
	var speed := Vector2(actor.velocity.x, actor.velocity.z).length()
	if _wave_left <= 0.0 and speed >= real_wave_min_speed:
		var ratio := clampf(speed / maxf(actor.sprint_speed, 0.1), 0.0, 1.0)
		WaterBody.add_wave(point, real_wave_wade_strength * lerpf(0.6, 1.0, ratio))
		_wave_left = real_wave_interval * lerpf(2.0, 1.0, ratio)

func _tick_ripples(delta: float) -> void:
	for i in _ripples.size():
		if _ripple_ages[i] >= 1.0:
			continue
		_ripple_ages[i] = minf(1.0, _ripple_ages[i] + delta / maxf(_ripple_life[i], 0.01))
		var ring := _ripples[i]
		ring.visible = _ripple_ages[i] < 1.0
		(ring.material_override as ShaderMaterial).set_shader_parameter("age", _ripple_ages[i])

func _ripple(position: Vector3, size: float, opacity: float, fill := 0.0) -> void:
	if not ripples_enabled or not _ensure_effects():
		return
	var i := _next_ripple
	_next_ripple = (_next_ripple + 1) % _ripples.size()
	var ring := _ripples[i]
	ring.global_position = position + Vector3.UP * 0.03
	var diameter := ripple_radius * 2.0 * size
	ring.scale = Vector3(diameter, 1.0, diameter)
	ring.rotation.y = randf() * TAU
	var material := ring.material_override as ShaderMaterial
	material.set_shader_parameter("ring_color", splash_color)
	material.set_shader_parameter("opacity", ripple_opacity * opacity)
	material.set_shader_parameter("fill", fill)
	material.set_shader_parameter("age", 0.0)
	_ripple_ages[i] = 0.0
	_ripple_life[i] = ripple_lifetime * lerpf(0.8, 1.3, clampf(size - 1.0, 0.0, 1.0))
	ring.visible = true

func _splash(position: Vector3, strength: float) -> void:
	if not _ensure_effects():
		return
	var size := strength * splash_scale
	_ripple(position, 1.0 + size * 1.2, 1.0, 0.0)
	_ripple(position, 0.5 + size * 0.7, 1.0, 0.7)
	# Corona: gotas grandes que salen en anillo hacia arriba y afuera.
	var crown := _burst(maxi(6, int(splash_droplets * clampf(strength, 0.2, 1.0))), 0.45 + 0.45 * size, size * 0.6)
	crown.spread = 24.0
	crown.initial_velocity_min = 2.5 + 2.5 * size
	crown.initial_velocity_max = 4.0 + 5.0 * size
	crown.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	crown.emission_ring_axis = Vector3.UP
	crown.emission_ring_radius = 0.3 + 0.4 * size
	crown.emission_ring_inner_radius = 0.15
	crown.emission_ring_height = 0.05
	_fire(crown, position)
	# Columna central: pocas bolas gordas que suben recto.
	var plume := _burst(maxi(3, int(splash_droplets * 0.3 * clampf(strength, 0.3, 1.0))), 0.4 + 0.4 * size, size)
	plume.spread = 8.0
	plume.initial_velocity_min = 3.0 + 3.0 * size
	plume.initial_velocity_max = 4.5 + 6.0 * size
	plume.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	plume.emission_sphere_radius = 0.15
	_fire(plume, position)

func _burst(amount: int, lifetime: float, size: float) -> CPUParticles3D:
	var drops := CPUParticles3D.new()
	drops.one_shot = true
	drops.explosiveness = 0.92
	drops.amount = amount
	drops.lifetime = lifetime
	drops.local_coords = false
	var mesh := SphereMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.12
	mesh.radial_segments = 10
	mesh.rings = 5
	var material := _droplet_material(1.0)
	material.vertex_color_use_as_albedo = true
	mesh.material = material
	drops.mesh = mesh
	# Blanco al salir, celeste al caer: lee como agua y no como humo.
	var tint := Gradient.new()
	tint.set_color(0, Color.WHITE)
	tint.set_color(1, Color(0.72, 0.88, 1.0))
	drops.color_ramp = tint
	drops.direction = Vector3.UP
	drops.gravity = Vector3(0.0, -16.0, 0.0)
	drops.scale_amount_min = 0.6 + 0.4 * size
	drops.scale_amount_max = 1.1 + 1.2 * size
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(0.6, 0.8))
	shrink.add_point(Vector2(1.0, 0.0))
	drops.scale_amount_curve = shrink
	return drops

func _fire(drops: CPUParticles3D, position: Vector3) -> void:
	_effects.add_child(drops)
	drops.global_position = position + Vector3.UP * 0.05
	drops.emitting = true
	get_tree().create_timer(drops.lifetime + 0.2, false).timeout.connect(drops.queue_free)

# --- Audio -----------------------------------------------------------------------------------------------------------

func _play(stream: AudioStream, volume_db: float, pitch: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	for voice in _voices:
		if not voice.playing:
			voice.stream = stream
			voice.volume_db = volume_db
			voice.pitch_scale = pitch
			voice.play()
			return

func _splash_stream() -> AudioStream:
	return splash_sound if splash_sound != null else _fallback_splash

## Next stroke sound (sequential or random without repeating) on its own voices, so splashes are never cut. Underwater
## strokes use the dive list and keep their own place in it.
func _play_stroke(underwater: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var sounds: Array[AudioStream] = []
	for sound in (dive_stroke_sounds if underwater else stroke_sounds):
		if sound != null:
			sounds.append(sound)
	var stream: AudioStream = null if underwater else _fallback_stroke
	if not sounds.is_empty():
		var previous := _dive_stroke_index if underwater else _stroke_index
		var streak := _dive_stroke_streak if underwater else _stroke_streak
		var order := dive_stroke_order if underwater else stroke_order
		var max_repeats := dive_stroke_max_repeats if underwater else stroke_max_repeats
		var index := _next_sound_index(previous, sounds.size(), order, streak, max_repeats)
		streak = streak + 1 if index == previous else 1
		if underwater:
			_dive_stroke_index = index
			_dive_stroke_streak = streak
		else:
			_stroke_index = index
			_stroke_streak = streak
		stream = sounds[index]
	if stream == null:
		return
	if underwater:
		_play_dive_stroke(stream)
		return
	while _stroke_voices.size() < stroke_voices:
		var voice := AudioStreamPlayer.new()
		voice.bus = "SFX"
		add_child(voice)
		_stroke_voices.append(voice)
	var count := mini(stroke_voices, _stroke_voices.size())
	var player := _stroke_voices[_next_stroke_voice % count]
	_next_stroke_voice = (_next_stroke_voice + 1) % count
	player.stream = stream
	var variation := dive_stroke_pitch_variation if underwater else stroke_pitch_variation
	player.volume_db = dive_stroke_volume_db if underwater else stroke_volume_db
	player.pitch_scale = 1.0 + randf_range(-variation, variation)
	player.play()

## Underwater stroke at a random speed with the same pitch: the player speeds the sound up (pitch_scale) and a pitch
## shift on that voice's own bus brings the pitch back. Each voice has its own bus so overlapping strokes do not share
## one correction.
func _play_dive_stroke(stream: AudioStream) -> void:
	var count := clampi(stroke_voices, 1, 6)
	while _dive_voices.size() < count:
		var voice := AudioStreamPlayer.new()
		voice.bus = _dive_voice_bus(StringName("SwimDiveVoice%d" % _dive_voices.size()))
		add_child(voice)
		_dive_voices.append(voice)
	var player := _dive_voices[_next_dive_voice % count]
	_next_dive_voice = (_next_dive_voice + 1) % count
	var speed := 1.0 + randf_range(0.0, dive_stroke_speed_variation)
	var pitch := 1.0 + randf_range(-dive_stroke_pitch_variation, dive_stroke_pitch_variation)
	var amount := dive_stroke_effect_amount if underwater_effect_enabled else 0.0
	pitch *= _set_voice_effects(player.bus, speed, amount)
	player.stream = stream
	player.volume_db = dive_stroke_volume_db
	player.pitch_scale = speed * pitch
	player.play()

## Start of a dive: plain, or through the underwater effect at Dive Start Effect Amount on its own voice.
func _play_dive_start() -> void:
	if dive_start_sound == null or DisplayServer.get_name() == "headless":
		return
	if not dive_start_effect_enabled or dive_start_effect_amount <= 0.0:
		_play(dive_start_sound, dive_start_volume_db, 1.0)
		return
	if _dive_start_voice == null:
		_dive_start_voice = AudioStreamPlayer.new()
		_dive_start_voice.bus = _dive_voice_bus(&"SwimDiveStart")
		add_child(_dive_start_voice)
	var pitch := _set_voice_effects(_dive_start_voice.bus, 1.0, dive_start_effect_amount)
	_dive_start_voice.stream = dive_start_sound
	_dive_start_voice.volume_db = dive_start_volume_db
	_dive_start_voice.pitch_scale = pitch
	_dive_start_voice.play()

## Sets the effects of an underwater voice bus: speed correction and the underwater effect blended by Amount (0 = clean,
## 1 = the Underwater values). Returns the pitch factor the voice must apply.
func _set_voice_effects(bus_name: StringName, speed: float, amount: float) -> float:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus < 0:
		return 1.0
	var shift := AudioServer.get_bus_effect(bus, 0) as AudioEffectPitchShift
	AudioServer.set_bus_effect_enabled(bus, 0, absf(speed - 1.0) > 0.005)
	if shift != null:
		shift.pitch_scale = 1.0 / speed
	var low := AudioServer.get_bus_effect(bus, 1) as AudioEffectLowPassFilter
	AudioServer.set_bus_effect_enabled(bus, 1, amount > 0.0)
	if low != null:
		# Blend in octaves from an open filter (16 kHz) down to the cutoff, so a small amount is a small change.
		low.cutoff_hz = 16000.0 * pow(underwater_cutoff_hz / 16000.0, amount)
		low.resonance = lerpf(0.5, underwater_resonance, amount)
	var reverb := AudioServer.get_bus_effect(bus, 2) as AudioEffectReverb
	AudioServer.set_bus_effect_enabled(bus, 2, amount > 0.0 and underwater_reverb > 0.0)
	if reverb != null:
		reverb.wet = underwater_reverb * amount
		reverb.room_size = underwater_reverb_size
	return lerpf(1.0, underwater_pitch, amount)

## Bus for one underwater stroke voice, created at runtime and sent to SFX. Effects: 0 pitch shift (speed variation),
## 1 low pass and 2 reverb (underwater effect). Shared by name between swimmers.
func _dive_voice_bus(bus_name: StringName) -> StringName:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return bus_name
	var bus := AudioServer.bus_count
	AudioServer.add_bus(bus)
	AudioServer.set_bus_name(bus, bus_name)
	AudioServer.set_bus_send(bus, &"SFX")
	var shift := AudioEffectPitchShift.new()
	shift.fft_size = AudioEffectPitchShift.FFT_SIZE_1024
	AudioServer.add_bus_effect(bus, shift)
	AudioServer.add_bus_effect(bus, AudioEffectLowPassFilter.new())
	var reverb := AudioEffectReverb.new()
	reverb.damping = 0.8
	reverb.dry = 1.0
	reverb.hipass = 0.1
	AudioServer.add_bus_effect(bus, reverb)
	return bus_name

## Order 0, sequential: the next one, wrapping. 1, random: any but the previous one. 2, random with repeats: any, but
## once the previous one has played Max Repeats times in a row it is left out.
func _next_sound_index(previous: int, size: int, order: int, streak: int, max_repeats: int) -> int:
	if order == 0 or size <= 1:
		return (previous + 1) % size if previous >= 0 and size > 0 else 0
	if previous < 0 or previous >= size:
		return randi_range(0, size - 1)
	if order == 2 and streak < max_repeats:
		return randi_range(0, size - 1)
	var pick := randi_range(0, size - 2)
	return pick + 1 if pick >= previous else pick

## Procedural splash (fallback when no sound is assigned): filtered noise burst with a quick attack and a bubbly tail.
func _make_splash(duration: float, seed_value: int) -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * duration)
	var samples := PackedByteArray()
	samples.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var low := 0.0
	var band := 0.0
	for i in count:
		var t := float(i) / rate
		var u := t / duration
		var noise := rng.randf_range(-1.0, 1.0)
		low = lerpf(low, noise, 0.25)
		band = lerpf(band, low, 0.5)
		var envelope := minf(1.0, t * 180.0) * pow(1.0 - u, 2.2)
		var bubble := sin(TAU * (380.0 + 900.0 * u) * t) * 0.25 * smoothstep(0.15, 0.4, u) * (1.0 - u)
		var value := ((low - band) * 1.6 + band * 0.6 + bubble) * envelope
		samples.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 24000))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = samples
	return stream
