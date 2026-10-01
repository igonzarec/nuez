@tool
extends Node
const Bank = preload("res://ui/dialogue/animalese_bank.gd")
var profile: AnimaleseProfile
var voices: Array[AudioStreamPlayer] = []
var remaining: Array[float] = []
var gains: Array[float] = []
var next_voice := 0
var cooldown := 0.0
var bus_name := ""
var high_pass: AudioEffectHighPassFilter
var low_pass: AudioEffectLowPassFilter
var distortion: AudioEffectDistortion

func _ready() -> void:
	# Bus privado: nunca modifica Master ni el sonido de otros personajes.
	bus_name = "Animalese_%d" % get_instance_id()
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master")
	high_pass = AudioEffectHighPassFilter.new()
	low_pass = AudioEffectLowPassFilter.new()
	distortion = AudioEffectDistortion.new()
	distortion.mode = AudioEffectDistortion.MODE_ATAN
	AudioServer.add_bus_effect(index, high_pass)
	AudioServer.add_bus_effect(index, low_pass)
	AudioServer.add_bus_effect(index, distortion)
	for i in 2:
		var voice := AudioStreamPlayer.new()
		voice.bus = bus_name
		add_child(voice)
		voices.append(voice)
		remaining.append(0.0)
		gains.append(-10.0)

func speak(letter: String, pitch_multiplier := 1.0) -> void:
	if profile == null or cooldown > 0 or voices.is_empty():
		return
	var stream := Bank.get_letter(letter, profile.language)
	if stream == null:
		return
	cooldown = profile.sound_interval
	high_pass.cutoff_hz = maxf(20, profile.high_pass_hz)
	low_pass.cutoff_hz = profile.low_pass_hz
	distortion.drive = profile.distortion
	var bus_index := AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_effect_enabled(bus_index, 0, profile.high_pass_hz > 0)
	AudioServer.set_bus_effect_enabled(bus_index, 2, profile.distortion > 0)
	# Desvanecer la voz anterior, no cortarla abruptamente al entrar otra letra.
	for i in voices.size():
		remaining[i] = minf(remaining[i], 0.012)
	var index := next_voice
	next_voice = (next_voice + 1) % voices.size()
	var voice := voices[index]
	voice.stream = stream
	voice.pitch_scale = clampf(profile.pitch * pitch_multiplier * pow(2, randf_range(-profile.pitch_variation, profile.pitch_variation) / 12.0), 0.4, 4.0)
	gains[index] = profile.volume_db
	voice.volume_db = gains[index]
	remaining[index] = stream.get_length() / voice.pitch_scale
	if profile.max_duration > 0:
		remaining[index] = minf(remaining[index], profile.max_duration)
	voice.play()

func _process(delta: float) -> void:
	cooldown = maxf(0, cooldown - delta)
	for i in voices.size():
		remaining[i] = maxf(0, remaining[i] - delta)
		if remaining[i] <= 0:
			voices[i].stop()
		elif remaining[i] < 0.012:
			voices[i].volume_db = gains[i] + linear_to_db(maxf(0.001, remaining[i] / 0.012))

func stop() -> void:
	cooldown = 0
	for i in voices.size():
		remaining[i] = 0
		voices[i].stop()

func _exit_tree() -> void:
	stop()
	var index := AudioServer.get_bus_index(bus_name)
	if index > 0:
		AudioServer.remove_bus(index)
