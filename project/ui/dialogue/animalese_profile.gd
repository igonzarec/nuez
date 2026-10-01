@tool
class_name AnimaleseProfile
extends Resource
## Perfil compartido entre el personaje y la prueba del editor.
@export_enum("Español", "English") var language := 0
## 1 original; 1.7 más agudo y rápido; 0.8 grave.
@export_range(0.5, 3, 0.05) var pitch := 1.7
## Variación por letra, en semitonos. Ejemplo: 1.2.
@export_range(0, 6, 0.1) var pitch_variation := 1.2
@export_range(-40, 0, 1) var volume_db := -10.0
## Separación mínima entre sonidos. 0.08 evita una ráfaga excesiva.
@export_range(0.03, 0.5, 0.01) var sound_interval := 0.08
## Duración audible máxima de cada letra, segundos. 0 reproduce el clip completo.
@export_range(0, 1, 0.01) var max_duration := 0.16
## Filtro pasa-altos: quita graves de la voz. 0 desactiva. Ejemplo: 450 Hz.
@export_range(0, 2500, 25) var high_pass_hz := 450.0
## Filtro pasa-bajos: suaviza los agudos. Ejemplo: 5500 Hz; 20000 casi sin filtro.
@export_range(1000, 20000, 100) var low_pass_hz := 5500.0
## Distorsión suave opcional. 0 desactiva; 0.15 añade un timbre caricaturesco.
@export_range(0, 1, 0.01) var distortion := 0.12
