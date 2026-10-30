@tool
extends Node3D
## Punto de retorno estable y cuerpo físico independiente de la presentación equipada.

## Activa objeto físico e interacción cuando no está equipado. En vivo.
@export var enabled := true

@export_group("Colocación")
## Identificador estable y único del origen. Vacío usa escena + ruta del nodo. Reiniciar tras cambiarlo.
@export var spawn_id := ""
## Transformación local inicial del cuerpo, relativa a este nodo. Requiere reiniciar.
@export var spawn_transform := Transform3D.IDENTITY
## Escena visual compartida, instanciada por separado. Requiere reiniciar.
@export var visual_scene: PackedScene = preload("res://scenes/accessories/green_hat_visual.tscn")
## Forma y colores compartidos con la presentación equipada. Live Preview en la escena visual.
@export var style: GreenHatStyle = preload("res://resources/accessories/green_hat_style.tres")
## Desplazamiento extra del gorro en metros. Con 0 el borde blanco se apoya justo sobre el suelo
## (la altura se calcula a partir de Brim Height y Collision Height). En vivo, también en el editor.
@export var visual_offset := Vector3.ZERO
## Rotación del gorro en grados. 0 lo deja recto, apoyado sobre el borde. En vivo, también en el editor.
@export var visual_rotation_degrees := Vector3.ZERO
## Escala visual; ajustar Collision Radius/Height si se cambia. En vivo, también en el editor.
@export var visual_scale := Vector3.ONE

@export_group("Aspecto en el suelo")
## Cuánto se ve desinflado el gorro tirado (0–1). 0 conserva la forma del gorro puesto; el gorro puesto
## nunca se desinfla. Live Preview, también en el editor.
@export_range(0.0, 1.0, 0.01) var deflate := 0.7
## Cuánto se hunde la tela verde en altura con Deflate = 1 (fracción). Live Preview.
@export_range(0.0, 0.9, 0.01) var deflate_height := 0.45
## Cuánto se ensancha la tela al hundirse con Deflate = 1 (fracción). Live Preview.
@export_range(0.0, 0.6, 0.01) var deflate_width := 0.12
## Cuánto se ablanda la tela con Deflate = 1 (fracción de la rigidez): la cola cae más lacia. En vivo.
@export_range(0.0, 0.95, 0.01) var deflate_softness := 0.6
## Ajusta al suelo al iniciar y devolver el objeto. Espera colisión del terreno antes de soltarlo.
@export var ground_snap := true
## Búsqueda vertical en metros alrededor del origen. Mayor permite desniveles mayores. Reiniciar.
@export_range(1, 500, 1) var ground_search := 160.0
## Margen sobre el suelo en metros; mayor deja una caída inicial más visible. Reiniciar.
@export_range(0.005, 0.2, 0.005) var ground_clearance := 0.025
## Caída máxima bajo el origen antes de recuperar el objeto, en metros. En vivo.
@export_range(5, 500, 1) var recovery_depth := 180.0
@export_group("Física")
## Gravedad y contactos del cuerpo. Desactivar lo congela. En vivo.
@export var physics_enabled := true
## Masa en kg. Mayor dificulta empujarlo. En vivo.
@export_range(0.05, 10, 0.05) var mass := 0.3
## Radio de colisión simple en metros; ajustar a la anchura visual. En vivo.
@export_range(0.1, 1.5, 0.01) var collision_radius := 0.52
## Alto de colisión en metros. Base apoyada bajo el borde. En vivo.
@export_range(0.08, 1, 0.01) var collision_height := 0.28
## Fricción de contacto: mayor reduce deslizamiento. En vivo.
@export_range(0, 1, 0.01) var friction := 0.85
## Rebote: 0 evita saltos al aterrizar. En vivo.
@export_range(0, 1, 0.01) var bounce := 0.03
## Amortiguación lineal en 1/s. Mayor frena antes. En vivo.
@export_range(0, 10, 0.1) var linear_damping := 1.2
## Amortiguación angular en 1/s. Mayor estabiliza los giros. En vivo.
@export_range(0, 10, 0.1) var angular_damping := 4.0
## Mantiene el borde horizontal; permite giro Y sin volcar en pendientes. En vivo.
@export var keep_upright := true
## Capas del cuerpo. Por defecto no bloquea al jugador ni el rayo de interacción. En vivo.
@export_flags_3d_physics var body_layer := 16
## Capas con las que colisiona; 1 es terreno. En vivo.
@export_flags_3d_physics var body_mask := 1
@export_group("Interacción")
## Distancia máxima al jugador en metros. Mayor permite recoger desde más lejos. En vivo.
@export_range(0.5, 8, 0.1) var interaction_distance := 2.8
## Altura del prompt sobre el cuerpo, en metros. En vivo.
@export_range(0.3, 3, 0.05) var prompt_height := 1.2
@export_group("Audio")
## Sonido al equipar; volumen y tono dentro del recurso. En vivo al abrir el selector.
@export var equip_sound: TrailSoundCue = preload("res://resources/accessories/green_hat_equip_sound.tres")
## Sonido al quitar; volumen y tono dentro del recurso. En vivo al abrir el selector.
@export var unequip_sound: TrailSoundCue = preload("res://resources/accessories/green_hat_unequip_sound.tres")
var _body: RigidBody3D
var _shape: CylinderShape3D
var _interaction: TrailInteractable
var _visual: Node3D
var _origin := ""
var _active := false
var _settling := false
var _editor_visual: Node3D

func _ready() -> void:
	if Engine.is_editor_hint():
		# Vista previa sólo de editor (no se guarda): se actualiza en vivo con la colocación y el desinflado.
		_editor_visual = visual_scene.instantiate()
		_editor_visual.set("style", style)
		_editor_visual.set("ground_collision", true)
		add_child(_editor_visual)
		_apply_look(_editor_visual)
		return
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_origin = spawn_id if not spawn_id.is_empty() else get_tree().current_scene.scene_file_path + ":" + str(get_tree().current_scene.get_path_to(self))
	_body = RigidBody3D.new()
	_body.name = "GroundBody"
	_body.freeze = true
	_body.continuous_cd = true
	_body.physics_material_override = PhysicsMaterial.new()
	add_child(_body)
	var collider := CollisionShape3D.new()
	_shape = CylinderShape3D.new()
	collider.shape = _shape
	_body.add_child(collider)
	_visual = visual_scene.instantiate()
	_visual.set("style", style)
	# La cola cae por gravedad y se apoya en el suelo bajo el gorro tirado.
	_visual.set("ground_collision", true)
	_apply_look(_visual)
	_body.add_child(_visual)
	_interaction = TrailInteractable.new()
	_interaction.display_name = "green hat"
	_interaction.verb = "Elegir"
	_interaction.activation = _open_choice
	_interaction.collision_exclusions = [_body.get_rid()]
	_body.add_child(_interaction)
	_interaction.build_prompt(prompt_height)
	TrailWardrobe.register_pickup("christmas_hat", self, _origin)
	TrailWardrobe.changed.connect(_changed)
	_apply_physics()
	_sync.call_deferred()

func _changed(item: String) -> void:
	if item == "christmas_hat": _sync()

func _sync() -> void:
	var authorized := TrailWardrobe.pickup_is_authorized("christmas_hat", self, _origin)
	if authorized: PauseMenu.configure_hat_audio(equip_sound, unequip_sound)
	var active := enabled and authorized and not TrailWardrobe.is_equipped("christmas_hat")
	_body.visible = active
	_interaction.available = active and not _settling
	if not active: _interaction.show_prompt(false, false)
	_body.collision_layer = body_layer if active else 0
	_body.collision_mask = body_mask if active else 0
	_body.freeze = not active or not physics_enabled
	if active and not _active: _restore.call_deferred()
	_active = active

## Transformación del gorro respecto al centro del cuerpo: borde apoyado en la base del cilindro de colisión.
func _visual_transform() -> Transform3D:
	var rest_height := (style.brim_height * 0.5 * visual_scale.y if style else 0.0) - collision_height * 0.5
	return Transform3D(Basis.from_euler(visual_rotation_degrees * PI / 180.0).scaled(visual_scale), Vector3(0, rest_height, 0) + visual_offset)

## Desinflado propio del gorro tirado; no toca el estilo compartido con el gorro puesto.
func _apply_look(visual: Node3D) -> void:
	visual.set("deflate", deflate)
	visual.set("deflate_height", deflate_height)
	visual.set("deflate_width", deflate_width)
	visual.set("deflate_softness", deflate_softness)
	if Engine.is_editor_hint():
		# En el editor el origen del nodo marca el suelo; el cuerpo se apoyaría sobre él.
		visual.transform = spawn_transform * Transform3D(Basis.IDENTITY, Vector3.UP * collision_height * 0.5) * _visual_transform()
	else:
		visual.transform = _visual_transform()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() and is_instance_valid(_editor_visual):
		if _editor_visual.get("style") != style: _editor_visual.set("style", style)
		_apply_look(_editor_visual)

func _apply_physics() -> void:
	_apply_look(_visual)
	_shape.radius = collision_radius
	_shape.height = collision_height
	_body.mass = mass
	_body.linear_damp = linear_damping
	_body.angular_damp = angular_damping
	_body.axis_lock_angular_x = keep_upright
	_body.axis_lock_angular_z = keep_upright
	_body.physics_material_override.friction = friction
	_body.physics_material_override.bounce = bounce
	_body.collision_layer = body_layer if _active else 0
	_body.collision_mask = body_mask if _active else 0
	_body.freeze = not _active or _settling or not physics_enabled
	_interaction.interaction_reach = interaction_distance
	_interaction.prompt_pin.set("height", prompt_height)

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or not is_instance_valid(_body): return
	var active := enabled and TrailWardrobe.pickup_is_authorized("christmas_hat", self, _origin) and not TrailWardrobe.is_equipped("christmas_hat")
	if active != _active: _sync()
	_apply_physics()
	if _active and not _settling and _body.global_position.y < global_position.y - recovery_depth: _restore()

func _restore() -> void:
	if _settling or not _active: return
	_settling = true
	_interaction.available = false
	_body.freeze = true
	_body.transform = spawn_transform
	_body.linear_velocity = Vector3.ZERO
	_body.angular_velocity = Vector3.ZERO
	if ground_snap:
		# Retry until streamed terrain collision is ready; never release into empty space.
		var grounded := false
		while is_inside_tree() and _active and not grounded:
			await get_tree().physics_frame
			if not is_inside_tree(): return
			var start := global_transform * spawn_transform.origin
			var ray := PhysicsRayQueryParameters3D.create(start + Vector3.UP * ground_search, start - Vector3.UP * ground_search, body_mask, [_body.get_rid()])
			var hit := get_world_3d().direct_space_state.intersect_ray(ray)
			if not hit.is_empty():
				_body.global_position = hit.position + Vector3.UP * (collision_height * 0.5 + ground_clearance)
				grounded = true
	_settling = false
	_interaction.available = _active
	_body.freeze = not physics_enabled or not _active
	_body.sleeping = false

func _open_choice() -> void:
	if _active:
		PauseMenu.open_hat_choice(_origin, equip_sound, unequip_sound)
