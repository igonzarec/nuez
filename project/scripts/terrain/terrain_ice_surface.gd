class_name TerrainIceSurface
extends Node
## Detecta hielo pintado en Terrain3D bajo un punto. ExplorerPlayer consulta el
## grupo "ice_surface_receivers" y entra en patinaje mientras ice_contact()
## devuelve datos. Colócalo como hijo del nodo Terrain3D. Ver docs/ice_skating.md.

@export_group("Detección")
## Activa la detección de hielo de este terreno. Apagado, el player nunca patina aquí. Se consulta en vivo.
@export var enabled := true
## Terrain3D donde se pinta el hielo. Vacío usa el nodo padre, que entonces debe ser un Terrain3D; si no lo es, avisa en la consola y no detecta hielo. Se resuelve al iniciar.
@export var terrain: Terrain3D
## Texto buscado (sin distinguir mayúsculas) en los nombres de las texturas de Terrain3D Assets. Cada slot cuyo nombre lo contenga cuenta como hielo, p. ej. «ice». Vacío desactiva la búsqueda por nombre. Se resuelve al iniciar.
@export var texture_name_match := "ice"
## IDs de slot de textura de Terrain3D que cuentan como hielo, además de los encontrados por nombre. Útil si el slot tiene otro nombre. Se resuelve al iniciar.
@export var extra_texture_ids: PackedInt32Array = PackedInt32Array()
## Cobertura mínima de hielo (0–1) para patinar. La cobertura sale de la mezcla base/overlay pintada: mayor exige hielo más puro y evita patinar en los bordes difuminados; menor amplía la zona de patinaje. Se consulta en vivo.
@export_range(0.05, 1.0, 0.05) var minimum_coverage := 0.5
## Distancia vertical máxima, en metros, entre los pies y la altura del terreno. Evita patinar sobre objetos o colisiones situadas por encima del hielo pintado. Se consulta en vivo.
@export_range(0.02, 1.0, 0.01, "suffix:m") var contact_tolerance := 0.25
## Pendiente máxima, en grados desde la horizontal, donde el hielo funciona. Por encima el player usa el movimiento normal o el deslizamiento por pendiente. Se consulta en vivo.
@export_range(0.0, 60.0, 0.5, "suffix:°") var maximum_slope_degrees := 35.0

var _ice_ids: Dictionary = {}

func _ready() -> void:
	add_to_group("ice_surface_receivers")
	if terrain == null:
		terrain = get_parent() as Terrain3D
	if terrain == null:
		push_warning("TerrainIceSurface '%s': no encuentra un Terrain3D. Asigna Terrain o colócalo como hijo de Terrain3D." % name)
	refresh_texture_ids()

## Vuelve a leer los slots de hielo. Llamar si se añaden texturas durante el juego.
func refresh_texture_ids() -> void:
	_ice_ids.clear()
	for id in extra_texture_ids:
		_ice_ids[id] = true
	if terrain == null or terrain.assets == null or texture_name_match.strip_edges().is_empty():
		return
	var needle := texture_name_match.strip_edges().to_lower()
	for asset in terrain.assets.texture_list:
		if asset and String(asset.name).to_lower().contains(needle):
			_ice_ids[asset.id] = true

## Devuelve {"coverage", "normal", "height"} si point está sobre hielo pintado;
## {} si no. ignore_height acepta puntos en el aire sobre el hielo (reflejos).
func ice_contact(point: Vector3, ignore_height := false) -> Dictionary:
	if not enabled or _ice_ids.is_empty() or terrain == null or terrain.data == null:
		return {}
	if not terrain.data.has_regionp(point) or terrain.data.get_control_hole(point):
		return {}
	var height := terrain.data.get_height(point)
	if not is_finite(height) or (not ignore_height and absf(point.y - height) > contact_tolerance):
		return {}
	var normal := terrain.data.get_normal(point)
	if not normal.is_finite() or normal.y < cos(deg_to_rad(maximum_slope_degrees)):
		return {}
	# x = base, y = overlay, z = mezcla hacia overlay (0–1).
	var texture := terrain.data.get_texture_id(point)
	if not texture.is_finite():
		return {}
	var coverage := 0.0
	if _ice_ids.has(int(texture.x)):
		coverage += 1.0 - texture.z
	if _ice_ids.has(int(texture.y)):
		coverage += texture.z
	if coverage < minimum_coverage:
		return {}
	return {"coverage": minf(coverage, 1.0), "normal": normal, "height": height}
