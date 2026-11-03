extends SceneTree
## Sintetiza los sonidos provisionales de patinaje en res://audio/ice_skate/.
## Son reemplazables: IceSkateAudio expone cada uno como slot en el Inspector.
## Uso: godot --headless --path project --script res://tools/generate_ice_skate_sounds.gd

const RATE := 44100
const OUT_DIR := "res://audio/ice_skate/"

var _rng := RandomNumberGenerator.new()

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_rng.seed = 7
	_save("ice_push.wav", _push(), false)
	_save("ice_glide_loop.wav", _glide(), true)
	_save("ice_brake_loop.wav", _brake(), true)
	_save("ice_land.wav", _land(), false)
	print("Ice skate sounds written to ", OUT_DIR)
	quit()

## Raspado de cuchilla: ruido en banda alta que barre hacia abajo, ataque seco.
func _push() -> PackedFloat32Array:
	var duration := 0.42
	var out := PackedFloat32Array()
	out.resize(int(RATE * duration))
	var filter := Biquad.new()
	for i in out.size():
		var u := float(i) / out.size()
		filter.bandpass(lerpf(5200.0, 2600.0, u), 1.6)
		var envelope := minf(1.0, u * 40.0) * pow(1.0 - u, 1.6)
		# Grano: pequeñas irregularidades del filo sobre el hielo.
		var grit := 0.75 + 0.25 * sin(u * 180.0 + _rng.randf() * 0.6)
		out[i] = filter.process(_rng.randf_range(-1.0, 1.0)) * envelope * grit
	return _normalize(out, 0.8)

## Siseo continuo de deslizamiento; los extremos se funden para un loop sin clics.
func _glide() -> PackedFloat32Array:
	var duration := 2.0
	var out := PackedFloat32Array()
	out.resize(int(RATE * duration))
	var filter := Biquad.new()
	filter.bandpass(3800.0, 0.9)
	var low := Biquad.new()
	low.bandpass(900.0, 0.7)
	for i in out.size():
		var t := float(i) / RATE
		var flutter := 0.85 + 0.15 * sin(t * TAU * 3.0) * sin(t * TAU * 0.5)
		var noise := _rng.randf_range(-1.0, 1.0)
		out[i] = (filter.process(noise) + low.process(noise) * 0.25) * flutter
	return _normalize(_loop_crossfade(out, int(RATE * 0.25)), 0.6)

## Frenada: raspado áspero con «spray» de hielo, más grave y entrecortado.
func _brake() -> PackedFloat32Array:
	var duration := 1.5
	var out := PackedFloat32Array()
	out.resize(int(RATE * duration))
	var filter := Biquad.new()
	filter.bandpass(2200.0, 0.8)
	var high := Biquad.new()
	high.bandpass(6500.0, 1.2)
	var chatter := 1.0
	for i in out.size():
		if i % 220 == 0:
			chatter = _rng.randf_range(0.55, 1.0)
		var noise := _rng.randf_range(-1.0, 1.0)
		out[i] = (filter.process(noise) + high.process(noise) * 0.5) * chatter
	return _normalize(_loop_crossfade(out, int(RATE * 0.2)), 0.85)

## Aterrizaje: golpe sordo corto más un «clac» brillante del filo.
func _land() -> PackedFloat32Array:
	var duration := 0.32
	var out := PackedFloat32Array()
	out.resize(int(RATE * duration))
	var click := Biquad.new()
	click.bandpass(4200.0, 2.0)
	var phase := 0.0
	for i in out.size():
		var t := float(i) / RATE
		phase += TAU * lerpf(170.0, 90.0, minf(1.0, t / 0.12)) / RATE
		var thump := sin(phase) * exp(-t * 28.0)
		var clack := click.process(_rng.randf_range(-1.0, 1.0)) * exp(-t * 55.0) * 1.6
		var ring := sin(t * TAU * 2350.0) * exp(-t * 22.0) * 0.12
		out[i] = (thump * 0.9 + clack + ring) * minf(1.0, t * 2000.0)
	return _normalize(out, 0.9)

func _loop_crossfade(samples: PackedFloat32Array, fade: int) -> PackedFloat32Array:
	var size := samples.size() - fade
	var out := PackedFloat32Array()
	out.resize(size)
	for i in size:
		out[i] = samples[i]
		if i < fade:
			var w := float(i) / fade
			out[i] = samples[i] * w + samples[size + i] * (1.0 - w)
	return out

func _normalize(samples: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var top := 0.0001
	for value in samples:
		top = maxf(top, absf(value))
	for i in samples.size():
		samples[i] *= peak / top
	return samples

func _save(file: String, samples: PackedFloat32Array, looping: bool) -> void:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	if looping:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = samples.size()
	stream.save_to_wav(OUT_DIR + file)

## Filtro biquad paso banda (RBJ cookbook).
class Biquad:
	var b0 := 0.0
	var b1 := 0.0
	var b2 := 0.0
	var a1 := 0.0
	var a2 := 0.0
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0

	func bandpass(frequency: float, q: float) -> void:
		var w := TAU * frequency / RATE
		var alpha := sin(w) / (2.0 * q)
		var a0 := 1.0 + alpha
		b0 = alpha / a0
		b1 = 0.0
		b2 = -alpha / a0
		a1 = -2.0 * cos(w) / a0
		a2 = (1.0 - alpha) / a0

	func process(x: float) -> float:
		var y := b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		return y
