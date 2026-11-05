# Agua: ríos, lagos y cascadas

Escenas de prueba:

- `scenes/water_playground.tscn`: terreno, agua y piedras. Se edita aquí.
- `scenes/3D_playground_water.tscn`: la versión jugable, con jugador, cámara y luz del juego.
  Ejecútala con **F6** sobre esa escena.

Terreno propio: `terrain_data/water_playground/`, con `vertex_spacing` de 1 m, como en el mundo final.

Archivos:

| Pieza | Archivo |
|---|---|
| Estilo (todos los ajustes visuales) | `scripts/water/water_style.gd`, recurso por defecto `assets/water/water_style_default.tres` |
| Base común (material, tallado) | `scripts/water/water_body.gd` |
| Río (con rápidos y cascada) | `scripts/water/water_river.gd` |
| Lago o estanque | `scripts/water/water_lake.gd` |
| Shader | `shaders/water/water_surface.gdshader` |

## Cómo se usa

1. **Añade un nodo** `WaterRiver` o `WaterLake` (Agregar nodo → busca "Water"). Aparece con una curva
   inicial: un tramo recto de 20 m o un círculo de 6 m.
2. **Dibuja la forma** con las herramientas de Path3D (barra superior del 3D: añadir, mover y
   borrar puntos).
   - **Río:** la altura de cada punto es la superficie del agua, y el agua fluye del primer punto
     al último. Donde la curva baja en pendiente aparecen rápidos; casi en vertical, una cascada.
   - **Lago:** se usa sólo el contorno en planta. El nivel del agua es la Y del propio nodo; muévelo
     para subirlo o bajarlo.
3. **Asigna `Terrain`** en el grupo **Cauce (Terrain3D)** y pulsa **Tallar cauce**. Guarda con
   **Ctrl+S**.
4. **Retoca a mano** con los pinceles de Terrain3D lo que quieras.

La malla del agua se rehace sola al editar la curva y no se guarda en la escena: no hay que hornear.

## Reglas del tallado

- **Sólo baja el terreno, nunca lo sube.** Si vuelves a tallar después de retocar, lo que hayas
  cavado más hondo se conserva. Un retoque que suba el terreno dentro del cauce se vuelve a bajar.
- **Perfil:**
  - Fondo plano a `Carve Depth` en la fracción `Bed Flat` del ancho (en ríos).
  - En lagos, el fondo baja en `Shore Width` metros desde la orilla.
  - Por encima del agua, la orilla sube con `Bank Angle` hasta `Bank Reach` metros.
- **Restaurar terreno** devuelve las alturas y la pintura de antes del primer tallado de *ese*
  nodo; los retoques hechos dentro de esa zona también se pierden. Si dos cuerpos de agua se
  tallaron superpuestos, restaura primero el último tallado.
- **Los tramos empinados (cascadas) no tallan**: cuelgan delante de la pared. Tallarlos abriría una
  ranura en el cliff.
- **Orillas como en un río real:** en cada curva, la orilla interior es una playa suave y la exterior un corte empinado. En tramos rectos se usa `Bank Angle`.
- **Pintura de orilla:** con `Bank Texture Id` ≥ 0 se pinta esa textura (arena) bajo el agua y
  hasta `Bank Paint Height` metros por encima. Se funde con el pasto a lo largo de
  `Bank Paint Blend`. En el playground es el ID 2, `dirt_sandy`.
- **Aviso de orilla inundada:** si junto al agua el terreno queda más bajo que la superficie, el
  agua flotaría sobre el borde. La salida lo indica. Baja la curva o sube esa orilla. En las uniones
  de un río con un lago es normal y no importa.

## Controles

### WaterRiver / WaterLake (Inspector)

| Grupo | Control | Efecto |
|---|---|---|
| Aspecto | Style | Recurso `WaterStyle`. Vacío usa el de por defecto. Compartido entre cuerpos de agua; **Make Unique** para un aspecto propio. |
| Nado | Swimmable, Current Strength, Swim Depth Limit | Si se puede nadar, cuánto arrastra la corriente y hasta qué profundidad. Ver [swimming.md](swimming.md). |
| Forma (río) | Width / Width Curve | Ancho en metros y multiplicador a lo largo del río. En vivo. |
| | Bank Overlap | Metros que la malla se mete bajo la orilla para ocultar su borde. Sólo se dibuja donde una orilla lo tapa: donde no hay orilla (repisa de un acantilado, borde de una cascada, terreno bajo) el agua conserva el ancho visible de su cauce (`Width`) en vez de desbordarse. La cortina y la espuma de su base usan ese mismo ancho. En vivo. |
| | Step / Cross Segments | Densidad de la malla a lo largo y a lo ancho. En vivo. |
| | Break Foam Length | Metros de espuma antes y después de un cambio de pendiente: borde y base de la cascada, inicio de rápidos. |
| Piedras del fondo (río) | Pebbles Enabled, Density, Size Min / Max, Small Bias, Width / Height Range, Sink, Tilt, Coverage, Edge Bias, Clumping, Clump Size, Min Depth, Colors, Brightness Variation, Roughness, Seed, Draw Distance, Chunk Length, Max Count | Cantos rodados ovalados en el fondo, sólo visuales (sin colisión). Se apoyan en la altura real del terreno (o en el perfil tallado si aún no hay datos) y se regeneran solos al cambiar el río o tallar. No van en cascadas, rápidos empinados ni dentro de lagos. **Colors** es un degradado: cada piedra toma un punto al azar, así que cada tramo es un rango de color; en modo Constant, colores fijos. Se dibujan en tramos de `Chunk Length` (25 m), cada uno con su propio centro, y `Draw Distance` oculta cada tramo por separado. Si la densidad pide más que `Max Count` (20.000), se reduce por igual en todo el río. Cuánto se ven depende de la transparencia del agua (`Clarity`, `Uniform Depth`). En vivo. |
| Cascada · forma (río) | Fall Bulge, Fall Exit Angle, Fall Arc, Fall Lip Round Before, Fall Lip Round, Fall Lip Round Strength, Fall Widen, Fall Thickness, Fall FX Offset, Fall FX Lift, Fall Lip Band Offset | Una cascada es el tramo de la curva más empinado que `Fall Start Angle` (35°); para una cascada que sale de una grieta basta un río corto: un punto dentro de la grieta, otro a 1–2 m casi a la misma altura (da la dirección de salida y el borde redondeado) y otro ya en el agua de abajo. La cortina sigue la trayectoria de un chorro: sale horizontal del borde y la gravedad la curva hasta la poza, así el borde queda redondeado y la textura del río sigue por encima antes de convertirse en caída. **Curva del borde:** `Fall Lip Round Before` (1,5 m, sobre el río: cuánto antes empieza a doblarse) y `Fall Lip Round` (1,5 m, sobre la cortina: cuánto tarda en pasar a caer) deciden su tamaño; `Fall Lip Round Strength` cuánto se redondea (1 = suave, menos = codo). **Forma de la caída:** `Fall Exit Angle` (grados: + sale subiendo con joroba, − sale ya hacia abajo) y `Fall Arc` (1 = arco de chorro, menos = rampa recta); aterriza siempre en el mismo sitio. Más suave con `Step` pequeño. La espuma de la base se coloca sola donde aterriza la cortina y delante de su grosor; `Fall FX Offset` (m, + hacia fuera) y `Fall FX Lift` (m) la ajustan a mano en cada río. `Fall Lip Band Offset` (m) decide dónde va la franja del borde en esa cascada (+ más abajo por la cortina, − más arriba por el río). `Fall Bulge` (0,5 m) = metros extra que el agua aterriza lejos del acantilado (más = borde más abierto). `Fall Widen` (0) la ensancha hacia abajo; en 0 cae con el ancho exacto del agua de origen. `Fall Thickness` (0,45 m) le da volumen: sección de frente casi plano y bordes que se redondean hacia atrás; vista de lado o en ángulo rasante es opaca, de frente se transparenta un poco. Delante del acantilado, entre el borde y el pie, no se puede nadar: el jugador cae. Al tallar, el cauce y las orillas (del río y de la poza) no cortan el acantilado bajo o detrás de una cascada; volver a pulsar **Tallar cauce** en el río y en la poza devuelve a su altura original las celdas que ya se habían cortado ahí. En vivo. |
| Desembocadura (río) | Mouth Blend Enabled / Mouth Blend Length | Donde el río entra o sale de un lago a su misma altura, su superficie sigue dentro del lago y se desvanece en `Mouth Blend Length` metros (8), también por los lados: el agua del río se abre en el lago en vez de cortarse en la orilla. Si la curva acaba en la orilla, el río se prolonga recto; en un estanque pequeño el fundido se acorta para no salir por el otro lado. Mayor = transición más larga. En vivo. |
| Forma (lago) | Bank Overlap | Igual que en el río. |
| Cauce | Terrain, Carve Depth, Bank Angle, Bank Reach | Perfil del tallado. `Bank Angle` (55°) es la margen cortada. Se aplican al tallar. |
| | Bank Angle Inner, Beach Bend Radius (río) | Orilla interior de las curvas: playa suave (20°), completa en curvas de radio ≤ `Beach Bend Radius` (25 m). |
| | Sand Max Angle | La arena sólo cubre orillas más suaves que este ángulo (playas); las márgenes cortadas quedan con la tierra o roca del Auto Shader. Bajo el agua siempre hay arena. |
| | Bed Flat (río) / Shore Width (lago) | Forma del fondo. |
| | Bank Texture Id, Bank Paint Height, Bank Paint Blend | Pintura de orilla. |
| | Tallar cauce / Restaurar terreno | Botones. |

### WaterStyle (doble clic en el recurso Style)

Todo se aplica en vivo, sin regenerar.

| Grupo | Controles | Sugerencias |
|---|---|---|
| Color | Shallow / Deep Color, Depth Scale, Depth Tone Amount, Uniform Depth, Clarity, Bed Tint, Self Light | **Tono por profundidad:** `Depth Tone Amount` 0 (así está el estilo por defecto) da a todo el agua el mismo tono, el de `Uniform Depth` (1,2 m): ríos, lagos y uniones se ven iguales aunque el cauce tallado tenga zanjas. Súbelo hacia 1 para orillas claras y centros oscuros. **Densidad:** baja `Clarity` y sube `Bed Tint` para agua turbia u opaca. Sube `Clarity` para cristalina. `Depth Scale` decide cuánto tarda en oscurecerse. |
| Color (ríos) | River Edge Light | Ríos más claros junto a las orillas y más azules en el centro del cauce (no depende de la profundidad; las uniones con lagos no cambian). |
| Líneas de orilla | Shore Line Strength / Depth / Width | Segunda línea fina y discontinua de espuma, algo separada de la orilla. La primera es la espuma de orilla (`Foam Width`). |
| Superficie | Wave Scale, Wave Strength, Wave Speed, Refraction | Para un lago en calma: `Wave Strength` 0,1–0,2. Para agua picada: `Wave Scale` 1 y `Strength` 0,6. |
| Corriente | Flow Speed, Flow Stretch | La velocidad también la usará el nado. `Stretch` 2–3 da vetas que leen la dirección. |
| Crestas | Color, Scale, Width, Softness, Amount, Strength, Stretch, Wobble, Speed, Trough Shade | **El rasgo principal de la referencia**: la red densa de líneas claras y onduladas que avanza con la corriente. Son curvas de nivel de un ruido deformado, cortadas en trazos. `Scale` 0,6–1 da agua picada; 1,5–3, ondas amplias. `Trough Shade` oscurece los valles para variar el azul. |
| Destellos | Color, Scale, Amount, Softness, Strength, Twinkle | Chispas sueltas encima de las crestas. `Amount` 0,1–0,2 acompaña; más da agua muy brillante. |
| Espuma de orilla | Color, Width, Softness, Noise Scale, Breakup, Strength | Aparece sola donde algo cruza el agua: orillas, piedras y, más adelante, el jugador. |
| Rápidos y cascadas | Ángulos de inicio y completos, Fall Color, Streak Scale, Fall Speed, Rapids Foam, Break Foam | Ángulos de la pendiente de la curva del río. |
| Cascada (cortina) | Fall Color Mix, Fall Crests, Fall Color, Fall Streak Color, Fall Shadow Color, Fall Transparency, Fall Reflection (reflejo del cielo y brillo del sol en la cortina: el brillo bajo el borde), Fall Streak Length / Scale (manchas oscuras), Fall Streak Wave / Softness, Fall Speed | La cortina es el mismo agua del río cayendo: sus colores (más oscuros abajo) y sus crestas, que justo bajo el borde siguen con la escala del río y se van estirando al bajar (`Fall Crests`), con espuma al pie. Sin costura en el borde: el río que se curva hacia la caída no lleva espuma de rápidos, y el agua más rápida (rápidos, cascadas) estira su dibujo en vez de deslizarlo a otra velocidad, así que no salen franjas rayadas donde cambia la pendiente. Pon el borde de la curva donde acaba la roca a los lados del río: si el río sigue más allá del acantilado, se ve como un canal colgado. `Fall Color Mix` (0,25) mezcla el color propio de la cascada. Ocupa todo el ancho que dibuja el río. Semitransparente de frente, opaca en ángulo; bordes sólidos. |
| Rápidos y cascadas › Cascada · franja del borde (+ borde de abajo, borde de arriba) | General: Band Transparency (transparencia real: deja ver el agua de debajo; alta puede marcar el pliegue), Fall Lip Band (opacidad; menor = más transparente: deja ver `Fall Color`, igual a ambos lados del pliegue), Band Color, Marks Light (brillo), Band Softness, Ragged Scale (tamaño de las irregularidades), Band Pulse (cuánto respira el grosor), Band Speed. Cada borde: Band Height / Band Up (grosor en metros sobre la cortina / sobre el río), Ragged, Shape (Muescas hacia dentro / Picos hacia fuera), Amount, Size (m), Width (m) | Una sola franja blanca que cruza el borde, medida en metros a lo largo de la superficie (río arriba y cortina abajo), así no tiene costura en el pliegue. Sus dos bordes son irregulares con el mismo ruido, pulso y velocidad, y cada uno lleva muescas de agua azul que entran o picos blancos que salen, con la misma forma (por defecto: abajo muescas, arriba picos). El grosor del centro blanco es `Band Up` + `Band Height`; las muescas no pasan del grosor. Color plano (`Band Color` × `Marks Light`), sin luz ni reflejos. `Lip Opaque` (1,5 m): el agua del río se vuelve opaca y deja de reflejar el cielo al acercarse al borde, para que el borde del acantilado bajo el agua no se vea como una línea oscura y los picos de arriba contrasten igual que las muescas de abajo desde cualquier ángulo. Muescas y picos nunca se solapan entre sí. |
| Rápidos y cascadas › Cascada · franja del pie (+ borde de arriba, borde de abajo) | Los mismos controles que la franja del borde con prefijo Foot: Fall Foot Band (opacidad), Transparency, Offset, Color, Softness, Ragged Scale, Pulse, Speed; borde de arriba (Band Up, Ragged, Shape, Amount, Size, Width; por defecto picos que suben por la cortina); borde de abajo (Band Down sobre el agua de abajo, Ragged, Shape, Amount, Size, Width) | La misma franja que la del borde, anclada al pie de la cascada y medida en metros desde el pie (hacia arriba por la cortina, hacia fuera sobre el agua). Aparte está `Break Foam` (espuma con ruido al pie, la mancha clara de borde blando); ponla en 0 si sólo quieres la franja. |
| Cascada · efectos | Fall FX Enabled; Foam Enabled / Size / Opacity / Patch / Rings / Ring Speed / Line Width / Dashes / Reach / Wobble / Drift; Puff Size / Density / Pulse / Opacity; Puff Size Variation / Shape Variation / Scatter / Seed; Puff Life Enabled / Life Speed / Life Speed Variation / Life Size Variation / Min Size / Hold; Bubbles Enabled / Amount / Size / Spread / Opacity; Mist Enabled / Amount / Size / Height / Opacity; Splash Enabled / Amount / Height / Size / Opacity / Shading; FX Color / FX Shadow Color | En la base de cada cascada, colocados solos donde acaba el tramo empinado, estilo cartoon: franja de lóbulos de espuma esponjosos que laten (`shaders/water/fall_puff.gdshader`, dos tonos: FX Color y FX Shadow Color), líneas blancas curvas que salen hacia la poza (`fall_foam.gdshader`: `Foam Patch` mancha sólida bajo los lóbulos, `Rings` cuántas líneas, `Ring Speed`, `Line Width`, `Dashes` cuánto se cortan en trazos, `Reach` hasta dónde llegan, `Wobble` ondulación, `Drift` velocidad general), burbujitas que aparecen sobre la espuma y se alejan con el agua (**Bubbles**) y gotas iguales a las del chapuzón del jugador (**Splash**; `Splash Size` 1 = mismo tamaño). Variedad de los lóbulos: `Size Variation` (tamaños), `Shape Variation` (aplastados, altos, girados), `Scatter` (desorden de las filas) y `Seed` (otro reparto). **Ciclo de vida** (`Puff Life Enabled`): cada lóbulo surge, crece, encoge hasta desaparecer y vuelve a surgir con otro tamaño; `Life Speed` (ciclos/s), `Life Speed Variation` (desacompasados), `Life Size Variation` (tamaño de cada aparición), `Min Size` (0 = desaparece del todo) y `Hold` (tiempo a tamaño completo).   `Bubbles Opacity`, `Splash Opacity` / `Splash Shading` (cuánto se oscurecen las gotas al caer). Las líneas de espuma de la poza: `Foam Opacity`; los lóbulos: `Puff Opacity`. La neblina existe pero viene apagada. Sólo visuales. Compartidos por todas las cascadas de los ríos que usan este estilo; cada río los reconstruye solo al cambiar un valor. En vivo. |
| Reflejo | Sky Color, Fresnel Strength / Power, Specular, Roughness | Con `Fresnel Strength` alto, los lagos vistos de lejos se vuelven pálidos. |
| Cáusticas | Color, Scale, Speed, Strength | Luz ondulante sobre el fondo; se apagan con la profundidad. |
| Distancia | Far Distance | Desde aquí el agua se simplifica, para combinar con el desenfoque de la cámara. |
| Bajo el agua | Underwater Color / Light Color, Fog Distance, Tint, Max Fog, Surface Color, Window | Sólo si la cámara se mete en el agua (TrailCamera › Dive Camera Underwater, apagado por defecto): niebla, luz desde arriba y la superficie vista desde abajo. |
| Movimiento de la superficie (experimental, apagado) | Surface Motion Enabled, Surface Resolution, Swell Height / Scale / Speed, Player Wave Height | La superficie sube y baja de verdad: oleaje de fondo (`Swell Height` 0,1 m: tres olas senoidales que se cruzan; también inclinan la luz, así que se nota desde lejos) y las ondas del jugador (`Player Wave Height` 0,14 m por onda de fuerza 1). Encendido, lagos y ríos se rehacen con una malla densa (`Surface Resolution`, 0,3 m: el lago grande pasa de ~1.400 a ~11.600 vértices); apagado, vuelven a ser ligeros y planos. El oleaje va en coordenadas de mundo, igual para ríos y lagos, así que las uniones encajan. Las cascadas no se mueven. La ardilla flotando sigue el oleaje (`WaterBody.swell_at()` calcula la misma altura que el shader, con un reloj compartido `motion_time`); las ondas del propio jugador no la mueven. En vivo; cambiar la resolución rehace las mallas (puede tardar un instante en lagos grandes). |
| Ondas del jugador | Player Wave Length, Speed, Strength, Rings, Damping, Falloff, Highlight | Aspecto de las ondas reales que crea el jugador (se activan en Swimming › Ondas reales). Ver [swimming.md](swimming.md). |
| Buceador visible | Swimmer Clarity, Swimmer Tint | Mientras bucea, deja ver sólo al jugador a través del agua (el resto no cambia). Clarity mayor = se ve más hondo; Tint menor = conserva sus colores. Ver [swimming.md](swimming.md). |

**Ideas de estilos:**

| Estilo | Ajustes |
|---|---|
| Referencia (por defecto) | Azul medio, `Clarity` 0,55 (el fondo apenas se ve) y crestas densas con `Scale` 0,9. |
| Arroyo de montaña | `Shallow` verde grisáceo, `Clarity` 2, `Flow Speed` 2,5 y más espuma de rápidos. |
| Laguna tropical | `Shallow` turquesa claro, `Deep` azul intenso, `Clarity` 3 y `Sparkle Amount` 0,4. |
| Pantano | `Shallow` y `Deep` verde oliva, `Clarity` 0,3, `Bed Tint` 0,9, sin destellos ni cáusticas. |
| Agua nocturna | `Self Light` 0,05, `Deep` casi negro, `Sky Color` azul oscuro y destellos tenues. |

## Cómo funciona (resumen técnico)

- **Fondo y espuma:** el shader lee la pantalla y la profundidad de lo opaco. Con eso calcula la
  profundidad del agua en cada píxel, el color por profundidad, el fondo refractado, las cáusticas
  sobre ese fondo y la espuma donde algo corta la superficie.
- **Datos de la malla del río:**
  - UV: espacio de corriente en metros.
  - Tangente: dirección del agua.
  - Color del vértice: pendiente, espuma de cambio de pendiente y distancia al borde.

  La cascada sale de la misma malla cuando la pendiente es casi vertical.
- **Orden de dibujo:** lagos 0, ríos 1, ondas del nadador 2. El desenfoque lejano de la cámara (−128) repinta la
  pantalla sólo con lo opaco; dibujado después, el agua queda encima y no desaparece.
- **Uniones:** dentro de un lago el río se coloca 1 cm por encima de su superficie y se dibuja después. Su transparencia
  (UV2.x de la malla, de 0 en la orilla a 1 tras `Mouth Blend Length`) funde las dos superficies sin cortes ni parpadeo.
  Con `Mouth Blend Enabled` apagado se recorta en la orilla, dejando una fila de solape.
  - El río también se sube al nivel del lago en la franja donde la malla del lago pasa bajo la orilla (`Bank Overlap`),
    para que el borde del lago no se pinte encima del río como una banda.
  - Sus lados se difuminan desde la orilla (UV2.y), así no se ven bordes rectos dentro del lago.
  - La normal del agua se orienta siempre hacia la cámara: las caras de los lagos miran hacia abajo, y antes eso subía al
    máximo el reflejo del cielo y los dejaba más pálidos que los ríos.
  - Todo es automático para cualquier río que entre o salga de un lago a su misma altura (±0,5 m).

## Límites conocidos

- **Unión río–lago:** con tono uniforme sólo cambia el dibujo de las crestas (el río las estira con la corriente); el fundido
  lo mezcla en `Mouth Blend Length`. Con `Depth Tone Amount` alto vuelven las diferencias de tono por profundidad.
- **Cascada:** sin sonido propio todavía, y la neblina no moja ni empuja al jugador (sólo visual).
- **Lejos:** el fondo refractado no se desenfoca como el resto, porque la captura de pantalla es
  anterior al desenfoque. `Far Distance` lo atenúa.
- **Relieve del fondo:** con `vertex_spacing` de 1 m, los triángulos del terreno se notan a través
  del agua clara. Más `Bed Tint` o menos `Clarity` lo disimulan.

## Siguientes fases

- **3. Nado y buceo** y **4. Animación procedural:** hechas. Ver [swimming.md](swimming.md).
- **5. Pulido:** cascada hecha (forma, espuma, neblina y salpicaduras). Pendiente: reflejo del jugador y medición de FPS.
