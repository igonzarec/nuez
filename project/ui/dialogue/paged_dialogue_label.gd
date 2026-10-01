@tool
extends DialogueLabel
## Pagina el documento ya compuesto por Godot, conservando BBCode e índices
## originales de pausas y mutaciones del plugin durante la escritura.
@export_group("Typewriter")
## Desactiva para mostrar cada página completa, sin saltar a la siguiente.
@export var typewriter_enabled := true
@export_enum("Letras", "Palabras") var reveal_mode := 0
## Ejemplo: 35 letras por segundo.
@export_range(1, 120, 1) var letters_per_second := 35.0
## Ejemplo: 5 palabras por segundo.
@export_range(1, 30, 0.5) var words_per_second := 5.0
## Pausa adicional después de puntuación, en segundos. 0 la elimina.
@export_range(0, 1, 0.05) var punctuation_pause := 0.2
@export_group("Typing Voice")
## Usa letras grabadas. Desactiva para volver al generador sintético anterior.
@export var recorded_voice_enabled := true
## Perfil predeterminado; sus valores controlan pitch, filtros y ritmo de las grabaciones.
@export var recorded_voice_profile: AnimaleseProfile = preload("res://audio/animalese/mara.tres")
var active_voice_profile: AnimaleseProfile
var recorded_player: Node
## Activa/desactiva todos los sonidos de escritura.
@export var typing_sound_enabled := true
@export_subgroup("Synthetic Fallback")
@export_range(-40, 0, 1) var typing_volume_db := -19.0
## Separación mínima entre sonidos, evita ráfagas al revelar palabras. Ejemplo: 0.06 s.
@export_range(0.03, 0.3, 0.01) var sound_interval := 0.06
## Duración de cada sílaba sintética. Ejemplo: 0.075 s.
@export_range(0.03, 0.2, 0.005) var syllable_duration := 0.075
## Variación aleatoria del tono, en semitonos; 0 lo mantiene estable.
@export_range(0, 5, 0.1) var pitch_variation := 0.7
## Alternativa: grabación corta propia en lugar de la voz sintetizada.
@export var voice_sample: AudioStream
var speaker_pitch := 1.0
var voice_player: AudioStreamPlayer
var voice_cache: Dictionary = {}
var last_sound_time := -1000.0

var page_index := 0
var page_starts: Array[int] = []
var page_ends: Array[int] = []
var page_offsets: Array[float] = []
var waiting_for_page := false
var manual_pages := false
var layout_dirty := true
var preview_page_index := 0
var last_area := Vector2.ZERO
var last_document := ""

func _ready() -> void:
	fit_content = true
	threaded = false
	scroll_active = false
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not Engine.is_editor_hint():
		recorded_player = preload("res://ui/dialogue/animalese_player.gd").new()
		add_child(recorded_player)
		voice_player = AudioStreamPlayer.new()
		voice_player.bus = &"SFX" if AudioServer.get_bus_index("SFX") >= 0 else &"Master"
		add_child(voice_player)
		spoke.connect(_speak_letter)

func invalidate_pages() -> void:
	layout_dirty = true

func show_manual_text(value: String, preview_page := 0) -> void:
	if not Engine.is_editor_hint():
		var line := DialogueLine.new()
		line.text = value
		dialogue_line = line
		type_out()
		return
	manual_pages = true
	_is_typing = false
	waiting_for_page = false
	page_index = 0
	preview_page_index = maxi(0, preview_page)
	text = value
	visible_characters = -1
	layout_dirty = true
	rebuild_pages()

func type_out() -> void:
	manual_pages = false
	waiting_for_page = false
	page_index = 0
	# Base mantiene las pausas, velocidades y mutaciones de la línea completa.
	# No permitimos que el modo instantáneo salte todas las páginas.
	seconds_per_step = 1.0 / letters_per_second
	seconds_per_pause_step = punctuation_pause
	super.type_out()
	layout_dirty = true
	rebuild_pages()

func _process(delta: float) -> void:
	var area := (get_parent() as Control).size
	if area != last_area or text != last_document:
		layout_dirty = true
	if layout_dirty:
		rebuild_pages()
	if Engine.is_editor_hint() or manual_pages or waiting_for_page:
		return
	if not typewriter_enabled and is_typing:
		skip_typing()
		return
	super._process(delta)

func rebuild_pages() -> void:
	var area := (get_parent() as Control).size
	if area.x < 1 or area.y < 1:
		return
	var previous_character := 0
	if page_index < page_starts.size():
		previous_character = page_starts[page_index]
	size.x = area.x
	# Consultar métricas fuerza la composición síncrona con el ancho final.
	var total := get_total_character_count()
	var line_count := get_line_count()
	size.y = maxf(area.y, get_content_height())
	page_starts.clear()
	page_ends.clear()
	page_offsets.clear()
	var first_line := 0
	while first_line < line_count:
		var origin := get_line_offset(first_line)
		var next_line := first_line + 1
		while next_line < line_count:
			var bottom := get_line_offset(next_line) - origin + get_line_height(next_line)
			if bottom > area.y + 0.1:
				break
			next_line += 1
		page_starts.append(get_line_range(first_line).x)
		page_ends.append(get_line_range(next_line).x if next_line < line_count else total)
		page_offsets.append(origin)
		first_line = next_line
	if page_starts.is_empty():
		page_starts.append(0)
		page_ends.append(total)
		page_offsets.append(0.0)
	page_index = 0
	for index in page_starts.size():
		if page_starts[index] <= previous_character:
			page_index = index
	if Engine.is_editor_hint():
		page_index = clampi(preview_page_index, 0, page_ends.size() - 1)
	elif not manual_pages:
		page_index = maxi(page_index, _page_for_character(visible_characters))
	last_area = area
	last_document = text
	layout_dirty = false
	_apply_page()

func _page_for_character(character: int) -> int:
	for index in page_ends.size():
		if character <= page_ends[index]:
			return index
	return page_ends.size() - 1

func _apply_page() -> void:
	position = Vector2(0, -page_offsets[page_index])
	if manual_pages or Engine.is_editor_hint():
		visible_characters = page_ends[page_index]
		waiting_for_page = has_more_pages()

func has_more_pages() -> bool:
	return page_index + 1 < page_ends.size()

func next_page() -> bool:
	if not has_more_pages():
		return false
	page_index += 1
	waiting_for_page = false
	_waiting_seconds = 0
	_apply_page()
	return true

func _type_next(delta: float, seconds_needed: float) -> void:
	# La recursión de la clase base también pasa por este límite de página.
	if has_more_pages() and visible_characters >= page_ends[page_index]:
		waiting_for_page = true
		return
	seconds_per_step = 1.0 / letters_per_second
	if reveal_mode == 1:
		var parsed := get_parsed_text()
		var next_index := visible_characters + 1
		# Sin espera dentro de una palabra; conserva índices del plugin.
		var word_ends := next_index >= parsed.length() or parsed[next_index] in [" ", "\n", "\t"]
		seconds_per_step = 1.0 / words_per_second if word_ends else 0.000001
	super._type_next(delta, seconds_needed)

func _speak_letter(letter: String, _index: int, _speed: float) -> void:
	if not typing_sound_enabled or not typewriter_enabled or Engine.is_editor_hint():
		return
	if recorded_voice_enabled:
		recorded_player.profile = active_voice_profile if active_voice_profile != null else recorded_voice_profile
		recorded_player.speak(letter, speaker_pitch)
		return
	if letter.to_lower() not in "abcdefghijklmnopqrstuvwxyzáéíóúüñ0123456789":
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - last_sound_time < sound_interval:
		return
	last_sound_time = now
	var key := "%s:%.3f" % [letter.to_lower(), syllable_duration]
	if voice_sample == null and not voice_cache.has(key):
		voice_cache[key] = _make_syllable(letter.to_lower())
	voice_player.stream = voice_sample if voice_sample != null else voice_cache[key]
	voice_player.pitch_scale = clampf(speaker_pitch * pow(2.0, randf_range(-pitch_variation, pitch_variation) / 12.0), 0.4, 3.0)
	voice_player.volume_db = typing_volume_db
	voice_player.play()

func _make_syllable(letter: String) -> AudioStreamWAV:
	# Fuente armónica con dos formantes: timbres a/e/i/o/u, distintos por letra.
	var vowels := [Vector2(800, 1200), Vector2(500, 1900), Vector2(300, 2300), Vector2(500, 900), Vector2(350, 700)]
	var index := "aeiou".find(letter)
	if index < 0:
		index = letter.unicode_at(0) % vowels.size()
	var formants: Vector2 = vowels[index]
	var sample_rate := 22050
	var count := int(sample_rate * syllable_duration)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var fundamental := 180.0 + float(letter.unicode_at(0) % 7) * 12.0
	for i in count:
		var t := float(i) / sample_rate
		var envelope := minf(t / 0.008, 1.0) * pow(1.0 - float(i) / count, 1.4)
		var sample := 0.0
		for harmonic in range(1, 17):
			var frequency := fundamental * harmonic
			var amplitude := exp(-pow((frequency - formants.x) / 250.0, 2.0)) + 0.5 * exp(-pow((frequency - formants.y) / 350.0, 2.0))
			sample += sin(TAU * frequency * t) * amplitude / 4.0
		bytes.encode_s16(i * 2, int(clampf(sample * envelope, -1, 1) * 26000))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.data = bytes
	return wav

func skip_typing() -> void:
	if page_ends.is_empty():
		return
	if not has_more_pages():
		super.skip_typing()
		return
	# Revelar solo esta página; no ejecutar acciones de páginas posteriores.
	_is_skipping_mutations = true
	for index in range(maxi(0, visible_characters), page_ends[page_index]):
		_mutate_inline_mutations(index)
	_is_skipping_mutations = false
	visible_characters = page_ends[page_index]
	waiting_for_page = true
	skipped_typing.emit()
