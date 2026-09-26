class_name TrailResident
extends Node3D

@export var coat_color := Color("b98256")
@export var rabbit := false
@export var motion_offset := 0.0
var visual: Node3D
var head: Node3D
var feet: Array[Node3D] = []
var hands: Array[Node3D] = []
var eyes: Array[MeshInstance3D] = []
var phase := 0.0
var gait := 0.0
var walk_blend := 0.0
var last_position := Vector3.ZERO

func _ready() -> void:
	visual = Node3D.new()
	add_child(visual)
	head = Node3D.new()
	head.position.y = 1.35
	visual.add_child(head)
	TrailLevel.part(visual, TrailLevel.sphere(0.40, 0.90), coat_color, Vector3(0, 0.72, 0))
	TrailLevel.part(head, TrailLevel.sphere(0.39, 0.76), Color("cdb58d"), Vector3.ZERO)
	TrailLevel.part(head, TrailLevel.sphere(0.18, 0.22), Color("e3d0a0"), Vector3(0, -0.11, 0.33))
	TrailLevel.part(head, TrailLevel.sphere(0.045, 0.06), Color("393b36"), Vector3(0, -0.04, 0.45))
	for side in [-1, 1]:
		TrailLevel.part(head, TrailLevel.sphere(0.12, 0.68 if rabbit else 0.28), Color("cdb58d"), Vector3(side * 0.24, 0.42, 0))
		eyes.append(TrailLevel.part(head, TrailLevel.sphere(0.05, 0.12), Color("303d40"), Vector3(side * 0.15, 0.04, 0.345)))
		var hip := Node3D.new()
		hip.position = Vector3(side * 0.20, 0.38, 0)
		visual.add_child(hip)
		TrailLevel.part(hip, TrailLevel.cylinder(0.1, 0.13, 0.3), Color("cdb58d"), Vector3(0, -0.12, 0))
		TrailLevel.part(hip, TrailLevel.sphere(0.15, 0.23), Color("455450"), Vector3(0, -0.25, 0.07))
		feet.append(hip)
		var shoulder := Node3D.new()
		shoulder.position = Vector3(side * 0.36, 0.97, 0)
		visual.add_child(shoulder)
		TrailLevel.part(shoulder, TrailLevel.cylinder(0.1, 0.14, 0.36), coat_color, Vector3(0, -0.15, 0))
		TrailLevel.part(shoulder, TrailLevel.sphere(0.10, 0.17), Color("cdb58d"), Vector3(0, -0.34, 0))
		hands.append(shoulder)
	TrailLevel.part(visual, TrailLevel.cylinder(0.27, 0.25, 0.11), Color("d5b25b"), Vector3(0, 1.1, 0))
	phase = motion_offset
	last_position = global_position

func _process(delta: float) -> void:
	phase += delta
	var travel := global_position.distance_to(last_position)
	var speed := travel / maxf(delta, 0.001)
	last_position = global_position
	walk_blend = lerpf(walk_blend, clampf(speed / 1.8, 0, 1), 1.0 - exp(-10.0 * delta))
	gait += minf(travel, 0.2) * 5.0
	visual.position.y = sin(phase * 1.8) * 0.016 + absf(sin(gait)) * 0.045 * walk_blend
	head.rotation.y = lerp_angle(head.rotation.y, sin(phase * 0.6) * 0.18 * (1.0 - walk_blend), 1.0 - exp(-3.0 * delta))
	head.rotation.z = sin(phase * 1.1) * 0.025
	var blink := 0.1 if fmod(phase, 4.9) > 4.77 else 1.0
	for eye in eyes:
		eye.scale.y = lerpf(eye.scale.y, blink, minf(1, delta * 40))
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		feet[i].rotation.x = sin(gait) * side * 0.6 * walk_blend
		hands[i].rotation.x = -sin(gait) * side * 0.5 * walk_blend + sin(phase * 2) * 0.035
		hands[i].rotation.z = side * (0.06 + sin(phase * 1.3) * 0.025)
