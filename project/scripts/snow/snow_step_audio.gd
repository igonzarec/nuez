extends Node
## Pasos de nieve: sustituye el efecto genérico, respetando SFX y Master.
@export var enabled := true
@export var samples: Array[AudioStream] = [
	preload("res://audio/snow_steps/snow_step_06_mid.wav"),
]
@export_group("Variantes activas")
## Puedes desactivar una variante sin borrar su archivo ni alterar las demás.
@export var use_step_01_noisy := false
@export var use_step_02_noisy := false
@export var use_step_03_soft := false
@export var use_step_04_soft := false
@export var use_step_05_mid := false
@export var use_step_06_mid := true
@export_group("Mezcla")
## Ganancia relativa al archivo. Se combina con SFX y Master.
@export_range(-60.0, 6.0, 0.5, "suffix:dB") var volume_db := -24.0
## 2 reproduce en la mitad de tiempo; el tono se compensa por separado.
@export_range(0.5, 2.0, 0.05) var playback_speed := 1.0
## Tono final: 1 original, 0.8 grave, 1.2 agudo, independiente de Playback Speed.
@export_range(0.5, 2.0, 0.05) var pitch := 1.0
@export_group("Frecuencia de pasos")
## Contactos por distancia: 2 doble, 0.5 mitad. Acompasa huellas y partículas,
## sin cambiar la velocidad del jugador ni la animación de las patas.
@export_range(0.25, 2.0, 0.05) var step_frequency := 2.0
## Separación mínima en segundos entre sonidos al caminar. Mayor valor reduce repeticiones.
@export_range(0.05, 1.0, 0.01) var walk_min_interval := 0.15
## Separación mínima al mantener Correr. No sustituye la muestra que elegiste.
@export_range(0.05, 1.0, 0.01) var run_min_interval := 0.13
@export_enum("Aleatorio sin repetición inmediata", "Secuencial") var selection_mode := 0
@export_group("Aterrizaje")
## Sonido al tocar suelo después de saltar o caer. Vacío recupera el sonido habitual.
@export var landing_sample: AudioStream = preload("res://audio/snow_steps/snow_step_06_mid.wav")
## Ganancia adicional respecto a Volume Db, sólo para el aterrizaje.
@export_range(-24.0, 12.0, 0.5) var landing_gain_db := 0.0
## Reproduce dos contactos de Snowstep 06, uno por cada pie.
@export var landing_double_step := true
## Separación entre ambos pies. 0 suena exactamente a la vez; 0,04–0,08 es más natural.
@export_range(0.0, 0.25, 0.01, "suffix:s") var landing_second_delay := 0.055
## Evita una pisada adicional justo después del sonido de aterrizaje.
@export_range(0.0, 0.6, 0.01) var landing_step_delay := 0.25
@export_group("Frecuencias del sonido")
@export var low_pass_enabled := false
## Menos Hz elimina más agudos: 2000 apagado; 8000 crujiente; 20000 casi completo.
@export_range(200.0, 20000.0, 100.0, "suffix:Hz") var cutoff_hz := 12000.0
var _actor: ExplorerPlayer
var _audio: TrailAudio
var _base_frequency := 1.0
var _on_snow := false
var _voices: Array[AudioStreamPlayer] = []
var _voice_index := 0
var _last_sample := -1
var _bus_name: StringName
var _pitch_effect: AudioEffectPitchShift
var _filter: AudioEffectLowPassFilter
var _settings_hash := 0
var _step_cooldown := 0.0

func bind(actor: ExplorerPlayer, audio: TrailAudio) -> void:
	_actor = actor
	_audio = audio
	_base_frequency = actor.step_frequency_multiplier
	audio.step_handler = Callable(self, "play_step")
	audio.land_handler = Callable(self, "play_landing")
	_bus_name = StringName("SnowSteps_%s" % get_instance_id())
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, _bus_name)
	AudioServer.set_bus_send(index, "SFX")
	_pitch_effect = AudioEffectPitchShift.new()
	_pitch_effect.fft_size = AudioEffectPitchShift.FFT_SIZE_1024
	AudioServer.add_bus_effect(index, _pitch_effect)
	_filter = AudioEffectLowPassFilter.new()
	_filter.db = AudioEffectFilter.FILTER_12DB
	_filter.resonance = 0.0
	AudioServer.add_bus_effect(index, _filter)
	for i in 8:
		var voice := AudioStreamPlayer.new()
		voice.bus = _bus_name
		add_child(voice)
		_voices.append(voice)
	_refresh_mix()

func set_surface(coverage: float) -> void:
	_on_snow = coverage >= 0.5
	if is_instance_valid(_actor):
		_actor.step_frequency_multiplier = _base_frequency * (step_frequency if _on_snow and enabled and not _enabled_indices().is_empty() else 1.0)

func _process(_delta: float) -> void:
	_step_cooldown = maxf(0.0, _step_cooldown - _delta)
	if not _pitch_effect:
		return
	var settings := hash([volume_db, playback_speed, pitch, low_pass_enabled, cutoff_hz])
	if settings != _settings_hash:
		_settings_hash = settings
		_refresh_mix()

func _refresh_mix() -> void:
	var index := AudioServer.get_bus_index(_bus_name)
	if index < 0:
		return
	# Stream speed shifts pitch too; correct it to the requested final tone.
	_pitch_effect.pitch_scale = pitch / maxf(0.01, playback_speed)
	AudioServer.set_bus_effect_enabled(index, 0, not is_equal_approx(_pitch_effect.pitch_scale, 1.0))
	_filter.cutoff_hz = cutoff_hz
	AudioServer.set_bus_effect_enabled(index, 1, low_pass_enabled)
	for voice in _voices:
		voice.pitch_scale = playback_speed
		voice.volume_db = volume_db

func play_step() -> bool:
	var available := _enabled_indices()
	if not enabled or not _on_snow or available.is_empty() or _voices.is_empty():
		return false
	if _step_cooldown > 0.0:
		return true
	_step_cooldown = run_min_interval if Input.is_action_pressed("sprint") else walk_min_interval
	var index := available[0]
	if selection_mode == 0:
		var choices := available.duplicate()
		if choices.size() > 1:
			choices.erase(_last_sample)
		index = choices[randi_range(0, choices.size() - 1)]
	else:
		var start := available.find(_last_sample)
		index = available[(start + 1) % available.size()]
	_last_sample = index
	var voice := _voices[_voice_index]
	_voice_index = (_voice_index + 1) % _voices.size()
	voice.stream = samples[index]
	voice.volume_db = volume_db
	voice.play()
	return true

func _play_contact(stream: AudioStream, gain: float) -> bool:
	if not enabled or not stream or _voices.is_empty(): return false
	var voice := _voices[_voice_index]
	_voice_index = (_voice_index + 1) % _voices.size()
	voice.stream = stream
	voice.volume_db = volume_db + gain
	voice.play()
	return true

func play_landing() -> bool:
	_step_cooldown = landing_step_delay
	var played := _play_contact(landing_sample, landing_gain_db)
	if played and landing_double_step:
		get_tree().create_timer(landing_second_delay).timeout.connect(_play_second_landing_step, CONNECT_ONE_SHOT)
	return played

func _play_second_landing_step() -> void:
	_play_contact(landing_sample, landing_gain_db)

func _enabled_indices() -> Array[int]:
	var toggles := [
		use_step_01_noisy, use_step_02_noisy, use_step_03_soft,
		use_step_04_soft, use_step_05_mid, use_step_06_mid,
	]
	var result: Array[int] = []
	var filenames := ["snow_step_01_noisy.wav", "snow_step_02_noisy.wav", "snow_step_03_soft.wav", "snow_step_04_soft.wav", "snow_step_05_mid.wav", "snow_step_06_mid.wav"]
	for index in samples.size():
		if not samples[index]: continue
		# El interruptor sigue al archivo aunque Samples se reordene o tenga sólo uno.
		var toggle_index := filenames.find(samples[index].resource_path.get_file())
		if toggle_index < 0: toggle_index = index
		if toggle_index >= toggles.size() or toggles[toggle_index]:
			result.append(index)
	return result

func _exit_tree() -> void:
	if is_instance_valid(_actor):
		_actor.step_frequency_multiplier = _base_frequency
	if is_instance_valid(_audio) and _audio.step_handler == Callable(self, "play_step"):
		_audio.step_handler = Callable()
	if is_instance_valid(_audio) and _audio.land_handler == Callable(self, "play_landing"):
		_audio.land_handler = Callable()
	for voice in _voices:
		voice.stop()
		voice.bus = "SFX"
	var index := AudioServer.get_bus_index(_bus_name)
	if index > 0:
		AudioServer.remove_bus(index)
