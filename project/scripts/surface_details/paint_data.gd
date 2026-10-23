@tool
extends Resource
## Cobertura independiente de texturas. Tiles de 16 m con texeles de 0.5 m.
## RGBA: nieve, hojas, tierra y pasto. Se guarda el campo, no cada partícula.
const SIDE := 32
const PIXEL_SIZE := 0.5
const TILE_SIZE := SIDE * PIXEL_SIZE

## Datos internos serializados. No modificar manualmente; usar el pincel y deshacer. Los tiles sólo se crean donde se pinta.
@export_storage var tiles: Dictionary = {}

func get_tile(key: Vector2i) -> Image:
	return tiles.get(key) as Image

func ensure_tile(key: Vector2i) -> Image:
	if not tiles.has(key):
		var image := Image.create(SIDE, SIDE, false, Image.FORMAT_RGBA8)
		image.fill(Color(0, 0, 0, 0))
		tiles[key] = image
	return tiles[key]

func snapshot(key: Vector2i) -> PackedByteArray:
	var image := get_tile(key)
	return image.get_data() if image != null else PackedByteArray()

func restore(snapshots: Dictionary) -> void:
	for key: Vector2i in snapshots:
		var bytes: PackedByteArray = snapshots[key]
		if bytes.is_empty():
			tiles.erase(key)
		else:
			tiles[key] = Image.create_from_data(SIDE, SIDE, false, Image.FORMAT_RGBA8, bytes)
	emit_changed()

func coverage(point: Vector2, channel: int) -> float:
	# Interpolación también entre tiles para evitar sus bordes.
	var uv := point / PIXEL_SIZE - Vector2(0.5, 0.5)
	var cell := Vector2i(uv.floor())
	var weight := uv - Vector2(cell)
	return lerpf(lerpf(_sample(cell, channel), _sample(cell + Vector2i.RIGHT, channel), weight.x),
		lerpf(_sample(cell + Vector2i.DOWN, channel), _sample(cell + Vector2i.ONE, channel), weight.x), weight.y)

func _sample(cell: Vector2i, channel: int) -> float:
	var key := Vector2i(floori(float(cell.x) / SIDE), floori(float(cell.y) / SIDE))
	var image := get_tile(key)
	if image == null:
		return 0.0
	return image.get_pixel(posmod(cell.x, SIDE), posmod(cell.y, SIDE))[channel]
