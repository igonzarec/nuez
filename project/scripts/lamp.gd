class_name TrailLamp
extends TrailInteractable

signal lit(lamp: TrailLamp)

var is_lit := false
@export var seed_cost := 3
var beacon_light: OmniLight3D
var glass_material: StandardMaterial3D
var embers: CPUParticles3D

func setup(world_position: Vector3, title: String) -> void:
	position = world_position
	name = title
	verb = "Restaurar farol · %d semillas" % seed_cost
	_build()

func _mat(color: Color, emission := Color.TRANSPARENT, energy := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	if energy > 0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = energy
	return material

func _part(mesh: Mesh, material: Material, offset: Vector3) -> void:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = offset
	add_child(part)

func _build() -> void:
	var dark_metal := _mat(Color("2b3d51"))
	var post := CylinderMesh.new()
	post.top_radius = 0.09
	post.bottom_radius = 0.12
	post.height = 2.05
	post.radial_segments = 7
	_part(post, dark_metal, Vector3(0, 1.02, 0))
	var cap := CylinderMesh.new()
	cap.top_radius = 0.38
	cap.bottom_radius = 0.3
	cap.height = 0.18
	cap.radial_segments = 8
	_part(cap, dark_metal, Vector3(0, 2.0, 0))
	var glass := CylinderMesh.new()
	glass.top_radius = 0.25
	glass.bottom_radius = 0.25
	glass.height = 0.52
	glass.radial_segments = 8
	glass_material = _mat(Color("4f7186"), Color("8daeb8"), 0.15)
	_part(glass, glass_material, Vector3(0, 1.72, 0))
	beacon_light = OmniLight3D.new()
	beacon_light.position = Vector3(0, 1.7, 0)
	beacon_light.light_color = Color("9dc9df")
	beacon_light.light_energy = 0.0
	beacon_light.omni_range = 8.5
	add_child(beacon_light)
	build_prompt(2.8)
	embers = CPUParticles3D.new()
	embers.amount = 16
	embers.lifetime = 2.8
	embers.position.y = 1.6
	embers.direction = Vector3.UP
	embers.spread = 40
	embers.gravity = Vector3(0, 0.2, 0)
	embers.initial_velocity_min = 0.12
	embers.initial_velocity_max = 0.4
	embers.scale_amount_min = 0.025
	embers.scale_amount_max = 0.055
	var spark := SphereMesh.new()
	spark.radius = 1
	spark.height = 2
	spark.radial_segments = 4
	spark.rings = 3
	spark.material = _mat(Color("ffd580"), Color("ffd580"), 1)
	embers.mesh = spark
	embers.emitting = false
	add_child(embers)

func activate(announce := true) -> void:
	if is_lit:
		return
	is_lit = true
	available = false
	prompt_label.visible = false
	glass_material.albedo_color = Color("ffd580")
	glass_material.emission = Color("ffc66d")
	glass_material.emission_energy_multiplier = 2.4
	beacon_light.light_color = Color("ffd590")
	beacon_light.light_energy = 2.8
	embers.emitting = true
	if announce:
		lit.emit(self)
