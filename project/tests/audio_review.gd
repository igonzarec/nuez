extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var audio := TrailAudio.new()
	root.add_child(audio)
	var settings := {"master": 0.8, "music": 1.0, "sfx": 1.0}
	audio.apply(settings)
	assert(audio.music.volume_db == -13 and audio.wind.volume_db == -23)
	for kind: String in audio.sounds:
		audio.play(kind)
		# TrailAudio now allocates voices by availability/priority, not next_voice.
		var voice: AudioStreamPlayer = null
		for candidate: AudioStreamPlayer in audio.voices:
			if candidate.stream == audio.sounds[kind]:
				voice = candidate
				break
		assert(voice != null)
		var expected_gain := -5.0
		if kind in ["step", "land"]:
			expected_gain = audio.get_step_volume_db() + audio.step_sample_gain_db
			if kind == "step" and Input.is_action_pressed("sprint"):
				expected_gain += audio.running_step_gain_db
		elif kind == "climb":
			expected_gain = audio.climb_volume_db
		elif kind == "camera_recenter":
			expected_gain = -2.0
		assert(is_equal_approx(voice.volume_db, expected_gain))
		var stream: AudioStreamWAV = audio.sounds[kind]
		var peak := 0.0
		for i in stream.data.size() / 2:
			peak = maxf(peak, absf(float(stream.data.decode_s16(i * 2))) / 32768.0)
		var output_peak := peak * db_to_linear(voice.volume_db) * 0.8
		assert(output_peak < 1.0)
		print("AUDIO ", kind, " individual peak dBFS=", linear_to_db(output_peak))
	var master := AudioServer.get_bus_index("Master")
	assert(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(master)), 0.8))
	var count := AudioServer.get_bus_effect_count(master)
	var other := TrailAudio.new()
	root.add_child(other)
	assert(AudioServer.get_bus_effect_count(master) == count)
	var limiter := AudioServer.get_bus_effect(master, count - 1) as AudioEffectHardLimiter
	assert(limiter != null and limiter.ceiling_db == -0.5 and limiter.pre_gain_db == 0)
	audio.apply({"master": 0.0, "music": 0.0, "sfx": 0.0})
	for bus in ["Master", "Music", "SFX"]:
		assert(AudioServer.is_bus_mute(AudioServer.get_bus_index(bus)))
	print("AUDIO REVIEW PASS: current cue gains, wind unchanged, saved sliders respected, mute and single safety limiter verified")
	audio.queue_free()
	other.queue_free()
	await process_frame
	quit()
