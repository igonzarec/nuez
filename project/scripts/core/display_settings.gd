class_name TrailDisplay
extends RefCounted
## Opciones compartidas por el menú, el guardado y las escenas de trabajo.

const DEFAULT_RESOLUTION := "1280x720"
const RESOLUTIONS := ["1280x720", "1366x768", "1600x900", "1920x1080", "2560x1440", "3840x2160"]
const RESOLUTION_NAMES := {
	"1280x720": "HD (720p)",
	"1366x768": "HD portátil (768p)",
	"1600x900": "HD+ (900p)",
	"1920x1080": "Full HD (1080p)",
	"2560x1440": "QHD (1440p)",
	"3840x2160": "4K UHD (2160p)",
}

static func resolution_label(value: String) -> String:
	return "%s · %s" % [RESOLUTION_NAMES.get(value, "Personalizada"), value.replace("x", " × ")]

static func validated_resolution(value: Variant) -> String:
	var requested := str(value)
	return requested if requested in RESOLUTIONS else DEFAULT_RESOLUTION

static func apply(settings: Dictionary) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var fullscreen: bool = settings.get("fullscreen", false) == true
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
	if fullscreen:
		return
	var parts := validated_resolution(settings.get("resolution", DEFAULT_RESOLUTION)).split("x")
	var requested := Vector2i(int(parts[0]), int(parts[1]))
	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	# Dejar espacio para los bordes y la barra de título en monitores pequeños.
	var decoration := DisplayServer.window_get_size_with_decorations() - DisplayServer.window_get_size()
	var available := (usable.size - decoration).max(Vector2i.ONE)
	var factor := minf(1.0, minf(float(available.x) / requested.x, float(available.y) / requested.y))
	var fitted := Vector2i(Vector2(requested) * factor)
	DisplayServer.window_set_size(fitted)
	DisplayServer.window_set_position(usable.position + (usable.size - fitted) / 2)
