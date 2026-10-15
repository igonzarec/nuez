class_name MovementDust
extends Node3D
## Una sola fuente de partículas 3D redondeadas para carrera con Sprint.

var rig: SquirrelRig
var actor: ExplorerPlayer
const PARTICLE_CAPACITY := 288
var particles: GPUParticles3D
var motion: ParticleProcessMaterial
var dust_material: ShaderMaterial
var fade_ramp: Gradient

func setup(owner_rig: SquirrelRig, owner_actor: ExplorerPlayer) -> void:
	rig = owner_rig
	actor = owner_actor
	particles = GPUParticles3D.new()
	particles.amount = PARTICLE_CAPACITY
	particles.name = "DustSource"
	particles.local_coords = false
	motion = ParticleProcessMaterial.new()
	motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	motion.direction = Vector3.BACK
	motion.gravity = Vector3(0.0, 0.15, 0.0)
	# Orientación aleatoria al nacer; sin velocidad angular durante la vida.
	motion.particle_flag_rotate_y = true
	motion.angle_min = 0.0
	motion.angle_max = 360.0
	particles.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	motion.damping_min = 1.2
	motion.damping_max = 1.8
	particles.visibility_aabb = AABB(Vector3(-5.0, -3.0, -5.0), Vector3(10.0, 6.0, 10.0))
	particles.draw_pass_1 = _make_round_mesh()
	fade_ramp = _make_fade_ramp()
	var fade_texture := GradientTexture1D.new()
	fade_texture.gradient = fade_ramp
	motion.color_ramp = fade_texture
	particles.process_material = motion
	particles.emitting = false
	add_child(particles)

func _process(_delta: float) -> void:
	if actor == null or particles == null:
		return
	var running := actor.is_on_floor() and actor.horizontal_speed >= actor.movement_dust_run_speed and Input.is_action_pressed("sprint") and not actor.is_sliding and not actor.is_climbing and not actor.is_gliding
	var active := actor.movement_dust_enabled and running
	# Una fuente plana en X/Y: la dispersión no añade separación en Z.
	var width := maxf(0.0, actor.movement_dust_scatter_width)
	var height := maxf(0.0, actor.movement_dust_scatter_height)
	particles.position = actor.movement_dust_source_offset + Vector3.UP * height * 0.5
	motion.emission_box_extents = Vector3(width * 0.5, height * 0.5, 0.0)
	motion.gravity = Vector3.UP * actor.movement_dust_rise_acceleration
	motion.spread = actor.movement_dust_spread_degrees
	var desired_lifetime := maxf(0.1, actor.movement_dust_lifetime)
	if not is_equal_approx(particles.lifetime, desired_lifetime):
		particles.lifetime = desired_lifetime
	motion.initial_velocity_min = actor.movement_dust_drift_speed * 0.45
	motion.initial_velocity_max = actor.movement_dust_drift_speed
	motion.scale_min = 1.0
	motion.scale_max = 1.0
	motion.color = Color(1.0, 1.0, 1.0, actor.movement_dust_opacity)
	motion.lifetime_randomness = actor.movement_dust_lifetime_randomness
	dust_material.set_shader_parameter("shape_variation", actor.movement_dust_shape_variation)
	dust_material.set_shader_parameter("initial_size", Vector2(minf(actor.movement_dust_size_min, actor.movement_dust_size_max), maxf(actor.movement_dust_size_min, actor.movement_dust_size_max)))
	dust_material.set_shader_parameter("final_size", Vector2(minf(actor.movement_dust_final_size_min, actor.movement_dust_final_size_max), maxf(actor.movement_dust_final_size_min, actor.movement_dust_final_size_max)))
	dust_material.set_shader_parameter("light_color", actor.movement_dust_light_color)
	dust_material.set_shader_parameter("shadow_color", actor.movement_dust_shadow_color)
	dust_material.set_shader_parameter("shadow_strength", actor.movement_dust_shadow_strength)
	dust_material.set_shader_parameter("shadow_threshold", actor.movement_dust_shadow_threshold)
	dust_material.set_shader_parameter("shadow_softness", actor.movement_dust_shadow_softness)
	var light_direction := actor.movement_dust_light_direction.normalized()
	if light_direction.is_zero_approx():
		light_direction = Vector3.UP
	dust_material.set_shader_parameter("light_direction", light_direction)
	if not is_equal_approx(fade_ramp.get_offset(1), actor.movement_dust_fade_start):
		fade_ramp.set_offset(1, actor.movement_dust_fade_start)
	# amount reinicia la simulación. amount_ratio cambia sólo futuras emisiones.
	particles.amount_ratio = clampf(float(actor.movement_dust_density) / PARTICLE_CAPACITY, 0.0, 1.0)
	particles.emitting = active

func _make_round_mesh() -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 16
	mesh.rings = 8
	dust_material = ShaderMaterial.new()
	dust_material.shader = preload("res://shaders/movement_dust.gdshader")
	mesh.material = dust_material
	return mesh

func _make_fade_ramp() -> Gradient:
	var gradient := Gradient.new()
	gradient.set_offset(0, 0.0)
	gradient.set_color(0, Color.WHITE)
	gradient.set_offset(1, 1.0)
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	gradient.add_point(actor.movement_dust_fade_start, Color.WHITE)
	return gradient
