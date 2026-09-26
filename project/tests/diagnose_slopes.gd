extends SceneTree
## Diagnostic only: does not modify player settings, terrain or normal save files.

var game: Node
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func frames(count: int) -> void:
	for i in count: await physics_frame
	await process_frame

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	game.start_game(false)
	await frames(30)
	print("AUDIO players=", game.audio.get_child_count(), " buses=", AudioServer.bus_count)
	for child in game.audio.get_children():
		if child is AudioStreamPlayer and child.stream:
			print("AUDIO stream bus=", child.bus, " gain=", child.volume_db, " seconds=", child.stream.get_length())
	var stream: AudioStreamWAV = game.audio.music.stream
	var quiet_samples := 0
	var clipped_samples := 0
	var count := stream.data.size() / 2
	for i in count:
		var sample := stream.data.decode_s16(i * 2)
		if sample == 0: quiet_samples += 1
		if absi(sample) >= 32767: clipped_samples += 1
	print("AUDIO music silence=", 100.0 * quiet_samples / count, "% clipped_samples=", clipped_samples)
	if quiet_samples < count * 0.35 or clipped_samples > 0:
		failures.append("Music should have quiet gaps and no clipping")
	if stream.data.decode_s16(0) != 0 or stream.data.decode_s16(stream.data.size() - 2) != 0:
		failures.append("Music loop should meet at silence")
	var steep_count := 0
	var maximum := 0.0
	var steepest := Vector3.ZERO
	for z in range(-34, 34, 2):
		for x in range(-34, 34, 2):
			var points := [TrailLevel.point(x, z), TrailLevel.point(x + 2, z), TrailLevel.point(x, z + 2), TrailLevel.point(x + 2, z + 2)]
			for triangle in [[0, 1, 2], [1, 3, 2]]:
				var normal: Vector3 = (points[triangle[2]] - points[triangle[0]]).cross(points[triangle[1]] - points[triangle[0]]).normalized()
				var angle := rad_to_deg(normal.angle_to(Vector3.UP))
				if angle > game.player.walkable_slope_degrees: steep_count += 1
				if angle > maximum:
					maximum = angle
					steepest = points[0]
	print("TERRAIN maximum_angle=", maximum, " over_48_degrees=", steep_count, " steepest_near=", steepest)
	# Ascend independently along many radial lines, recording transient slowdowns
	# on the ground mesh separately from actual trees, logs and perimeter walls.
	for route in 24:
		var angle := route * TAU / 24
		var start := Vector2(sin(angle), cos(angle)) * 25 + Vector2(0, -4)
		game.player.position = TrailLevel.point(start.x, start.y, 0.12)
		game.player.velocity = Vector3.ZERO
		game.player.reset_physics_interpolation()
		game.camera_rig.yaw = 0
		game.camera_rig.snap()
		await frames(30)
		var slow := 0
		var min_speed := 100.0
		var first_slow := Vector3.ZERO
		var details := ""
		var lost_floor := 0
		var worst_run := 0
		var current_run := 0
		for tick in 400:
			var offset: Vector3 = Vector3(0, 0, -4) - game.player.position
			offset.y = 0
			if offset.length() < 2.5: break
			var direction := offset.normalized()
			Input.action_press("move_right", maxf(0, direction.x))
			Input.action_press("move_left", maxf(0, -direction.x))
			Input.action_press("move_back", maxf(0, direction.z))
			Input.action_press("move_forward", maxf(0, -direction.z))
			await physics_frame
			if tick < 30: continue
			var speed: float = game.player.horizontal_speed
			min_speed = minf(min_speed, speed)
			if not game.player.is_on_floor(): lost_floor += 1
			if speed < 1.5:
				slow += 1
				current_run += 1
				worst_run = maxi(current_run, worst_run)
				if first_slow == Vector3.ZERO:
					first_slow = game.player.position
					for hit_index in game.player.get_slide_collision_count():
						var hit: KinematicCollision3D = game.player.get_slide_collision(hit_index)
						details += " normal=" + str(hit.get_normal()) + " collider=" + str(hit.get_collider().get_path())
			else: current_run = 0
		for action: String in ["move_right", "move_left", "move_back", "move_forward"]: Input.action_release(action)
		print("ASCENT ", route, " min_speed=", snappedf(min_speed, 0.01), " slow_frames=", slow, " longest=", worst_run, " airborne=", lost_floor, " first=", first_slow, details)
		# These three radial shortcuts intersect real tree/rock colliders; all other
		# lines reproduce the previously reported ground-triangle snagging.
		if route not in [6, 22, 23] and (slow > 0 or lost_floor > 0):
			failures.append("Ground-only ascent %d stalled or lost floor contact" % route)
	print("SLOPE/AUDIO SUMMARY: 24 ascents, 21 unobstructed ground lines; failures=", failures)
	game.queue_free()
	await frames(3)
	quit(0 if failures.is_empty() else 1)
