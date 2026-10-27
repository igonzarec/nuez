@tool
class_name TreeMaterialPalette
extends Resource
## Materiales propios de un mesh Terrain3D. El propio asset los aplica al recibir cambios, sin TreeColors.
## Conserva los materiales importados: sólo modifica copias temporales de las superficies reconocidas.

@export_group("Activación")
## Activa esta paleta. Apagar restaura las superficies originales. En vivo.
@export var enabled := true:
	set(value):
		if enabled != value:
			enabled = value
			emit_changed()
## Filtro guardado para migrar la biblioteca anterior; no se usa en materiales asignados directamente a un mesh.
@export_storage var asset_prefix := "":
	set(value):
		if asset_prefix != value:
			asset_prefix = value
			emit_changed()
## Nombres guardados para migrar la biblioteca anterior; no se usan en materiales asignados directamente a un mesh.
@export_storage var asset_names: PackedStringArray = []:
	set(value):
		if asset_names != value:
			asset_names = value
			emit_changed()

@export_group("Tronco")
## Activa los cambios de tronco. Apagar conserva su material importado. En vivo.
@export var bark_enabled := true:
	set(value):
		if bark_enabled != value:
			bark_enabled = value
			emit_changed()
## Fragmentos del nombre de material que identifican tronco, sin distinguir mayúsculas. No usan el nombre del nodo. En vivo.
@export var bark_material_keywords: PackedStringArray = ["trunk", "bark", "wood"]:
	set(value):
		if bark_material_keywords != value:
			bark_material_keywords = value
			emit_changed()
## Índices de superficie adicionales para modelos sin nombres útiles, desde 0. Se aplican en cada LOD; verificar el orden. En vivo.
@export var bark_surface_indices: PackedInt32Array = []:
	set(value):
		if bark_surface_indices != value:
			bark_surface_indices = value
			emit_changed()
## Color/tinte del tronco. Se multiplica por la textura si existe; blanco conserva su color. En vivo.
@export var bark_color := Color(0.46, 0.30, 0.18, 1.0):
	set(value):
		if bark_color != value:
			bark_color = value
			emit_changed()
## Conservar usa la textura importada; Reemplazar usa Bark Texture; Sin textura produce color liso. No modifica el GLB. En vivo.
@export_enum("Conservar", "Reemplazar", "Sin textura") var bark_texture_mode := 0:
	set(value):
		if bark_texture_mode != value:
			bark_texture_mode = value
			emit_changed()
## Textura de color del tronco para modo Reemplazar. Vacía produce color liso. Mayor resolución consume más memoria GPU; se comparte entre instancias. En vivo.
@export var bark_texture: Texture2D:
	set(value):
		if bark_texture != value:
			bark_texture = value
			emit_changed()

@export_group("Hojas")
## Activa los cambios de hojas. Apagar conserva su material importado. En vivo.
@export var foliage_enabled := true:
	set(value):
		if foliage_enabled != value:
			foliage_enabled = value
			emit_changed()
## Fragmentos del nombre de material que identifican follaje, sin distinguir mayúsculas. Si coincide con tronco, gana follaje. En vivo.
@export var foliage_material_keywords: PackedStringArray = ["leaves", "leaf", "foliage", "green"]:
	set(value):
		if foliage_material_keywords != value:
			foliage_material_keywords = value
			emit_changed()
## Índices de superficie adicionales para follaje, desde 0 y por LOD. Usar sólo si los nombres no bastan. En vivo.
@export var foliage_surface_indices: PackedInt32Array = []:
	set(value):
		if foliage_surface_indices != value:
			foliage_surface_indices = value
			emit_changed()
## Color/tinte del follaje. Se multiplica por la textura; blanco conserva su color y verde tiñe una máscara blanca. En vivo.
@export var foliage_color := Color(0.26, 0.40, 0.13, 1.0):
	set(value):
		if foliage_color != value:
			foliage_color = value
			emit_changed()
## Conservar usa la textura importada; Reemplazar usa Foliage Texture; Sin textura elimina también el recorte de esa textura. En vivo.
@export_enum("Conservar", "Reemplazar", "Sin textura") var foliage_texture_mode := 0:
	set(value):
		if foliage_texture_mode != value:
			foliage_texture_mode = value
			emit_changed()
## Textura RGBA de follaje para modo Reemplazar. Alfa 0 recorta el fondo con Alpha Scissor. Mayor resolución consume más memoria GPU. En vivo.
@export var foliage_texture: Texture2D:
	set(value):
		if foliage_texture != value:
			foliage_texture = value
			emit_changed()
## Conserva transparencia original, fuerza opaco o usa recorte alfa. Alpha Scissor es apropiado para hojas en planos y conserva sombras; opaco es más barato. En vivo.
@export_enum("Conservar", "Opaco", "Alpha Scissor") var foliage_transparency := 0:
	set(value):
		if foliage_transparency != value:
			foliage_transparency = value
			emit_changed()
## Umbral alfa (0–1), usado sólo con Alpha Scissor. Subir recorta más píxeles; bajar conserva más borde. No inventa una máscara ausente. En vivo.
@export_range(0.0, 1.0, 0.01) var alpha_scissor_threshold := 0.5:
	set(value):
		if alpha_scissor_threshold != value:
			alpha_scissor_threshold = value
			emit_changed()
## Dibuja ambas caras de las hojas. Útil para planos; puede aumentar el trabajo de píxeles. Apagar descarta caras traseras. En vivo.
@export var foliage_double_sided := true:
	set(value):
		if foliage_double_sided != value:
			foliage_double_sided = value
			emit_changed()

@export_group("Acabado")
## Sustituye rugosidad y brillo de las partes reconocidas. Apagar conserva los valores originales. En vivo.
@export var override_finish := true:
	set(value):
		if override_finish != value:
			override_finish = value
			emit_changed()
## Rugosidad: 1 mate, 0 brillante. Sólo con Override Finish. En vivo.
@export_range(0.0, 1.0, 0.01) var roughness := 1.0:
	set(value):
		if roughness != value:
			roughness = value
			emit_changed()
## Intensidad especular: subir aumenta reflejos. Sólo con Override Finish. En vivo.
@export_range(0.0, 1.0, 0.01) var specular := 0.1:
	set(value):
		if specular != value:
			specular = value
			emit_changed()


func matches_asset(asset_name: String) -> bool:
	return enabled and ((not asset_prefix.is_empty() and asset_name.begins_with(asset_prefix)) or asset_name in asset_names)


func signature() -> int:
	return hash([enabled, asset_prefix, asset_names, bark_enabled, bark_material_keywords,
		bark_surface_indices, bark_color, bark_texture_mode, bark_texture, foliage_enabled,
		foliage_material_keywords, foliage_surface_indices, foliage_color, foliage_texture_mode,
		foliage_texture, foliage_transparency, alpha_scissor_threshold, foliage_double_sided,
		override_finish, roughness, specular])


func make_material(original: Material, surface_name: String, surface: int) -> StandardMaterial3D:
	# Custom shaders need an explicit shader-specific integration; never discard them.
	if original != null and not original is StandardMaterial3D:
		return null
	var label := surface_name.to_lower()
	if original != null:
		label += " " + original.resource_name.to_lower()
	var foliage := foliage_enabled and (surface in foliage_surface_indices or _matches(label, foliage_material_keywords))
	var bark := bark_enabled and (surface in bark_surface_indices or _matches(label, bark_material_keywords))
	if not foliage and not bark:
		return null
	var material := original.duplicate() as StandardMaterial3D if original != null else StandardMaterial3D.new()
	material.albedo_color = foliage_color if foliage else bark_color
	var mode := foliage_texture_mode if foliage else bark_texture_mode
	if mode == 1:
		material.albedo_texture = foliage_texture if foliage else bark_texture
	elif mode == 2:
		material.albedo_texture = null
	if foliage:
		if foliage_transparency == 1:
			material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		elif foliage_transparency == 2:
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			material.alpha_scissor_threshold = alpha_scissor_threshold
		material.cull_mode = BaseMaterial3D.CULL_DISABLED if foliage_double_sided else BaseMaterial3D.CULL_BACK
	if override_finish:
		material.roughness = roughness
		material.metallic_specular = specular
	return material


func _matches(label: String, keywords: PackedStringArray) -> bool:
	for keyword in keywords:
		if not keyword.is_empty() and label.contains(keyword.to_lower()):
			return true
	return false
