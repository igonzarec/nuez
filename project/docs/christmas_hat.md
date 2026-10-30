# Gorro navideño

Accesorio low-poly tipo juguete (facetado y mate como la ardilla) que la ardilla encuentra tirado, recoge con el botón de
interacción y luego se pone o se quita desde la pausa. Hay dos objetos con el
mismo aspecto:

| Objeto | Archivo | Uso |
| --- | --- | --- |
| Gorro del suelo | `scenes/accessories/christmas_hat_pickup.tscn` | Interactuable con física (`RigidBody3D`). |
| Gorro en la cabeza | Nodo **HatSlot** de `scenes/player.tscn` | Sujeto al hueso `head`; sólo cambia `visible`. |
| Aspecto y física compartidos | `resources/accessories/christmas_hat_style.tres` | `ChristmasHatStyle`; editarlo cambia ambos. |
| Sonido al conseguirlo | `resources/accessories/christmas_hat_pickup_sound.tres` | `TrailSoundCue` con `audio/sfx/nut_cracking.wav`. |

## Colocarlo en una escena

1. En **FileSystem**, arrastra `res://scenes/accessories/christmas_hat_pickup.tscn`
   a la vista 3D de cualquier escena con la ardilla.
2. Muévelo y gíralo con el gizmo. El origen es el borde inferior del ribete:
   apóyalo sobre el suelo. Con **Start Asleep** activo queda congelado exactamente
   ahí hasta que la ardilla lo empuje; después es un cuerpo físico normal.
3. Ejemplo ya colocado: `3D_playground.tscn`, cerca del punto de inicio.

Al acercarse aparece el mismo prompt que en NPC y letreros. Al pulsar **E /
cuadrado** (o cruz en el suelo) suena el efecto, salen destellos y el gorro
queda **puesto al instante, sin animación**. No vuelve a aparecer en el mundo.
Desde la pausa: **Quitarse / Ponerse el gorro navideño**.

El estado se guarda en `user://wardrobe.json` (autoload `TrailWardrobe`), aparte
de la expedición, y vale para la partida y para las escenas de trabajo. Para volver
a probar la recogida, activa **Depuración → Reset Ownership On Start** en el
gorro del suelo (y desactívalo después).

## Controles del estilo (Inspector del `.tres`)

Abre `christmas_hat_style.tres` o despliega **Style** en el gorro o en HatSlot.
Forma, peluche, color y calidad **regeneran** la malla (Live Preview en el
editor); la física se actualiza **en vivo**.

- **Forma · cuerpo:** radio de la base, largo (altura), inclinación de la copa,
  abombado, radio y curva de la punta, caída (ángulo y dirección), curvatura
  del pliegue (posición y suavidad), *Fold Min Radius* y ondulación opcional.
  *Fold Min Radius* (2 por defecto) impide que la curva gire más cerrada que dos
  veces el grosor local de la tela: el doblez queda limpio, sin estrías, y la caída
  que falta se completa en la parte fina de la cola. Bájalo para dobleces más
  cerrados a costa de comprimir el interior.
- **Ribete:** grosor, alto y almohadillas regulares (cantidad y profundidad):
  esponjoso pero geométrico.
- **Pompón:** radio y desplazamiento (*Pompom Offset*).
- **Color:** rojo cálido y apagado, rojo del doblez y su intensidad, blanco y
  blanco de los surcos.
- **Material:** rugosidad y especular como la ardilla (0,5 / 0,5) y brillo de
  borde (0 por defecto). La opción mate del personaje en Apariencia también lo afecta.
- **Detalle opcional · peluche:** bultos irregulares y capas de pelo translúcidas.
  Desactivado por defecto para mantener el estilo low-poly; cada capa añade geometría.
- **Física de la cola:** *Rigid Length* (0,45) mantiene rígida la copa que abraza
  la cabeza: el gorro nunca pierde su forma y sólo se mueve la cola. *Rigid Blend*
  reparte la transición entre la parte rígida y la suelta. Además: activación, segmentos, rigidez en la base y en la punta,
  gravedad, amortiguación, arrastre del aire (cuánto ondea al correr o planear),
  inercia (*Motion Follow*), velocidad máxima, esfera de la cabeza e iteraciones.
- **Suavizado y subdivisiones:** *Faceted* (facetas planas como la ardilla;
  apagado suaviza), anillos y lados de la tela, divisiones del ribete y del pompón.
  Con los valores por defecto el gorro tiene unos 1.000 triángulos.

Ejemplos: una cola más larga y colgante usa *Body Length* 0,9 y *Tip Stiffness
Ratio* 0,12; un gorro más tieso usa *Base Stiffness* 450 y *Air Drag* 0,3. Para
un acabado de peluche, sube *Fur Shells* a 3 y *Lump Strength* a 0,3.

## Ajuste en la cabeza (HatSlot en `player.tscn`)

- **Wear Mode:** *Wardrobe* (el jugador lo lleva según la pausa; los NPC nunca),
  *Always* (p. ej. para que un NPC lo lleve siempre) o *Never*.
- **Ajuste en la cabeza:** posición, rotación y escala respecto al hueso
  `head`, en vivo. Con Y = 180 el gorro mira hacia la nuca: X positivo lo echa
  atrás y baja el frente hacia los ojos; Z lo ladea. El lado de la cola se elige
  con *Droop Direction* del estilo (por defecto, costado derecho y algo atrás,
  con el pompón a la altura de la oreja).
- **Hide Ears When Worn:** el gorro cubre la parte alta de la cabeza y oculta las
  orejas (sólo su `visible`) mientras está puesto. *Ear Mesh Names* lista las mallas.
- *Head Collision Scale* del estilo (1,15) dimensiona la esfera de la cabeza
  para que la cola no la atraviese; súbelo si la cola se hunde en la cabeza.
- **Vista previa en el editor → Editor Fit Preview:** muestra la ardilla con el
  gorro dentro de `player.tscn` para ajustar el encaje sin jugar. No se guarda.

## Gorro del suelo (Inspector del pickup)

- **Interacción:** alcance, altura del prompt y *Equip On Pickup* (apagado sólo
  lo guarda y se pone desde la pausa).
- **Sonido y efecto:** `TrailSoundCue` (volumen, tono y variación) y destello
  (activación, cantidad y color). Usa el bus de efectos si la escena tiene `TrailAudio`.
- **Física:** colisión ajustada al estilo, *Start Asleep*, fuerza y radio del
  empuje. La ardilla atraviesa el gorro (capa 16) y lo empuja con un impulso,
  así que no la frena ni la cámara choca con él. La cola apoya en el suelo
  mediante un rayo hacia abajo por fotograma físico.

## Notas técnicas

- La malla se genera por código (`scripts/accessories/christmas_hat_visual.gd`)
  sobre un `Skeleton3D` propio: hueso raíz para el ribete y una cadena a lo largo
  de la cola. Una simulación Verlet mueve sólo los puntos de la cola (gravedad,
  inercia, aire, colisión con la cabeza y el suelo) y orienta los huesos.
- La simulación corre en `_physics_process`, después del movimiento del personaje.
  El proyecto usa interpolación de física: leer la cabeza en `_process` daba
  sacudidas a la cola (parpadeo) porque su posición sólo cambia en cada tick.
- La colisión con la cabeza nunca empuja la cola más allá de su forma de reposo, y
  un giro casi opuesto al de reposo se ignora para evitar saltos de 180°. Las mallas iguales se
  comparten entre gorros mediante una caché.
- Malla procedural en un `MeshInstance3D` (*HatMesh*) con facetas planas y
  materiales `StandardMaterial3D` con colores de vértice: heredan el toon y el
  acabado mate del personaje. El gorro del suelo pertenece al grupo
  `character_look` para que también los herede.
