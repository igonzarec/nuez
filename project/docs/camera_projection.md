# Proyección de cámara: perspectiva u ortográfica

La cámara orbital (`project/scripts/player_camera.gd`) puede usar proyección
**ortográfica**: sin perspectiva, el tamaño en pantalla no depende de la
distancia y las líneas paralelas siguen paralelas (look diorama). Todo lo demás
funciona igual: stick derecho, recentrado R2, seguimiento frontal, planeo,
colisión de cámara y agua. Por defecto sigue en Perspectiva.

## Dónde están los controles

Selecciona `CameraRig` en la escena (o abre `project/scenes/camera_rig.tscn` y
selecciona su raíz para cambiar los defaults compartidos). En el Inspector,
grupo **Proyección**:

| Propiedad | Qué hace |
|---|---|
| `Projection` | Perspectiva u Ortográfica. |
| `Ortho Size` | Ortográfica: alto visible en metros. Es el zoom. |
| `Near Clip` / `Far Clip` | Planos de recorte cercano y lejano (se aplican en ambas proyecciones). |

Se actualiza en vivo; con el juego en marcha se puede pulir desde el árbol
*Remote* → `CameraRig`.

## Qué cambia en ortográfica

- **El zoom es `Ortho Size`.** `Distance` y `Field Of View` ya no agrandan ni
  achican al personaje: `Distance` sólo aleja la cámara, lo que ayuda a que el
  terreno cercano no quede cortado por `Near Clip`.
- **La colisión sigue sirviendo**: elevar la cámara sobre un obstáculo destapa
  al jugador igual que antes.
- **Al subir o bajar la inclinación** el giro se percibe más "de maqueta",
  porque no hay perspectiva que dé profundidad.
- Desenfoque de distancia, siluetas, niebla submarina y revelado del nadador
  reconstruyen la profundidad con la proyección inversa de la cámara, así que
  funcionan igual en ortográfica.

## Ejemplo

Diorama: `Projection` Ortográfica, `Ortho Size` 20–30, `Pitch Degrees` en torno
a -35, `Distance` 30 o más.

Rendimiento: un `Ortho Size` grande muestra más terreno y objetos a la vez.
