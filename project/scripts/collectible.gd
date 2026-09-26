class_name LightFragment
extends Area3D

signal collected(fragment: LightFragment)
@export var seed_id := ""
@export var rotation_speed := 1.6
@export var bob_height := 0.13
var bob_time := 0.0
var claimed := false
var visual: MeshInstance3D

func setup(world_position: Vector3) -> void:
	position = world_position
	_build()

func _build() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape3D.new()
	var collision := SphereShape3D.new()
	collision.radius = 0.45
	shape.shape = collision
	add_child(shape)
	var crystal := MeshInstance3D.new()
	visual = crystal
	var mesh := SphereMesh.new()
	mesh.radius = 0.23
	mesh.height = 0.64
	mesh.radial_segments = 6
	mesh.rings = 4
	crystal.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("ffe59a")
	material.emission_enabled = true
	material.emission = Color("efb65b")
	material.emission_energy_multiplier = 0.65
	crystal.material_override = material
	add_child(crystal)
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	bob_time += delta
	rotation.y += rotation_speed * delta
	visual.position.y = sin(bob_time * 2.4) * bob_height

func _on_body_entered(body: Node3D) -> void:
	if claimed or not body is ExplorerPlayer or not body.control_enabled:
		return
	claimed = true
	collected.emit(self)
	queue_free()
