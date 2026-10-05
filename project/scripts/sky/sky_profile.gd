@tool
extends Resource
## Ambiente editable. Los perfiles se mezclan manualmente desde StylizedSky.
@export var label := "Día"
## Color del cielo sobre la cabeza.
@export var zenith := Color(0.015, 0.33, 0.85)
## Color del horizonte; el degradado evita un fondo totalmente plano.
@export var horizon := Color(0.52, 0.78, 0.95)
@export var cloud_color := Color(0.98, 0.99, 1.0)
@export var cloud_shadow := Color(0.62, 0.73, 0.85)
@export var sun_color := Color(1.0, 0.96, 0.89)
## Intensidad de luz directa sobre terreno y personaje.
@export_range(0.0, 3.0, 0.01) var sun_energy := 0.65
## Intensidad de las sombras proyectadas; reduce este valor en días nublados.
@export_range(0.0, 1.0, 0.01) var shadow_opacity := 1.0
## Altura del sol en grados. Negativo lo sitúa bajo el horizonte.
@export_range(-30.0, 90.0, 1.0) var sun_elevation := 48.0
## Dirección horizontal del sol.
@export_range(-180.0, 180.0, 1.0) var sun_azimuth := -42.0
@export var ambient_color := Color(0.68, 0.79, 0.92)
@export_range(0.0, 2.0, 0.01) var ambient_energy := 0.35
@export var fog_color := Color(0.65, 0.78, 0.9)
## Niebla de profundidad compatible con Compatibility; cero la desactiva.
@export_range(0.0, 0.02, 0.0001) var fog_density := 0.0
## Mezcla de color para nublado. No genera ni elimina nubes al cambiar de perfil.
@export_range(0.0, 1.0, 0.01) var overcast := 0.0
