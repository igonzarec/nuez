@tool
extends Node3D
## Presentación de green hat en la cabeza; la cola se mueve con la física del visual. No recoge objetos.
## En el editor muestra la ardilla con el gorro para ajustar el encaje sin jugar (no se guarda en la escena).

## Activa la presentación del jugador. No equipa automáticamente. En vivo.
@export var enabled := true
## Escena visual independiente del pickup. Requiere reiniciar.
@export var visual_scene: PackedScene = preload("res://scenes/accessories/green_hat_visual.tscn")
## Forma, colores y física compartidos con el pickup. Live Preview en editor y juego.
@export var style: GreenHatStyle = preload("res://resources/accessories/green_hat_style.tres")

@export_group("Posición respecto al jugador")
## Posición del centro del borde respecto al hueso head, en metros. Y menor baja el gorro y abraza más la cabeza;
## Z negativo lo adelanta hacia la cara (pega el frente). En vivo, también en el editor.
@export var head_offset := Vector3(0, 0.63, -0.03)
## Giro en grados. 180 en Y compensa el frente +Z del modelo importado; X positivo baja la parte trasera
## del borde (el frente queda junto a los ojos); Z lo ladea. En vivo, también en el editor.
@export var head_rotation_degrees := Vector3(4, 180, 0)
## Escala local del gorro. Mayor envuelve una cabeza mayor. En vivo, también en el editor.
@export var hat_scale := Vector3.ONE
## Oculta las mallas de orejas mientras está equipado y restaura su visibilidad previa. En vivo.
@export var hide_ears := true

@export_group("Corte de la cabeza")
## Recorta la malla de la cabeza por encima de un plano a la altura del borde mientras el gorro está puesto,
## para que nunca asome a través de la tela. Sólo cambia la malla visible (no la colisión ni el GLB);
## al quitar el gorro se restaura la original. En vivo, también en el editor.
@export var cut_head := true
## Altura del plano de corte respecto al centro del borde, en metros del gorro. 0 corta a media altura del
## borde (el borde tapa el corte); negativo corta más abajo; positivo deja más cabeza. En vivo.
@export_range(-0.4, 0.6, 0.005, "suffix:m") var cut_height := 0.0
## Inclinación del plano en grados (X adelante/atrás, Z lateral), relativa al borde. En vivo.
@export var cut_tilt_degrees := Vector2.ZERO
## Mallas del modelo que se recortan.
@export var cut_mesh_names := PackedStringArray(["nuez_cabeza"])

@export_group("Vista previa en el editor")
## Muestra la ardilla (playertest2) con el gorro y su física en el editor. Sólo editor; no se guarda ni existe en juego.
@export var editor_preview := true:
	set(value):
		editor_preview = value
		if Engine.is_editor_hint() and is_inside_tree(): _update_editor_preview()
## Muestra también la vista previa en niveles que instancian al jugador (no en NPC). Al editar player.tscn siempre se ve.
@export var editor_preview_in_levels := false:
	set(value):
		editor_preview_in_levels = value
		if Engine.is_editor_hint() and is_inside_tree(): _update_editor_preview()

const PREVIEW_MODEL := "res://assets/playertest2/playertest2.glb"

var _actor: ExplorerPlayer
var _attachment: BoneAttachment3D
var _visual: Node3D
var _ears: Dictionary = {}
var _ears_hidden := false
var _preview: Node3D
var _cut_originals: Dictionary = {}
var _cut_signature: Array = []

func _ready() -> void:
	if Engine.is_editor_hint():
		_update_editor_preview.call_deferred()
		return
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_bind.call_deferred()

func _bind() -> void:
	_actor = get_parent() as ExplorerPlayer
	if not _actor or is_instance_valid(_actor.command_source) or _actor.is_in_group("npc_actors"): return
	var skeleton := _actor.model.playertest2_skeleton
	if not skeleton or skeleton.find_bone("head") < 0:
		push_warning("green hat: falta el hueso head.")
		return
	_attachment = BoneAttachment3D.new()
	_attachment.name = "GreenHatHeadAttachment"
	_attachment.bone_name = "head"
	skeleton.add_child(_attachment)
	_visual = visual_scene.instantiate()
	_visual.set("style", style)
	_attachment.add_child(_visual)
	for node in _actor.model.find_children("*", "MeshInstance3D", true, false):
		if "oreja" in node.name.to_lower(): _ears[node] = node.visible
	TrailInteraction.ensure_for(_actor)
	TrailWardrobe.changed.connect(_wardrobe_changed)
	_sync()

func _wardrobe_changed(item: String) -> void:
	if item == "christmas_hat" and is_instance_valid(_visual): _sync()

func _process(_delta: float) -> void:
	if not is_instance_valid(_visual): return
	if Engine.is_editor_hint():
		_place(_visual)
		if _visual.get("style") != style: _visual.set("style", style)
		_update_cut(_preview, true)
	else:
		_sync()

func _place(visual: Node3D) -> void:
	visual.position = head_offset
	visual.rotation_degrees = head_rotation_degrees
	visual.scale = hat_scale

func _sync() -> void:
	var equipped := enabled and TrailWardrobe.is_equipped("christmas_hat")
	if _visual.get("style") != style: _visual.set("style", style)
	_visual.visible = equipped
	_place(_visual)
	_update_cut(_actor.model, equipped)
	var conceal := equipped and hide_ears
	if conceal == _ears_hidden: return
	for ear in _ears:
		if not is_instance_valid(ear): continue
		if conceal:
			_ears[ear] = ear.visible
			ear.visible = false
		else: ear.visible = _ears[ear]
	_ears_hidden = conceal

## Recorta (o restaura) la cabeza cuando cambia el estado, la posición del gorro o el plano.
func _update_cut(model: Node, equipped: bool) -> void:
	if not is_instance_valid(model) or not is_instance_valid(_visual): return
	var active := equipped and cut_head
	var signature := [active, cut_height, cut_tilt_degrees, head_offset, head_rotation_degrees, hat_scale, cut_mesh_names]
	if signature == _cut_signature: return
	_cut_signature = signature
	for mesh_name in cut_mesh_names:
		var target := model.find_child(mesh_name, true, false) as MeshInstance3D
		if not target: continue
		if not _cut_originals.has(target): _cut_originals[target] = target.mesh
		var original: Mesh = _cut_originals[target]
		if not active:
			target.mesh = original
			continue
		# Plano en el espacio de la malla: ambos cuelgan del hueso head, así que la relación es fija.
		var to_mesh := target.global_transform.affine_inverse() * _visual.global_transform
		var tilt := Basis.from_euler(Vector3(deg_to_rad(cut_tilt_degrees.x), 0.0, deg_to_rad(cut_tilt_degrees.y)))
		var normal := (to_mesh.basis * (tilt * Vector3.UP)).normalized()
		var plane := Plane(normal, to_mesh * Vector3(0.0, cut_height, 0.0))
		target.mesh = _cut_mesh(original, plane)

## Copia de la malla sin la parte por encima del plano; los triángulos cortados se recortan en el borde.
func _cut_mesh(source: Mesh, plane: Plane) -> ArrayMesh:
	var result := ArrayMesh.new()
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if indices.is_empty():
			indices.resize(vertices.size())
			for index in vertices.size(): indices[index] = index
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for corner in range(0, indices.size(), 3):
			var polygon: Array = []
			for offset in 3:
				var index := indices[corner + offset]
				polygon.append([vertices[index], normals[index] if not normals.is_empty() else Vector3.UP])
			var kept := _clip(polygon, plane)
			for fan in range(1, kept.size() - 1):
				for point in [kept[0], kept[fan], kept[fan + 1]]:
					st.set_normal(point[1])
					st.add_vertex(point[0])
		var mesh_part := st.commit()
		if mesh_part.get_surface_count() == 0: continue
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_part.surface_get_arrays(0))
		result.surface_set_material(result.get_surface_count() - 1, source.surface_get_material(surface))
	return result

## Sutherland–Hodgman contra un plano: conserva lo que queda por debajo (lado opuesto a la normal).
func _clip(polygon: Array, plane: Plane) -> Array:
	var kept: Array = []
	for index in polygon.size():
		var current: Array = polygon[index]
		var following: Array = polygon[(index + 1) % polygon.size()]
		var current_distance := plane.distance_to(current[0])
		var following_distance := plane.distance_to(following[0])
		if current_distance <= 0.0: kept.append(current)
		if (current_distance <= 0.0) != (following_distance <= 0.0):
			var t := current_distance / (current_distance - following_distance)
			kept.append([(current[0] as Vector3).lerp(following[0], t), (current[1] as Vector3).lerp(following[1], t).normalized()])
	return kept

## Ardilla y gorro de previsualización en el editor, con la misma orientación que SquirrelRig.
func _update_editor_preview() -> void:
	if is_instance_valid(_preview):
		_preview.queue_free()
		_preview = null
		_visual = null
		_cut_originals.clear()
		_cut_signature = []
	if not editor_preview or not visual_scene or not is_inside_tree(): return
	if get_tree().edited_scene_root != get_parent():
		if not editor_preview_in_levels: return
		var ancestor := get_parent()
		while ancestor:
			if ancestor is SquirrelNPC: return
			ancestor = ancestor.get_parent()
	_preview = Node3D.new()
	_preview.name = "EditorHatPreview"
	add_child(_preview)
	var model: Node3D = load(PREVIEW_MODEL).instantiate()
	model.rotation.y = PI
	_preview.add_child(model)
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty(): return
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = "head"
	skeletons[0].add_child(attachment)
	_visual = visual_scene.instantiate()
	_visual.set("style", style)
	attachment.add_child(_visual)
	_place(_visual)
	if hide_ears:
		for node in model.find_children("*", "MeshInstance3D", true, false):
			if "oreja" in node.name.to_lower(): node.visible = false

func _exit_tree() -> void:
	if Engine.is_editor_hint(): return
	for target in _cut_originals:
		if is_instance_valid(target): target.mesh = _cut_originals[target]
	if _ears_hidden:
		for ear in _ears:
			if is_instance_valid(ear): ear.visible = _ears[ear]
	if is_instance_valid(_attachment): _attachment.queue_free()
