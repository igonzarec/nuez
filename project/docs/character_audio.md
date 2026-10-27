# Audio del personaje: eventos, recursos y voces

El personaje emite eventos mediante `feedback(kind)`. `TrailAudio.bind_player`
conecta esa señal una vez con el reproductor central. El movimiento decide
**cuándo** ocurrió algo; las definiciones de sonido deciden **qué** reproducir
y con qué mezcla. Las escenas principales y previews usan el mismo enlace.

| Evento | Definición | Muestra |
| --- | --- | --- |
| `jump` | `res://resources/audio/player_jump.tres` | `res://audio/character/jump.wav` |
| `wall_recoil` | `res://resources/audio/player_hurt.tres` | `res://audio/character/hurt.wav` |
| `splat` | La misma definición de dolor | La misma muestra de dolor |

Jump reemplaza por completo el tono sintetizado anterior; ya no se genera
ni se usa un fallback a ese sonido. Los WAV se importan sin recortar ni
normalizar. Se conserva tono/velocidad originales por defecto.

## Dónde se edita

En **res://scenes/player.tscn → SquirrelExplorer → Audio de reacciones**, abre
**Jump Sound** o **Hurt Sound**. También puedes abrir directamente sus `.tres`
desde FileSystem. Ambos son recursos `TrailSoundCue`:

| Propiedad | Inicial | Efecto |
| --- | --- | --- |
| Enabled | Sí | Silencia el efecto sin desconectar eventos. |
| Stream | WAV correspondiente | Sustituye la muestra del siguiente evento. |
| Volume Db | −6 salto / −5 dolor | Nivel previo a los buses SFX y Master. |
| Pitch Scale | 1 | Multiplica tono y velocidad; mayor suena más agudo y corto. |
| Pitch Variation | 0 | Variación aleatoria; 0,05 equivale a ±5 %. |
| Priority | 2 salto / 3 dolor | Protege estas voces frente a efectos de prioridad menor. |
| Max Instances | 1 | Limita voces simultáneas de esa definición por TrailAudio. |
| Restart Oldest | Sí | Reinicia su voz más antigua si ya llegó al límite. |
| Cooldown | 0,08 s | Evita disparos repetidos demasiado próximos. |

Los ajustes se consultan en cada evento nuevo; no alteran una voz ya iniciada.
Guarda el recurso para conservarlos. Los recursos externos se comparten entre
escenas: usa **Make Unique** y guarda una nueva definición si necesitas una
mezcla distinta en una escena. Asignar un recurso vacío silencia ese evento.

## Reproducción y mezcla

TrailAudio reutiliza su pool de **ocho AudioStreamPlayer**, sin crear nodos
por cada salto o impacto. Busca primero una voz libre. Si está lleno, sólo
puede reemplazar una voz de prioridad igual o menor, eligiendo primero la
prioridad menor y después la más antigua. Si todas son más importantes,
descarta el nuevo sonido. Los efectos antiguos del pool usan prioridad 0.

Así un paso no corta hurt. El límite por definición evita acumular gritos.
Con Restart Oldest activo, un splat puede reiniciar hurt aunque todavía suene
el choque de pared anterior, respetando Cooldown. Son dos eventos que apuntan
a la misma muestra y comparten límite y cooldown.

La mezcla sigue **definición → SFX → Master**. Los controles existentes de
volumen de usuario y el limitador del Master se conservan. Son efectos 2D
centrados para el personaje controlado; no llevan atenuación por distancia.
La música, el viento y las capas de planeo mantienen reproductores dedicados
porque necesitan bucles y transiciones. El planeo usa dos voces con crossfade.

SnowStepAudio conserva su propio pool, bus de filtrado y handlers de pasos y
aterrizaje normal. Sus filtros no afectan a las vocalizaciones nuevas. Splat
no emite además `land`, por lo que no duplica el contacto normal de nieve.

## Cómo crecer sin duplicar lógica

Para otro efecto breve, crea un `TrailSoundCue` en `resources/audio`, asigna
su stream y mezcla, y llama a `TrailAudio.play_cue(definicion)` desde el evento
correspondiente. Para eventos del jugador, añade su asignación en el despacho
central `play(kind)`; no crees reproductores en cada estado. Nuevos efectos
pueden reutilizar límites, cooldown y prioridades sin tocar el motor del pool.

Los efectos antiguos aún usan el catálogo `sounds` y los pasos especializados
conservan sus handlers. Esta incorporación introduce definiciones para las
vocalizaciones; no migra automáticamente todo el audio existente. Para futuros
NPC o fuentes ambientales con posición, conviene un pool de AudioStreamPlayer3D
separado que reutilice las definiciones, según la distancia y espacialización
que necesite ese sistema.
