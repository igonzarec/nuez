extends Node3D
## Recorrido aislado del prototipo Terrain3D: jugador, camara, audio y nevada.

@export_group("Terreno")
## Escena del terreno que se prueba. Debe contener un nodo Terrain3D (en cualquier nivel). Se instancia al ejecutar, asi que no se ve en el editor de esta escena; edita el terreno abriendo su propia escena. Cambiarla requiere volver a ejecutar.
@export var terrain_scene: PackedScene
@export_group("Inicio del jugador")
## Coordenadas X/Z donde aparece la ardilla. Deben estar dentro de una region creada en Terrain3D; se proyecta sobre la altura real al iniciar. Si quedan fuera y Auto Spawn Fallback esta activo, se usa el centro de la primera region.
@export var spawn_xz := Vector2(110.0, 110.0)
## Si Spawn XZ cae fuera de las regiones del terreno, busca automaticamente el centro de una region valida en vez de dejar al jugador sin control. Util al cambiar Terrain Scene entre mapas con regiones en distintas posiciones. Desactivalo para detectar errores de Spawn XZ.
@export var auto_spawn_fallback := true
## Altura desde la que se busca el terreno, en metros. Aumenta este valor solo si el relieve llega por encima del punto de inicio.
@export_range(10.0, 500.0, 1.0, "suffix:m") var spawn_ray_height := 120.0
@export_group("Colision de Terrain3D")
## Radio alrededor de la camara que conserva colision dinamica. Mayor valor permite explorar mas lejos antes de regenerarla y usa mas memoria.
@export_range(16, 256, 1, "suffix:m") var collision_radius := 96
@export_group("Nevada")
## Activa los copos que siguen al personaje. Cambia en vivo durante F6.
@export var snowfall_enabled := true

var terrain: Terrain3D
var terrain_instance: Node
@onready var player: ExplorerPlayer = $SquirrelExplorer
@onready var camera_rig: TrailCamera = $CameraRig
@onready var snowfall = $Snowfall
@onready var snow_steps = $SnowStepAudio
var preview_audio: TrailAudio

func _ready() -> void:
	if not _load_terrain():
		return
	TrailInput.install()
	player.set_controls(false)
	# DYNAMIC_GAME crea colision cerca de la camara durante el juego. La capa 4
	# tambien deja que la camara orbital detecte el relieve como obstaculo.
	terrain.collision_mode = Terrain3DCollision.DYNAMIC_GAME
	terrain.collision_layer = 1 | 4
	terrain.collision_radius = collision_radius
	preview_audio = TrailAudio.new()
	preview_audio.name = "PreviewAudio"
	add_child(preview_audio)
	preview_audio.bind_player(player)
	preview_audio.bind_camera(camera_rig)
	snow_steps.bind(player, preview_audio)
	snow_steps.set_surface(1.0)
	camera_rig.target = player
	camera_rig.enabled = true
	player.camera_rig = camera_rig
	var spawn := _resolve_spawn()
	player.spawn_position = spawn + Vector3.UP * 0.15
	player.respawn()
	camera_rig.snap()
	camera_rig.camera.make_current()
	snowfall.enabled = snowfall_enabled
	snowfall.target = player
	# Deja que Terrain3D construya la colision alrededor de la camara activa.
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.set_controls(true)

func _load_terrain() -> bool:
	if terrain_scene == null:
		push_error("Asigna una escena en Terrain Scene (grupo Terreno) del nodo raiz.")
		return false
	terrain_instance = terrain_scene.instantiate()
	terrain_instance.name = "TerrainInstance"
	add_child(terrain_instance)
	move_child(terrain_instance, 0)
	var found := terrain_instance.find_children("*", "Terrain3D", true, false)
	if terrain_instance is Terrain3D:
		found.append(terrain_instance)
	if found.is_empty():
		push_error("La escena de Terrain Scene no contiene ningun nodo Terrain3D.")
		return false
	terrain = found[0]
	return true

## Devuelve el punto de aparicion sobre el relieve. Si Spawn XZ queda fuera de
## las regiones, cae al centro de la primera region para no dejar al jugador
## congelado: cada terreno coloca sus regiones donde quiere.
func _resolve_spawn() -> Vector3:
	var height := terrain.data.get_height(Vector3(spawn_xz.x, 0.0, spawn_xz.y))
	if not is_nan(height):
		return Vector3(spawn_xz.x, height, spawn_xz.y)
	if not auto_spawn_fallback:
		push_error("Spawn XZ esta fuera de las regiones de Terrain3D. Cambia Spawn XZ dentro del terreno o activa Auto Spawn Fallback.")
		return Vector3(spawn_xz.x, 0.0, spawn_xz.y)
	var locations: Array = terrain.data.get_region_locations()
	if locations.is_empty():
		push_error("El terreno no tiene regiones guardadas. Abre su escena, crea una region con Add Region y guarda con Ctrl+S.")
		return Vector3(spawn_xz.x, 0.0, spawn_xz.y)
	# El centro de la region evita los bordes, donde la colision puede faltar.
	var region_meters := float(terrain.region_size) * terrain.vertex_spacing
	var location: Vector2i = locations[0]
	var center := (Vector2(location) + Vector2(0.5, 0.5)) * region_meters
	var center_height := terrain.data.get_height(Vector3(center.x, 0.0, center.y))
	if is_nan(center_height):
		center_height = 0.0
	push_warning("Spawn XZ %s esta fuera de las regiones; se usa el centro de la region %s en %s. Ajusta Spawn XZ para fijarlo." % [spawn_xz, location, center])
	return Vector3(center.x, center_height, center.y)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
		player.respawn()
