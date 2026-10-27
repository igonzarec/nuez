class_name TrailSoundCue
extends Resource
## Definición reutilizable de un efecto; TrailAudio administra su reproducción.

## Permite silenciar este efecto sin desconectar el evento. En vivo para nuevas reproducciones.
@export var enabled := true
## Muestra de sonido. Cambiarla afecta el siguiente evento; no modifica una voz ya reproduciéndose.
@export var stream: AudioStream
## Volumen en dB antes de SFX/Master. Mayor destaca el efecto. En vivo para nuevos eventos.
@export_range(-60.0, 6.0, 0.5, "suffix:dB") var volume_db := -5.0
## Multiplicador de tono y velocidad; 1 conserva el archivo. Mayor suena más agudo y corto. En vivo para nuevos eventos.
@export_range(0.25, 2.0, 0.01) var pitch_scale := 1.0
## Variación aleatoria de tono como fracción de Pitch Scale. 0 conserva el original; 0,05 varía ±5 %. En vivo para nuevos eventos.
@export_range(0.0, 0.25, 0.005) var pitch_variation := 0.0
## Prioridad frente a otras voces del pool. Mayor protege el sonido; pasos y efectos antiguos usan 0. Sólo reemplaza voces de prioridad igual o menor. En vivo.
@export_range(0, 10, 1) var priority := 2
## Cantidad máxima de reproducciones simultáneas de este recurso por TrailAudio. Mayor permite solapes y ocupa más voces del pool. En vivo.
@export_range(1, 8, 1) var max_instances := 1
## Al alcanzar Max Instances, reinicia la voz más antigua de este recurso. Activo permite oír un nuevo impacto aunque aún suene el anterior; apagado descarta el nuevo evento. Respeta Cooldown. En vivo.
@export var restart_oldest := true
## Intervalo mínimo en segundos entre eventos que usan este recurso. Mayor evita repeticiones rápidas; 0 permite cada evento. Compartido por splat y choque si usan la misma definición. En vivo.
@export_range(0.0, 2.0, 0.01, "suffix:s") var cooldown := 0.08
