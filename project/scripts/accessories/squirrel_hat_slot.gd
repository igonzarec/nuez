@tool
class_name SquirrelHatSlot
extends Node3D
## Sujeta el gorro al hueso de la cabeza del SquirrelRig del ExplorerPlayer padre.
## Ponerse o quitarse el gorro sólo cambia su propiedad visible, sin animación.
## Colocar como hijo directo del ExplorerPlayer (player.tscn) con transformación identidad.

enum WearMode {
	## El jugador lo lleva si lo tiene puesto en el vestuario (pausa). Los NPC nunca.
	WARDROBE,
	## Siempre puesto, también en NPC. Útil para dar el gorro a un personaje concreto.
	ALWAYS,
	## Nunca puesto.
	NEVER,
}

## Identificador del accesorio en TrailWardrobe.
@export var item_id := "christmas_hat"
## Estilo compartido con el gorro del suelo. Cambiarlo afecta a ambos si usan el mismo recurso.
@export var style: ChristmasHatStyle:
	set(value):
		style = value
		if is_instance_valid(_hat): _hat.style = value
		_update_preview()
## Quién decide si se lleva puesto. En vivo.
@export var wear_mode := WearMode.WARDROBE:
	set(value):
		wear_mode = value
		_refresh_visibility()
## Hueso del esqueleto de playertest2 al que se sujeta.
@export var bone_name := &"head"

@export_group("Ajuste en la cabeza")
## Posición del borde inferior del gorro respecto al hueso de la cabeza, en metros. Y sube el gorro; bajarlo lo acerca a los ojos. En vivo.
@export var fit_position := Vector3(0.0, 0.68, 0.0):
	set(value):
		fit_position = value
		_apply_fit()
## Rotación del gorro en grados. Con Y = 180 el +Z del gorro mira hacia la nuca: X positivo lo echa atrás
## (el frente baja hacia los ojos) y Z lo ladea. El lado de la cola se elige con Droop Direction del estilo. En vivo.
@export var fit_rotation_degrees := Vector3(8.0, 180.0, 0.0):
	set(value):
		fit_rotation_degrees = value
		_apply_fit()
## Escala uniforme del gorro sobre la cabeza. Mayor lo agranda; la física se adapta sola. En vivo.
@export_range(0.2, 3.0, 0.01) var fit_scale := 1.0:
	set(value):
		fit_scale = value
		_apply_fit()

## Oculta las orejas mientras el gorro está puesto (el gorro las cubre). Sólo cambia su visible. En vivo.
@export var hide_ears_when_worn := true:
	set(value):
		hide_ears_when_worn = value
		_refresh_visibility()
## Nombres de las mallas de orejas del modelo que se ocultan con Hide Ears When Worn.
@export var ear_mesh_names := PackedStringArray(["nuez_oreja_izquierda", "nuez_oreja_derecha"])

@export_group("Vista previa en el editor")
## Muestra la ardilla (playertest2) con el gorro en el editor para ajustar Fit Position, Rotation y Scale.
## No se guarda en la escena ni existe en juego.
@export var editor_fit_preview := false:
	set(value):
		editor_fit_preview = value
		_update_preview()

const PREVIEW_MODEL := "res://assets/playertest2/playertest2.glb"

var _hat: ChristmasHatVisual
var _actor: ExplorerPlayer
var _preview: Node3D

func _ready() -> void:
	if Engine.is_editor_hint():
		_update_preview()
		return
	_attach.call_deferred()

## True cuando el gorro está visible en la cabeza.
func is_worn() -> bool:
	return is_instance_valid(_hat) and _hat.visible

func _attach() -> void:
	_actor = get_parent() as ExplorerPlayer
	if not _actor or not is_instance_valid(_actor.model) or not _actor.model.playertest2_skeleton:
		push_warning("SquirrelHatSlot: necesita ser hijo de un ExplorerPlayer con SquirrelRig.")
		return
	_hat = _mount(_actor.model.playertest2_skeleton)
	if not TrailWardrobe.changed.is_connected(_on_wardrobe_changed):
		TrailWardrobe.changed.connect(_on_wardrobe_changed)
	_refresh_visibility()

func _mount(skeleton: Skeleton3D) -> ChristmasHatVisual:
	var attachment := BoneAttachment3D.new()
	attachment.name = "HatAttachment"
	attachment.bone_name = bone_name
	skeleton.add_child(attachment)
	var hat := ChristmasHatVisual.new()
	hat.name = "ChristmasHat"
	hat.style = style
	attachment.add_child(hat)
	_apply_fit(hat)
	return hat

func _apply_fit(hat: ChristmasHatVisual = null) -> void:
	for target: ChristmasHatVisual in [hat, _hat, _preview_hat()]:
		if is_instance_valid(target):
			target.position = fit_position
			target.rotation_degrees = fit_rotation_degrees
			target.scale = Vector3.ONE * fit_scale

func _on_wardrobe_changed(changed_id: String) -> void:
	if changed_id == item_id: _refresh_visibility()

func _refresh_visibility() -> void:
	if not is_instance_valid(_hat): return
	var is_player := is_instance_valid(_actor) and not is_instance_valid(_actor.command_source) and not _actor.is_in_group("npc_actors")
	match wear_mode:
		WearMode.ALWAYS: _hat.visible = true
		WearMode.NEVER: _hat.visible = false
		_: _hat.visible = is_player and TrailWardrobe.is_equipped(item_id)
	if is_instance_valid(_actor) and is_instance_valid(_actor.model):
		_set_ears_visible(_actor.model, not (hide_ears_when_worn and _hat.visible))

func _set_ears_visible(model: Node, value: bool) -> void:
	for ear_name in ear_mesh_names:
		var ear := model.find_child(ear_name, true, false) as Node3D
		if ear: ear.visible = value

func _preview_hat() -> ChristmasHatVisual:
	return _preview.find_child("ChristmasHat", true, false) as ChristmasHatVisual if is_instance_valid(_preview) else null

func _update_preview() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree(): return
	if is_instance_valid(_preview):
		_preview.queue_free()
		_preview = null
	if not editor_fit_preview: return
	# Igual que SquirrelRig: el modelo de Blender mira al revés que el controlador.
	_preview = Node3D.new()
	_preview.name = "FitPreview"
	add_child(_preview)
	var model: Node3D = load(PREVIEW_MODEL).instantiate()
	model.rotation.y = PI
	_preview.add_child(model)
	var skeleton := model.find_children("*", "Skeleton3D", true, false)
	if not skeleton.is_empty(): _mount(skeleton[0])
	_set_ears_visible(model, not hide_ears_when_worn)
