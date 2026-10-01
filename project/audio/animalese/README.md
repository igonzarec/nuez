# Letras grabadas / Animalese

53 clips PCM WAV mono: 27 en `es/` y 26 en `en/`. `enye.wav` corresponde a ñ.
Las vocales acentuadas usan su vocal base; ü usa u. En inglés ñ usa n.
Espacios, signos y caracteres sin grabación no generan sonido.

Fuentes conservadas fuera de la carpeta Godot: `sounds/animalese mine/` en la
raíz del repositorio. Cortes automáticos en silencios de 250 ms, umbral RMS
-38 dB, margen de 35 ms antes y 55 ms después, fundidos de 5 ms.
Los segmentos coinciden con los tamaños de ambos alfabetos y se asignaron en
orden alfabético según la descripción de la grabación. `segments.json` de cada
idioma conserva los tiempos originales para revisar cualquier corte.
No se normalizó ni alteró el pitch de los archivos; los efectos son en vivo.
`tools/split_alphabet.py` permite inspeccionar/regenerar sin sobrescribir originales
ni clips existentes. No es una suite de pruebas.

## Escuchar y editar en Godot

Abre `res://ui/dialogue/animalese_preview.tscn`, selecciona el nodo raíz y usa
los botones del Inspector **Reproducir ejemplo**, **Escuchar abecedario** y
**Detener**. No hay reproducción automática. También puedes abrir la escena con
F6 y usar sus botones en pantalla. `Audition Original` permite comparar la voz
sin efectos; para escuchar completos los archivos usa el recorrido del abecedario.

Expande **Profile** y modifica:

- Language: español / inglés.
- Pitch: 1 original, 1.7 agudo y rápido, 0.8 grave.
- Pitch Variation: variación en semitonos; 0 fija, 1.2 natural/cómica.
- Volume Db: -10 de ejemplo; menor valor suena más bajo.
- Sound Interval: 0.08 s evita sonidos excesivos durante escritura rápida.
- Max Duration: 0.16 s de balbuceo; 0 usa el clip completo.
- High Pass Hz: 450 quita graves; 0 desactiva.
- Low Pass Hz: 5500 suaviza agudos; 20000 casi transparente.
- Distortion: 0.12 añade textura; 0 desactiva.

Pitch también cambia la velocidad/duración del audio; estos efectos estilizan
la voz pero no garantizan anonimato. La voz respeta el bus SFX en el juego.

## Personajes

`mara.tres` es el perfil compartido de Mara y del ejemplo. Guarda sus cambios.
El globo contiene **Character Voice Profiles** (nombre exacto → perfil).
Duplica el `.tres` para nuevos personajes; no edites un recurso compartido si
quieres cambiar solo uno. `english.tres` sirve como punto de partida en inglés.

Por compatibilidad se conserva **Character Voice Pitches** en el globo:
se multiplica por el pitch del perfil. Mara mantiene 1.15; la prueba tiene
**Character Pitch Multiplier = 1.15** para reproducir el mismo resultado.
Puedes poner ambos multiplicadores en 1 y manejar el tono solo desde el perfil.
Los hablantes sin perfil usan **Recorded Voice Profile** de DialogueLabel.

En `DialogueLabel → Typing Voice`, **Typing Sound Enabled** silencia la voz;
**Recorded Voice Enabled** cambia entre estas grabaciones y el sintetizador
anterior. Los controles de **Synthetic Fallback** solo afectan al sintetizador.
La prueba usa el mismo reproductor y efectos que el diálogo real.
