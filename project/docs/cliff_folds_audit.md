# Auditoría de CliffFolds (2026-10-30)

Revisión de sólo lectura de `scripts/terrain/cliff_folds_generator.gd` (1 021 líneas, 66
exportaciones), `scripts/terrain/cliff_contour_builder.gd` (879 líneas) y los shaders
`cliff_slope_surface.gdshaderinc`, `cliff_slope_surface.gdshader` y `cliff_slope_fade.gdshader`.
No se cambió código. Las verificaciones previas fueron renders; no hay medición de FPS.

## Veredicto

El **núcleo es sólido**: la generación lee alturas sin modificarlas, es determinista y siempre
parte de cero. La gestión de agujeros propios, el bake y la detección de bake desactualizado
impiden fallos silenciosos.

La **unión con Terrain3D está parchada**. Casi todos los ajustes recientes compensan el mismo
origen: una malla superpuesta a un terreno con LOD por anillos y agujeros por vértice. Cada parche
es razonable y está probado, pero hay demasiadas capas que interactúan, y la integración depende de
nombres internos de Terrain3D.

## Prioridad alta: robustez

**A1 · Acoplamiento con internos de Terrain3D.**
- El override se construye buscando texto en el shader de Terrain3D:
  - `VERTEX_ANCHOR` y una regex sobre `auto_blend`.
  - Las variables `scale`, `start_pos`, `vertex_lerp` y `v_vertex`, y `get_index_coord`.
  - `_control_maps` con el bit 2 de agujero.
- Si Terrain3D cambia, el override se omite con un aviso, pero el fallo apenas se ve: vuelven los
  picos o la mezcla lineal.
- Recomendación:
  - Aislarlo en un módulo propio (`terrain3d_override.gd`).
  - Comprobar la versión del plugin y avisar si no es una versión probada.
  - Documentar una comprobación manual de 5 minutos para cada actualización de Terrain3D.

**A2 · Se puede perder un override propio del usuario.**
- Si el material ya tenía un override sin la marca de CliffFolds, se parchea una copia y se marca
  como nuestro.
- Al apagar Rock By Angle y Far Spike Fix, `_apply_terrain_override` pone el override a `null`, y
  el original del usuario desaparece.
- Recomendación: guardar el override original (`@export_storage`) y restaurarlo.

**A3 · El generador se adueña del material de Terrain3D.**
- Cada regeneración reescribe `auto_shader`, `auto_base_texture`, `auto_overlay_texture` y
  `auto_slope` (`_apply_terrain_material`).
- Si alguien los cambia en Terrain3D, se pierden al regenerar.
- Recomendación: un interruptor "Manage Terrain Material" o, como mínimo, documentarlo junto a
  esos controles.

**A4 · El LOD de malla puede hundir el collar bajo el terreno.**
- `generate_lods` simplifica todo el chunk, incluido el collar, que debe quedar 2 cm sobre la
  escultura.
- Al simplificarse puede quedar por debajo y dejar asomar la hierba de Terrain3D en cimas y pies.
  Es el principal sospechoso de los "cortes" en la cima.
- No lo pude reproducir forzando el LOD, así que no está confirmado.
- Recomendación (elegir una):
  - Separar el collar y la banda de fundido en una superficie sin LOD y dejar el LOD sólo para los
    pliegues.
  - O dejar `Mesh LOD` apagado por defecto hasta que el mapa lo necesite.

**A5 · Reconstrucción en el juego.**
- `Rebuild Stale Bake` evita caer al vacío, pero cuesta unos 5 s en el hilo principal.
- Los agujeros que abre sólo existen en memoria.
- Es correcto como red de seguridad. En una exportación debería anotarse en el log, y conviene
  decidir si se mantiene activo en builds de release.

## Prioridad media: simplificación y deuda

**M1 · Demasiadas capas de costura.**
- Las capas son: `seam_lift`, `seam_depth_offset`, collar (`seam_overlap`), banda tramada,
  banda opaca de lejos, faldón (sólo sin fundido), inset mínimo de agujeros, `_protect_end` y
  `_no_hole`.
- Recomendación:
  - Definir un único modelo: collar opaco + banda de fundido + adelanto en profundidad.
  - Retirar el faldón y unir lift y depth offset si no aportan por separado.

**M2 · Dos sistemas de texturizado.**
- *Match Terrain Shading* encendido usa una réplica del Auto Shader. Apagado usa la mezcla antigua
  por Rock Start/Blend Angle, triplanar con la normal de la malla.
- Tu escena usa el modo antiguo. Ahí la hierba de la malla tiene otra escala y otra proyección que
  Terrain3D, así que la unión en las cimas se nota por fuerza.
- Recomendación:
  - Probar primero con Match encendido; no requiere código.
  - Después, elegir un solo modo. Si el antiguo gusta más en los pliegues, usarlo sólo donde
    `relief > 0` y copiar el terreno en collar y banda.

**M3 · Réplica manual del Auto Shader.**
- `cliff_surface_albedo()` copia la fórmula de mezcla, la proyección y la escala de Terrain3D.
- Se desincroniza si Terrain3D cambia. Va ligado a A1.

**M4 · Estado muerto y controles de migración.**
- `_amplitude`, `_positions` y `_subdivisions` sólo se declaran y se vacían.
- `edge_fade_cells`, `max_subdivisions`, `reconstruct_surface` y `visibility_range` son de
  migración.
- `copy_reference_settings` depende de que exista `cliff_playground.tscn`.
- Recomendación: retirarlos tras confirmar que ninguna escena los necesita, y revisar los grupos
  del Inspector (66 exportaciones).

**M5 · Nombres desfasados.** `_update_rock_angles` ya empuja también el LOD bias, el fundido
lejano, Clean Rock Edge y Far Spike. Conviene renombrarlo a `_push_live_params`.

**M6 · Aviso "Los ajustes cambiaron desde el bake" demasiado sensible.**
- `_preview_parameters` incluye controles en vivo que el juego ya aplica al cargar: ángulos de
  roca, fundido lejano, LOD bias, Far Spike Push/Reach.
- Recomendación: separar los parámetros que exigen hornear de los que se aplican en vivo.

**M7 · Constantes ocultas.**
- Tolerancia de bake desactualizado (2 cm).
- Far Spike: umbral de 60° y 24 muestras.
- Clean Rock Edge: 0,15 y 0,03.
- Otras: `normal_split_angle` 60 y `MIN_GROUP` 32.
- Son técnicas, pero el umbral de 60° del Far Spike debería seguir a `Minimum Slope`.

**M8 · Coste del Far Spike en GPU.**
- Todo vértice de los anillos gruesos sin un cliff cerca recorre las 24 lecturas antes de
  descartarse. Sólo los que tienen un cliff cerca salen antes.
- Probablemente barato, pero sin medir.
- Recomendación: perfilar. Si pesa, usar un primer anillo de 8 muestras y sólo continuar si hay
  desnivel.

**M9 · Escala con el tamaño del mundo.**
- Regenerar lee todo el terreno y reconstruye todos los cliffs por cualquier cambio (~5 s ahora).
- El bake es un único archivo de 11 MB.
- En un mundo grande convendrá regenerar por región o por cliff, con bakes separados.

## Aceptar como límite (documentado)

- **L1.** Astilla en el contorno de un pilar contra el cielo a más de ~200 m: no hay nada detrás
  que gane en profundidad.
- **L2.** Junto a un cliff lejano, el terreno empujado puede dejar ver lo que esté justo detrás o
  enterrado.
- **L3.** Los triángulos gruesos del borde de los agujeros tienen normales de pared; la banda
  opaca de lejos los tapa.
- **L4.** Cuevas y voladizos no son posibles con un heightmap.
- **L5.** Tres fuentes de verdad: escena (agujeros propios, override, ajustes), bake y datos de
  Terrain3D. Están vigiladas por la detección de bake desactualizado, la recuperación y la unión
  de agujeros. Hornear y cerrar sin Ctrl+S deja agujeros no registrados, que "Adoptar" resuelve.

## Seguimiento 2026-10-31: modelo sin agujeros, descartado

Para atacar la raíz de los parches se probó Terrain3D sin agujeros con los pliegues desplazados
hacia fuera. Los detalles están en `automatic_cliff_playground.md`, sección *Alternativa
descartada*.
- **Resultado:** la escalada se mantenía, pero los picos lejanos seguían apareciendo. Vienen del
  LOD de Terrain3D en la esquina cóncava del pie, no de los agujeros, así que Far Spike Fix sigue
  siendo necesario.
- **Decisión:** se mantiene el modelo con agujeros, que además gusta más estéticamente.
- **Consecuencias para esta auditoría:**
  - A1 y M8 no se pueden eliminar cambiando de modelo: Far Spike Fix es estructural mientras haya
    malla sobre Terrain3D. Aislarlo y vigilar la versión (A1) gana prioridad.
  - Queda **Rock Follows Cliffs**, que deriva los ángulos de roca de Minimum Slope. Resuelve la
    parte de M7 que tocaba a la roca; el umbral de 60° del Far Spike sigue fijo.

## Plan sugerido

1. **Sin código:** activar Match Terrain Shading y revisar los cortes de la cima (M2). Si
   persisten, subir Mesh LOD Bias o apagar Mesh LOD (A4).
2. **Endurecer:** módulo de override con comprobación de versión y override del usuario
   preservado (A1, A2). Esfuerzo medio.
3. **LOD seguro:** collar y banda sin LOD (A4). Esfuerzo bajo-medio.
4. **Limpieza:** estado muerto, renombrado y separación de parámetros en vivo (M4–M6). Esfuerzo
   bajo.
5. **Decisión de diseño:** un modelo de costura y un modo de textura (M1, M2). Es lo que más
   reduce la sensación de parche.
6. **Medir:** perfilar FPS en el juego con y sin Far Spike Fix y Mesh LOD (M8).
