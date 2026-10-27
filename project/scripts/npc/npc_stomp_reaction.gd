@tool
extends Node
## Resorte reutilizable del NPC. Deforma sólo el visual; la cápsula permanece estable.

@export_group("Contacto y rebote")
## Activa colisión del NPC con el player en la capa 4, independiente de los bloqueadores de cámara (capa 3). Apagar permite atravesarlo. En vivo; no cambia su colisión con el terreno.
@export var player_collision_enabled := true
## Activa rebote, compresión y sonido al caer desde arriba. Desactivar conserva la colisión si Player Collision Enabled está activo. En vivo.
@export var bounce_enabled := true
## Velocidad vertical de salida en m/s; mayor da más altura. 5 produce unos 0,6 m con gravedad 20. En vivo; independiente de la velocidad de caída.
@export_range(1.0, 15.0, 0.1, "suffix:m/s") var bounce_speed := 5.0
## Velocidad descendente mínima en m/s para contactos sin apoyo. Mayor ignora roces lentos en el aire; si el player ya está apoyado encima siempre rebota para impedir quedarse parado. En vivo; requiere Bounce Enabled.
@export_range(0.1, 10.0, 0.1, "suffix:m/s") var minimum_fall_speed := 0.8
## Normal vertical mínima del contacto (0 lateral, 1 techo plano). Mayor exige caer más centrado; evita rebotes al chocar de lado. En vivo.
@export_range(0.1, 1.0, 0.05) var top_normal_min := 0.65
## Fracción de altura de la cápsula a partir de la que cuenta como cabeza. Mayor reduce la zona válida; se combina con Top Normal Min. En vivo.
@export_range(0.5, 1.0, 0.01) var top_height_fraction := 0.7
## Segundos mínimos entre impactos aceptados; evita duplicar contactos del mismo salto. Mayor limita el ritmo. En vivo.
@export_range(0.05, 2.0, 0.01, "suffix:s") var impact_cooldown := 0.2

@export_group("Resorte visual")
## Fracción de altura comprimida: 0,18 reduce un 18 %. Mayor aplasta más; no cambia proporciones guardadas ni colisión. En vivo.
@export_range(0.0, 0.6, 0.01) var compression := 0.18
## Expansión lateral relativa a la compresión. Mayor ensancha más X/Z al apretar. 0 sólo cambia altura. En vivo.
@export_range(0.0, 1.0, 0.05) var lateral_expansion := 0.4
## Ciclos por segundo de la oscilación amortiguada. Mayor recupera y oscila más rápido. En vivo; no requiere regenerar geometría.
@export_range(0.5, 10.0, 0.1, "suffix:Hz") var spring_frequency := 3.5
## Atenuación por segundo de las oscilaciones. Mayor detiene antes el resorte; menor deja más rebote visual. En vivo.
@export_range(1.0, 25.0, 0.5) var spring_damping := 8.0
## Activa para disparar un resorte de muestra en el editor; se desmarca solo. Respeta Overall Size y las proporciones. Sin sonido ni rebote físico.
@export var preview_spring := false

@export_group("Sonido del impacto")
## Sonido espacial por caída aceptada. Vacío silencia. Se usa el WAV indicado; cambiarlo no modifica el archivo original. En vivo.
@export var impact_sound: AudioStream = preload("res://audio/sfx/boing drum.wav")
## Volumen del boing en dB; mayor suena más fuerte. En vivo, al siguiente impacto.
@export_range(-40.0, 6.0, 0.5, "suffix:dB") var sound_volume_db := 0.0
## Distancia de referencia del audio 3D, en metros. Mayor reduce la pérdida de volumen desde la cámara: 14 acompaña su órbita habitual. Se combina con Volume y Max Distance. En vivo, al siguiente impacto.
@export_range(1.0, 40.0, 0.5, "suffix:m") var sound_unit_size := 14.0
## Tono y velocidad del boing; mayor suena más agudo y corto. En vivo, al siguiente impacto.
@export_range(0.5, 2.0, 0.05) var sound_pitch := 1.0
## Alcance máximo en metros del audio 3D. Mayor permite oír desde más lejos. En vivo, al siguiente impacto.
@export_range(1.0, 80.0, 1.0, "suffix:m") var sound_max_distance := 45.0

@export_group("Regaño")
## Activa el diálogo automático tras varias caídas. Usa el bloqueo y la mirada compartidos; espera al aterrizaje. En vivo.
@export var complaint_enabled := true
## Impactos necesarios dentro de Count Window. Mayor tarda más en quejarse; 2 equivale a un par de caídas. En vivo.
@export_range(1, 10, 1) var complaint_after_hits := 2
## Segundos sin recibir impacto antes de olvidar la cuenta; también es el plazo para abrir un regaño pendiente. Mayor permite saltos más espaciados. En vivo.
@export_range(1.0, 60.0, 0.5, "suffix:s") var count_window := 8.0
## Segundos entre regaños, desde que se abre uno. Mayor evita conversaciones frecuentes; el resorte y el sonido continúan. En vivo.
@export_range(0.0, 120.0, 1.0, "suffix:s") var complaint_cooldown := 20.0
## Texto del regaño para este NPC. Vacío lo silencia. No sustituye su conversación normal; se captura al abrir. En vivo.
@export_multiline var complaint_text := "¡Eh! ¡Soy una ardilla, no un trampolín! Si buscas nueces, están en los árboles, no dentro de mi cabeza."

var visual_scale := Vector3.ONE
var _spring_time := 100.0
var _impact_left := 0.0
var _count_left := 0.0
var _complaint_left := 0.0
var _hits := 0
var _pending_player: ExplorerPlayer
var _audio: AudioStreamPlayer3D

func _process(delta: float) -> void:
	if preview_spring:
		preview_spring = false
		if Engine.is_editor_hint():
			_spring_time = 0.0
	_spring_time += delta
	var squash := compression * exp(-spring_damping * _spring_time) * cos(TAU * spring_frequency * _spring_time)
	visual_scale = Vector3(1.0 + squash * lateral_expansion, 1.0 - squash, 1.0 + squash * lateral_expansion)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var body := get_parent().get_node("Body") as ExplorerPlayer
	body.set_collision_layer_value(4, player_collision_enabled)
	_impact_left = maxf(0.0, _impact_left - delta)
	_count_left = maxf(0.0, _count_left - delta)
	_complaint_left = maxf(0.0, _complaint_left - delta)
	if _count_left <= 0.0 or not complaint_enabled or not bounce_enabled:
		_hits = 0
		_pending_player = null
	if is_instance_valid(_pending_player):
		var dialogue := get_parent().get_node("Dialogue")
		if dialogue.try_open_reaction(_pending_player, complaint_text):
			_pending_player = null
			_hits = 0
			_complaint_left = complaint_cooldown

func try_stomp(player: ExplorerPlayer, hit: KinematicCollision3D, fall_speed: float) -> bool:
	var npc := get_parent() as SquirrelNPC
	var body := npc.get_node("Body") as ExplorerPlayer
	if not player_collision_enabled or not bounce_enabled or _impact_left > 0.0:
		return false
	if fall_speed < minimum_fall_speed and not player.is_on_floor():
		return false
	if body.is_in_dialogue() or body.is_splat or body.is_climbing or not body.is_on_floor():
		return false
	if hit.get_normal().y < top_normal_min:
		return false
	# La cápsula privada ya incluye Overall Size. Convierte el contacto a su espacio.
	var collider: CollisionShape3D
	for child in body.get_children():
		if child is CollisionShape3D and child.shape is CapsuleShape3D:
			collider = child
			break
	if not collider:
		return false
	var capsule := collider.shape as CapsuleShape3D
	var contact_height := collider.to_local(hit.get_position()).y + capsule.height * 0.5
	if contact_height < capsule.height * top_height_fraction:
		return false
	_impact_left = impact_cooldown
	_spring_time = 0.0
	player.bounce_from_npc(bounce_speed)
	if impact_sound:
		if not is_instance_valid(_audio):
			_audio = AudioStreamPlayer3D.new()
			body.add_child(_audio)
		_audio.position = collider.position
		_audio.stream = impact_sound
		_audio.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
		_audio.volume_db = sound_volume_db
		_audio.unit_size = sound_unit_size
		_audio.pitch_scale = sound_pitch
		_audio.max_distance = sound_max_distance
		_audio.play()
	if complaint_enabled and _complaint_left <= 0.0:
		_hits += 1
		_count_left = count_window
		if _hits >= complaint_after_hits:
			_pending_player = player
	return true
