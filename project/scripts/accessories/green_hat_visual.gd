@tool
extends Node3D
## Malla de green hat: borde acolchado fijo y un cono recto con esqueleto en la cola.
## La curva no se modela: la gravedad dobla la mitad blanda del cono. La cola es una cadena
## articulada: en cada articulación el peso de toda la tela que cuelga (y del pompón) genera un
## par que un resorte de flexión resiste. La misma física responde a inercia, aire, giros y colisión.

## Recurso compartido de forma, color y física. Cambios visibles con Live Preview.
@export var style: GreenHatStyle
## Regenera al editar el recurso; agrupa cambios cada 0,2 s. Desactivar evita trabajo en editor.
@export var live_preview := true
## Simula la gravedad también en el editor para previsualizar la caída real. Apagado muestra el cono recto.
@export var simulate_in_editor := true
## Apoya la cola en el suelo bajo el gorro (un rayo por tick). Úsalo en el gorro tirado. En vivo.
@export var ground_collision := false
## Capas que cuentan como suelo para Ground Collision.
@export_flags_3d_physics var ground_mask := 1

@export_group("Desinflado")
## Aspecto desinflado de esta instancia (0–1), sin cambiar el estilo compartido: 0 es el gorro puesto;
## 1 aplica todo Deflate Height, Deflate Width y Deflate Softness. Lo usa el gorro tirado. Live Preview.
@export_range(0.0, 1.0, 0.01) var deflate := 0.0
## Cuánto se hunde la tela verde en altura con Deflate = 1 (fracción). Mayor la aplasta más. Live Preview.
@export_range(0.0, 0.9, 0.01) var deflate_height := 0.45
## Cuánto se ensancha la tela al hundirse con Deflate = 1 (fracción). Live Preview.
@export_range(0.0, 0.6, 0.01) var deflate_width := 0.12
## Cuánto se ablanda la tela con Deflate = 1 (fracción de la rigidez). Mayor deja la cola más lacia. En vivo.
@export_range(0.0, 0.95, 0.01) var deflate_softness := 0.6

const SETTLE_STEPS := 360
const STEP := 1.0 / 120.0
## Rigidez de contacto (1/s²) contra la cabeza, el borde y el suelo.
const CONTACT := 900.0

var _signature: Array = []
var _clock := 0.0
var _skeleton: Skeleton3D
var _tail: MeshInstance3D
var _rest_points := PackedVector3Array()
var _rest_radii := PackedFloat32Array()
var _rest_global: Array = []
var _rest_dir := Vector3.UP
var _pinned := 0
var _rest_basis := Basis.IDENTITY
var _lengths := PackedFloat32Array()
var _mass := PackedFloat32Array()
var _moments := PackedFloat32Array()
var _turns: Array[Quaternion] = []
var _spins := PackedVector3Array()
var _points := PackedVector3Array()
var _frames: Array[Basis] = []
var _carry_velocity := PackedVector3Array()
var _carry_acceleration := PackedVector3Array()
var _previous_xf := Transform3D.IDENTITY
var _sim_ready := false
var _ground := Plane()
var _ground_valid := false

func _ready() -> void:
	if not style: style = GreenHatStyle.new()
	# Después del movimiento del personaje en el mismo tick de física.
	process_physics_priority = 200
	visibility_changed.connect(func() -> void: _sim_ready = false)
	rebuild()

func _process(delta: float) -> void:
	if not live_preview: return
	_clock += delta
	if _clock < 0.2: return
	_clock = 0.0
	if style and _signature != _full_signature(): rebuild()

## Estilo compartido más el desinflado de esta instancia.
func _full_signature() -> Array:
	return style.signature() + [deflate, deflate_height, deflate_width]

## Aplastamiento lineal del desinflado alrededor del centro del borde: baja y ensancha la tela verde.
func _deflate_basis() -> Basis:
	var widen := 1.0 + deflate * deflate_width
	return Basis.from_scale(Vector3(widen, 1.0 - deflate * deflate_height, widen))

func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = style.roughness
	mat.metallic_specular = 0.15
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

func _surface(rings: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(rings.size() - 1):
		for col in range(style.segments):
			var j := (col + 1) % style.segments
			for point in [rings[row][col], rings[row + 1][col], rings[row][j], rings[row][j], rings[row + 1][col], rings[row + 1][j]]:
				st.add_vertex(point)
	st.generate_normals()
	return st.commit()

## Perfil cerrado del borde: (desplazamiento radial hacia dentro, altura). Empieza y termina
## en el centro de la cara exterior; cantos de cuarto de círculo.
func _brim_profile() -> Array[Vector2]:
	var half := style.brim_height * 0.5
	var corner := minf(style.brim_thickness, style.brim_height) * 0.45
	var points: Array[Vector2] = [Vector2(0.0, 0.0)]
	var centers := [Vector2(-corner, half - corner), Vector2(-style.brim_thickness + corner, half - corner), Vector2(-style.brim_thickness + corner, -half + corner), Vector2(-corner, -half + corner)]
	for quarter in 4:
		for step in 5:
			var angle := PI * 0.5 * (quarter + step / 4.0)
			points.append(centers[quarter] + Vector2(cos(angle), sin(angle)) * corner)
	points.append(Vector2(0.0, 0.0))
	return points

func rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_signature = _full_signature().duplicate()
	_sim_ready = false
	# Borde: rectángulo de cantos redondeados con la cara exterior vertical; fijo a la cabeza.
	var rings: Array = []
	for point: Vector2 in _brim_profile():
		var ring: Array[Vector3] = []
		for col in range(style.segments):
			var a := TAU * col / style.segments
			ring.append(Vector3((style.brim_radii.x + point.x) * cos(a), point.y, (style.brim_radii.y + point.x) * sin(a)))
		rings.append(ring)
	var brim := MeshInstance3D.new()
	brim.name = "WarmBrim"
	brim.mesh = _surface(rings)
	brim.material_override = _material(style.trim_color)
	add_child(brim)
	_build_tail()

## Cono recto inclinado hacia atrás, con esqueleto: raíz fija y cadena a lo largo del eje.
func _build_tail() -> void:
	var bones := style.tail_bones
	var rows := bones * ceili(float(style.length_rings) / bones)
	var cone_dir := (Basis(Vector3.UP, deg_to_rad(style.tip_direction_degrees)) * Basis(Vector3.RIGHT, deg_to_rad(style.backward_angle_degrees)) * Vector3.UP).normalized()
	var side := Vector3.RIGHT.rotated(Vector3.UP, deg_to_rad(style.tip_direction_degrees))
	var other := side.cross(cone_dir).normalized()
	# Desinflado: toda la geometría verde y los huesos pasan por el mismo aplastamiento lineal,
	# así la cadena sigue recta y la física usa la forma desinflada como reposo.
	var squash := _deflate_basis()
	_rest_dir = (squash * cone_dir).normalized()
	# Crown Offset mueve todo lo verde (malla, huesos y física) respecto al borde blanco.
	var base := Vector3(0, 0.03, 0) + style.crown_offset
	var base_x := style.brim_radii.x - style.brim_thickness * 0.55
	var base_z := style.brim_radii.y - style.brim_thickness * 0.55
	_rest_points = PackedVector3Array()
	_rest_radii = PackedFloat32Array()
	for index in bones + 1:
		var t := float(index) / bones
		_rest_points.append(squash * (base + cone_dir * style.cone_length * t))
		_rest_radii.append(maxf(base_x, base_z) * _radius(t))
	_pinned = 0
	for index in bones:
		if float(index) / bones <= style.rigid_ratio + 0.0001: _pinned = index
	_skeleton = Skeleton3D.new()
	_skeleton.name = "TailSkeleton"
	_skeleton.add_bone("root")
	_rest_global = [Transform3D.IDENTITY]
	var bone_basis := Basis(side, _rest_dir, side.cross(_rest_dir)).orthonormalized()
	_rest_basis = bone_basis
	for index in bones:
		_skeleton.add_bone("tail_%d" % index)
		_skeleton.set_bone_parent(index + 1, index)
		var global_rest := Transform3D(bone_basis, _rest_points[index])
		_skeleton.set_bone_rest(index + 1, (_rest_global[index] as Transform3D).affine_inverse() * global_rest)
		_rest_global.append(global_rest)
	_skeleton.reset_bone_poses()
	add_child(_skeleton)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(_material(style.body_color))
	var grid: Array = []
	# La base de la copa se apoya plana sobre el borde (sin hueco delante) y gira hasta quedar
	# perpendicular al cono inclinado a lo largo de la parte rígida: la tela del frente se alarga.
	var flat_other := side.cross(Vector3.UP).normalized()
	for row in rows + 1:
		var t := float(row) / rows
		var center := base + cone_dir * style.cone_length * t
		var radius := _radius(t)
		var settle := smoothstep(0.0, maxf(style.rigid_ratio, 0.05), t)
		var ring_other := flat_other.slerp(other, settle).normalized()
		var ring_side := side
		var ring: Array = []
		for col in style.segments:
			var a := TAU * col / style.segments
			var fold := style.folds * sin(a * 3.0 + t * 8.0) * sin(t * PI)
			var x := maxf(0.01, base_x * radius + fold)
			var z := maxf(0.01, base_z * radius + fold)
			ring.append([squash * (center + ring_side * cos(a) * x + ring_other * sin(a) * z), _weights(t)])
		grid.append(ring)
	for row in rows:
		for col in style.segments:
			var j := (col + 1) % style.segments
			for cell in [grid[row][col], grid[row + 1][col], grid[row][j], grid[row][j], grid[row + 1][col], grid[row + 1][j]]:
				st.set_bones(cell[1][0])
				st.set_weights(cell[1][1])
				st.add_vertex(cell[0])
	st.index()
	st.generate_normals()
	var mesh := st.commit()
	# Pompón unido al último hueso, a lo largo de la cola.
	var pom := SurfaceTool.new()
	pom.begin(Mesh.PRIMITIVE_TRIANGLES)
	pom.set_material(_material(style.trim_color))
	# El pompón sigue el desinflado en posición pero conserva su forma redonda.
	var pom_center := squash * (base + cone_dir * (style.cone_length + style.pom_backward_offset))
	var latitudes := 8
	var longitudes := 16
	var tip_bones := PackedInt32Array([bones, 0, 0, 0])
	var tip_weights := PackedFloat32Array([1.0, 0.0, 0.0, 0.0])
	var sphere: Array = []
	for row in latitudes + 1:
		var theta := PI * row / latitudes
		var line: Array = []
		for col in longitudes:
			var phi := TAU * col / longitudes
			var normal := side * sin(theta) * cos(phi) + _rest_dir * cos(theta) + other * sin(theta) * sin(phi)
			line.append(pom_center + Vector3(normal.x * style.pom_scale.x, normal.y * style.pom_scale.y, normal.z * style.pom_scale.z) * style.pom_radius)
		sphere.append(line)
	for row in latitudes:
		for col in longitudes:
			var j := (col + 1) % longitudes
			for point in [sphere[row][col], sphere[row + 1][col], sphere[row][j], sphere[row][j], sphere[row + 1][col], sphere[row + 1][j]]:
				pom.set_bones(tip_bones)
				pom.set_weights(tip_weights)
				pom.add_vertex(point)
	pom.index()
	pom.generate_normals()
	pom.commit(mesh)
	_tail = MeshInstance3D.new()
	_tail.name = "SoftCrown"
	_tail.mesh = mesh
	_skeleton.add_child(_tail)
	_tail.skeleton = NodePath("..")

## Radio relativo a lo largo del cono: cúpula llena sobre el borde y cola que se afina.
func _radius(t: float) -> float:
	var taper := lerpf(1.0, style.tip_ratio, pow(t, style.taper_power))
	return taper * (1.0 + style.crown_fullness * sin(PI * minf(t / 0.4, 1.0)))

## Pesos de un vértice: la copa queda unida a la raíz y la cola se reparte entre huesos vecinos.
func _weights(t: float) -> Array:
	var bones := style.tail_bones
	var f := t * bones
	var bone := mini(int(f), bones - 1)
	var s := f - bone
	var weights := {bone + 1: 1.0}
	if s < 0.5:
		weights[bone] = 0.5 - s
		weights[bone + 1] = 0.5 + s
	elif bone + 2 <= bones:
		weights[bone + 2] = s - 0.5
		weights[bone + 1] = 1.5 - s
	# Sólo la costura con el borde queda en la raíz; la copa sigue a sus huesos (rígidos salvo transmisión).
	var lock := 1.0 - smoothstep(0.0, 0.06, t)
	if lock > 0.0:
		for key in weights.keys(): weights[key] *= 1.0 - lock
		weights[0] = weights.get(0, 0.0) + lock
	var keys := weights.keys()
	keys.sort_custom(func(a: int, b: int) -> bool: return weights[a] > weights[b])
	var ids := PackedInt32Array([0, 0, 0, 0])
	var values := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	var total := 0.0
	for index in mini(4, keys.size()): total += weights[keys[index]]
	for index in mini(4, keys.size()):
		ids[index] = keys[index]
		values[index] = weights[keys[index]] / total
	return [ids, values]

# --- Física de la cola -------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_skeleton) or _rest_points.is_empty(): return
	var active := style.tail_physics and is_visible_in_tree() and (not Engine.is_editor_hint() or simulate_in_editor)
	if not active:
		if _sim_ready:
			_skeleton.reset_bone_poses()
			_sim_ready = false
		return
	_update_ground()
	var xf := _skeleton.global_transform
	var dt := minf(delta, 1.0 / 20.0)
	if not _sim_ready or xf.origin.distance_to(_previous_xf.origin) > 3.0:
		_reset(xf)
		# Asentar: la cola cae por su peso antes del primer fotograma visible.
		for step in SETTLE_STEPS: _step(xf, STEP)
	else:
		# Velocidad y aceleración de cada punto si la cola fuera rígida con la cabeza:
		# su opuesto es la inercia (acelerar, frenar, girar) y la velocidad da el arrastre del aire.
		for index in _points.size():
			var carried := xf * (_previous_xf.affine_inverse() * _points[index])
			var velocity := (carried - _points[index]) / maxf(dt, 0.0001)
			_carry_acceleration[index] = ((velocity - _carry_velocity[index]) / maxf(dt, 0.0001)).limit_length(style.max_inertia)
			_carry_velocity[index] = velocity
		var steps := clampi(ceili(dt / STEP), 1, 4)
		for step in steps: _step(xf, dt / steps)
	_previous_xf = xf
	_apply_pose(xf)

func _reset(xf: Transform3D) -> void:
	var count := _rest_points.size()
	_lengths.resize(count - 1)
	_mass.resize(count)
	for index in count - 1: _lengths[index] = (_rest_points[index + 1] - _rest_points[index]).length()
	# Masa por punto proporcional a la circunferencia: la cola fina pesa menos.
	for index in count: _mass[index] = _rest_radii[index]
	# Par que hace el peso de la tela horizontal en cada articulación (sin el pompón: así su
	# peso extra sí dobla más la punta). La rigidez se escala con él en cada paso.
	_moments.resize(count)
	for joint in count:
		var moment := 0.0
		for point in range(joint + 1, count): moment += _mass[point] * (_rest_points[point] - _rest_points[joint]).length()
		_moments[joint] = moment
	_mass[count - 1] += _rest_radii[count - 1] * style.pom_weight * 3.0
	_turns.resize(count - 1)
	_turns.fill(Quaternion.IDENTITY)
	_spins.resize(count - 1)
	_spins.fill(Vector3.ZERO)
	_carry_velocity.resize(count)
	_carry_velocity.fill(Vector3.ZERO)
	_carry_acceleration.resize(count)
	_carry_acceleration.fill(Vector3.ZERO)
	_previous_xf = xf
	_forward(xf)
	_sim_ready = true

## Rigidez de una articulación: alta en toda la cola salvo una única zona blanda (campana) centrada en
## Fold Position. Fold Strength decide cuánto se ablanda y Fold Spread su anchura. Se lee en vivo.
func _joint_stiffness(joint: int, count: int) -> float:
	var progress := clampf(float(joint - _pinned) / maxi(count - 2 - _pinned, 1), 0.0, 1.0)
	var distance := (progress - style.fold_position) / maxf(style.fold_spread * 0.5, 0.01)
	var softening := style.fold_strength * 0.97 * exp(-distance * distance)
	softening = maxf(softening, style.tip_softness * 0.97 * smoothstep(0.7, 1.0, progress))
	return style.tail_stiffness * (1.0 - softening) * _softness() * _moments[joint] * _gravity()

## Factor de rigidez del desinflado (1 sin desinflar).
func _softness() -> float:
	return 1.0 - deflate * deflate_softness

## Fracción de flexibilidad de una articulación de la copa: máxima junto a la cola y nula en el borde.
func _crown_flex(joint: int) -> float:
	if joint >= _pinned: return 1.0
	# Con transmisión 1 la copa junto a la cola es el doble de rígida que la cola: siempre cede menos.
	return 0.5 * style.crown_transmission * pow(float(joint + 1) / float(_pinned + 1), style.crown_transition)

func _gravity() -> float:
	return float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)) * maxf(style.gravity_scale, 0.0001)

func _root_basis(xf: Transform3D) -> Basis:
	return xf.basis.orthonormalized() * _rest_basis

## Cinemática directa desde el borde: cada tramo gira respecto al anterior (la copa sólo si recibe transmisión).
func _forward(xf: Transform3D) -> void:
	var count := _rest_points.size()
	var scale_factor := xf.basis.get_scale().x
	var frame := _root_basis(xf)
	_points.resize(count)
	_frames.resize(count - 1)
	_points[0] = xf * _rest_points[0]
	for segment in count - 1:
		frame = frame * Basis(_turns[segment])
		_frames[segment] = frame
		_points[segment + 1] = _points[segment] + frame.y * _lengths[segment] * scale_factor

func _step(xf: Transform3D, dt: float) -> void:
	var count := _points.size()
	var scale_factor := xf.basis.get_scale().x
	var gravity := Vector3.DOWN * _gravity()
	var center := xf * style.collision_center
	var radius := style.collision_radius * scale_factor
	# Fuerza por punto: gravedad, inercia, aire y contactos (cabeza, borde y suelo).
	var forces := PackedVector3Array()
	forces.resize(count)
	for index in range(1, count):
		# La copa sólo recibe contacto; gravedad, inercia y aire actúan sobre la cola.
		var force := Vector3.ZERO
		if index > _pinned: force = gravity - _carry_acceleration[index] * style.inertia - _carry_velocity[index] * style.air_drag
		# La tela (con Collision Margin de su grosor) no entra en la cabeza; si en reposo ya está más cerca
		# del centro, sólo impide que se hunda más de lo que estaba (no deforma la copa).
		var clearance := _rest_radii[index] * scale_factor * style.collision_margin
		var from_center := _points[index] - center
		var rest_distance := (xf * _rest_points[index] - center).length()
		var depth := minf(radius + clearance, rest_distance) - from_center.length()
		if depth > 0.0 and from_center.length() > 0.0001: force += from_center.normalized() * depth * CONTACT
		if _ground_valid:
			var floor_clearance := (style.pom_radius if index == count - 1 else _rest_radii[index] * 0.6) * scale_factor
			var height := _ground.distance_to(_points[index])
			if height < floor_clearance: force += _ground.normal * (floor_clearance - height) * CONTACT
		forces[index] = force * _mass[index]
	var limit := deg_to_rad(style.max_bend_degrees)
	for segment in count - 1:
		var flex := _crown_flex(segment)
		if flex <= 0.0005:
			# Copa rígida: vuelve a su forma si Crown Transmission bajó en vivo.
			_turns[segment] = Quaternion.IDENTITY
			_spins[segment] = Vector3.ZERO
			continue
		var joint := _points[segment]
		var torque := Vector3.ZERO
		var inertia_sum := 0.0
		for point in range(segment + 1, count):
			var arm := _points[point] - joint
			torque += arm.cross(forces[point])
			inertia_sum += _mass[point] * arm.length_squared()
		var parent := _frames[segment - 1] if segment > 0 else _root_basis(xf)
		var turn := _turns[segment]
		var angle := turn.get_angle()
		# En la copa, la rigidez es la de la cola dividida por la flexibilidad transmitida (muy rígida junto al borde).
		var stiffness := _joint_stiffness(segment, count) if segment >= _pinned else minf(style.tail_stiffness * _softness() / flex, 2000.0) * _moments[segment] * _gravity()
		# Resorte y amortiguación implícitos (Euler hacia atrás): estables con cualquier rigidez, también la
		# muy alta de la copa. Amortiguación relativa a la crítica (2·ζ·√(K/I)): sin rebote con ζ = 1.
		var inertia_value := maxf(inertia_sum, 0.000001)
		var omega_sq := stiffness / inertia_value
		var damping := 2.0 * style.damping_ratio * sqrt(omega_sq)
		# Velocidad de giro en el espacio del tramo padre: no queda desalineada cuando la copa gira.
		var to_parent := parent.inverse()
		var bend := turn.get_axis() * angle if angle > 0.00001 else Vector3.ZERO
		var acceleration := to_parent * torque / inertia_value - bend * omega_sq
		var spin := (_spins[segment] + acceleration * dt) / (1.0 + damping * dt + omega_sq * dt * dt)
		# Sólo flexión: sin torsión sobre el propio eje del tramo.
		var axis := (to_parent * _frames[segment].y).normalized()
		spin -= axis * spin.dot(axis)
		_spins[segment] = spin
		var local := spin * dt
		if local.length() > 0.0000001:
			turn = (Quaternion(local.normalized(), local.length()) * turn).normalized()
			if turn.get_angle() > limit:
				turn = Quaternion(turn.get_axis(), limit)
				_spins[segment] = Vector3.ZERO
			_turns[segment] = turn
		# Los tramos siguientes heredan el giro en el mismo paso.
		_forward(xf)

func _apply_pose(xf: Transform3D) -> void:
	var inverse := xf.affine_inverse()
	var to_local := xf.basis.orthonormalized().inverse()
	var parent := Transform3D.IDENTITY
	for chain in _points.size() - 1:
		var bone_global := Transform3D((to_local * _frames[chain]).orthonormalized(), inverse * _points[chain])
		var local := parent.affine_inverse() * bone_global
		_skeleton.set_bone_pose_position(chain + 1, local.origin)
		_skeleton.set_bone_pose_rotation(chain + 1, local.basis.get_rotation_quaternion())
		parent = bone_global

func _update_ground() -> void:
	_ground_valid = false
	if not ground_collision or not is_inside_tree(): return
	var origin := global_position + Vector3.UP * 0.5
	var query := PhysicsRayQueryParameters3D.create(origin, origin + Vector3.DOWN * 3.0, ground_mask)
	var node := get_parent()
	while node:
		if node is CollisionObject3D:
			query.exclude = [node.get_rid()]
			break
		node = node.get_parent()
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		_ground = Plane(hit.normal, hit.position)
		_ground_valid = true
