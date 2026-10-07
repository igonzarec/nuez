@tool
extends MeshInstance3D
## Flat preview/application tile for the reusable grass material. No collision.
## All controls update live, grouped every 0.2 s. The material can also be used on UV meshes.

@export_group("Surface")
## Shows or hides this surface in editor/game. Live.
@export var enabled := true
## Tile dimensions in metres, local X/Z. Updates mesh live; does not move this node.
@export var size_metres := Vector2(12, 12)
## Repetitions per metre. Larger values make individual texture blades smaller. Live.
@export_range(0.05, 10.0, 0.05) var repeats_per_metre := 1.0
## Source color map. Default generated carpet grass. Live.
@export var albedo_texture: Texture2D = preload("res://assets/textures/grass_carpet/grass_albedo.png")
## OpenGL (+Y) normal map; adds lighting detail without geometry. Live.
@export var normal_texture: Texture2D = preload("res://assets/textures/grass_carpet/grass_normal.png")

@export_group("Color")
## Grass color, including non-green hues. Recolor=1 uses texture detail with this hue. Live.
@export var tint := Color(0.30, 0.45, 0.20)
## 1 replaces source hue; 0 multiplies original colors by Tint (use white to see source). Live.
@export_range(0.0, 1.0, 0.01) var recolor := 1.0
## Contrast of the recolored fine detail. Zero gives a flat tint; normal still works. Live.
@export_range(0.0, 2.0, 0.01) var contrast := 0.65
## Brightness multiplier. 1 is neutral. Live.
@export_range(0.0, 2.0, 0.01) var brightness := 1.0
## Strength of broad world-space color variation. Zero disables it. Live.
@export_range(0.0, 0.5, 0.01) var macro_strength := 0.06
## Broad variation frequency per metre. Lower values make larger patches. Live.
@export_range(0.01, 2.0, 0.01) var macro_scale := 0.2

@export_group("Relief and lighting")
## Normal intensity. Zero removes simulated relief, 1 uses the map as authored. Live.
@export_range(0.0, 2.0, 0.01) var normal_strength := 0.45
## Roughness, 1 matte and 0 glossy. Live.
@export_range(0.0, 1.0, 0.01) var roughness := 0.9

var _elapsed := 0.0
var _material: ShaderMaterial

func _ready() -> void:
	mesh = PlaneMesh.new()
	_material = preload("res://materials/grass_carpet_surface.tres").duplicate() as ShaderMaterial
	material_override = _material
	_refresh()

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 0.2:
		_elapsed = 0.0
		_refresh()

func _refresh() -> void:
	if _material == null:
		return
	visible = enabled
	var plane := mesh as PlaneMesh
	var dimensions := Vector2(maxf(0.01, size_metres.x), maxf(0.01, size_metres.y))
	if plane.size != dimensions:
		plane.size = dimensions
	# PlaneMesh UVs are 0..1: scale each axis independently for metric repetitions.
	_material.set_shader_parameter("tile_size", dimensions)
	_material.set_shader_parameter("texture_scale", repeats_per_metre)
	for property: String in ["albedo_texture", "normal_texture", "tint", "recolor", "contrast", "brightness", "macro_strength", "macro_scale", "normal_strength", "roughness"]:
		_material.set_shader_parameter(property, get(property))
