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
| | Bank Overlap | Metros que la malla se mete bajo la orilla para ocultar su borde. En vivo. |
| | Step / Cross Segments | Densidad de la malla a lo largo y a lo ancho. En vivo. |
| | Break Foam Length | Metros de espuma antes y después de un cambio de pendiente: borde y base de la cascada, inicio de rápidos. |
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
| Superficie | Wave Scale, Wave Strength, Wave Speed, Refraction | Para un lago en calma: `Wave Strength` 0,1–0,2. Para agua picada: `Wave Scale` 1 y `Strength` 0,6. |
| Corriente | Flow Speed, Flow Stretch | La velocidad también la usará el nado. `Stretch` 2–3 da vetas que leen la dirección. |
| Crestas | Color, Scale, Width, Softness, Amount, Strength, Stretch, Wobble, Speed, Trough Shade | **El rasgo principal de la referencia**: la red densa de líneas claras y onduladas que avanza con la corriente. Son curvas de nivel de un ruido deformado, cortadas en trazos. `Scale` 0,6–1 da agua picada; 1,5–3, ondas amplias. `Trough Shade` oscurece los valles para variar el azul. |
| Destellos | Color, Scale, Amount, Softness, Strength, Twinkle | Chispas sueltas encima de las crestas. `Amount` 0,1–0,2 acompaña; más da agua muy brillante. |
| Espuma de orilla | Color, Width, Softness, Noise Scale, Breakup, Strength | Aparece sola donde algo cruza el agua: orillas, piedras y, más adelante, el jugador. |
| Rápidos y cascadas | Ángulos de inicio y completos, Fall Color, Streak Scale, Fall Speed, Rapids Foam, Break Foam | Ángulos de la pendiente de la curva del río. |
| Reflejo | Sky Color, Fresnel Strength / Power, Specular, Roughness | Con `Fresnel Strength` alto, los lagos vistos de lejos se vuelven pálidos. |
| Cáusticas | Color, Scale, Speed, Strength | Luz ondulante sobre el fondo; se apagan con la profundidad. |
| Distancia | Far Distance | Desde aquí el agua se simplifica, para combinar con el desenfoque de la cámara. |
| Bajo el agua | Underwater Color / Light Color, Fog Distance, Tint, Max Fog, Surface Color, Window | Sólo si la cámara se mete en el agua (TrailCamera › Dive Camera Underwater, apagado por defecto): niebla, luz desde arriba y la superficie vista desde abajo. |
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
- **Cascada:** es una cortina recta, todavía sin salpicaduras, neblina ni espuma en la base. Llegan
  en la fase 5.
- **Lejos:** el fondo refractado no se desenfoca como el resto, porque la captura de pantalla es
  anterior al desenfoque. `Far Distance` lo atenúa.
- **Relieve del fondo:** con `vertex_spacing` de 1 m, los triángulos del terreno se notan a través
  del agua clara. Más `Bed Tint` o menos `Clarity` lo disimulan.

## Siguientes fases

- **3. Nado y buceo** y **4. Animación procedural:** hechas. Ver [swimming.md](swimming.md).
- **5. Pulido:** espuma, neblina y salpicaduras en la cascada, reflejo del jugador y medición de FPS.
