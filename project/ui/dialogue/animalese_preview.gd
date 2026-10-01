@tool
extends Control
## Selecciona este nodo y usa Reproducir / Detener en el Inspector.
## Edita el recurso Profile para cambiar también la voz del personaje que lo comparte.
@export var profile: AnimaleseProfile = preload("res://audio/animalese/mara.tres")
@export_multiline var example_text := "Hola, soy Mara. Bienvenido al sendero. ¿Mañana habrá nieve?"
## 1.15 coincide con el multiplicador actual de Mara en el globo.
@export_range(0.5, 2.5, 0.05) var character_pitch_multiplier := 1.15
@export_range(1, 80, 1) var letters_per_second := 20.0
@export_range(0, 1, 0.05) var punctuation_pause := 0.2
## Comparación con tu grabación sin pitch, filtros, distorsión ni truncado.
## No modifica el perfil guardado. Útil con Escuchar abecedario.
@export var audition_original := false
@export_tool_button("Reproducir ejemplo", "Play") var play_example: Callable = play
@export_tool_button("Escuchar abecedario", "AudioStreamPlayer") var play_alphabet: Callable = alphabet
@export_tool_button("Detener", "Stop") var stop_example: Callable = stop
var player: Node
var sequence := ""
var cursor := 0
var countdown := 0.0
var alphabet_mode := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not Engine.is_editor_hint():
		$Play.pressed.connect(play)
		$Stop.pressed.connect(stop)

func _ensure_player() -> void:
	if not is_instance_valid(player):
		player = preload("res://ui/dialogue/animalese_player.gd").new()
		add_child(player)
	player.profile = _audition_profile()

func _audition_profile() -> AnimaleseProfile:
	if not audition_original or profile == null:
		return profile
	var original := profile.duplicate() as AnimaleseProfile
	original.pitch = 1.0
	original.pitch_variation = 0.0
	original.high_pass_hz = 0.0
	original.low_pass_hz = 20000.0
	original.distortion = 0.0
	original.max_duration = 0.0
	return original

func play() -> void:
	stop()
	_ensure_player()
	alphabet_mode = false
	sequence = example_text
	cursor = 0
	countdown = 0

func alphabet() -> void:
	play()
	alphabet_mode = true
	sequence = "abcdefghijklmnñopqrstuvwxyz" if profile != null and profile.language == 0 else "abcdefghijklmnopqrstuvwxyz"

func stop() -> void:
	sequence = ""
	if is_instance_valid(player):
		player.stop()

func _process(delta: float) -> void:
	if sequence.is_empty() or cursor >= sequence.length():
		return
	countdown -= delta
	if countdown > 0:
		return
	player.profile = _audition_profile()
	var letter := sequence[cursor]
	player.speak(letter, 1.0 if audition_original else character_pitch_multiplier)
	cursor += 1
	countdown = 1.0 if alphabet_mode else 1.0 / letters_per_second
	if letter in ".,;:!?":
		countdown += punctuation_pause

func _exit_tree() -> void:
	stop()
