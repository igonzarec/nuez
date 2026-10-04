# Pisadas de nieve

Estas seis muestras ya venían separadas. Se copiaron sin modificar desde
`sounds/snow steps/` para que Godot las importe como recursos del proyecto.

| Archivo | Variante |
| --- | --- |
| snow_step_01_noisy.wav | Noisy 1 |
| snow_step_02_noisy.wav | Noisy 2 |
| snow_step_03_soft.wav | Soft 3 |
| snow_step_04_soft.wav | Soft 4 |
| snow_step_05_mid.wav | Mid 5 |
| snow_step_06_mid.wav | Mid 6 |

En Godot, abre `scenes/terrain_snow_playground.tscn` y selecciona el nodo
SnowStepAudio. En **Variantes activas** puedes habilitar cada clip de forma
independiente; si desactivas todos, se recupera el paso habitual. Consulta
`docs/terrain_snow_playground.md` para volumen, velocidad, pitch, cadencia y
filtro de agudos.
