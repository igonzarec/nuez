@tool
extends RefCounted
## Finds what a ray from the editor camera touches: Terrain3D and visible MeshInstance3D. No editor classes here.

## Nearest hit as {"point": Vector3, "name": String}, or {} when the ray touches nothing. Exclude holds the nodes to
## ignore together with their children (the selection, so a node never lands on itself).
static func find_point(world: World3D, from: Vector3, direction: Vector3, length: float, terrains: Array,
		use_meshes: bool, exclude: Array) -> Dictionary:
	var best := {}
	var best_distance := length
	for terrain in terrains:
		if not is_instance_valid(terrain) or terrain.data == null:
			continue
		# CPU mode: the GPU mode answers with the previous frame's depth, wrong for a single click.
		var point: Vector3 = terrain.get_intersection(from, direction, false)
		if not point.is_finite() or absf(point.z) > 1e30:
			continue
		var distance := from.distance_to(point)
		if distance < best_distance:
			best_distance = distance
			best = {"point": point, "name": String(terrain.name)}
	if not use_meshes:
		return best
	var to := from + direction * best_distance
	for id in RenderingServer.instances_cull_ray(from, to, world.scenario):
		var instance := instance_from_id(id) as MeshInstance3D
		if instance == null or instance.mesh == null or not instance.is_visible_in_tree() or _excluded(instance, exclude):
			continue
		var hit: Variant = _hit_mesh(instance, from, to)
		if hit == null:
			continue
		var distance := from.distance_to(hit)
		if distance < best_distance:
			best_distance = distance
			best = {"point": hit, "name": String(instance.name)}
	return best

static func _excluded(node: Node, exclude: Array) -> bool:
	for other in exclude:
		if is_instance_valid(other) and (node == other or other.is_ancestor_of(node)):
			return true
	return false

## Nearest triangle of the mesh on the segment, in world space, or null. Runs once per click, so looping is fine.
static func _hit_mesh(instance: MeshInstance3D, from: Vector3, to: Vector3) -> Variant:
	var to_local := instance.global_transform.affine_inverse()
	var a := to_local * from
	var b := to_local * to
	var faces := instance.mesh.get_faces()
	var best: Variant = null
	var best_distance := INF
	for i in range(0, faces.size() - 2, 3):
		var hit: Variant = Geometry3D.segment_intersects_triangle(a, b, faces[i], faces[i + 1], faces[i + 2])
		if hit == null:
			continue
		var distance := a.distance_squared_to(hit)
		if distance < best_distance:
			best_distance = distance
			best = hit
	return null if best == null else instance.global_transform * (best as Vector3)
