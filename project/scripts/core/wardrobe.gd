extends Node
## Vestuario persistente del jugador: accesorios obtenidos y puestos.
## Se guarda aparte de la expedición para funcionar igual en la partida y en las escenas de trabajo.

signal changed(item_id: String)

const PATH := "user://wardrobe.json"
const QA_PATH := "user://qa_wardrobe.json"
## Nombre visible de cada accesorio en el menú de pausa.
const NAMES := {"christmas_hat": "green hat"}

var _owned: Array[String] = []
var _equipped: Array[String] = []
var _store := TrailSave.new()
var _path := PATH
var _origins: Dictionary = {}
var _pickups: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if "--qa" in OS.get_cmdline_user_args():
		_path = QA_PATH
	var data := _store.read_json(_path)
	var saved_origins: Variant = data.get("origins", {})
	if saved_origins is Dictionary:
		for key in saved_origins:
			if key is String and saved_origins[key] is String: _origins[key] = saved_origins[key]
	var owned: Variant = data.get("owned", [])
	var equipped: Variant = data.get("equipped", [])
	for id: Variant in (owned if owned is Array else []):
		if id is String and not _owned.has(id): _owned.append(id)
	for id: Variant in (equipped if equipped is Array else []):
		if id is String and _owned.has(id) and not _equipped.has(id): _equipped.append(id)

func owns(item_id: String) -> bool:
	return _owned.has(item_id)

func is_equipped(item_id: String) -> bool:
	return _equipped.has(item_id)

func owned_items() -> Array[String]:
	return _owned.duplicate()

func display_name(item_id: String) -> String:
	return NAMES.get(item_id, item_id.replace("_", " "))

## Registra el accesorio como obtenido y, si se pide, lo pone al instante.
func acquire(item_id: String, equip := true) -> void:
	if not _owned.has(item_id): _owned.append(item_id)
	if equip and not _equipped.has(item_id): _equipped.append(item_id)
	_save()
	changed.emit(item_id)

func set_equipped(item_id: String, value: bool) -> void:
	if not _owned.has(item_id) or value == is_equipped(item_id):
		return
	if value: _equipped.append(item_id)
	else: _equipped.erase(item_id)
	_save()
	changed.emit(item_id)

func toggle(item_id: String) -> void:
	set_equipped(item_id, not is_equipped(item_id))

## Olvida un accesorio obtenido; útil para volver a probar su recogida.
func forget(item_id: String) -> void:
	if not _owned.has(item_id):
		return
	_origins.erase(item_id)
	_owned.erase(item_id)
	_equipped.erase(item_id)
	_save()
	changed.emit(item_id)

func _save() -> bool:
	return _store.write_json(_path, {"owned": _owned, "equipped": _equipped, "origins": _origins})

func register_pickup(item: String, pickup: Node, origin: String) -> void:
	var handle: WeakRef = _pickups.get(item)
	var previous: Node = handle.get_ref() if handle else null
	if not is_instance_valid(previous) or not previous.is_inside_tree():
		_pickups[item] = weakref(pickup)
	elif _origins.get(item, "") == origin and previous.get("_origin") != origin:
		_pickups[item] = weakref(pickup)
	# Migra vestuario antiguo sin origen al primer punto cargado; se guarda en la siguiente elección.
	if owns(item) and _origins.get(item, "").is_empty(): _origins[item] = origin
	changed.emit(item)

func pickup_is_authorized(item: String, pickup: Node, origin: String) -> bool:
	var handle: WeakRef = _pickups.get(item)
	return handle != null and handle.get_ref() == pickup and (_origins.get(item, "") in ["", origin])

## Cambio transaccional: si falla el disco, conserva el estado anterior.
func set_hat_equipped(value: bool, origin := "") -> bool:
	var owned_before := _owned.duplicate()
	var equipped_before := _equipped.duplicate()
	var origins_before := _origins.duplicate()
	if value and not owns("christmas_hat"):
		if origin.is_empty(): return false
		_owned.append("christmas_hat")
	if not owns("christmas_hat"): return false
	if not origin.is_empty() and _origins.get("christmas_hat", "").is_empty(): _origins["christmas_hat"] = origin
	_equipped.erase("christmas_hat")
	if value: _equipped.append("christmas_hat")
	if not _save():
		_owned.assign(owned_before)
		_equipped.assign(equipped_before)
		_origins = origins_before
		return false
	changed.emit("christmas_hat")
	return true

