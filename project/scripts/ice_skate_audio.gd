class_name IceSkateAudio
extends Node3D
## Sonidos de patinaje de un ExplorerPlayer (player o NPC): empujón por zancada,
## siseo continuo según la velocidad, frenada y aterrizaje sobre hielo.
## Colócalo como hijo del ExplorerPlayer. Los sonidos son posicionales (bus SFX).
## Ver docs/ice_skating.md.

@export_group("General")
## Activa todos los sonidos de patinaje de este personaje. En vivo.
@export var enabled := true
## Bus de audio de todos los reproductores. Se aplica al iniciar.
@export var bus: StringName = &"SFX"
## Distancia, en metros, a la que el volumen empieza a caer. Mayor hace que se oigan más lejos (útil para NPC). Se aplica al iniciar.
@export_range(1.0, 30.0, 0.5, "suffix:m") var unit_size := 6.0
## Distancia máxima audible, en metros. Se aplica al iniciar.
@export_range(5.0, 200.0, 1.0, "suffix:m") var max_distance := 40.0

@export_group("Empujón")
## Raspado corto al inicio de cada zancada. Sustituible por cualquier sample. En vivo.
@export var push_stream: AudioStream = preload("res://audio/ice_skate/ice_push.wav")
## Volumen del empujón, en dB. En vivo.
@export_range(-40.0, 12.0, 0.5, "suffix:dB") var push_volume_db := -8.0
## Variación aleatoria de tono por empujón (± fracción). 0 suena siempre igual; mayor evita la repetición. En vivo.
@export_range(0.0, 0.4, 0.01) var push_pitch_variation := 0.12

@export_group("Deslizamiento")
## Loop de siseo mientras patina. Si el sample no está marcado como loop, se fuerza al cargar. En vivo.
@export var glide_stream: AudioStream = preload("res://audio/ice_skate/ice_glide_loop.wav")
## Volumen del siseo a Full Speed, en dB. En vivo.
@export_range(-40.0, 12.0, 0.5, "suffix:dB") var glide_volume_db := -14.0
## Velocidad (m/s) por debajo de la cual el siseo calla. En vivo.
@export_range(0.0, 5.0, 0.05, "suffix:m/s") var glide_min_speed := 0.4
## Velocidad (m/s) con la que el siseo alcanza su volumen y tono máximos. En vivo.
@export_range(0.5, 20.0, 0.1, "suffix:m/s") var glide_full_speed := 8.0
## Tono del siseo a baja y a máxima velocidad (x = mínimo, y = máximo). En vivo.
@export var glide_pitch_range := Vector2(0.8, 1.2)

@export_group("Frenada")
## Loop áspero mientras dura la frenada de hockey. En vivo.
@export var brake_stream: AudioStream = preload("res://audio/ice_skate/ice_brake_loop.wav")
## Volumen de la frenada a Full Speed, en dB; baja con la velocidad. En vivo.
@export_range(-40.0, 12.0, 0.5, "suffix:dB") var brake_volume_db := -6.0

@export_group("Aterrizaje")
## Golpe al caer sobre hielo; sustituye al aterrizaje de nieve/tierra. En vivo.
@export var land_stream: AudioStream = preload("res://audio/ice_skate/ice_land.wav")
## Volumen del aterrizaje, en dB. En vivo.
@export_range(-40.0, 12.0, 0.5, "suffix:dB") var land_volume_db := -6.0

@export_group("Mezcla")
## Rapidez con que los loops suben y bajan de volumen, en s⁻¹. Mayor responde antes al entrar o salir del hielo. En vivo.
@export_range(1.0, 40.0, 0.5) var fade_speed := 10.0

var _actor: ExplorerPlayer
var _push: AudioStreamPlayer3D
var _land: AudioStreamPlayer3D
var _glide: AudioStreamPlayer3D
var _brake: AudioStreamPlayer3D
var _glide_level := 0.0
var _brake_level := 0.0
var _silent := false

func _ready() -> void:
	_actor = get_parent() as ExplorerPlayer
	_silent = DisplayServer.get_name() == "headless"
	_push = _make_player()
	_land = _make_player()
	_glide = _make_player()
	_brake = _make_player()
	if not _actor:
		return
	_actor.skate_stroke.connect(_on_stroke)
	_actor.feedback.connect(_on_feedback)

func _make_player() -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.bus = bus
	player.unit_size = unit_size
	player.max_distance = max_distance
	add_child(player)
	return player

func _on_stroke() -> void:
	if not enabled or not push_stream:
		return
	_push.stream = push_stream
	_push.volume_db = push_volume_db
	_push.pitch_scale = 1.0 + randf_range(-push_pitch_variation, push_pitch_variation)
	if not _silent:
		_push.play()

func _on_feedback(kind: String) -> void:
	if kind != "ice_land" or not enabled or not land_stream:
		return
	_land.stream = land_stream
	_land.volume_db = land_volume_db
	_land.pitch_scale = randf_range(0.95, 1.05)
	if not _silent:
		_land.play()

func _process(delta: float) -> void:
	if not _actor:
		return
	var skating := enabled and _actor.is_skating
	var speed := clampf(inverse_lerp(glide_min_speed, glide_full_speed, _actor.horizontal_speed), 0.0, 1.0)
	var blend := 1.0 - exp(-fade_speed * delta)
	_glide_level = lerpf(_glide_level, speed if skating and not _actor.skate_braking else 0.0, blend)
	_brake_level = lerpf(_brake_level, maxf(speed, 0.3) if skating and _actor.skate_braking else 0.0, blend)
	_tick_loop(_glide, glide_stream, _glide_level, glide_volume_db)
	_glide.pitch_scale = lerpf(glide_pitch_range.x, glide_pitch_range.y, _glide_level)
	_tick_loop(_brake, brake_stream, _brake_level, brake_volume_db)

func _tick_loop(player: AudioStreamPlayer3D, stream: AudioStream, level: float, volume_db: float) -> void:
	if level < 0.01 or not stream:
		if player.playing:
			player.stop()
		return
	if player.stream != stream and player.get_meta("source", null) != stream:
		player.stream = _looping(stream)
		player.set_meta("source", stream)
	player.volume_db = volume_db + linear_to_db(level)
	if not player.playing and not _silent:
		player.play(randf() * player.stream.get_length())

func _looping(stream: AudioStream) -> AudioStream:
	var wav := stream as AudioStreamWAV
	if not wav or wav.loop_mode != AudioStreamWAV.LOOP_DISABLED:
		return stream
	# Los samples importados sin loop se duplican con loop forward completo.
	wav = wav.duplicate() as AudioStreamWAV
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = int(wav.get_length() * wav.mix_rate)
	return wav
