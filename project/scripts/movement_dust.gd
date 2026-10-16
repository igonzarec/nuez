class_name MovementDust
extends Node3D
## Una fuente de partículas 3D redondeadas para Sprint y aterrizaje de planeo.

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
	var sliding_glide := actor.is_glide_landing
	var running := actor.is_on_floor() and actor.horizontal_speed >= actor.movement_dust_run_speed and Input.is_action_pressed("sprint") and not actor.is_sliding and not actor.is_climbing and not actor.is_gliding and not sliding_glide
	var glide_dust := sliding_glide and actor.glide_landing_dust_enabled and actor.is_on_floor() and actor.horizontal_speed > 0.1
	var slope_dust := actor.is_sliding and actor.slide_dust_enabled and not actor.is_climbing and not actor.is_gliding and actor.slide_velocity.length() > actor.slide_dust_min_speed
	var active := actor.movement_dust_enabled and (running or glide_dust or slope_dust)
	# Carrera conserva la fuente X/Y; al aterrizar planeando también ocupa Z.
	var width := maxf(0.0, actor.glide_landing_dust_width if sliding_glide else actor.movement_dust_scatter_width)
	var height := maxf(0.0, actor.glide_landing_dust_height if sliding_glide else actor.movement_dust_scatter_height)
	var depth := maxf(0.0, actor.glide_landing_dust_depth) if sliding_glide else 0.0
	var source_offset := actor.glide_landing_dust_source_offset if sliding_glide else actor.movement_dust_source_offset
	var size_multiplier := actor.glide_landing_dust_size_multiplier if sliding_glide else 1.0
	particles.position = source_offset + Vector3.UP * height * 0.5
	particles.basis = Basis.IDENTITY
	var surface_follow := active and actor.movement_dust_surface_follow_enabled
	if surface_follow:
		_place_on_surface(source_offset, height)
	motion.emission_box_extents = Vector3(width * 0.5, height * 0.5, depth * 0.5)
	motion.gravity = Vector3.UP * actor.movement_dust_rise_acceleration
	motion.spread = actor.movement_dust_spread_degrees
	var desired_lifetime := maxf(0.1, actor.movement_dust_lifetime)
	if not is_equal_approx(particles.lifetime, desired_lifetime):
		particles.lifetime = desired_lifetime
	var drift := Vector3(0.0, actor.movement_dust_surface_lift_speed if surface_follow else 0.0, actor.movement_dust_drift_speed)
	motion.direction = drift.normalized() if not drift.is_zero_approx() else Vector3.BACK
	motion.initial_velocity_min = drift.length() * 0.45
	motion.initial_velocity_max = drift.length()
	motion.scale_min = 1.0
	motion.scale_max = 1.0
	motion.color = Color(1.0, 1.0, 1.0, actor.movement_dust_opacity)
	motion.lifetime_randomness = actor.movement_dust_lifetime_randomness
	dust_material.set_shader_parameter("shape_variation", actor.movement_dust_shape_variation)
	dust_material.set_shader_parameter("initial_size", Vector2(minf(actor.movement_dust_size_min, actor.movement_dust_size_max), maxf(actor.movement_dust_size_min, actor.movement_dust_size_max)) * size_multiplier)
	dust_material.set_shader_parameter("final_size", Vector2(minf(actor.movement_dust_final_size_min, actor.movement_dust_final_size_max), maxf(actor.movement_dust_final_size_min, actor.movement_dust_final_size_max)) * size_multiplier)
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
	var density := actor.glide_landing_dust_density if sliding_glide else actor.movement_dust_density
	particles.amount_ratio = clampf(float(density) / PARTICLE_CAPACITY, 0.0, 1.0)
	particles.emitting = active

func _surface_basis(normal: Vector3) -> Basis:
	# La estela de resbalamiento queda detrás del desplazamiento, aunque
	# el personaje esté mirando cuesta arriba o en otra dirección.
	var back_direction := -actor.slide_velocity if actor.is_sliding and not actor.slide_velocity.is_zero_approx() else rig.global_basis.z
	var back := back_direction.slide(normal).normalized()
	if back.is_zero_approx():
		back = Vector3.BACK.slide(normal).normalized()
	if back.is_zero_approx():
		back = Vector3.RIGHT.slide(normal).normalized()
	return Basis(normal.cross(back).normalized(), normal, back).orthonormalized()

func _place_on_surface(offset: Vector3, height: float) -> void:
	var normal := actor.slide_surface_normal.normalized() if actor.is_sliding else actor.get_floor_normal().normalized()
	if normal.is_zero_approx():
		normal = Vector3.UP
	var surface_basis := _surface_basis(normal)
	# X/Z se miden sobre el plano, no sobre una caja horizontal que penetra
	# la ladera detrás del personaje al descender.
	var point := actor.global_position + surface_basis * Vector3(offset.x, 0.0, offset.z)
	var reach := actor.movement_dust_surface_probe_distance
	var query := PhysicsRayQueryParameters3D.create(point + normal * reach, point - normal * reach, actor.collision_mask, [actor.get_rid()])
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
	var minimum_up := 0.0 if actor.is_sliding else cos(actor.floor_max_angle)
	if not hit.is_empty() and Vector3(hit.normal).y >= minimum_up:
		point = hit.position
		normal = Vector3(hit.normal).normalized()
		surface_basis = _surface_basis(normal)
	particles.global_transform = Transform3D(surface_basis, point + normal * (offset.y + height * 0.5 + actor.movement_dust_surface_clearance))

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
