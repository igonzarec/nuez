@tool
class_name SquirrelNPC
extends Node3D
## Base reutilizable: mismo ExplorerPlayer y animaciones, con órdenes independientes de Input.

signal feedback(kind: String)
enum ControlMode { PATROL, COMMANDS }
const PatrolPoint = preload("res://scripts/npc/patrol_point.gd")

@export_group("NPC · identidad")
## Nombre mostrado al hablar con este NPC. Cambiarlo no renombra nodos ni modifica el player. Se consulta al iniciar cada conversación.
@export var display_name := "Ardilla"

@export_group("NPC · diálogo")
## Permite hablar si hay texto, un jugador cercano y línea de visión. Usa E o el botón de interacción del mando y el globo existente del juego. En vivo.
@export var dialogue_enabled := true
## Texto de la conversación de este personaje. Vacío no ofrece interacción. Editable por instancia; se captura al abrir el diálogo. El globo conserva su paginación y sonido de voz existentes.
@export_multiline var dialogue_text := ""
## Distancia máxima entre el jugador y Body para hablar, en metros. Mayor permite iniciar desde más lejos. No atraviesa paredes. En vivo; la consulta se realiza cada 0,15 s.
@export_range(0.5, 8.0, 0.1, "suffix:m") var dialogue_reach := 2.8
## Altura del icono de conversación sobre los pies, en metros antes de Overall Size. Mayor lo eleva. Sólo el icono; el globo usa su seguimiento de personaje. En vivo.
@export_range(0.2, 5.0, 0.05, "suffix:m") var dialogue_prompt_height := 2.2
## Solicita orientación mutua durante el diálogo. Ambos esperan en su sitio, con animaciones activas. La mirada de cada actor se activa en Body > Mirada al interactuar y en el player. Se consulta al iniciar la conversación.
@export var face_on_dialogue := true

@export_group("NPC · gestos al hablar")
## Activa el aleteo suave de brazos mientras se escribe la voz del NPC. No mueve al actor. En vivo.
@export var talking_gesture_enabled := true
## Amplitud del aleteo en grados, limitada por Talking Arm Min/Max Degrees. Mayor abre y cierra más los brazos; 0 elimina la oscilación. En vivo.
@export_range(0.0, 60.0, 0.5, "suffix:°") var talking_arm_degrees := 10.0
## Ciclos de aleteo por segundo. Mayor mueve los brazos más rápido; 0 detiene la fase. En vivo.
@export_range(0.0, 8.0, 0.1, "suffix:Hz") var talking_arm_hz := 1.8
## Apertura inicial de los brazos al hablar, en grados, además del aleteo. Mayor separa los brazos del torso. En vivo.
@export_range(0.0, 60.0, 0.5, "suffix:°") var talking_arm_open_degrees := 8.0
## Apertura mínima al hablar, en grados respecto al reposo y simétrica para ambos brazos. Subir evita que se acerquen al torso; valores negativos permiten giro hacia dentro. Limita apertura más aleteo antes de la mezcla de entrada/salida, que vuelve al reposo. En vivo y en Preview Talking Gesture; si Min > Max se ordenan los límites.
@export_range(-90.0, 90.0, 0.5, "suffix:°") var talking_arm_min_degrees := 0.0
## Apertura máxima al hablar en grados respecto al reposo. Reducir limita cuánto se separan los brazos. Se combina con Min y con apertura más amplitud; ambos límites iguales fijan la apertura. No modifica proporciones. En vivo y en la previsualización; entrada/salida conserva la mezcla al reposo.
@export_range(-90.0, 90.0, 0.5, "suffix:°") var talking_arm_max_degrees := 60.0
## Segundos para entrar y salir suavemente del gesto. Mayor suaviza la transición; 0 cambia inmediatamente. En vivo.
@export_range(0.0, 1.0, 0.01, "suffix:s") var talking_gesture_blend_time := 0.18
## Previsualiza los gestos de brazos y cabeza en el editor sin iniciar conversación. Sólo editor; se suman a la pose de reposo.
@export var preview_talking_gesture := false

@export_group("NPC · cabeza al interactuar")
## Activa un movimiento suave de cabeza durante la conversación, también al esperar una página. No gira el cuerpo ni interrumpe la mirada al player. En vivo; Preview Talking Gesture permite verlo en el editor.
@export var interaction_head_enabled := true
## Amplitud máxima del giro lateral de cabeza en grados, a cada lado del reposo. Mayor acentúa el gesto; 0 elimina ese eje. En vivo, sin regeneración; conserva la escala de la cabeza.
@export_range(0.0, 30.0, 0.5, "suffix:°") var interaction_head_yaw_degrees := 4.0
## Amplitud máxima del gesto arriba/abajo en grados. Mayor marca más el asentimiento; 0 lo elimina. En vivo y en la previsualización.
@export_range(0.0, 30.0, 0.5, "suffix:°") var interaction_head_pitch_degrees := 2.5
## Amplitud máxima de inclinación de cabeza hacia los hombros, en grados. Mayor da más balanceo; 0 lo elimina. En vivo y en la previsualización.
@export_range(0.0, 20.0, 0.5, "suffix:°") var interaction_head_roll_degrees := 1.5
## Ciclos por segundo del movimiento de cabeza, independientes del aleteo. Mayor acelera; 0 detiene el avance de la fase. En vivo; los ejes se desfasan para evitar un movimiento rígido.
@export_range(0.0, 5.0, 0.05, "suffix:Hz") var interaction_head_hz := 0.6
## Segundos para entrar y salir del gesto de cabeza. Mayor suaviza; 0 aplica el gesto inmediatamente. En vivo; desactivar Enabled también regresa suavemente al reposo.
@export_range(0.0, 1.0, 0.01, "suffix:s") var interaction_head_blend_time := 0.25

var dialogue_speaking := false
var _talk_phase := 0.0
var _talk_weight := 0.0
var _head_phase := 0.0
var _head_weight := 0.0

@export_group("NPC · control")
## Patrol sigue los Marker3D de Route; Commands usa las órdenes de este Inspector o set_action_held/pulse_action/set_move_direction. Ambos usan el controlador completo del player, sin responder al teclado del usuario. En vivo.
@export var control_mode: ControlMode = ControlMode.PATROL
## Dirección global de movimiento en modo Commands: X lateral, Z avance; longitud hasta 1. Para trepar, Z negativo sube y positivo baja. Y se ignora; salto tiene su propia orden. En vivo.
@export var command_direction := Vector3.ZERO
## Mantiene Sprint en modo Commands. Usa Sprint Speed del nodo Body y su animación de carrera. En vivo.
@export var command_sprint := false
## Mantiene planeo en modo Commands cuando ya está en el aire. Usa todos los controles Glide de Body; desactivar recoge membranas. En vivo.
@export var command_glide := false
## Mantiene agarre en modo Commands. Sólo trepa donde lo permite la física y la configuración de Body. En vivo.
@export var command_climb := false
## Solicita una pulsación de salto en modo Commands y vuelve a false al consumirla. En Remote permite probar salto o pataleo durante splat; en Local guardado true solicita salto al iniciar. No permite doble salto. En vivo.
@export var jump_requested := false

@export_group("NPC · recorrido")
## Activa la patrulla en modo Patrol. Desactivar deja de dar movimiento, pero el actor conserva gravedad y estados en curso. En vivo.
@export var patrol_enabled := true
## Velocidad de caminar del NPC, en m/s. Se aplica al Walk Speed de Body; correr usa el Sprint Speed independiente de Body. Mayor camina más rápido. En vivo.
@export_range(0.1, 15.0, 0.1, "suffix:m/s") var walk_speed := 1.6
## Segundos de descanso al llegar a cada punto. Mayor espera más; 0 continúa sin pausa. Se captura al llegar.
@export_range(0.0, 10.0, 0.1, "suffix:s") var waypoint_pause := 1.0
## Radio horizontal de llegada al punto, en metros. Mayor cambia antes de destino; para puntos de trepa también se compara la altura. En vivo.
@export_range(0.05, 2.0, 0.05, "suffix:m") var arrival_distance := 0.35
## Une el último punto al primero. Apagado recorre ida y vuelta. Se consulta en cada extremo de ruta.
@export var loop_route := true
## Contenedor de Marker3D en orden del árbol. Un NPCPatrolPoint añade sprint, salto, planeo y agarre al tramo que llega a él. Mover marcadores cambia la ruta en vivo; nunca se regeneran ni sobrescriben sus posiciones.
@export_node_path("Node3D") var route_path := NodePath("Route")
## Segundos bloqueado antes de intentar el siguiente punto. Mayor espera más. Es una patrulla simple, sin cálculo de desvíos. En vivo.
@export_range(0.2, 10.0, 0.1, "suffix:s") var blocked_retry_time := 1.5

@export_group("NPC · suelo y seguridad")
## Terrain3D para consultas de altura de la patrulla. Vacío busca uno en la escena; sin terreno usa rayos físicos. Se resuelve al iniciar. No crea ni modifica colisiones de terreno.
@export_node_path("Node3D") var terrain_path: NodePath
## Coloca Body sobre el suelo disponible al empezar. Conserva el nodo raíz y los puntos manuales. Apagar conserva su altura, útil para empezar en el aire. Requiere reiniciar.
@export var snap_on_start := true
## Espera si la colisión física aún no está cargada cerca del NPC. Evita caer a través de Terrain3D cuando su colisión dinámica sigue a una cámara lejana. Reanuda al encontrar apoyo; no crea proxies. En vivo.
@export var wait_for_ground_collision := true
## Evita pendientes fuertes, bordes y obstáculos al patrullar. Apagar permite autorizar saltos/planeos sobre bordes mediante puntos o Commands; las colisiones reales del actor permanecen activas. En vivo.
@export var edge_safety_enabled := true
## Pendiente máxima del siguiente apoyo, en grados desde la horizontal. Mayor permite laderas más fuertes; sólo controla patrulla con Edge Safety. La física usa los límites de Body. En vivo.
@export_range(0.0, 70.0, 0.5, "suffix:°") var max_slope_degrees := 40.0
## Distancia de consulta por delante, en metros. Mayor evita antes los bordes. Una consulta de suelo adicional y un rayo de obstáculo al caminar. En vivo.
@export_range(0.1, 2.0, 0.05, "suffix:m") var edge_lookahead := 0.65
## Descenso máximo aceptado entre apoyos de patrulla, en metros. Menor se detiene antes de bordes. Sólo con Edge Safety; en vivo.
@export_range(0.05, 2.0, 0.05, "suffix:m") var max_ground_drop := 0.4
## Ascenso máximo aceptado entre apoyos de patrulla, en metros. Menor rechaza escalones grandes. Para trepar una pared usa Commands o desactiva Edge Safety en una ruta diseñada. En vivo.
@export_range(0.05, 2.0, 0.05, "suffix:m") var max_ground_rise := 0.6
## Separación sobre suelo al proyectar la posición inicial, en metros. Mayor eleva el inicio; no altera la altura del modelo del player. Se captura al iniciar.
@export_range(0.0, 0.2, 0.005, "suffix:m") var ground_margin := 0.02
## Altura de origen del rayo de apoyo respecto a los pies, en metros. Mayor puede encontrar superficies superiores; evita que alcance techos. En vivo.
@export_range(0.2, 10.0, 0.1, "suffix:m") var ground_probe_height := 2.0
## Alcance bajo los pies del rayo de apoyo, en metros. Mayor detecta suelo más lejos durante la espera; no modifica seguridad de bordes. En vivo.
@export_range(0.2, 20.0, 0.1, "suffix:m") var ground_probe_depth := 4.0

@export_group("NPC · animación de caminar")
## Ritmo del mismo clip de caminar que usa el player. Se aplica a Walk Member Animation Speed de Body; correr conserva su ajuste independiente. Mayor acelera las patas. En vivo.
@export_range(0.05, 3.0, 0.05) var walk_animation_speed := 0.72
## Reproduce caminar en el editor sin mover Body ni marcadores. En ejecución el controlador completo decide la animación. En vivo sólo para vista previa.
@export var preview_walk_animation := false

@export_group("NPC · colores")
## Aplica la paleta independiente de este NPC. Apagar recupera los materiales originales del jugador. Vista previa en vivo en Local y Remote; guarda en Local para persistir. Nunca modifica el GLB ni los materiales del player.
@export var custom_colors_enabled := true:
	set(value):
		custom_colors_enabled = value
		_colors_dirty = true
## Color del pelaje: torso, cabeza, brazos, piernas y parte exterior de orejas. Mayor luminosidad aclara el pelaje. En vivo en el editor y juego; conserva los demás parámetros originales del material.
@export_color_no_alpha var fur_color := Color("964f28"):
	set(value):
		fur_color = value
		_colors_dirty = true
## Color independiente de la cola. Mayor luminosidad la aclara. Sólo este NPC; en vivo en editor y juego.
@export_color_no_alpha var tail_color := Color("964f28"):
	set(value):
		tail_color = value
		_colors_dirty = true
## Color de zonas claras de rostro y panza, correspondientes a m_rostro del modelo. Mayor luminosidad las aclara. En vivo en editor y juego.
@export_color_no_alpha var muzzle_belly_color := Color("d49257"):
	set(value):
		muzzle_belly_color = value
		_colors_dirty = true
## Color de manos y pies. Mayor luminosidad aclara las extremidades. No cambia su geometría. En vivo en editor y juego.
@export_color_no_alpha var paws_color := Color("593625"):
	set(value):
		paws_color = value
		_colors_dirty = true
## Color interior de ambas orejas. Mayor luminosidad lo destaca sobre el pelaje. En vivo en editor y juego.
@export_color_no_alpha var inner_ear_color := Color("ec7151"):
	set(value):
		inner_ear_color = value
		_colors_dirty = true
## Color de ojos y nariz, que comparten m_ojos_negro en el GLB. Mayor luminosidad aclara ambos. En vivo en editor y juego.
@export_color_no_alpha var eyes_nose_color := Color("312924"):
	set(value):
		eyes_nose_color = value
		_colors_dirty = true

@export_group("NPC · proporciones generales")
## Activa las proporciones visuales propias de esta instancia. Apagar recupera las escalas originales capturadas al cargarla. No modifica GLB, player ni cápsula física. En vivo en el editor y juego; sin regeneración de malla.
@export var proportions_enabled := true
## Tamaño uniforme de todo el NPC: 1 original, 0,8 un 20 % menor y 1,2 un 20 % mayor. Se combina con Head Size, torso y miembros. No mueve Route ni sobrescribe la escala manual de la escena. En vivo en editor y juego; sin regenerar.
@export_range(0.25, 3.0, 0.01) var overall_size := 1.0
## Ajusta también radio, altura y centro de la cápsula privada de este NPC a Overall Size. Apagar conserva la cápsula original aunque cambie el visual. No cambia gravedad, velocidad, alcance de trepa ni ruta. En vivo en ejecución.
@export var scale_collision_with_size := true
## Tamaño uniforme de cabeza, incluidos ojos, nariz y orejas. 1 conserva el modelo, 0,8 reduce un 20 %, 1,2 aumenta un 20 %. Las orejas admiten además su ajuste propio. En vivo; no cambia la colisión.
@export_range(0.25, 2.0, 0.01) var head_size := 1.0
## Anchura del torso respecto al original: 1 normal, 1,25 un 25 % más ancho. Sólo deforma la pieza del torso para no engordar cabeza ni brazos. En vivo; valores extremos pueden cruzar las uniones.
@export_range(0.25, 2.5, 0.01) var torso_width := 1.0
## Grosor del torso de panza a espalda: 1 normal, mayor lo hace más gordito. Se combina con Torso Width. Sólo visual y en vivo; no amplía la cápsula.
@export_range(0.25, 2.5, 0.01) var torso_depth := 1.0
## Altura de la pieza del torso alrededor de su centro: 1 conserva la altura. No reposiciona automáticamente cuello, hombros ni caderas; cambios grandes pueden dejar huecos o cruces. En vivo.
@export_range(0.5, 1.5, 0.01) var torso_height := 1.0
## Longitud de ambos brazos desde sus hombros: 1 original, menor acorta y mayor alarga. Incluye manos y conserva las rotaciones de animación. En vivo; los apoyos siguen siendo poses aproximadas, sin IK.
@export_range(0.5, 1.75, 0.01) var arms_length := 1.0
## Grosor de ambos brazos y manos, sin cambiar la longitud. 1 conserva el original; mayor los hace más robustos. En vivo; valores extremos pueden cruzar el torso.
@export_range(0.5, 2.0, 0.01) var arms_thickness := 1.0
## Longitud de ambas piernas desde la cadera: 1 original. Incluye pies; mayor puede hundirlos en el suelo y menor dejarlos flotando porque la cápsula no cambia. En vivo; recomendable empezar entre 0,9 y 1,1.
@export_range(0.5, 1.75, 0.01) var legs_length := 1.0
## Grosor de ambas piernas y pies, conservando su longitud. 1 original; mayor los hace más robustos. Sólo visual y en vivo.
@export_range(0.5, 2.0, 0.01) var legs_thickness := 1.0
## Tamaño uniforme de la cola desde su base: 1 original, menor la reduce y mayor la agranda. Conserva el balanceo y los ajustes de color. En vivo; no modifica colisión.
@export_range(0.25, 2.0, 0.01) var tail_size := 1.0
## Longitud adicional sobre el eje longitudinal del hueso de la cola. Se multiplica por Tail Size; 1 no añade estiramiento. En vivo; ampliaciones grandes pueden atravesar suelo o cuerpo.
@export_range(0.5, 2.0, 0.01) var tail_length := 1.0
## Tamaño de ambas orejas relativo a la cabeza. 1 conserva su proporción; 0,8 las reduce un 20 % adicional al ajuste Head Size. En vivo; no cambia ojos ni hocico.
@export_range(0.25, 2.0, 0.01) var ears_size := 1.0

var _body: ExplorerPlayer
var _visual: Node3D
var _animation: AnimationPlayer
var _skeleton: Skeleton3D
var _walk_clip := &""
var _surfaces: Array[Dictionary] = []
var _colors_dirty := true
var _walking := false
var _terrain: Node3D
var _terrain_retry := 0.0
var _started := false
var _initial_snap_done := false
var _waypoint := 0
var _route_direction := 1
var _pause_left := 0.0
var _blocked_time := 0.0
var _leg_started_index := -1
var _move := Vector2.ZERO
var _held_actions: Dictionary = {}
var _pressed_actions: Dictionary = {}
var _queued_pulses: Dictionary = {}
var _external_held: Dictionary = {}
var _proportion_bones: Dictionary = {}
var _torso_meshes: Array[Dictionary] = []
var _size_root: Node3D
var _original_visual_scale := Vector3.ONE
var _size_collider: CollisionShape3D
var _original_capsule_radius := 0.42
var _original_capsule_height := 1.42
var _original_collider_position := Vector3.ZERO
var _last_collision_size := -1.0

func _ready() -> void:
	process_physics_priority = -100
	# Después de SquirrelRig (100), para conservar proporciones aunque Idle
	# o una pose procedural restablezcan los huesos durante este frame.
	process_priority = 200
	_body = get_node("Body") as ExplorerPlayer
	var preview := get_node("EditorVisual") as Node3D
	preview.visible = Engine.is_editor_hint()
	if Engine.is_editor_hint():
		_visual = preview
		_size_root = preview
	else:
		_visual = _body.model
		_size_root = _visual.get_node("BodyPivot/NuezPlayerTest2") as Node3D
		_body.command_source = self
		_body.set_physics_process(false)
		_body.feedback.connect(_forward_feedback)
		for child in _body.get_children():
			if child is CollisionShape3D and child.shape is CapsuleShape3D:
				_size_collider = child
				_size_collider.shape = child.shape.duplicate()
				_original_capsule_radius = _size_collider.shape.radius
				_original_capsule_height = _size_collider.shape.height
				_original_collider_position = _size_collider.position
				break
	# EditorVisual puede guardar la escala calculada por @tool al salvar
	# una escena heredada. No debe convertirse en una nueva escala base.
	_original_visual_scale = Vector3.ONE if Engine.is_editor_hint() else _size_root.scale
	_animation = _visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var skeletons := _visual.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty():
		_skeleton = skeletons[0] as Skeleton3D
		for bone_name in ["head", "arm_left", "arm_right", "leg_left", "leg_right", "tail_base", "ear_left", "ear_right"]:
			var index := _skeleton.find_bone(bone_name)
			if index >= 0:
				# La escala de pose neutra del rig es 1; la escala de importación
				# pertenece al rest. Evita acumular proporciones al recargar @tool.
				_proportion_bones[bone_name] = {"index": index, "scale": Vector3.ONE}
	for mesh: MeshInstance3D in _visual.find_children("*", "MeshInstance3D", true, false):
		if String(mesh.name).contains("nuez_torso"):
			_torso_meshes.append({"mesh": mesh, "scale": Vector3.ONE})
		if String(mesh.name).contains("membrana"):
			mesh.visible = false
		for surface in mesh.mesh.get_surface_count():
			var original := mesh.get_active_material(surface) as StandardMaterial3D
			if original:
				var role := "tail" if String(mesh.name).contains("cola") else original.resource_name
				_surfaces.append({"mesh": mesh, "surface": surface, "original": original, "material": original.duplicate(), "role": role})
	if _animation:
		for clip in _animation.get_animation_list():
			if String(clip).ends_with("Run"):
				_walk_clip = clip
	_apply_colors()
	if Engine.is_editor_hint():
		_update_animation(0.0)
	_apply_proportions()

func _process(delta: float) -> void:
	if _colors_dirty and is_instance_valid(_visual):
		_apply_colors()
	if Engine.is_editor_hint():
		_update_animation(walk_speed if preview_walk_animation else 0.0)
		if preview_walk_animation and _animation:
			_animation.advance(delta)
	_apply_proportions()
	_apply_talking_gesture(delta)
	_apply_interaction_head(delta)

func _apply_interaction_head(delta: float) -> void:
	if not is_instance_valid(_skeleton) or not _proportion_bones.has("head"):
		return
	var interacting := preview_talking_gesture if Engine.is_editor_hint() else is_instance_valid(_body) and _body.is_in_dialogue()
	var target := 1.0 if interaction_head_enabled and interacting else 0.0
	_head_weight = move_toward(_head_weight, target, delta / maxf(0.001, interaction_head_blend_time)) if interaction_head_blend_time > 0.0 else target
	_head_phase = fmod(_head_phase + delta * TAU * interaction_head_hz, TAU)
	var index: int = _proportion_bones["head"].index
	var base := _skeleton.get_bone_pose_rotation(index)
	if Engine.is_editor_hint() and not preview_walk_animation:
		base = Quaternion.IDENTITY
	# Convertir ejes del personaje al espacio del hueso importado.
	var rest := _skeleton.get_bone_global_rest(index).basis.orthonormalized().get_rotation_quaternion()
	var angles := Vector3(
		sin(_head_phase * 2.0) * deg_to_rad(interaction_head_pitch_degrees),
		sin(_head_phase) * deg_to_rad(interaction_head_yaw_degrees),
		sin(_head_phase + 0.7) * deg_to_rad(interaction_head_roll_degrees)
	) * _head_weight
	_skeleton.set_bone_pose_rotation(index, base * rest.inverse() * Quaternion.from_euler(angles) * rest)

func _apply_talking_gesture(delta: float) -> void:
	if not is_instance_valid(_skeleton):
		return
	var speaking := preview_talking_gesture if Engine.is_editor_hint() else dialogue_speaking
	var target := 1.0 if talking_gesture_enabled and speaking else 0.0
	_talk_weight = move_toward(_talk_weight, target, delta / maxf(0.001, talking_gesture_blend_time)) if talking_gesture_blend_time > 0.0 else target
	_talk_phase = fmod(_talk_phase + delta * TAU * talking_arm_hz, TAU)
	for side in ["arm_left", "arm_right"]:
		if not _proportion_bones.has(side):
			continue
		var index: int = _proportion_bones[side].index
		var base := _skeleton.get_bone_pose_rotation(index)
		# La previsualización en reposo no evalúa un clip cada frame.
		if Engine.is_editor_hint() and not preview_walk_animation:
			base = Quaternion.IDENTITY
		# Los ejes locales del rest importado invierten la apertura respecto
		# al eje FORWARD: el positivo de autoría debe alejar ambos brazos del torso.
		var sign_side := -1.0 if side == "arm_left" else 1.0
		var wave := sin(_talk_phase + (0.35 if side == "arm_right" else 0.0))
		var lower := minf(talking_arm_min_degrees, talking_arm_max_degrees)
		var upper := maxf(talking_arm_min_degrees, talking_arm_max_degrees)
		var limited_degrees := clampf(talking_arm_open_degrees + wave * talking_arm_degrees, lower, upper)
		var angle := deg_to_rad(limited_degrees) * _talk_weight
		_skeleton.set_bone_pose_rotation(index, base * Quaternion(Vector3.FORWARD, angle * sign_side))

func _apply_proportions() -> void:
	var size := clampf(overall_size, 0.25, 3.0) if proportions_enabled else 1.0
	if is_instance_valid(_size_root):
		_size_root.scale = _original_visual_scale * size
	var collision_size := size if scale_collision_with_size else 1.0
	if is_instance_valid(_size_collider) and not is_equal_approx(_last_collision_size, collision_size):
		var capsule := _size_collider.shape as CapsuleShape3D
		capsule.radius = _original_capsule_radius * collision_size
		capsule.height = _original_capsule_height * collision_size
		_size_collider.position = _original_collider_position * collision_size
		_last_collision_size = collision_size
	if not is_instance_valid(_skeleton):
		return
	var factors := {
		"head": Vector3.ONE * head_size,
		"arm_left": Vector3(arms_thickness, arms_length, arms_thickness),
		"arm_right": Vector3(arms_thickness, arms_length, arms_thickness),
		"leg_left": Vector3(legs_thickness, legs_length, legs_thickness),
		"leg_right": Vector3(legs_thickness, legs_length, legs_thickness),
		"tail_base": Vector3(1.0, tail_length, 1.0) * tail_size,
		"ear_left": Vector3.ONE * ears_size,
		"ear_right": Vector3.ONE * ears_size,
	}
	for bone_name in _proportion_bones:
		var entry: Dictionary = _proportion_bones[bone_name]
		var factor: Vector3 = factors[bone_name] if proportions_enabled else Vector3.ONE
		# Siempre parte de la escala original: nunca multiplica la aplicada
		# en el frame anterior ni toca rotaciones/posiciones animadas.
		_skeleton.set_bone_pose_scale(entry.index, entry.scale * factor.clamp(Vector3.ONE * 0.05, Vector3.ONE * 3.0))
	var torso_factor := Vector3(torso_width, torso_height, torso_depth) if proportions_enabled else Vector3.ONE
	for entry in _torso_meshes:
		var mesh := entry.mesh as MeshInstance3D
		if is_instance_valid(mesh):
			mesh.scale = entry.scale * torso_factor.clamp(Vector3.ONE * 0.05, Vector3.ONE * 3.0)

func _forward_feedback(kind: String) -> void:
	feedback.emit(kind)

## API de IA: dirección global; no gira la cámara ni pulsa Input global.
func set_move_direction(direction: Vector3) -> void:
	command_direction = direction.limit_length(1.0)

## API de IA: mantiene o suelta jump, sprint, glide o climb en modo Commands.
func set_action_held(action: StringName, held: bool) -> void:
	_external_held[action] = held

## API de IA: pulsación de un tick, también válida para reacciones de splat.
func pulse_action(action: StringName) -> void:
	_queued_pulses[action] = true

func action_pressed(action: StringName) -> bool:
	return bool(_held_actions.get(action, false))

func action_just_pressed(action: StringName) -> bool:
	return bool(_pressed_actions.get(action, false))

func movement_input() -> Vector2:
	return _move

func _apply_colors() -> void:
	var palette := {"m_body": fur_color, "tail": tail_color, "m_rostro": muzzle_belly_color, "m_hands": paws_color, "m_ear": inner_ear_color, "m_ojos_negro": eyes_nose_color}
	for entry in _surfaces:
		var mesh := entry.mesh as MeshInstance3D
		var material := entry.material as StandardMaterial3D
		material.albedo_color = palette.get(entry.role, entry.original.albedo_color)
		mesh.set_surface_override_material(entry.surface, material if custom_colors_enabled else null)
	_colors_dirty = false

func _update_animation(speed: float) -> void:
	if not _animation or _walk_clip.is_empty():
		return
	if speed > 0.03:
		if not _walking:
			_animation.play(_walk_clip)
		_animation.speed_scale = walk_animation_speed * clampf(speed / maxf(0.05, walk_speed), 0.1, 2.0)
		_walking = true
	else:
		if _walking or _animation.current_animation != _walk_clip:
			_animation.play(_walk_clip)
			_animation.pause()
			if _skeleton:
				for bone in _skeleton.get_bone_count():
					_skeleton.reset_bone_pose(bone)
		_walking = false

func _resolve_terrain(delta: float) -> void:
	if is_instance_valid(_terrain):
		return
	_terrain_retry -= delta
	if _terrain_retry > 0.0:
		return
	_terrain_retry = 1.0
	if not terrain_path.is_empty():
		_terrain = get_node_or_null(terrain_path) as Node3D
	else:
		var found := get_tree().root.find_children("*", "Terrain3D", true, false)
		if not found.is_empty():
			_terrain = found[0] as Node3D

func _support(point: Vector3) -> Dictionary:
	if is_instance_valid(_terrain):
		var data: Object = _terrain.get("data")
		if data:
			var height: float = data.call("get_height", point)
			var normal: Vector3 = data.call("get_normal", point)
			if is_finite(height) and normal.is_finite() and not normal.is_zero_approx():
				return {"position": Vector3(point.x, height, point.z), "normal": normal.normalized()}
		return {}
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * ground_probe_height, point - Vector3.UP * ground_probe_depth, _body.collision_mask, [_body.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query)

func _physical_support(point: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * ground_probe_height, point - Vector3.UP * ground_probe_depth, _body.collision_mask, [_body.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query)

func _points() -> Array[Node3D]:
	var points: Array[Node3D] = []
	var route := get_node_or_null(route_path)
	if route:
		for child in route.get_children():
			if child is Marker3D:
				points.append(child)
	return points

func _next_point(count: int) -> void:
	if count <= 1:
		return
	if loop_route:
		_waypoint = (_waypoint + 1) % count
	else:
		if _waypoint + _route_direction >= count or _waypoint + _route_direction < 0:
			_route_direction = -_route_direction
		_waypoint += _route_direction
	_leg_started_index = -1
	_blocked_time = 0.0
	_pause_left = waypoint_pause

func _patrol(delta: float, support: Dictionary, actions: Dictionary) -> void:
	_pause_left = maxf(0.0, _pause_left - delta)
	var points := _points()
	if not patrol_enabled or points.is_empty() or _pause_left > 0.0:
		return
	_waypoint = clampi(_waypoint, 0, points.size() - 1)
	var target := points[_waypoint]
	var offset := target.global_position - _body.global_position
	var vertical := offset.y
	offset.y = 0.0
	var point := target as PatrolPoint
	var climbing_requested := point != null and point.climb_held
	if offset.length() <= arrival_distance and (not climbing_requested or absf(vertical) <= arrival_distance):
		_next_point(points.size())
		return
	if point:
		actions[&"sprint"] = point.sprint
		actions[&"glide"] = point.glide_in_air and not _body.is_on_floor()
		actions[&"climb"] = point.climb_held
		if _leg_started_index != _waypoint:
			if point.jump_before_leg:
				pulse_action(&"jump")
			_leg_started_index = _waypoint
	var direction := offset.normalized()
	var safe := true
	if edge_safety_enabled:
		var ahead := _support(_body.global_position + direction * minf(edge_lookahead, offset.length()))
		safe = not support.is_empty() and not ahead.is_empty()
		if safe:
			var rise: float = ahead.position.y - support.position.y
			safe = ahead.normal.y >= cos(deg_to_rad(max_slope_degrees)) and rise <= max_ground_rise and -rise <= max_ground_drop
		if safe:
			var chest := _body.global_position + Vector3.UP * 0.85
			var query := PhysicsRayQueryParameters3D.create(chest, chest + direction * edge_lookahead, _body.collision_mask, [_body.get_rid()])
			safe = get_world_3d().direct_space_state.intersect_ray(query).is_empty()
	if safe:
		_move = Vector2(direction.x, direction.z)
		if _body.is_climbing:
			_move = Vector2(0.0, -signf(vertical))
	if not safe or _body.horizontal_speed < 0.03:
		_blocked_time += delta
		if _blocked_time >= blocked_retry_time:
			_next_point(points.size())
	else:
		_blocked_time = 0.0

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not is_instance_valid(_body):
		return
	_resolve_terrain(delta)
	_body.walk_speed = walk_speed
	_body.walk_member_animation_speed = walk_animation_speed
	var support := _support(_body.global_position)
	var physical := _physical_support(_body.global_position)
	if not _initial_snap_done and not support.is_empty():
		_initial_snap_done = true
		if snap_on_start:
			_body.global_position.y = support.position.y + ground_margin
			_body.spawn_position = _body.global_position
			_body.fall_peak_y = _body.global_position.y
			_body.reset_physics_interpolation()
			physical = _physical_support(_body.global_position)
	var near_ground: bool = not support.is_empty() and _body.global_position.y <= support.position.y + maxf(0.5, absf(_body.velocity.y) * delta + 0.2)
	var waiting: bool = wait_for_ground_collision and physical.is_empty() and (not _started or (near_ground and not _body.is_climbing))
	if waiting:
		_body.set_physics_process(false)
		return
	_started = true
	_body.set_physics_process(true)
	_move = Vector2.ZERO
	if _body.is_in_dialogue():
		# Conserva destino y temporizadores; la patrulla se reanuda al terminar.
		_held_actions.clear()
		_pressed_actions.clear()
		_queued_pulses.clear()
		return
	var next_actions: Dictionary = {}
	if control_mode == ControlMode.PATROL:
		_patrol(delta, support, next_actions)
	else:
		_move = Vector2(command_direction.x, command_direction.z).limit_length(1.0)
		next_actions = {&"sprint": command_sprint, &"glide": command_glide and not _body.is_on_floor(), &"climb": command_climb}
		for action in _external_held:
			next_actions[action] = _external_held[action]
		if jump_requested:
			pulse_action(&"jump")
			jump_requested = false
	_pressed_actions.clear()
	if _body.is_on_floor():
		next_actions[&"glide"] = false
	for action in _queued_pulses:
		next_actions[action] = true
	for action in next_actions:
		if bool(next_actions[action]) and (not bool(_held_actions.get(action, false)) or _queued_pulses.has(action)):
			_pressed_actions[action] = true
	_held_actions = next_actions
	_queued_pulses.clear()
