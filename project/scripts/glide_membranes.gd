@tool
class_name GlideMembranes
extends Node3D
## Membranas de planeo procedurales: una superficie entre costado, mano y pata
## que se reconstruye cada frame desde los huesos de playertest2.
## Colocar como hijo directo del ExplorerPlayer (player.tscn) con transformación identidad.
## Sustituye a las membranas de Blender sólo cuando Source = Procedural; la
## visibilidad la controla SquirrelRig con el mismo glide_amount de siempre.

enum Source {
	## Usa las membranas modeladas en Blender (Shape Key membrana_abierta).
	BLENDER,
	## Oculta las de Blender y dibuja esta superficie procedural.
	PROCEDURAL,
}

## Qué membranas se ven en juego. Cambiarlo permite comparar en vivo.
@export var source := Source.PROCEDURAL:
	set(value):
		source = value
		_mark_dirty()

@export_group("Anclajes (lado izquierdo)")
## Los anclajes se definen para el lado izquierdo, en el espacio local de cada hueso
## (metros). El lado derecho se refleja automáticamente en X. En vivo.
## Hueso del cuerpo al que se pegan el hombro y la cadera de la membrana.
@export var body_bone := &"spine":
	set(value):
		body_bone = value
		_mark_anchors_dirty()
## Punto de unión en el hombro, relativo a Body Bone. Y sube el borde delantero por el costado; X más negativo lo separa del torso.
@export var shoulder_offset := Vector3(-0.19, 0.55, 0.0):
	set(value):
		shoulder_offset = value
		_mark_anchors_dirty()
## Punto de unión en la cadera, relativo a Body Bone. Y más bajo alarga la membrana hacia la cola.
@export var hip_offset := Vector3(-0.2, 0.15, 0.0):
	set(value):
		hip_offset = value
		_mark_anchors_dirty()
## Hueso del brazo izquierdo.
@export var arm_bone := &"arm_left":
	set(value):
		arm_bone = value
		_mark_anchors_dirty()
## Esquina de la mano, relativa a Arm Bone. Y avanza a lo largo del brazo (la mano acaba
## hacia 0,46); con X y Z en 0 la esquina queda dentro del brazo y no asoma ningún pico.
@export var wrist_offset := Vector3(0.0, 0.33, 0.0):
	set(value):
		wrist_offset = value
		_mark_anchors_dirty()
## Hueso de la pierna izquierda.
@export var leg_bone := &"leg_left":
	set(value):
		leg_bone = value
		_mark_anchors_dirty()
## Esquina del tobillo, relativa a Leg Bone. Y avanza hacia el pie (acaba hacia 0,37).
@export var ankle_offset := Vector3(0.0, 0.33, 0.0):
	set(value):
		ankle_offset = value
		_mark_anchors_dirty()

@export_group("Forma")
## Curva del borde exterior (mano → tobillo), en fracción de su longitud. Positivo lo
## mete hacia el cuerpo (borde cóncavo); negativo lo abomba hacia fuera. En vivo.
@export_range(-0.5, 0.5, 0.01) var outer_edge_curve := 0.08:
	set(value):
		outer_edge_curve = value
		_mark_dirty()
## Curva del borde delantero (hombro → mano). Positivo lo hunde hacia atrás.
@export_range(-0.5, 0.5, 0.01) var front_edge_curve := 0.06:
	set(value):
		front_edge_curve = value
		_mark_dirty()
## Curva del borde trasero (cadera → tobillo). Positivo lo hunde hacia delante.
@export_range(-0.5, 0.5, 0.01) var rear_edge_curve := 0.08:
	set(value):
		rear_edge_curve = value
		_mark_dirty()
## Abombado por el aire, en fracción del ancho. Positivo empuja el centro hacia la
## espalda (como si el aire llenara la membrana); 0 la deja plana.
@export_range(-0.5, 0.5, 0.01) var billow := 0.1:
	set(value):
		billow = value
		_mark_dirty()
## Subdivisiones del cuerpo hacia la mano. Más suaviza las curvas; coste mínimo.
@export_range(1, 24, 1) var columns := 8:
	set(value):
		columns = value
		_mark_dirty()
## Subdivisiones del hombro a la cadera.
@export_range(1, 24, 1) var rows := 8:
	set(value):
		rows = value
		_mark_dirty()

@export_group("Apertura")
## Cuánto se recogen mano y tobillo hacia el costado mientras la membrana abre o cierra
## (Glide Amount < 1). 0 = sólo siguen a los huesos; 1 = salen pegadas al cuerpo.
@export_range(0.0, 1.0, 0.01) var fold_retract := 0.6:
	set(value):
		fold_retract = value
		_mark_dirty()

@export_group("Apariencia")
## Material propio. Si se asigna, ignora los colores de abajo.
@export var material_override_custom: Material:
	set(value):
		material_override_custom = value
		_apply_material()
## Color principal de la membrana (por defecto, el marrón de las manos).
@export var color := Color(0.35, 0.21, 0.15):
	set(value):
		color = value
		_mark_dirty()
## Color de los bordes libres. Igual a Color para un tono uniforme.
@export var edge_color := Color(0.22, 0.12, 0.08):
	set(value):
		edge_color = value
		_mark_dirty()
## Anchura del degradado de borde, en fracción de la membrana. 0 lo desactiva.
@export_range(0.0, 0.5, 0.01) var edge_width := 0.18:
	set(value):
		edge_width = value
		_mark_dirty()
## Rugosidad: 1 = mate; valores bajos dan brillo.
@export_range(0.0, 1.0, 0.01) var roughness := 0.8:
	set(value):
		roughness = value
		_apply_material()
## Luz que atraviesa la membrana a contraluz (Backlight). Negro lo desactiva.
@export var backlight := Color(0.25, 0.1, 0.05):
	set(value):
		backlight = value
		_apply_material()
## Proyecta sombra.
@export var cast_shadows := true:
	set(value):
		cast_shadows = value
		_apply_material()

@export_group("Vista previa en el editor")
## Muestra la ardilla en la pose de planeo con estas membranas para ajustarlas en el editor.
## No se guarda en la escena ni existe en juego.
@export var editor_preview := false:
	set(value):
		editor_preview = value
		_update_preview()
## Clip que posa la ardilla en la vista previa.
@export var preview_animation := &"Glide":
	set(value):
		preview_animation = value
		_update_preview()
## Momento del clip, en fracción de su duración.
@export_range(0.0, 1.0, 0.01) var preview_time := 0.0:
	set(value):
		preview_time = value
		_pose_preview()
## Apertura simulada (Glide Amount) en la vista previa.
@export_range(0.0, 1.0, 0.01) var preview_open := 1.0:
	set(value):
		preview_open = value
		_mark_dirty()
## Muestra también las membranas de Blender, abiertas, para comparar.
@export var preview_show_blender := false:
	set(value):
		preview_show_blender = value
		_pose_preview()

const PREVIEW_MODEL := "res://assets/playertest2/playertest2.glb"
const BLENDER_SHAPE := &"membrana_abierta"

var open_amount := 0.0
var _skeleton: Skeleton3D
var _mesh_instance: MeshInstance3D
var _mesh := ArrayMesh.new()
var _material := StandardMaterial3D.new()
var _preview: Node3D
var _anchors: Array = []
var _dirty := true

func _ready() -> void:
	# Después de SquirrelRig (100): la pose ya incluye clip, temblor y mezclas.
	process_priority = 110
	_apply_material()
	if Engine.is_editor_hint():
		_update_preview()
		return
	_attach.call_deferred()

## True cuando estas membranas sustituyen a las de Blender.
func replaces_blender() -> bool:
	return source == Source.PROCEDURAL

## Llamado por SquirrelRig con glide_amount (0 cerrada, 1 abierta).
func set_open_amount(amount: float) -> void:
	open_amount = clampf(amount, 0.0, 1.0)

func _attach() -> void:
	var actor := get_parent() as ExplorerPlayer
	if not actor or not is_instance_valid(actor.model) or not actor.model.playertest2_skeleton:
		push_warning("GlideMembranes: necesita ser hijo de un ExplorerPlayer con SquirrelRig.")
		return
	actor.model.procedural_membranes = self
	_bind(actor.model.playertest2_skeleton)

func _bind(skeleton: Skeleton3D) -> void:
	_skeleton = skeleton
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "ProceduralMembranes"
	_mesh_instance.mesh = _mesh
	# Hijo del Skeleton3D: los puntos se calculan en su espacio local.
	skeleton.add_child(_mesh_instance)
	_anchors.clear()
	_apply_material()

func _process(_delta: float) -> void:
	if not is_instance_valid(_mesh_instance):
		return
	var amount := preview_open if Engine.is_editor_hint() else open_amount
	var shown := source == Source.PROCEDURAL and amount > 0.01
	_mesh_instance.visible = shown
	if not shown:
		return
	# En juego los huesos se mueven cada frame; en el editor sólo al cambiar algo.
	if Engine.is_editor_hint() and not _dirty:
		return
	_dirty = false
	_rebuild(amount)

func _mark_dirty() -> void:
	_dirty = true

func _mark_anchors_dirty() -> void:
	_anchors.clear()
	_dirty = true

func _resolve_anchors() -> void:
	# [hueso, offset] por esquina y lado. El lado derecho se refleja en el espacio
	# del esqueleto en reposo, así no depende de cómo se orienten los huesos.
	_anchors.clear()
	var left := [[body_bone, shoulder_offset], [arm_bone, wrist_offset], [body_bone, hip_offset], [leg_bone, ankle_offset]]
	var body := _skeleton.find_bone(body_bone)
	if body < 0:
		return
	# El esqueleto no está centrado en X = 0: se refleja en el espacio del hueso del cuerpo.
	var body_rest := _skeleton.get_bone_global_rest(body)
	for side in 2:
		var corners: Array = []
		for entry in left:
			var bone := _skeleton.find_bone(entry[0])
			if bone < 0:
				_anchors.clear()
				return
			var offset: Vector3 = entry[1]
			if side == 1:
				var mirrored_bone := _skeleton.find_bone(String(entry[0]).replace("left", "right"))
				if mirrored_bone < 0:
					_anchors.clear()
					return
				var body_point := body_rest.affine_inverse() * (_skeleton.get_bone_global_rest(bone) * offset)
				body_point.x = -body_point.x
				offset = _skeleton.get_bone_global_rest(mirrored_bone).affine_inverse() * (body_rest * body_point)
				bone = mirrored_bone
			corners.append([bone, offset])
		_anchors.append(corners)

func _rebuild(amount: float) -> void:
	if _anchors.is_empty():
		_resolve_anchors()
	_mesh.clear_surfaces()
	if _anchors.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var body := _skeleton.find_bone(body_bone)
	# El modelo mira a +Z: la espalda es -Z del hueso del cuerpo.
	var dorsal := (_skeleton.get_bone_global_pose(body).basis * Vector3.FORWARD).normalized()
	for corners in _anchors:
		var p: Array[Vector3] = []
		for corner in corners:
			p.append(_skeleton.get_bone_global_pose(corner[0]) * corner[1])
		var shoulder := p[0]
		var hip := p[2]
		var retract := (1.0 - amount) * fold_retract
		var wrist := p[1].lerp(shoulder, retract)
		var ankle := p[3].lerp(hip, retract)
		var width := ((wrist - shoulder).length() + (ankle - hip).length()) * 0.5
		var base := vertices.size()
		var grid: Array[Vector3] = []
		for row in rows + 1:
			var v := float(row) / rows
			for column in columns + 1:
				var u := float(column) / columns
				var point := _coons(u, v, shoulder, wrist, hip, ankle)
				point += dorsal * billow * width * sin(PI * u) * sin(PI * v)
				grid.append(point)
				vertices.append(point)
				uvs.append(Vector2(u, v))
				# Bordes libres: exterior (u=1), delantero (v=0) y trasero (v=1).
				var free_distance := minf(1.0 - u, minf(v, 1.0 - v))
				var edge := 1.0 - smoothstep(0.0, edge_width, free_distance) if edge_width > 0.0 else 0.0
				colors.append(color.lerp(edge_color, edge))
		# Normales por diferencias del propio grid, orientadas hacia la espalda.
		var flip := 1.0
		for row in rows + 1:
			for column in columns + 1:
				var right := grid[row * (columns + 1) + mini(column + 1, columns)] - grid[row * (columns + 1) + maxi(column - 1, 0)]
				var down := grid[mini(row + 1, rows) * (columns + 1) + column] - grid[maxi(row - 1, 0) * (columns + 1) + column]
				var normal := right.cross(down).normalized()
				if row == 0 and column == 0:
					flip = -1.0 if normal.dot(dorsal) < 0.0 else 1.0
				normals.append(normal * flip)
		for row in rows:
			for column in columns:
				var a := base + row * (columns + 1) + column
				var b := a + 1
				var c := a + columns + 1
				var d := c + 1
				# Godot usa orden horario para la cara frontal (la de la normal).
				if flip > 0.0:
					indices.append_array([a, c, b, b, c, d])
				else:
					indices.append_array([a, b, c, b, d, c])
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

func _coons(u: float, v: float, shoulder: Vector3, wrist: Vector3, hip: Vector3, ankle: Vector3) -> Vector3:
	# Parche de Coons: interpola los cuatro bordes curvos; el borde del cuerpo es recto.
	var center := (shoulder + wrist + hip + ankle) * 0.25
	var front := _edge(shoulder, wrist, u, front_edge_curve, center)
	var rear := _edge(hip, ankle, u, rear_edge_curve, center)
	var inner := shoulder.lerp(hip, v)
	var outer := _edge(wrist, ankle, v, outer_edge_curve, center)
	var bilinear := shoulder.lerp(wrist, u).lerp(hip.lerp(ankle, u), v)
	return front.lerp(rear, v) + inner.lerp(outer, u) - bilinear

func _edge(from: Vector3, to: Vector3, t: float, curve: float, center: Vector3) -> Vector3:
	# Curva hacia el centro de la membrana, perpendicular al borde, con perfil parabólico.
	var straight := from.lerp(to, t)
	var direction := (to - from).normalized()
	var inward := center - straight
	inward = (inward - direction * inward.dot(direction)).normalized()
	return straight + inward * curve * from.distance_to(to) * 4.0 * t * (1.0 - t)

func _apply_material() -> void:
	_material.vertex_color_use_as_albedo = true
	_material.vertex_color_is_srgb = true
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.roughness = roughness
	_material.backlight_enabled = backlight != Color.BLACK
	_material.backlight = backlight
	if is_instance_valid(_mesh_instance):
		_mesh_instance.material_override = material_override_custom if material_override_custom else _material
		_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_dirty = true

func _update_preview() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	if is_instance_valid(_preview):
		_preview.queue_free()
		_preview = null
	_mesh_instance = null
	_skeleton = null
	if not editor_preview:
		return
	_preview = Node3D.new()
	_preview.name = "MembranePreview"
	add_child(_preview)
	# Igual que SquirrelRig: el modelo de Blender mira al revés que el controlador.
	var model: Node3D = load(PREVIEW_MODEL).instantiate()
	model.rotation.y = PI
	_preview.add_child(model)
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return
	_bind(skeletons[0])
	_pose_preview()

func _pose_preview() -> void:
	if not is_instance_valid(_preview):
		return
	var player := _preview.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player:
		# En el editor el AnimationPlayer de una instancia no aplica la pose:
		# se desactiva y se muestrean las pistas del clip directamente.
		player.active = false
		for animation_name in player.get_animation_list():
			if String(animation_name).ends_with(String(preview_animation)):
				_sample_pose(player, player.get_animation(animation_name))
				break
	for mesh_instance: MeshInstance3D in _preview.find_children("*", "MeshInstance3D", true, false):
		if mesh_instance == _mesh_instance or not mesh_instance.mesh:
			continue
		for shape in mesh_instance.mesh.get_blend_shape_count():
			if mesh_instance.mesh.get_blend_shape_name(shape) == BLENDER_SHAPE:
				mesh_instance.visible = preview_show_blender
				mesh_instance.set_blend_shape_value(shape, 1.0)
	_dirty = true

func _sample_pose(player: AnimationPlayer, animation: Animation) -> void:
	var time := preview_time * animation.length
	var animation_root := player.get_node(player.root_node)
	for bone in _skeleton.get_bone_count():
		_skeleton.reset_bone_pose(bone)
	for track in animation.get_track_count():
		var path := animation.track_get_path(track)
		if animation_root.get_node_or_null(NodePath(path.get_concatenated_names())) != _skeleton:
			continue
		var bone := _skeleton.find_bone(path.get_concatenated_subnames())
		if bone < 0:
			continue
		match animation.track_get_type(track):
			Animation.TYPE_ROTATION_3D:
				_skeleton.set_bone_pose_rotation(bone, animation.rotation_track_interpolate(track, time))
			Animation.TYPE_POSITION_3D:
				_skeleton.set_bone_pose_position(bone, animation.position_track_interpolate(track, time))
			Animation.TYPE_SCALE_3D:
				_skeleton.set_bone_pose_scale(bone, animation.scale_track_interpolate(track, time))
