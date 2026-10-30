@tool
class_name ChristmasHatPickup
extends RigidBody3D
## Gorro navideño tirado en el mundo. Colócalo con el gizmo en cualquier escena con ExplorerPlayer.
## Al acercarse aparece el mismo prompt que en NPC y letreros; al interactuar suena su efecto,
## desaparece y queda guardado (y puesto) en TrailWardrobe. Si ya se obtuvo, no vuelve a aparecer.
## Física real: cae y se asienta en el terreno, rueda en pendientes y la ardilla lo empuja.

const PromptScene = preload("res://ui/interaction/interaction_prompt.tscn")

## Identificador del accesorio en TrailWardrobe. Debe coincidir con el HatSlot del jugador.
@export var item_id := "christmas_hat"
## Estilo compartido con el gorro de la cabeza: mismo aspecto y física.
@export var style: ChristmasHatStyle:
	set(value):
		style = value
		var visual := get_node_or_null("Visual") as ChristmasHatVisual
		if visual: visual.style = value
		_fit_collision()

@export_group("Interacción")
## Distancia máxima entre la ardilla y el gorro para mostrar el prompt, en metros. En vivo.
@export_range(0.5, 6.0, 0.05, "suffix:m") var interaction_reach := 1.9
## Altura del prompt sobre el gorro, en metros. En vivo.
@export_range(0.2, 3.0, 0.05, "suffix:m") var prompt_height := 0.95
## Pone el gorro en la cabeza al recogerlo. Apagado sólo lo guarda; se pone desde la pausa.
@export var equip_on_pickup := true

@export_group("Sonido y efecto")
## Efecto al conseguir el gorro. Usa el bus de efectos de TrailAudio si la escena lo tiene.
@export var pickup_sound: TrailSoundCue
## Destellos y pelusa blanca al recogerlo.
@export var burst_enabled := true
## Cantidad de partículas del destello. Mayor es más vistoso; coste mínimo y sólo una vez.
@export_range(4, 128, 1) var burst_amount := 36
@export var burst_color := Color("fff4d6")

@export_group("Física")
## Ajusta la colisión del ribete a las medidas del estilo. Apagado conserva la forma manual.
@export var auto_fit_collision := true:
	set(value):
		auto_fit_collision = value
		_fit_collision()
## Se queda exactamente donde lo colocaste (congelado) hasta que la ardilla lo empuje; después es un cuerpo físico normal. Apagado cae y se asienta al empezar.
@export var start_asleep := true
## Impulso con que la ardilla empuja el gorro al pasar a través de él, en N·s por m/s de la ardilla. 0 lo hace inamovible por contacto.
@export_range(0.0, 1.0, 0.005) var push_strength := 0.06
## Distancia horizontal de contacto entre la ardilla y el gorro para empujarlo, en metros.
@export_range(0.1, 2.0, 0.05, "suffix:m") var push_radius := 0.65

@export_group("Depuración")
## Olvida el gorro al iniciar la escena para volver a probar la recogida. Desactívalo en la versión final.
@export var reset_ownership_on_start := false

var _player: ExplorerPlayer
var _prompt: Node3D
var _prompt_anchor: Node3D
var _near := false
var _clock := 0.0
var _gamepad := false
var _collected := false

func _ready() -> void:
	_fit_collision()
	if Engine.is_editor_hint(): return
	add_to_group("character_look")
	collision_layer = 16
	collision_mask = 1
	if reset_ownership_on_start: TrailWardrobe.forget(item_id)
	if TrailWardrobe.owns(item_id):
		queue_free()
		return
	# Congelado conserva la colocación exacta; el primer empujón lo libera.
	freeze = start_asleep
	_prompt_anchor = Node3D.new()
	_prompt_anchor.name = "PromptAnchor"
	_prompt_anchor.top_level = true
	add_child(_prompt_anchor)
	_prompt = PromptScene.instantiate()
	_prompt.set("preview_at_origin", false)
	_prompt.visible = false
	_prompt_anchor.add_child(_prompt)

func _fit_collision() -> void:
	if not auto_fit_collision or not style or not is_inside_tree(): return
	var shape_node := get_node_or_null("BrimCollision") as CollisionShape3D
	if not shape_node: return
	var cylinder := shape_node.shape as CylinderShape3D
	if not cylinder:
		cylinder = CylinderShape3D.new()
		shape_node.shape = cylinder
	cylinder.radius = style.opening_radius + style.brim_thickness
	cylinder.height = style.brim_height
	shape_node.position = Vector3(0.0, style.brim_height * 0.5, 0.0)

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or _collected or not is_instance_valid(_player): return
	# La ardilla atraviesa el gorro (capa propia) y lo empuja con un impulso proporcional a su velocidad.
	var offset := global_position - _player.global_position
	offset.y = 0.0
	var speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	if push_strength > 0.0 and offset.length() < push_radius and speed > 0.3 and absf(global_position.y - _player.global_position.y) < 1.0:
		var away := offset.normalized() if offset.length() > 0.01 else Vector3(_player.velocity.x, 0.0, _player.velocity.z).normalized()
		var push := Vector3(_player.velocity.x, 0.0, _player.velocity.z).project(away)
		if push.dot(away) > 0.0:
			freeze = false
			apply_central_impulse((push + Vector3.UP * push.length() * 0.25) * push_strength * mass)

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _collected: return
	_prompt_anchor.global_position = global_position
	_clock -= delta
	if _clock > 0.0: return
	_clock = 0.15
	if not is_instance_valid(_player):
		_player = _find_player(get_tree().current_scene) if get_tree().current_scene else null
	_near = _can_collect() and _player.global_position.distance_to(global_position) <= interaction_reach
	_prompt.set("height", prompt_height)
	_prompt.set("key_text", TrailInput.interaction_glyph() if _gamepad else "E")
	_prompt.call("set_prompt_visible", _near)

func _can_collect() -> bool:
	return is_instance_valid(_player) and _player.control_enabled and not _player.is_in_dialogue() and not get_tree().paused and not get_tree().get_first_node_in_group("active_dialogue")

func _find_player(node: Node) -> ExplorerPlayer:
	if node is ExplorerPlayer and not is_instance_valid(node.command_source) and not node.is_in_group("npc_actors"):
		return node as ExplorerPlayer
	for child in node.get_children():
		var found := _find_player(child)
		if found: return found
	return null

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or _collected: return
	if event is InputEventKey and event.echo: return
	if event is InputEventJoypadButton:
		_gamepad = true
		TrailInput.active_device = event.device
	elif event is InputEventKey or event is InputEventMouseButton:
		_gamepad = false
	if not _near or not _can_collect(): return
	var contextual_accept := event is InputEventJoypadButton and event.is_action_pressed("ui_accept") and _player.is_on_floor()
	if event.is_action_pressed("interact") or contextual_accept:
		if contextual_accept: _player.consume_interaction_press()
		get_viewport().set_input_as_handled()
		collect()

## Recoge el gorro: sonido, destello, guardado en el vestuario y desaparición del mundo.
func collect() -> void:
	if _collected: return
	_collected = true
	_prompt.call("set_prompt_visible", false)
	if is_instance_valid(_player):
		_player.face_interaction_partner(self)
		_player.react("interact")
	_play_sound()
	if burst_enabled: _burst()
	TrailWardrobe.acquire(item_id, equip_on_pickup)
	freeze = true
	collision_layer = 0
	$Visual.visible = false
	get_tree().create_timer(2.5).timeout.connect(queue_free)

func _play_sound() -> void:
	if not pickup_sound or not pickup_sound.enabled or not pickup_sound.stream: return
	if PauseMenu.play_cue(pickup_sound): return
	var voice := AudioStreamPlayer3D.new()
	voice.stream = pickup_sound.stream
	voice.volume_db = pickup_sound.volume_db
	voice.pitch_scale = pickup_sound.pitch_scale * randf_range(1.0 - pickup_sound.pitch_variation, 1.0 + pickup_sound.pitch_variation)
	voice.top_level = true
	add_child(voice)
	voice.global_position = global_position
	voice.play()

func _burst() -> void:
	var particles := CPUParticles3D.new()
	particles.top_level = true
	add_child(particles)
	particles.global_position = global_position + Vector3.UP * 0.25
	particles.one_shot = true
	particles.explosiveness = 0.92
	particles.amount = burst_amount
	particles.lifetime = 0.9
	particles.direction = Vector3.UP
	particles.spread = 75.0
	particles.initial_velocity_min = 1.2
	particles.initial_velocity_max = 2.6
	particles.gravity = Vector3(0.0, -2.5, 0.0)
	particles.damping_min = 1.5
	particles.damping_max = 3.0
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.2
	var fade := Curve.new()
	fade.add_point(Vector2(0.0, 1.0))
	fade.add_point(Vector2(1.0, 0.0))
	particles.scale_amount_curve = fade
	var quad := SphereMesh.new()
	quad.radius = 0.035
	quad.height = 0.07
	quad.radial_segments = 6
	quad.rings = 3
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = burst_color
	quad.material = material
	particles.mesh = quad
	particles.emitting = true
