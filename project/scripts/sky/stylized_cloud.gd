@tool
extends Node3D
## Nube individual: mover/rotar/escalar este nodo para colocarla a mano.
@export var shape_seed := 1
## Número de lóbulos. Reconstruir con Regenerate Shape tras editarlo.
@export_range(3, 24, 1) var lobes := 9
## Anchura y profundidad; cambios visibles sin regenerar.
@export var dimensions := Vector3(30, 12, 18)
## Variación de tamaños y posiciones entre lóbulos. Requiere regeneración.
@export_range(0.0, 1.0, 0.01) var irregularity := 0.5
## Desplaza la cumbre principal hacia un lado; cero la centra. Regenerar.
@export_range(0.0, 1.0, 0.01) var asymmetry := 0.65
## Diferencia de tamaño entre los lóbulos. Regenerar.
@export_range(0.0, 1.0, 0.01) var lobe_size_variation := 0.6
## Altura de las cumbres sobre la base; valores bajos forman nubes aplanadas. Regenerar.
@export_range(0.0, 1.5, 0.05) var peak_height := 0.85
## Alineación inferior de los lóbulos de base; uno da una base más uniforme. Regenerar.
@export_range(0.0, 1.0, 0.01) var base_flatness := 0.75
## Resolución de la superficie fusionada. Mayor valor mejora el contorno pero encarece regenerar.
@export_range(12, 48, 4) var roundness := 28
## Radio de fusión entre volúmenes. Mayor suaviza hendiduras y une abultamientos. Regenerar.
@export_range(0.03, 0.3, 0.01) var fusion_softness := 0.14
@export var cloud_color := Color(0.98, 0.99, 1.0)
@export var shadow_color := Color(0.62, 0.73, 0.85)
## Anchura de transición entre luz y sombra; mayor es más suave.
@export_range(0.05, 1.0, 0.01) var shading_softness := 0.75
@export_tool_button("Regenerate Shape") var regenerate_action = regenerate
## Reconstruye automáticamente la forma al editarla. Sólo actúa en el editor.
@export var live_preview := true
## Espera después del último cambio para agrupar el arrastre de sliders.
@export_range(0.1, 1.5, 0.05) var preview_delay := 0.35
var sun_direction := Vector3(0.4, 0.8, 0.3)
var _mesh: MeshInstance3D
var _material: ShaderMaterial
var _built_shape: Array = []
var _observed_shape: Array = []
var _preview_wait := 0.0

func _ready() -> void:
	regenerate()

func regenerate() -> void:
	if not is_inside_tree():
		return
	if is_instance_valid(_mesh):
		remove_child(_mesh)
		_mesh.queue_free()
	_mesh = MeshInstance3D.new()
	_mesh.name = "FusedCloudSurface"
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shapes: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = shape_seed
	# Núcleo continuo: los lóbulos se apoyan en él, evitando anillos y huecos.
	shapes.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.9, 0.32, 0.7)), Vector3(0, -0.04, 0)))
	var base_count := maxi(1, int((lobes - 1) * 0.5))
	var peak_count := lobes - 1 - base_count
	var peak_offset := rng.randf_range(-0.23, 0.23) * asymmetry
	for i in base_count:
		var along := float(i) / maxf(1.0, base_count - 1)
		var x := lerpf(-0.36, 0.36, along) if base_count > 1 else 0.0
		var size := lerpf(1.0, rng.randf_range(0.65, 1.25), lobe_size_variation)
		var extent := Vector3(0.42, 0.4, 0.65) * size
		var bottom := lerpf(rng.randf_range(-0.26, -0.12), -0.2, base_flatness)
		var center := Vector3(x + rng.randf_range(-0.035, 0.035) * irregularity, bottom + extent.y * 0.5, rng.randf_range(-0.12, 0.12) * irregularity)
		shapes.append(Transform3D(Basis.IDENTITY.scaled(extent), center))
	for i in peak_count:
		# Una cumbre dominante y cumbres secundarias desiguales, sin simetría radial.
		var x := peak_offset if i == 0 else rng.randf_range(-0.33, 0.33)
		var dominance := 1.0 if i == 0 else rng.randf_range(0.45, 0.85)
		var size := lerpf(1.0, rng.randf_range(0.65, 1.2), lobe_size_variation)
		var height := (0.3 + peak_height * 0.65 * dominance) * size
		var extent := Vector3(rng.randf_range(0.32, 0.52), height, rng.randf_range(0.45, 0.7))
		var center := Vector3(x, -0.05 + height * 0.36, rng.randf_range(-0.17, 0.17) * irregularity)
		shapes.append(Transform3D(Basis.IDENTITY.scaled(extent), center))
	_mesh.mesh = preload("res://scripts/sky/cloud_surface.gd").build(shapes, roundness, maxf(0.01, fusion_softness))
	_material = ShaderMaterial.new()
	_material.shader = preload("res://shaders/stylized_cloud.gdshader")
	_mesh.material_override = _material
	add_child(_mesh)
	_update_material()
	_built_shape = _shape_settings()
	_observed_shape = _built_shape.duplicate()
	_preview_wait = 0.0

func _process(delta: float) -> void:
	if Engine.is_editor_hint() and live_preview:
		var settings := _shape_settings()
		if settings != _observed_shape:
			_observed_shape = settings
			_preview_wait = 0.0
		if settings != _built_shape:
			_preview_wait += delta
			if _preview_wait >= preview_delay:
				regenerate()
	_update_material()

func _shape_settings() -> Array:
	return [shape_seed, lobes, irregularity, asymmetry, lobe_size_variation, peak_height, base_flatness, roundness, fusion_softness]

func _update_material() -> void:
	if not is_instance_valid(_mesh):
		return
	_mesh.scale = Vector3(maxf(0.1, dimensions.x), maxf(0.1, dimensions.y), maxf(0.1, dimensions.z))
	_material.set_shader_parameter("cloud_color", cloud_color)
	_material.set_shader_parameter("shadow_color", shadow_color)
	_material.set_shader_parameter("shading_softness", shading_softness)
	_material.set_shader_parameter("sun_direction", sun_direction)
