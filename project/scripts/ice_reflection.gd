class_name IceReflection
extends Node3D
## Reflejo ligero de un ExplorerPlayer (player o NPC) sobre hielo de Terrain3D.
## Dibuja una copia invertida de sus mallas rígidas bajo el plano del hielo, con
## shaders/ice_reflection.gdshader. Funciona con el renderer Compatibility (sin
## SSR). Colócalo como hijo del ExplorerPlayer. Ver docs/ice_skating.md.

const SHADER := preload("res://shaders/ice_reflection.gdshader")

@export_group("General")
## Activa el reflejo de este personaje. Apagado oculta la copia y no consulta el hielo. En vivo.
@export var enabled := true
## Intensidad del reflejo (0–1) sobre hielo completo. 0,3 es un brillo sutil; 0,6 casi un espejo. En vivo.
@export_range(0.0, 1.0, 0.01) var opacity := 0.3
## Distancia, en metros, en que el reflejo se desvanece al alejarse del plano del hielo. Menor deja visibles sólo pies y piernas; mayor refleja el cuerpo entero. En vivo.
@export_range(0.05, 3.0, 0.05, "suffix:m") var fade_depth := 0.9
## Altura máxima sobre el hielo, en metros, a la que aún se refleja (saltos, planeo). Se desvanece gradualmente hasta este valor. En vivo.
@export_range(0.1, 10.0, 0.1, "suffix:m") var max_height := 3.0
## Rapidez de aparición y desaparición al entrar o salir del hielo, en s⁻¹. En vivo.
@export_range(1.0, 40.0, 0.5) var response := 8.0

@export_group("Color")
## Color del hielo que tiñe el reflejo. En vivo.
@export var tint := Color(0.55, 0.75, 0.95)
## Cuánto pesa Tint frente a los colores del personaje (0–1). En vivo.
@export_range(0.0, 1.0, 0.01) var tint_amount := 0.35
## Multiplicador de brillo de los colores reflejados. Menor oscurece el reflejo. En vivo.
@export_range(0.0, 2.0, 0.01) var brightness := 0.9

@export_group("Rendimiento")
## Segundos entre búsquedas de mallas nuevas (p. ej. al ponerse un sombrero). Menor detecta antes cambios de accesorios; cada búsqueda recorre el modelo. En vivo.
@export_range(0.1, 5.0, 0.1, "suffix:s") var rescan_interval := 1.0
## Separación del reflejo sobre el terreno para evitar parpadeos de profundidad, en metros. Aumentar si el reflejo parpadea a lo lejos. En vivo.
@export_range(0.0, 0.3, 0.005, "suffix:m") var depth_lift := 0.04

var _actor: ExplorerPlayer
var _mirror: Node3D
var _entries: Array = []
var _materials: Dictionary = {}
var _level := 0.0
var _plane := 0.0
var _rescan_left := 0.0

func _ready() -> void:
	_actor = get_parent() as ExplorerPlayer
	_mirror = Node3D.new()
	_mirror.name = "Mirror"
	_mirror.top_level = true
	_mirror.visible = false
	add_child(_mirror)

func _process(delta: float) -> void:
	if not _actor or not _actor.model:
		return
	var target := 0.0
	if enabled and _actor.skate_enabled:
		var contact := _actor.ice_contact_at(_actor.global_position, true)
		if not contact.is_empty():
			_plane = contact.height
			var height := _actor.global_position.y - _plane
			target = opacity * contact.coverage * (1.0 - smoothstep(max_height * 0.5, max_height, height))
	_level = lerpf(_level, target, 1.0 - exp(-response * delta))
	if _level < 0.004:
		_mirror.visible = false
		return
	_rescan_left -= delta
	if _rescan_left <= 0.0:
		_rescan_left = rescan_interval
		_rescan()
	_mirror.visible = true
	for material: ShaderMaterial in _materials.values():
		material.set_shader_parameter("opacity", _level)
		material.set_shader_parameter("plane_height", _plane)
		material.set_shader_parameter("fade_depth", fade_depth)
		material.set_shader_parameter("depth_lift", depth_lift)
		material.set_shader_parameter("tint", tint)
		material.set_shader_parameter("tint_amount", tint_amount)
		material.set_shader_parameter("brightness", brightness)
	# Reflexión respecto al plano horizontal y = _plane.
	var mirror := Transform3D(Basis.from_scale(Vector3(1.0, -1.0, 1.0)), Vector3(0.0, 2.0 * _plane, 0.0))
	for entry: Array in _entries:
		var source: MeshInstance3D = entry[0]
		var copy: MeshInstance3D = entry[1]
		if not is_instance_valid(source):
			continue
		copy.visible = source.is_visible_in_tree()
		if not copy.visible:
			continue
		if copy.mesh != source.mesh:
			copy.mesh = source.mesh
			_assign_materials(source, copy)
		copy.global_transform = mirror * source.global_transform

func _rescan() -> void:
	var sources: Array = []
	for node in _actor.model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		# Las mallas con skin necesitan el esqueleto; las rígidas cubren el modelo.
		if mesh_instance.mesh and mesh_instance.skin == null:
			sources.append(mesh_instance)
	var known: Dictionary = {}
	for entry: Array in _entries:
		known[entry[0]] = entry
	var updated: Array = []
	for source: MeshInstance3D in sources:
		if known.has(source):
			updated.append(known[source])
			known.erase(source)
			continue
		var copy := MeshInstance3D.new()
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		copy.mesh = source.mesh
		_mirror.add_child(copy)
		_assign_materials(source, copy)
		updated.append([source, copy])
	for entry: Array in known.values():
		(entry[1] as Node).queue_free()
	_entries = updated

func _assign_materials(source: MeshInstance3D, copy: MeshInstance3D) -> void:
	for surface in source.mesh.get_surface_count():
		copy.set_surface_override_material(surface, _reflection_material(source.get_active_material(surface)))

func _reflection_material(original: Material) -> ShaderMaterial:
	if _materials.has(original):
		return _materials[original]
	var material := ShaderMaterial.new()
	material.shader = SHADER
	var base := original as BaseMaterial3D
	if base:
		material.set_shader_parameter("albedo", base.albedo_color)
		material.set_shader_parameter("use_vertex_color", base.vertex_color_use_as_albedo)
		if base.albedo_texture:
			material.set_shader_parameter("albedo_texture", base.albedo_texture)
			material.set_shader_parameter("use_texture", true)
	else:
		material.set_shader_parameter("albedo", Color(0.5, 0.4, 0.35))
	_materials[original] = material
	return material
