@tool
class_name ChristmasHatVisual
extends Node3D
## Gorro navideño procedural compartido por el gorro del suelo y el de la cabeza.
## Genera terciopelo, ribete y pompón de peluche simulado sobre un esqueleto en la cola,
## y simula esa cola (gravedad, inercia, aire y colisión). Todo el aspecto vive en Style.
## El origen es el centro del borde inferior del ribete; +Y sube hacia la copa.

## Recurso de aspecto y física. Compartirlo garantiza el mismo gorro en todas partes.
@export var style: ChristmasHatStyle:
	set(value):
		if style and style.changed.is_connected(_on_style_changed): style.changed.disconnect(_on_style_changed)
		style = value
		if style: style.changed.connect(_on_style_changed)
		_queue_rebuild()

@export_group("Simulación")
## Choca la cola y el pompón contra el suelo bajo el gorro (un rayo por fotograma físico). Úsalo en el gorro tirado. En vivo.
@export var ground_collision := false
## Capas que cuentan como suelo para Ground Collision.
@export_flags_3d_physics var ground_mask := 1
## Simula también en el editor. Apagado muestra la forma de reposo exacta del estilo.
@export var simulate_in_editor := false

@export_group("Live Preview")
## Regenera al cambiar el estilo. Las mallas iguales se comparten entre gorros y no se recalculan.
@export var live_preview := true
## Fuerza la regeneración (p. ej. tras desactivar Live Preview).
@export_tool_button("Regenerar gorro", "Reload") var regenerate_button := rebuild

const FIBER_SIZE := 128
static var _cache: Dictionary = {}

var _skeleton: Skeleton3D
var _mesh_instance: MeshInstance3D
var _data: Dictionary
var _points := PackedVector3Array()
var _previous := PackedVector3Array()
var _last_root := Vector3.ZERO
var _sim_ready := false
var _rebuild_pending := false
var _ground := Plane()
var _ground_valid := false

func _ready() -> void:
	# Después del movimiento del personaje en el mismo tick.
	process_physics_priority = 200
	visibility_changed.connect(func() -> void: _sim_ready = false)
	rebuild()

func _on_style_changed() -> void:
	if live_preview or not Engine.is_editor_hint(): _queue_rebuild()

func _queue_rebuild() -> void:
	if _rebuild_pending or not is_inside_tree(): return
	_rebuild_pending = true
	rebuild.call_deferred()

## Reconstruye malla y esqueleto. Reutiliza la malla en caché si otro gorro ya la generó.
func rebuild() -> void:
	_rebuild_pending = false
	if is_instance_valid(_skeleton):
		remove_child(_skeleton)
		_skeleton.queue_free()
	_skeleton = null
	_mesh_instance = null
	_sim_ready = false
	if not style: return
	var key := _signature()
	if not _cache.has(key):
		_cache[key] = _generate()
	_data = _cache[key]
	_skeleton = Skeleton3D.new()
	_skeleton.name = "HatSkeleton"
	var rest: Array = _data.bone_rest
	for index in rest.size():
		_skeleton.add_bone("hat_root" if index == 0 else "hat_tail_%d" % index)
		if index > 0: _skeleton.set_bone_parent(index, index - 1)
		_skeleton.set_bone_rest(index, rest[index])
	_skeleton.reset_bone_poses()
	add_child(_skeleton)
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "HatMesh"
	_mesh_instance.mesh = _data.mesh
	_skeleton.add_child(_mesh_instance)
	_mesh_instance.skeleton = NodePath("..")

## Punto del extremo de la cola en coordenadas globales (centro del pompón).
func tip_global_position() -> Vector3:
	if _sim_ready and not _points.is_empty(): return _points[_points.size() - 1]
	if _data: return global_transform * (_data.points as PackedVector3Array)[(_data.points as PackedVector3Array).size() - 1]
	return global_position

# --- Simulación ------------------------------------------------------------

# La simulación corre en el tick de física: con la interpolación de física del proyecto, la cabeza
# sólo cambia de posición en cada tick y leerla en _process daría sacudidas (parpadeo) a la cola.
func _physics_process(delta: float) -> void:
	_update_ground()
	_simulate(delta)

func _update_ground() -> void:
	if not ground_collision or not is_inside_tree() or Engine.is_editor_hint() and not simulate_in_editor:
		_ground_valid = false
		return
	var origin := global_position + Vector3.UP * 0.4
	var query := PhysicsRayQueryParameters3D.create(origin, origin + Vector3.DOWN * 3.0, ground_mask)
	var owner_body := _find_body()
	if owner_body: query.exclude = [owner_body.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	_ground_valid = not hit.is_empty()
	if _ground_valid: _ground = Plane(hit.normal, hit.position)

func _find_body() -> CollisionObject3D:
	var node := get_parent()
	while node:
		if node is CollisionObject3D: return node
		node = node.get_parent()
	return null

func _simulate(delta: float) -> void:
	if not is_instance_valid(_skeleton) or not _data: return
	var simulate := style.physics_enabled and is_visible_in_tree() and (not Engine.is_editor_hint() or simulate_in_editor)
	if not simulate:
		if _sim_ready:
			_skeleton.reset_bone_poses()
			_sim_ready = false
		return
	var xf := _skeleton.global_transform
	var rest: PackedVector3Array = _data.points
	var count := rest.size()
	var root_delta := xf.origin - _last_root
	if not _sim_ready or root_delta.length() > 3.0:
		_points.resize(count)
		_previous.resize(count)
		for index in count:
			_points[index] = xf * rest[index]
			_previous[index] = _points[index]
		_last_root = xf.origin
		_sim_ready = true
		root_delta = Vector3.ZERO
	_last_root = xf.origin
	var steps := clampi(ceili(delta * 120.0), 1, 4)
	var dt := minf(delta, 1.0 / 20.0) / steps
	if dt <= 0.0: return
	var gravity := Vector3.DOWN * float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)) * style.gravity_scale
	var follow := root_delta * style.motion_follow / steps
	var radii: PackedFloat32Array = _data.radii
	var scale_factor := xf.basis.get_scale().x
	var head_radius := style.opening_radius * style.head_collision_scale
	var head_center := xf * Vector3(0.0, style.brim_height * 0.5 - style.opening_radius * sqrt(maxf(style.head_collision_scale * style.head_collision_scale - 1.0, 0.0)), 0.0)
	var max_step := style.max_speed * dt
	# La copa (puntos hasta Pinned) sigue rígida a la cabeza; sólo la cola se simula.
	var pinned: int = _data.pinned
	for index in pinned + 1:
		_points[index] = xf * rest[index]
		_previous[index] = _points[index]
	for step in steps:
		for index in range(pinned + 1, count):
			var point := _points[index] + follow
			var velocity := (point - _previous[index] - follow) * maxf(0.0, 1.0 - style.damping * dt * 10.0)
			var stiffness := style.base_stiffness * lerpf(1.0, style.tip_stiffness_ratio, float(index - pinned) / maxi(count - 1 - pinned, 1))
			var acceleration := (xf * rest[index] - point) * stiffness + gravity - velocity / dt * style.air_drag
			velocity = (velocity + acceleration * dt * dt).limit_length(max_step)
			_previous[index] = point
			_points[index] = point + velocity
		for iteration in style.solver_iterations:
			for index in range(pinned, count - 1):
				var target_length := (xf.basis * (rest[index + 1] - rest[index])).length()
				var offset := _points[index + 1] - _points[index]
				var distance := offset.length()
				if distance < 0.00001: continue
				var correction := offset * ((distance - target_length) / distance)
				if index == pinned: _points[index + 1] -= correction
				else:
					_points[index] += correction * 0.5
					_points[index + 1] -= correction * 0.5
			for index in range(pinned + 1, count):
				var clearance := radii[index] * scale_factor
				var from_head := _points[index] - head_center
				# Nunca empuja más allá de la forma de reposo: evita doblar la cola contra la cabeza.
				var minimum := minf(head_radius * scale_factor + clearance, (xf * rest[index] - head_center).length())
				if from_head.length() < minimum:
					_points[index] = head_center + from_head.normalized() * minimum
				if _ground_valid:
					var height := _ground.distance_to(_points[index])
					if height < clearance:
						_points[index] += _ground.normal * (clearance - height)
						# Rozamiento: la tela apoyada no patina sobre el suelo.
						_previous[index] = _previous[index].lerp(_points[index], 0.5)
	_apply_pose(xf)

func _apply_pose(xf: Transform3D) -> void:
	var inverse := xf.affine_inverse()
	var rest_global: Array = _data.bone_global
	var rest_dirs: PackedVector3Array = _data.dirs
	var parent := Transform3D.IDENTITY
	for chain in _points.size() - 1:
		var start := inverse * _points[chain]
		var direction := (inverse * _points[chain + 1] - start).normalized()
		# Casi opuesto a la dirección de reposo el giro más corto es ambiguo y salta entre fotogramas.
		if direction.is_zero_approx() or direction.dot(rest_dirs[chain]) < -0.95: direction = rest_dirs[chain]
		var bone_basis := Basis(Quaternion(rest_dirs[chain], direction)) * (rest_global[chain + 1] as Transform3D).basis
		var bone_global := Transform3D(bone_basis, start)
		var local := parent.affine_inverse() * bone_global
		_skeleton.set_bone_pose_position(chain + 1, local.origin)
		_skeleton.set_bone_pose_rotation(chain + 1, local.basis.get_rotation_quaternion())
		parent = bone_global

# --- Generación ------------------------------------------------------------

func _signature() -> String:
	var values: Array = []
	for property in style.get_property_list():
		if property.usage & PROPERTY_USAGE_STORAGE and property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			values.append(style.get(property.name))
	return str(values).sha256_text()

func _generate() -> Dictionary:
	var s := style
	var chain := s.physics_segments
	var rings := chain * ceili(float(s.body_rings) / chain)
	var radial := s.radial_segments
	var half_height := s.brim_height * 0.5
	var noise := FastNoiseLite.new()
	noise.seed = s.noise_seed
	noise.frequency = 1.0
	# Línea central: sube desde el ribete y se dobla hacia Droop Direction en el pliegue.
	var droop_direction := Vector3(sin(deg_to_rad(s.droop_direction_degrees)), 0.0, cos(deg_to_rad(s.droop_direction_degrees)))
	var profile_start := smoothstep(s.fold_position - s.fold_softness, s.fold_position + s.fold_softness, 0.0)
	var profile_end := smoothstep(s.fold_position - s.fold_softness, s.fold_position + s.fold_softness, 1.0)
	var bend := func(t: float) -> float:
		return deg_to_rad(s.lean_degrees) + deg_to_rad(s.droop_degrees) * (smoothstep(s.fold_position - s.fold_softness, s.fold_position + s.fold_softness, t) - profile_start) / maxf(profile_end - profile_start, 0.0001)
	var puff_span := clampf(s.fold_position + s.fold_softness, 0.1, 1.0)
	var radius_at := func(t: float) -> float:
		var puff := 1.0 + s.crown_puff * sin(PI * clampf(t / puff_span, 0.0, 1.0))
		return s.opening_radius * lerpf(1.0, s.tip_ratio, pow(t, s.taper_power)) * puff
	var step_length := s.body_length / rings
	var centers := PackedVector3Array()
	var tangents := PackedVector3Array()
	var cursor := Vector3(0.0, half_height * 1.15, 0.0)
	# La curva nunca gira más cerrada que Fold Min Radius × el radio local de la tela:
	# así el interior del pliegue no se monta sobre sí mismo. La caída pendiente se completa más
	# adelante, donde la cola ya es fina.
	var angle: float = bend.call(0.0)
	var substeps := 8
	for ring in rings + 1:
		var t := float(ring) / rings
		centers.append(cursor)
		tangents.append((Vector3.UP * cos(angle) + droop_direction * sin(angle)).normalized())
		if ring == rings: break
		for sub in substeps:
			var u := t + (sub + 0.5) / (rings * substeps)
			var max_turn: float = step_length / substeps / (s.fold_min_radius * radius_at.call(u))
			angle = move_toward(angle, bend.call(u), max_turn)
			cursor += (Vector3.UP * cos(angle) + droop_direction * sin(angle)) * step_length / substeps
	# Marco de transporte paralelo: evita torsiones al curvar la cola.
	var normals := PackedVector3Array([droop_direction])
	for ring in range(1, rings + 1):
		normals.append((Quaternion(tangents[ring - 1], tangents[ring]) * normals[ring - 1]).normalized())
	var mesh_data := {"vertices": PackedVector3Array(), "colors": PackedColorArray(), "bones": PackedInt32Array(), "weights": PackedFloat32Array(), "indices": PackedInt32Array()}
	# Curvatura máxima cercana: el lado interior del doblez no puede pasar del centro de giro.
	var curvatures := PackedFloat32Array()
	for ring in rings + 1:
		var previous := maxi(ring - 1, 0)
		var next := mini(ring + 1, rings)
		curvatures.append((tangents[next] - tangents[previous]).length() / (step_length * (next - previous)))
	# Terciopelo.
	for ring in rings + 1:
		var t := float(ring) / rings
		var tangent := tangents[ring]
		var normal := normals[ring]
		var binormal := tangent.cross(normal)
		var curvature := (tangents[mini(ring + 1, rings)] - tangents[maxi(ring - 1, 0)]) / (step_length * (mini(ring + 1, rings) - maxi(ring - 1, 0)))
		var bend_amount := clampf(curvature.length() * radius_at.call(t) * 1.6, 0.0, 1.0)
		var bend_direction := curvature.normalized() if curvature.length() > 0.0001 else Vector3.ZERO
		var weights := _tail_weights(t, chain)
		var fold_limit := INF
		for near in range(maxi(ring - 3, 0), mini(ring + 4, rings + 1)):
			if curvatures[near] > 0.0001: fold_limit = minf(fold_limit, 0.85 / curvatures[near])
		for side in radial:
			var phi := TAU * side / radial
			var direction := normal * cos(phi) + binormal * sin(phi)
			var inner := maxf(0.0, direction.dot(bend_direction))
			var wrinkle := noise.get_noise_3d(cos(phi) * s.wrinkle_frequency, sin(phi) * s.wrinkle_frequency, t * s.body_length * s.wrinkle_frequency * 2.5)
			wrinkle *= 1.0 + 2.0 * inner * bend_amount
			var radius: float = radius_at.call(t) * (1.0 + s.wrinkle_strength * wrinkle)
			# La tela se aplasta en el interior del pliegue en lugar de atravesarse.
			if inner > 0.001: radius = _soft_min(radius, fold_limit / inner, radius * 0.35)
			mesh_data.vertices.append(centers[ring] + direction * radius)
			var shade := s.fold_shading * clampf(pow(inner, 0.7) * bend_amount + maxf(0.0, -wrinkle) * 0.35, 0.0, 1.0)
			mesh_data.colors.append(s.velvet_color.lerp(s.fold_color, shade))
			_append_weights(mesh_data, weights)
	_append_grid(mesh_data.indices, 0, rings, radial)
	var body := _finish(mesh_data)
	# Ribete: toro elíptico con almohadillas regulares y, opcionalmente, bultos de peluche.
	var fur := {"vertices": PackedVector3Array(), "colors": PackedColorArray(), "bones": PackedInt32Array(), "weights": PackedFloat32Array(), "indices": PackedInt32Array()}
	var tube := s.brim_tube_segments
	var lump_height := s.lump_strength * minf(s.brim_thickness, half_height)
	for around in s.brim_segments:
		var a := TAU * around / s.brim_segments
		var outward := Vector3(cos(a), 0.0, sin(a))
		# Cada almohadilla abulta en su centro y se hunde en la costura con la siguiente.
		var pillow := sin(PI * fposmod(a * s.brim_puffs / TAU, 1.0)) if s.brim_puffs > 0 else 1.0
		var swell := 1.0 - s.brim_puff_depth * (1.0 - pillow)
		for section in tube:
			var b := TAU * section / tube
			var base := outward * (s.opening_radius + s.brim_thickness * swell * cos(b)) + Vector3.UP * (half_height + half_height * lerpf(1.0, swell, 0.5) * sin(b))
			var normal := (outward * cos(b) / s.brim_thickness + Vector3.UP * sin(b) / half_height).normalized()
			var lump := _lumps(base, s) if s.lump_strength > 0.0 else 1.0
			fur.vertices.append(base + normal * lump_height * (lump - 0.5))
			fur.colors.append(s.fur_shadow_color.lerp(s.fur_color, clampf(lump * 1.2, 0.0, 1.0) * lerpf(1.0, pillow, minf(1.0, s.brim_puff_depth * 4.0))))
			_append_weights(fur, {0: 1.0})
	_append_grid(fur.indices, 0, s.brim_segments, tube, true)
	# Pompón al final de la cola, unido al último hueso.
	var tip_center := centers[rings] + tangents[rings] * s.pompom_radius * 0.55 + s.pompom_offset
	var pompom_start: int = fur.vertices.size()
	var latitudes := s.pompom_rings
	var longitudes := s.pompom_rings * 2
	var pompom_lump := s.lump_strength * s.pompom_radius * 0.8
	for row in latitudes + 1:
		var theta := PI * row / latitudes
		for column in longitudes:
			var phi := TAU * column / longitudes
			var normal := Vector3(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi))
			var lump := _lumps(tip_center + normal * s.pompom_radius, s) if s.lump_strength > 0.0 else 1.0
			fur.vertices.append(tip_center + normal * (s.pompom_radius + pompom_lump * (lump - 0.5)))
			fur.colors.append(s.fur_shadow_color.lerp(s.fur_color, clampf(lump * 1.2, 0.0, 1.0)))
			_append_weights(fur, {chain: 1.0})
	_append_grid(fur.indices, pompom_start, latitudes, longitudes)
	var fur_surface := _finish(fur)
	# Malla final: superficies base y capas de pelo (shells) desplazadas por la normal.
	var mesh := ArrayMesh.new()
	_add_surface(mesh, body, 0.0, s.faceted, _velvet_material(s, -1))
	_add_surface(mesh, fur_surface, 0.0, s.faceted, _fur_material(s, -1))
	for layer in s.fur_shells:
		_add_surface(mesh, fur_surface, s.fur_length * (layer + 1) / s.fur_shells, false, _fur_material(s, layer))
	for layer in s.velvet_shells:
		_add_surface(mesh, body, s.velvet_fuzz_length * (layer + 1) / s.velvet_shells, false, _velvet_material(s, layer))
	# Huesos: raíz fija para el ribete y una cadena a lo largo de la cola.
	var points := PackedVector3Array()
	var radii := PackedFloat32Array()
	var bone_global: Array = [Transform3D.IDENTITY]
	var bone_rest: Array = [Transform3D.IDENTITY]
	var dirs := PackedVector3Array()
	for index in chain + 1:
		var ring := index * rings / chain
		points.append(centers[ring])
		radii.append(s.pompom_radius if index == chain else radius_at.call(float(ring) / rings))
	for index in chain:
		var ring := index * rings / chain
		var tangent := tangents[ring]
		var normal := normals[ring]
		var bone_xf := Transform3D(Basis(normal, tangent, normal.cross(tangent)).orthonormalized(), centers[ring])
		bone_rest.append((bone_global[index] as Transform3D).affine_inverse() * bone_xf)
		bone_global.append(bone_xf)
		dirs.append((points[index + 1] - points[index]).normalized())
	var pinned := 0
	for index in chain + 1:
		if float(index) / chain <= s.rigid_length + 0.0001: pinned = index
	pinned = mini(pinned, chain - 1)
	return {"mesh": mesh, "points": points, "radii": radii, "bone_global": bone_global, "bone_rest": bone_rest, "dirs": dirs, "pinned": pinned}

## Mínimo suave: evita la arista dura donde la tela empieza a aplastarse en el doblez.
func _soft_min(a: float, b: float, k: float) -> float:
	var h := clampf(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
	return lerpf(b, a, h) - k * h * (1.0 - h)

## Pesos de un vértice de la cola: hueso propio con mezcla suave hacia el vecino en cada junta.
## La base queda anclada a la raíz para no despegarse del ribete.
func _tail_weights(t: float, chain: int) -> Dictionary:
	var f := t * chain
	var bone := mini(int(f), chain - 1)
	var s := f - bone
	var weights := {bone + 1: 1.0}
	if s < 0.5:
		weights[bone] = 0.5 - s
		weights[bone + 1] = 0.5 + s
	elif bone + 2 <= chain:
		weights[bone + 2] = s - 0.5
		weights[bone + 1] = 1.5 - s
	var lock := 1.0 - smoothstep(style.rigid_length, style.rigid_length + style.rigid_blend, t)
	if lock > 0.0:
		for key in weights.keys(): weights[key] *= 1.0 - lock
		weights[0] = weights.get(0, 0.0) + lock
	return weights

func _append_weights(target: Dictionary, weights: Dictionary) -> void:
	var keys := weights.keys()
	keys.sort_custom(func(a: int, b: int) -> bool: return weights[a] > weights[b])
	var total := 0.0
	for index in mini(4, keys.size()): total += weights[keys[index]]
	for index in 4:
		if index < keys.size():
			target.bones.append(keys[index])
			target.weights.append(weights[keys[index]] / total)
		else:
			target.bones.append(0)
			target.weights.append(0.0)

## Rejilla cerrada alrededor (columnas) y abierta o cerrada a lo largo (filas), en orden horario.
func _append_grid(indices: PackedInt32Array, start: int, rows: int, columns: int, wrap_rows := false) -> void:
	var total_rows := rows + (0 if wrap_rows else 1)
	for row in rows:
		var next_row := (row + 1) % total_rows
		for column in columns:
			var next_column := (column + 1) % columns
			var a := start + row * columns + column
			var b := start + row * columns + next_column
			var c := start + next_row * columns + column
			var d := start + next_row * columns + next_column
			indices.append_array([a, c, b, b, c, d])

func _finish(data: Dictionary) -> Dictionary:
	var vertices: PackedVector3Array = data.vertices
	var indices: PackedInt32Array = data.indices
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	for index in range(0, indices.size(), 3):
		var a := vertices[indices[index]]
		var face := (vertices[indices[index + 2]] - a).cross(vertices[indices[index + 1]] - a)
		for corner in 3: normals[indices[index + corner]] += face
	for index in normals.size(): normals[index] = normals[index].normalized()
	data.normals = normals
	return data

## Añade una superficie. Push desplaza por la normal (capas de pelo); Faceted separa los
## triángulos con normal plana para el aspecto low-poly de la ardilla.
func _add_surface(mesh: ArrayMesh, data: Dictionary, push: float, faceted: bool, material: Material) -> void:
	var vertices: PackedVector3Array = data.vertices.duplicate()
	if push > 0.0:
		for index in vertices.size(): vertices[index] += data.normals[index] * push
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	if faceted:
		var indices: PackedInt32Array = data.indices
		var flat_vertices := PackedVector3Array()
		var flat_normals := PackedVector3Array()
		var flat_colors := PackedColorArray()
		var flat_bones := PackedInt32Array()
		var flat_weights := PackedFloat32Array()
		for corner in range(0, indices.size(), 3):
			var a := vertices[indices[corner]]
			var face := (vertices[indices[corner + 2]] - a).cross(vertices[indices[corner + 1]] - a).normalized()
			for offset in 3:
				var source := indices[corner + offset]
				flat_vertices.append(vertices[source])
				flat_normals.append(face)
				flat_colors.append(data.colors[source])
				flat_bones.append_array((data.bones as PackedInt32Array).slice(source * 4, source * 4 + 4))
				flat_weights.append_array((data.weights as PackedFloat32Array).slice(source * 4, source * 4 + 4))
		arrays[Mesh.ARRAY_VERTEX] = flat_vertices
		arrays[Mesh.ARRAY_NORMAL] = flat_normals
		arrays[Mesh.ARRAY_COLOR] = flat_colors
		arrays[Mesh.ARRAY_BONES] = flat_bones
		arrays[Mesh.ARRAY_WEIGHTS] = flat_weights
	else:
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = data.normals
		arrays[Mesh.ARRAY_COLOR] = data.colors
		arrays[Mesh.ARRAY_BONES] = data.bones
		arrays[Mesh.ARRAY_WEIGHTS] = data.weights
		arrays[Mesh.ARRAY_INDEX] = data.indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(mesh.get_surface_count() - 1, material)

## Bultos redondeados tipo algodón (ruido celular): 1 en la cima de cada bulto, 0 en los surcos.
func _lumps(point: Vector3, s: ChristmasHatStyle) -> float:
	var large := _cell_dome(point * s.lump_density, s.noise_seed)
	var small := _cell_dome(point * s.lump_density * 2.3 + Vector3(17.1, 3.7, 9.2), s.noise_seed + 1)
	return clampf(large * 0.8 + small * 0.25, 0.0, 1.0)

func _cell_dome(point: Vector3, seed_value: int) -> float:
	var cell := point.floor()
	var nearest := 9.0
	for x in range(-1, 2):
		for y in range(-1, 2):
			for z in range(-1, 2):
				var corner := cell + Vector3(x, y, z)
				var jitter := Vector3(_hash(corner, seed_value), _hash(corner, seed_value + 11), _hash(corner, seed_value + 23))
				nearest = minf(nearest, point.distance_squared_to(corner + jitter))
	return sqrt(clampf(1.0 - nearest * 1.6, 0.0, 1.0))

func _hash(cell: Vector3, seed_value: int) -> float:
	var value := sin(cell.dot(Vector3(127.1, 311.7, 74.7)) + seed_value * 12.9898) * 43758.5453
	return value - floorf(value)

func _velvet_material(s: ChristmasHatStyle, layer: int) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = s.roughness
	material.metallic_specular = s.specular
	# Sólo caras exteriores: el interior del doblez comprimido no debe verse como estrías oscuras.
	material.cull_mode = BaseMaterial3D.CULL_BACK
	if s.plush_rim > 0.0:
		material.rim_enabled = true
		material.rim = s.plush_rim
		material.rim_tint = 0.65
	if layer >= 0:
		_make_shell(material, s, layer, s.velvet_shells, s.fur_fiber_scale * 2.0)
		material.albedo_color = Color(1.06, 1.06, 1.06)
	return material

func _fur_material(s: ChristmasHatStyle, layer: int) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = s.roughness
	material.metallic_specular = s.specular
	if s.plush_rim > 0.0:
		material.rim_enabled = true
		material.rim = s.plush_rim
		material.rim_tint = 0.3
	if layer >= 0:
		_make_shell(material, s, layer, s.fur_shells, s.fur_fiber_scale)
		var lift := 1.0 + 0.08 * float(layer + 1) / s.fur_shells
		material.albedo_color = Color(lift, lift, lift)
	return material

## Capa de pelo: fibras de ruido recortadas por alfa; cada capa exterior deja menos fibras.
func _make_shell(material: StandardMaterial3D, s: ChristmasHatStyle, layer: int, layers: int, fiber_scale: float) -> void:
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = lerpf(0.42, 0.82, float(layer + 1) / maxi(layers, 1))
	material.albedo_texture = _fiber_texture(s.noise_seed)
	material.uv1_triplanar = true
	material.uv1_triplanar_sharpness = 2.0
	material.uv1_scale = Vector3.ONE * fiber_scale
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

static var _fiber_textures: Dictionary = {}

func _fiber_texture(seed_value: int) -> Texture2D:
	if _fiber_textures.has(seed_value): return _fiber_textures[seed_value]
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	noise.frequency = 0.12
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 1))
	var texture := NoiseTexture2D.new()
	texture.width = FIBER_SIZE
	texture.height = FIBER_SIZE
	texture.seamless = true
	texture.generate_mipmaps = true
	texture.noise = noise
	texture.color_ramp = ramp
	_fiber_textures[seed_value] = texture
	return texture
