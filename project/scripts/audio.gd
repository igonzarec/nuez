class_name TrailAudio
extends Node

var voices: Array[AudioStreamPlayer] = []
var sounds: Dictionary = {}
var next_voice := 0
var music: AudioStreamPlayer
var wind: AudioStreamPlayer
var ambience_started := false
## Surface playback callback: true means the footstep has already been handled.
var step_handler: Callable
var jump_handler: Callable
var land_handler: Callable
var deploy: AudioStreamPlayer
var gliding: AudioStreamPlayer
var glide_fade: Tween
var glide_active := false
var deploy_left := -1.0
var glide_fade_in := 0.3
var glide_fade_out := 0.4
var deploy_delay := 0.0
var glide_volume := 1.0
var glide_random_start := true
var glide_layers: Array[AudioStreamPlayer] = []
var glide_layer := 0
var glide_mix := 1.0
var glide_crossfade := 0.6
var glide_crossfade_duration := 0.6
var glide_envelope := 0.0:
	set(value):
		glide_envelope = value
		_update_glide_volumes()
## Volumen del raspado de agarres. -14 dB es suave; -8 dB destaca sobre el viento.
@export_range(-40.0, 0.0, 1.0) var climb_volume_db := -12.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Leave saved slider levels intact; catch rare overlapping SFX peaks only.
	var master := AudioServer.get_bus_index("Master")
	var has_limiter := false
	for index in AudioServer.get_bus_effect_count(master):
		if AudioServer.get_bus_effect(master, index) is AudioEffectHardLimiter:
			has_limiter = true
	if not has_limiter:
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db = -0.5
		AudioServer.add_bus_effect(master, limiter)
	for bus: String in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	for i in 8:
		var voice := AudioStreamPlayer.new()
		voice.bus = "SFX"
		add_child(voice)
		voices.append(voice)
	for kind: String in ["jump", "land", "step", "climb", "collect", "ignite", "ui", "back", "deny", "complete"]:
		sounds[kind] = _tone(kind)
	# Sonido dedicado para R2/C; no reutiliza el clic genérico de los menús.
	sounds["camera_recenter"] = preload("res://audio/camera_recenter.wav")
	music = _loop("Music", _ambience(false), -13)
	wind = _loop("SFX", _ambience(true), -23)
	deploy = _loop("SFX", preload("res://audio/deploy2.wav"), 0.0)
	deploy.process_mode = Node.PROCESS_MODE_PAUSABLE
	var glide_stream := preload("res://audio/WhistlingWind.wav").duplicate() as AudioStreamWAV
	# El bucle se hace entre dos voces; evita el salto brusco de final a inicio.
	glide_stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	gliding = _loop("SFX", glide_stream, 0.0)
	glide_layers = [gliding, _loop("SFX", glide_stream, 0.0)]
	for layer in glide_layers:
		layer.process_mode = Node.PROCESS_MODE_PAUSABLE
		layer.volume_linear = 0.0

func bind_player(actor: ExplorerPlayer) -> void:
	var feedback_callback := Callable(self, "play")
	if not actor.feedback.is_connected(feedback_callback):
		actor.feedback.connect(feedback_callback)
	bind_gliding(actor)

func bind_camera(camera_rig: TrailCamera) -> void:
	var recenter_callback := Callable(self, "play").bind("camera_recenter")
	if not camera_rig.recenter_requested.is_connected(recenter_callback):
		camera_rig.recenter_requested.connect(recenter_callback)

func bind_gliding(actor: ExplorerPlayer) -> void:
	set_gliding(false)
	glide_fade_in = actor.gliding_fade_in
	glide_fade_out = actor.gliding_fade_out
	deploy_delay = actor.deploy_delay
	deploy.volume_linear = actor.deploy_volume
	deploy.pitch_scale = actor.deploy_pitch
	glide_volume = actor.gliding_volume
	for layer in glide_layers:
		layer.pitch_scale = actor.gliding_pitch
	glide_random_start = actor.gliding_random_start
	glide_crossfade = minf(actor.gliding_loop_crossfade, gliding.stream.get_length() / actor.gliding_pitch * 0.25)
	var gliding_callback := Callable(self, "set_gliding")
	if not actor.gliding_changed.is_connected(gliding_callback):
		actor.gliding_changed.connect(gliding_callback)
	var exiting_callback := Callable(self, "set_gliding").bind(false)
	if not actor.tree_exiting.is_connected(exiting_callback):
		actor.tree_exiting.connect(exiting_callback)

func _process(delta: float) -> void:
	# TrailAudio sigue activo en menús; el retraso debe usar tiempo de juego.
	if get_tree().paused:
		return
	if deploy_left >= 0.0:
		deploy_left -= delta
		if deploy_left <= 0.0:
			deploy_left = -1.0
			if glide_active and DisplayServer.get_name() != "headless":
				deploy.play()
	_tick_glide_loop(delta)

func _glide_start_position() -> float:
	# Reserva dos transiciones y un margen para no escoger un fragmento demasiado corto.
	var reserve := (glide_crossfade * 2.0 + 0.2) * gliding.pitch_scale
	return randf() * maxf(0.0, gliding.stream.get_length() - reserve) if glide_random_start else 0.0

func _update_glide_volumes() -> void:
	if glide_layers.is_empty():
		return
	# Curva de potencia constante para sostener el nivel durante el solapamiento.
	glide_layers[glide_layer].volume_linear = glide_envelope * sin(glide_mix * PI * 0.5)
	glide_layers[1 - glide_layer].volume_linear = glide_envelope * cos(glide_mix * PI * 0.5)

func _stop_glide_layers() -> void:
	for layer in glide_layers:
		layer.stop()

func _tick_glide_loop(delta: float) -> void:
	if DisplayServer.get_name() == "headless" or glide_layers.is_empty():
		return
	if glide_mix < 1.0:
		glide_mix = minf(1.0, glide_mix + delta / maxf(0.001, glide_crossfade_duration))
		_update_glide_volumes()
		if glide_mix >= 1.0:
			glide_layers[1 - glide_layer].stop()
	if not glide_active or glide_mix < 1.0:
		return
	var current := glide_layers[glide_layer]
	var remaining := (current.stream.get_length() - current.get_playback_position()) / current.pitch_scale
	if not current.playing:
		remaining = 0.0
	if remaining <= glide_crossfade + 0.1:
		glide_crossfade_duration = minf(glide_crossfade, maxf(0.001, remaining - 0.025))
		glide_layer = 1 - glide_layer
		glide_mix = 0.0
		_update_glide_volumes()
		glide_layers[glide_layer].play(_glide_start_position())

func set_gliding(active: bool) -> void:
	if glide_active == active:
		return
	glide_active = active
	deploy_left = -1.0
	if glide_fade:
		glide_fade.kill()
	if active:
		if deploy_delay <= 0.0:
			if DisplayServer.get_name() != "headless":
				deploy.play()
		else:
			deploy_left = deploy_delay
		# Al volver a desplegar durante el fade out, parte de silencio otra vez.
		_stop_glide_layers()
		glide_layer = 0
		glide_mix = 1.0
		glide_envelope = 0.0
		if DisplayServer.get_name() != "headless":
			gliding.play(_glide_start_position())
	var duration := glide_fade_in if active else glide_fade_out
	var target_volume := glide_volume if active else 0.0
	if duration <= 0.0:
		glide_envelope = target_volume
		if not active:
			_stop_glide_layers()
		return
	glide_fade = create_tween().bind_node(gliding).set_pause_mode(Tween.TWEEN_PAUSE_BOUND)
	glide_fade.tween_property(self, "glide_envelope", target_volume, duration)
	if not active:
		glide_fade.tween_callback(_stop_glide_layers)

func _loop(bus: String, stream: AudioStreamWAV, gain: float) -> AudioStreamPlayer:
	var voice := AudioStreamPlayer.new()
	voice.bus = bus
	voice.stream = stream
	voice.volume_db = gain
	add_child(voice)
	return voice

func play(kind: String) -> void:
	if kind == "jump" and jump_handler.is_valid() and jump_handler.call():
		return
	if kind == "land" and land_handler.is_valid() and land_handler.call():
		return
	if kind == "step" and step_handler.is_valid() and step_handler.call():
		return
	if not sounds.has(kind):
		return
	var voice := voices[next_voice]
	next_voice = (next_voice + 1) % voices.size()
	voice.stream = sounds[kind]
	voice.volume_db = -14 if kind == "step" else -5
	# El swish de recentrado debe distinguirse del ambiente y de la interfaz.
	if kind == "camera_recenter":
		voice.volume_db = -2
	if kind == "climb":
		voice.volume_db = climb_volume_db
	if DisplayServer.get_name() != "headless":
		voice.play()

func apply(settings: Dictionary) -> void:
	climb_volume_db = linear_to_db(maxf(0.00001, float(settings.get("climb_sfx", 0.5)))) - 6.0
	for pair: Array in [["Master", "master"], ["Music", "music"], ["SFX", "sfx"]]:
		var index := AudioServer.get_bus_index(pair[0])
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(0.0001, settings[pair[1]])))
		AudioServer.set_bus_mute(index, settings[pair[1]] <= 0.001)
	# Start once, after saved volumes/mutes have been applied. In particular, never
	# play a burst at default bus volume while generating the other audio streams.
	if not ambience_started and DisplayServer.get_name() != "headless":
		music.play()
		wind.play()
		ambience_started = true

func _exit_tree() -> void:
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	sounds.clear()

func _wav(samples: PackedByteArray, looping := false) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = samples
	if looping:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = samples.size() / 2
	return stream

func _tone(kind: String) -> AudioStreamWAV:
	var duration := 0.22
	if kind == "step": duration = 0.10
	if kind == "land": duration = 0.16
	if kind == "climb": duration = 0.19
	if kind in ["ignite", "complete"]:
		duration = 1.4
	var count := int(22050 * duration)
	var samples := PackedByteArray()
	samples.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var phase := 0.0
	var soft_noise := 0.0
	for i in count:
		var t := float(i) / 22050
		var u := t / duration
		var frequency := 660.0
		match kind:
			"jump": frequency = lerpf(260, 530, u)
			"land", "step": frequency = 110
			"collect": frequency = 880.0 if u < 0.42 else 1320.0
			"ignite", "complete": frequency = [261.63, 329.63, 392.0, 523.25][mini(3, int(u * 4))]
			"back", "deny": frequency = lerpf(390, 220, u)
		phase += TAU * frequency / 22050
		var value := sin(phase) * 0.45 + sin(phase * 2) * 0.1
		if kind in ["land", "step"]:
			soft_noise = lerpf(soft_noise, rng.randf_range(-1, 1), 0.28)
			value = soft_noise * 0.65
		if kind == "climb":
			# Raspado granular con dos pequeños contactos, distinto del paso sordo.
			var noise := rng.randf_range(-1.0, 1.0)
			soft_noise = lerpf(soft_noise, noise, 0.12)
			value = (noise - soft_noise) * (0.16 + 0.3 * pow(absf(sin(u * PI * 2.0)), 6))
		value *= minf(1, t * 100) * pow(1.0 - u, 2)
		samples.encode_s16(i * 2, int(value * 26000))
	return _wav(samples)

func _ambience(is_wind: bool) -> AudioStreamWAV:
	# Sparse, gently decaying notes with silence between phrases. The old sustained
	# four-sine bass chord sounded like an electrical hum, especially on headphones.
	var count := 22050 * 12
	var samples := PackedByteArray()
	samples.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 107
	var low := 0.0
	for i in count:
		var t := float(i) / 22050
		var value := 0.0
		if is_wind:
			low = lerpf(low, rng.randf_range(-1, 1), 0.02)
			value = low * 2 * sin(PI * t / 12) * sin(PI * t / 12)
		else:
			var note_time := fmod(t, 3.0)
			var frequency: float = [523.25, 659.25, 783.99, 587.33][mini(3, int(t / 3.0))]
			if note_time < 1.8:
				var envelope := smoothstep(0, 0.06, note_time) * exp(-note_time * 2.8) * (1.0 - smoothstep(1.4, 1.8, note_time))
				value = (sin(TAU * frequency * note_time) * 0.25 + sin(TAU * frequency * 2 * note_time) * 0.035) * envelope
		samples.encode_s16(i * 2, int(clampf(value, -1, 1) * 26000))
	return _wav(samples, true)
