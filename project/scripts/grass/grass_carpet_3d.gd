@tool
extends Node3D
## Short opaque grass in spatial MultiMesh chunks. No collision is created.
## Changes are grouped at 0.3 s intervals. Generated children are transient;
## manually placed children and this node's transform are never overwritten.

@export_group("Preview")
## Shows or hides only generated grass, in editor and game. Updates live.
@export var enabled := true
## Regenerates geometry after Inspector changes in the editor. Disable for large patches.
## Material controls remain live. Runtime geometry changes require Regenerate().
@export var live_preview := true
## Rebuilds the patch after terrain edits or when Live Preview is disabled.
@export_tool_button("Regenerate grass", "Reload") var regenerate_action: Callable = regenerate

@export_group("Distribution")
## Local X/Z size in metres. Larger areas cost more instances. Requires regeneration.
@export var area_size := Vector2(12.0, 12.0)
## Tufts per square metre, each containing Blades Per Tuft blades. Requires regeneration.
@export_range(1.0, 200.0, 1.0) var density := 140.0
## Hard cap per patch, applied uniformly over its area. Limits memory and geometry cost.
@export_range(100, 100000, 100) var max_tufts := 30000
## Repeatable arrangement seed. Changing it redistributes grass on regeneration.
@export var distribution_seed := 19
## Chunk width in metres. Smaller chunks improve culling but add draw calls. Regenerate.
@export_range(2.0, 32.0, 1.0) var chunk_size := 6.0

@export_group("Blade shape")
## Mean height in metres. 0.12–0.20 gives short carpet grass. Regenerate.
@export_range(0.02, 1.0, 0.01) var blade_height := 0.12
## Full blade width in metres. Wider leaves fill gaps with fewer tufts. Regenerate.
@export_range(0.005, 0.15, 0.005) var blade_width := 0.028
## Blades in each shared tuft; each blade uses three triangles. Regenerate.
@export_range(1, 8, 1) var blades_per_tuft := 4
## Radius of blade roots around each tuft centre, metres. Fills gaps between tufts. Regenerate.
@export_range(0.0, 0.2, 0.005) var tuft_radius := 0.045
## Tip bend as a fraction of blade height. Zero is upright. Regenerate.
@export_range(0.0, 1.0, 0.01) var bend := 0.3
## Random size variation, fraction of nominal size (0.25 = ±25%). Regenerate.
@export_range(0.0, 0.8, 0.01) var size_variation := 0.25

@export_group("Palette")
## One to 32 colors, three by default. Add/remove array entries to change variants.
## Equal probability per tuft. Empty arrays use one green. Updates live, no redistribution.
@export var colors: Array[Color] = [Color(0.24, 0.40, 0.14), Color(0.30, 0.46, 0.18), Color(0.36, 0.50, 0.22)]
## Multiplies the base of each blade; darker values create depth. Live.
@export var root_tint := Color(0.75, 0.80, 0.65)
## Multiplies blade tips. White preserves palette colors. Live.
@export var tip_tint := Color.WHITE
## Additional random brightness per tuft. Zero keeps only palette differences. Live.
@export_range(0.0, 0.5, 0.01) var color_variation := 0.12

@export_group("Lighting")
## Surface roughness: 1 matte, 0 glossy. Live.
@export_range(0.0, 1.0, 0.01) var roughness := 0.9
## Tilts lighting normals upward for a soft carpet appearance. 0 shows sharper facets. Live.
@export_range(0.0, 1.0, 0.01) var normal_up := 0.7
## Simulated light through leaves. Increasing brightens backlit blades. Live.
@export_range(0.0, 1.0, 0.01) var backlight := 0.2
## Individual grass shadows are expensive at high density. Off by default. Live.
@export var cast_shadows := false

@export_group("Distance")
## Camera distance in metres where blades begin shrinking. Base texture stays visible. Live.
@export_range(1.0, 150.0, 1.0) var fade_start := 28.0
## Distance in metres where blades disappear; clamped above Fade Start. Live.
## Chunks are culled beyond this distance plus their extent.
@export_range(2.0, 200.0, 1.0) var fade_end := 40.0

@export_group("Optional wind")
## Enables shader animation. Off gives entirely static grass. Live.
@export var wind_enabled := false
## Lateral tip movement in metres before instance scaling. Live; increases visual motion.
@export_range(0.0, 0.3, 0.005) var wind_strength := 0.04
## Animation speed. Zero freezes the phase. Live.
@export_range(0.0, 5.0, 0.1) var wind_speed := 1.0
## Direction in local X/Z coordinates, normalized internally. Live.
@export var wind_direction := Vector2(1.0, 0.3)

@export_group("Terrain3D placement")
## Optional Terrain3D node. Empty creates a flat patch at this node's local Y=0.
## Assigning a terrain samples its height/normal on regeneration, without needing collision.
@export_node_path("Terrain3D") var terrain_path: NodePath
## Reject slopes above this angle in degrees when a terrain is assigned. Regenerate.
@export_range(0.0, 89.0, 1.0) var maximum_slope := 48.0
## 0 grows vertically; 1 follows terrain normals. Only used with Terrain3D. Regenerate.
@export_range(0.0, 1.0, 0.05) var align_to_ground := 0.5
## Root offset in metres along the sampled normal. Small negative values hide roots. Regenerate.
@export_range(-0.2, 0.2, 0.005) var ground_offset := -0.005
## Restrict to a painted terrain texture ID. -1 accepts all surfaces, including snow.
## This reads painted base/overlay weights, not procedural Auto Shader coverage. Regenerate.
@export_range(-1, 31, 1) var required_texture_id := -1
## Minimum painted weight of Required Texture ID. Ignored when ID is -1. Regenerate.
@export_range(0.0, 1.0, 0.05) var minimum_texture_weight := 0.5

var _generated: Node3D
var _material: ShaderMaterial
var _signature := 0
var _elapsed := 0.0

func _ready() -> void:
	regenerate.call_deferred()

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < 0.3:
		return
	_elapsed = 0.0
	if is_instance_valid(_generated):
		_generated.visible = enabled
	_update_material()
	if Engine.is_editor_hint() and live_preview and _signature != _geometry_signature():
		regenerate()

func _geometry_signature() -> int:
	return hash([area_size, density, max_tufts, distribution_seed, chunk_size,
		blade_height, blade_width, blades_per_tuft, tuft_radius, bend, size_variation,
		terrain_path, maximum_slope, align_to_ground, ground_offset,
		required_texture_id, minimum_texture_weight, global_transform])

func _update_material() -> void:
	if _material == null:
		return
	var palette := PackedColorArray()
	for i in 32:
		palette.append(colors[i % colors.size()] if not colors.is_empty() else Color(0.4, 0.6, 0.2))
	_material.set_shader_parameter("palette", palette)
	_material.set_shader_parameter("palette_count", clampi(colors.size(), 1, 32))
	for property: String in ["root_tint", "tip_tint", "color_variation", "roughness", "normal_up", "backlight", "wind_enabled", "wind_strength", "wind_speed"]:
		_material.set_shader_parameter(property, get(property))
	_material.set_shader_parameter("wind_direction", wind_direction.normalized())
	_material.set_shader_parameter("fade_start", fade_start)
	_material.set_shader_parameter("fade_end", maxf(fade_start + 0.1, fade_end))
	if is_instance_valid(_generated):
		for child: MultiMeshInstance3D in _generated.get_children():
			child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			child.visibility_range_end = maxf(fade_start + 0.1, fade_end) + chunk_size * 2.0
			child.extra_cull_margin = wind_strength + blade_height

## Rebuild after sculpting/painting the terrain. Only this component's transient children change.
func regenerate() -> void:
	if not is_inside_tree():
		return
	_signature = _geometry_signature()
	if is_instance_valid(_generated):
		remove_child(_generated)
		_generated.queue_free()
	_generated = Node3D.new()
	_generated.name = "GeneratedGrass"
	add_child(_generated)
	_generated.visible = enabled
	_material = ShaderMaterial.new()
	_material.shader = preload("res://shaders/grass_carpet_blades.gdshader")
	var tuft := _build_tuft()
	var terrain: Node = get_node_or_null(terrain_path) if not terrain_path.is_empty() else null
	if not terrain_path.is_empty() and (terrain == null or not terrain.is_class("Terrain3D")):
		push_warning("Grass: Terrain Path must point to Terrain3D. No grass generated.")
		return
	var data: Object = terrain.get("data") if terrain != null else null
	if terrain != null and data == null:
		push_warning("Grass: Terrain3D data unavailable; regenerate when loaded.")
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = distribution_seed
	var extent := Vector2(maxf(0.1, area_size.x), maxf(0.1, area_size.y))
	var count := mini(max_tufts, int(extent.x * extent.y * density))
	var groups: Dictionary = {}
	for i in count:
		var pos := Vector3(rng.randf_range(-extent.x * 0.5, extent.x * 0.5), 0, rng.randf_range(-extent.y * 0.5, extent.y * 0.5))
		var up := Vector3.UP
		if data != null:
			var world := to_global(pos)
			var h: float = data.call("get_height", world)
			if not is_finite(h):
				continue
			world.y = h
			var normal: Vector3 = data.call("get_normal", world)
			if not normal.is_finite() or normal.dot(Vector3.UP) < cos(deg_to_rad(maximum_slope)):
				continue
			if required_texture_id >= 0:
				var ids: Vector3 = data.call("get_texture_id", world)
				var weight := (1.0 - ids.z if int(ids.x) == required_texture_id else 0.0) + (ids.z if int(ids.y) == required_texture_id else 0.0)
				if weight < minimum_texture_weight:
					continue
			pos = to_local(world + normal * ground_offset)
			up = (global_basis.inverse() * Vector3.UP.lerp(normal, align_to_ground)).normalized()
		else:
			pos.y += ground_offset
		var right := Vector3.RIGHT.slide(up).normalized()
		if right.length_squared() < 0.01:
			right = Vector3.FORWARD.slide(up).normalized()
		var basis := Basis(right, up, right.cross(up)).rotated(up, rng.randf() * TAU)
		basis = basis.scaled(Vector3.ONE * rng.randf_range(1.0 - size_variation, 1.0 + size_variation))
		var key := Vector2i(floori((pos.x + extent.x * 0.5) / chunk_size), floori((pos.z + extent.y * 0.5) / chunk_size))
		if not groups.has(key):
			groups[key] = []
		groups[key].append([Transform3D(basis, pos), Color(rng.randf(), rng.randf(), 0, 1)])
	for key: Vector2i in groups:
		var entries: Array = groups[key]
		var center := Vector3.ZERO
		for entry: Array in entries:
			var t: Transform3D = entry[0]
			center += t.origin
		center /= entries.size()
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_custom_data = true
		multi.mesh = tuft
		multi.instance_count = entries.size()
		for i in entries.size():
			var transform: Transform3D = entries[i][0]
			transform.origin -= center
			multi.set_instance_transform(i, transform)
			multi.set_instance_custom_data(i, entries[i][1])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multi
		instance.material_override = _material
		_generated.add_child(instance)
		instance.position = center
	_update_material()

func _build_tuft() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in blades_per_tuft:
		var angle := TAU * float(blade) / float(blades_per_tuft)
		var rotation := Basis(Vector3.UP, angle)
		var h := blade_height * (1.0 - float(blade % 3) * 0.08)
		var w := blade_width * 0.5
		var points := [Vector3(-w, 0, 0), Vector3(w, 0, 0),
			Vector3(-w * 0.65, h * 0.55, h * bend * 0.25),
			Vector3(w * 0.65, h * 0.55, h * bend * 0.25), Vector3(0, h, h * bend)]
		var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(0, 0.55), Vector2(1, 0.55), Vector2(0.5, 1)]
		for index in [0, 2, 1, 1, 2, 3, 2, 4, 3]:
			surface.set_uv(uvs[index])
			surface.add_vertex(rotation * (points[index] + Vector3(0, 0, tuft_radius)))
	surface.generate_normals()
	return surface.commit()
