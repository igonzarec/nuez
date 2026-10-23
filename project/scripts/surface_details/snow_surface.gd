@tool
extends RefCounted
## Capa continua sobre el relieve. Usa la misma máscara que el pincel y no tiene vida de partículas.
const PaintData = preload("res://scripts/surface_details/paint_data.gd")

static func create_noise(style: Resource) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = style.random_seed
	noise.frequency = 1.0 / maxf(0.1,style.snow_relief_scale)
	noise.fractal_octaves = 2
	return noise

static func depth_at(point: Vector2, style: Resource, noise: FastNoiseLite) -> float:
	return style.snow_depth+(noise.get_noise_2dv(point)*0.5+0.5)*style.snow_relief

static func build(terrain: Terrain3D, paint: Resource, key: Vector2i, style: Resource, channel: int = 0) -> ArrayMesh:
	var divisions := maxi(1, ceili(terrain.vertex_spacing / style.snow_mesh_spacing))
	var step := terrain.vertex_spacing / divisions
	var side := maxi(1, ceili(PaintData.TILE_SIZE / step))
	step = PaintData.TILE_SIZE / side
	var origin := Vector2(key) * PaintData.TILE_SIZE
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var valid := PackedByteArray()
	var noise := create_noise(style)
	var cosine := cos(deg_to_rad(style.maximum_slope))
	for z in side + 1:
		for x in side + 1:
			var point := origin + Vector2(x, z) * step
			var world := Vector3(point.x, 0, point.y)
			var height := terrain.data.get_height(world)
			var normal := terrain.data.get_normal(world)
			var exists := is_finite(height) and normal.is_finite() and terrain.data.has_regionp(world) and not terrain.data.get_control_hole(world)
			var coverage: float = paint.coverage(point, channel) if exists else 0.0
			var slope_weight := smoothstep(cosine,minf(1.0,cosine+0.06),normal.y) if cosine < 0.9999 else float(normal.y >= 0.9999)
			coverage *= slope_weight if exists else 0.0
			var relief: float = (noise.get_noise_2dv(point) * 0.5 + 0.5) * style.snow_relief
			if exists:
				var dx: float = (noise.get_noise_2dv(point+Vector2(0.1,0))-noise.get_noise_2dv(point-Vector2(0.1,0)))*style.snow_relief/0.4
				var dz: float = (noise.get_noise_2dv(point+Vector2(0,0.1))-noise.get_noise_2dv(point-Vector2(0,0.1)))*style.snow_relief/0.4
				normal = (normal-Vector3(dx,0,dz)).normalized()
			var fullness := smoothstep(0.0,0.65,coverage)
			vertices.append(Vector3(x * step, (height if exists else 0.0) + style.ground_offset + (style.snow_depth + relief)*fullness, z * step))
			normals.append(normal if exists else Vector3.UP)
			colors.append(Color(1, 1, 1, coverage))
			valid.append(1 if exists else 0)
	var indices := PackedInt32Array()
	for z in side:
		for x in side:
			var a := z * (side + 1) + x
			var b := a + 1
			var c := a + side + 1
			var d := c + 1
			for triangle in [[a,b,c], [b,d,c]]:
				if valid[triangle[0]] == 0 or valid[triangle[1]] == 0 or valid[triangle[2]] == 0: continue
				if maxf(colors[triangle[0]].a, maxf(colors[triangle[1]].a,colors[triangle[2]].a)) <= 0.001: continue
				indices.append_array(PackedInt32Array(triangle))
	if indices.is_empty(): return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
