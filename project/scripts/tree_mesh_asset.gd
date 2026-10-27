@tool
class_name TreeMeshAsset
extends Terrain3DMeshAsset
## Asset Terrain3D con materiales de árbol propios. Conserva los campos nativos, ID y pinceladas.

const Palette = preload("res://scripts/tree_material_palette.gd")
const LodPreparer = preload("res://scripts/tree_lod_preparer.gd")

@export_group("LOD - Preparación en editor")
## GLB/escena original para preparar o regenerar los LOD. Vacío usa Scene File la primera vez. Conserva este origen al generar la escena derivada; no modifica el modelo ni sus importaciones. Sólo se usa al pulsar Preparar LOD.
@export var lod_source_model: PackedScene
## Carpeta res:// para escenas y mallas generadas. Regenerar reemplaza sólo los archivos generados de este asset; no editar esos archivos a mano. Cambiar requiere Preparar LOD.
@export_dir var lod_output_directory := "res://resources/trees/lod_scenes"
## Fracción objetivo de triángulos del nivel intermedio. 0.5 busca el 50 %; reutiliza índices importados y simplifica por piezas el follaje protegido. Es un objetivo, no una cuota exacta. Mayor conserva detalle. Requiere Preparar LOD.
@export_range(0.05, 1.0, 0.01) var lod_mid_ratio := 0.5
## Fracción objetivo del nivel lejano. Mayor conserva silueta y cuesta más GPU; menor puede perder ramas/hojas. Se limita al ratio intermedio. Requiere Preparar LOD.
@export_range(0.01, 1.0, 0.01) var lod_far_ratio := 0.18
## Mínimo de triángulos por superficie, salvo que el original ya tenga menos. Evita seleccionar reducciones extremas de follaje. No garantiza conservar todas las ramas. Mayor limita la simplificación. Requiere Preparar LOD.
@export_range(1, 512, 1) var lod_min_surface_triangles := 32
## Conserva todas las piezas conectadas de hojas, reconocidas con Foliage Material Keywords/Surface Indices. Simplifica cada pieza; las cartas UV convexas completas pueden reducirse a su contorno. Evita perder ramas enteras. Más costoso sólo al preparar; desactivar permite LOD global. Requiere Preparar LOD.
@export var lod_preserve_leaf_parts := true
## Tolerancia en coordenadas UV para enderezar bordes casi rectos de las cartas lejanas. Mayor permite simplificar más, con posible pérdida de curvatura; 0 conserva todos los vértices del contorno. Sólo con Preserve Leaf Parts; requiere Preparar LOD.
@export_range(0.0, 0.01, 0.0001) var lod_leaf_uv_tolerance := 0.002
## Malla intermedia manual opcional. Debe compartir origen, escala, UV y materiales con el modelo. Vacío elige índices LOD importados. Requiere Preparar LOD.
@export var lod_mid_override: ArrayMesh
## Malla lejana manual opcional para mejorar la silueta cuando el LOD automático falla. Debe compartir origen y escala; conservar nombres de material para los colores. Requiere Preparar LOD.
@export var lod_far_override: ArrayMesh
## Prepara tres niveles en disco y los asigna a ESTE asset sin repintar. Conserva ID, densidad, altura, colores y propiedades de colocación. Sólo editor; las ediciones costosas se agrupan en este botón. Repetir regenera desde Source Model.
@export_tool_button("Preparar / regenerar LOD", "Bake") var prepare_lod_action: Callable:
	get:
		return Callable(self, "prepare_tree_lods")
## Resultado de la última preparación: triángulos por nivel y advertencias. Sólo lectura; comparar visualmente antes de ajustar rangos definitivos.
@export_multiline var lod_preparation_report := "Sin preparar. Se usan los LOD/rangos actuales del asset."

@export_group("LOD - Distancias y sombras")
## Activa los tres niveles preparados. Apagar conserva sólo LOD0 hasta la distancia final (más costoso). Sólo afecta a la escena preparada por este asset; no altera modelos o LOD externos. En vivo.
@export var tree_lod_enabled := true:
	set(value):
		tree_lod_enabled = value
		request_material_update()
## Metros hasta el cambio de LOD0 a LOD1. Mayor conserva detalle cercano a más distancia. Terrain3D decide por celdas de 32 m, no por árbol. Se limita por debajo del rango intermedio. En vivo tras preparar LOD.
@export_range(1.0, 2000.0, 1.0, "suffix:m") var lod_near_distance := 80.0:
	set(value):
		lod_near_distance = value
		request_material_update()
## Metros hasta cambiar de LOD1 a LOD2. Mayor mantiene detalle intermedio y cuesta más GPU. Se limita entre el rango cercano y final. En vivo tras preparar LOD.
@export_range(2.0, 4000.0, 1.0, "suffix:m") var lod_mid_distance := 220.0:
	set(value):
		lod_mid_distance = value
		request_material_update()
## Distancia final en metros: LOD2 queda visible hasta este rango, sujeto a cámara/frustum. Mayor amplía paisaje y número de celdas dibujadas. No es distancia de sombras. En vivo tras preparar LOD.
@export_range(3.0, 8000.0, 1.0, "suffix:m") var lod_far_distance := 900.0:
	set(value):
		lod_far_distance = value
		request_material_update()
## Último nivel que proyecta sombras: -1 ninguna, 0 cercano, 1 cercano/intermedio, 2 todos. Reducir ahorra GPU sin ocultar el árbol. También depende de la distancia de sombras de la luz. En vivo tras preparar LOD.
@export_range(-1, 2, 1) var lod_last_shadow_level := 1:
	set(value):
		lod_last_shadow_level = value
		request_material_update()
## Escena derivada guardada para reconocer los LOD propios. No se edita en Inspector; permite volver a abrir el proyecto sin regenerar. Si Scene File cambia manualmente, no se sobrescriben sus rangos.
@export_storage var prepared_lod_scene: PackedScene

@export_group("Colores del árbol")
## Color/tinte de las hojas de ESTE mesh. Blanco conserva la textura; verde tiñe la máscara blanca. Se aplica en el siguiente ciclo del editor/juego sin TreeColors y se guarda dentro de Tree Materials. No cambia el tronco ni otros meshes.
@export var foliage_color: Color:
	get:
		request_material_update()
		return tree_materials.foliage_color if tree_materials != null else Color(0.26, 0.40, 0.13, 1.0)
	set(value):
		_ensure_materials()
		tree_materials.foliage_color = value
		emit_changed()
		request_material_update()
## Color/tinte del tronco de ESTE mesh. Blanco conserva el color de la textura marrón; se multiplica por ella. Se aplica en el siguiente ciclo sin TreeColors y se guarda dentro de Tree Materials. Para color liso elegir Bark Texture Mode: Sin textura en los ajustes avanzados.
@export var bark_color: Color:
	get:
		request_material_update()
		return tree_materials.bark_color if tree_materials != null else Color(0.46, 0.30, 0.18, 1.0)
	set(value):
		_ensure_materials()
		tree_materials.bark_color = value
		emit_changed()
		request_material_update()

@export_group("Materiales del árbol")
## Colores, texturas y recorte de hojas de ESTE mesh, aplicados automáticamente sin nodos auxiliares. Abrir para ajustes avanzados; las ediciones se agrupan en el siguiente ciclo. Usar Make Unique si se comparte el recurso y se desean colores independientes.
@export var tree_materials: Palette = Palette.new():
	set(value):
		if tree_materials != null and tree_materials.changed.is_connected(request_material_update):
			tree_materials.changed.disconnect(request_material_update)
		tree_materials = value
		request_material_update()
## Reaplica sólo los materiales de este mesh. Útil después de una recarga de script/importación. No cambia geometría, ID ni pinceladas; no requiere TreeColors.
@export_tool_button("Reaplicar materiales", "Reload") var refresh_tree_materials: Callable:
	get:
		return Callable(self, "apply_tree_materials")

var _tree_material_entries: Array[Dictionary] = []
var _tree_material_stamp := 0
var _tree_material_pending := false


func _init() -> void:
	request_material_update()


func request_material_update() -> void:
	if tree_materials != null and not tree_materials.changed.is_connected(request_material_update):
		tree_materials.changed.connect(request_material_update)
	if not file_changed.is_connected(request_material_update):
		file_changed.connect(request_material_update)
	if not setting_changed.is_connected(request_material_update):
		setting_changed.connect(request_material_update)
	if not instancer_setting_changed.is_connected(request_material_update):
		instancer_setting_changed.connect(request_material_update)
	if not _tree_material_pending:
		_tree_material_pending = true
		apply_tree_materials.call_deferred()


func apply_tree_materials() -> void:
	_tree_material_pending = false
	_apply_tree_lod_ranges()
	var meshes: Array[ArrayMesh] = []
	var configuration: Array = [material_override, tree_materials.signature() if tree_materials != null else 0]
	if scene_file != null:
		for lod in range(last_lod + 1):
			var mesh := get_mesh(lod) as ArrayMesh
			if mesh != null:
				meshes.append(mesh)
				configuration.append([mesh, mesh.get_surface_count()])
	var stamp := hash(configuration)
	var intact := true
	for entry in _tree_material_entries:
		if entry.surface >= entry.mesh.get_surface_count() or entry.mesh.surface_get_material(entry.surface) != entry.material:
			intact = false
	if stamp == _tree_material_stamp and intact:
		return
	_tree_material_stamp = stamp
	_restore_tree_materials()
	if tree_materials == null or not tree_materials.enabled or material_override != null:
		return
	var visited: Dictionary = {}
	for mesh in meshes:
		if visited.has(mesh.get_instance_id()):
			continue
		visited[mesh.get_instance_id()] = true
		for surface in mesh.get_surface_count():
			var original := mesh.surface_get_material(surface)
			var material := tree_materials.make_material(original, mesh.surface_get_name(surface), surface)
			if material != null:
				mesh.surface_set_material(surface, material)
				_tree_material_entries.append({"mesh": mesh, "surface": surface, "original": original, "material": material})


func _restore_tree_materials() -> void:
	for entry in _tree_material_entries:
		if entry.surface < entry.mesh.get_surface_count() and entry.mesh.surface_get_material(entry.surface) == entry.material:
			entry.mesh.surface_set_material(entry.surface, entry.original)
	_tree_material_entries.clear()


func _ensure_materials() -> void:
	if tree_materials == null:
		tree_materials = Palette.new()


func _validate_property(property: Dictionary) -> void:
	if property.name in ["foliage_color", "bark_color"]:
		# Inspector proxies only: serialize the source resource once, avoiding
		# duplicate color values overwriting it in an unpredictable loading order.
		property.usage = property.usage & ~PROPERTY_USAGE_STORAGE
	if property.name == "lod_preparation_report":
		property.usage |= PROPERTY_USAGE_READ_ONLY
	if prepared_lod_scene != null and scene_file == prepared_lod_scene:
		if property.name in ["last_lod", "last_shadow_lod"] or (property.name.begins_with("lod") and property.name.ends_with("_range")):
			property.usage |= PROPERTY_USAGE_READ_ONLY


func _apply_tree_lod_ranges() -> void:
	if prepared_lod_scene == null or scene_file != prepared_lod_scene:
		return
	var far_limit := maxf(3.0, lod_far_distance)
	var mid_limit := clampf(lod_mid_distance, 2.0, far_limit - 1.0)
	var near_limit := clampf(lod_near_distance, 1.0, mid_limit - 1.0)
	var last := mini(2, get_lod_count() - 1) if tree_lod_enabled else 0
	if last_lod != last:
		last_lod = last
	var limits := [near_limit, mid_limit, far_limit] if tree_lod_enabled else [far_limit]
	for level in range(last + 1):
		if not is_equal_approx(get_lod_range(level), limits[level]):
			set_lod_range(level, limits[level])
	var shadow_level := mini(last, lod_last_shadow_level)
	if last_shadow_lod != shadow_level:
		last_shadow_lod = shadow_level


func prepare_tree_lods() -> void:
	if not Engine.is_editor_hint():
		push_warning("Preparar LOD sólo está disponible en el editor. El juego utiliza las mallas ya guardadas.")
		return
	_prepare_tree_lods()


func _prepare_tree_lods() -> void:
	var source := lod_source_model if lod_source_model != null else scene_file
	if source == prepared_lod_scene and source != null:
		lod_preparation_report = "Elegir el modelo original en Lod Source Model; no regenerar desde la escena derivada."
		return
	var stem := (name.validate_filename().to_snake_case() + "_asset_%d" % id)
	var result := LodPreparer.prepare(source, lod_output_directory, stem, lod_mid_ratio,
		minf(lod_far_ratio, lod_mid_ratio), lod_min_surface_triangles, lod_mid_override, lod_far_override,
		lod_preserve_leaf_parts, tree_materials.foliage_material_keywords if tree_materials != null else PackedStringArray(["leaf", "leaves", "foliage", "green"]),
		tree_materials.foliage_surface_indices if tree_materials != null else PackedInt32Array(), lod_leaf_uv_tolerance)
	if result.has("error"):
		lod_preparation_report = result.error
		push_error(lod_preparation_report)
		emit_changed()
		return
	# Native set_scene_file() may derive name/density/ranges from the new mesh.
	# Restore authored placement settings exactly; only LOD ranges change here.
	var authored := {"name": name, "id": id, "density": density, "height_offset": height_offset,
		"enabled": enabled, "cast_shadows": cast_shadows, "material_override": material_override,
		"material_overlay": material_overlay, "shadow_impostor": shadow_impostor, "fade_margin": fade_margin}
	_restore_tree_materials()
	lod_source_model = source
	prepared_lod_scene = result.scene
	# Assign the freshly packed resource directly. Clearing Scene File first
	# makes Terrain3D rebuild live batches against a temporarily empty asset.
	scene_file = prepared_lod_scene
	for property in authored:
		set(property, authored[property])
	lod_preparation_report = result.report
	_apply_tree_lod_ranges()
	_tree_material_stamp = 0
	apply_tree_materials()
	notify_property_list_changed()
	emit_changed()
