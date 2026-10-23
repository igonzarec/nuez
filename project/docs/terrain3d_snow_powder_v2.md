# Snow Powder V2: bordes con grano

Recurso: `res://assets/textures/snow_powder_v2/snow_powder_terrain3d.tres`.
Arrastrarlo al panel **Textures** de Terrain3D y seleccionar **Snow Powder V2**
para pintar. La nieve anterior se conserva y ninguna escena se ha cambiado.

Esta variante conserva el acabado de nieve clara en polvo, con textura hasta
los cuatro bordes. Elimina la franja lisa de la primera versión, que marcaba
una cuadrícula al repetirse. Se inspeccionó una composición de 3 × 3 copias.
La coincidencia de píxeles opuestos no es exacta (diferencia máxima 43/255);
la revisión visual muestra continuidad de estilo, no garantiza una textura
matemáticamente periódica. Revisar también en el nivel, sobre todo con normales
fuertes y luz rasante. La repetición de los motivos sigue siendo posible.

Mapas RGBA8 de 1024 × 1024: RGB albedo + alfa altura en
`snow_albedo_height.png`; RGB normal OpenGL +Y + alfa rugosidad 0.9 en
`snow_normal_roughness.png`. La altura es una aproximación por luminancia.
Se conservan los mapas separados y la fuente ImageGen sin modificar.

Los controles están en el Inspector del Terrain3DTextureAsset y se actualizan
en vivo: **UV Scale** (0.5 inicial; aumentarlo reduce el tamaño del grano),
**Albedo Color** (blanco conserva la fuente), **Normal Depth** (0.65 inicial;
0 aplana el microrelieve), **Roughness** (0 inicial; negativos dan más brillo)
y **AO Strength** (0 inicial; aumentarlo oscurece el relieve aparente).
No cambian geometría ni colisión. Para comparar las dos variantes, mantener
iguales estos valores y la iluminación.

Conversión técnica con Godot 4.6:
`Godot --headless --path project --script ../tools/build_snow_powder_v2.gd`.
Si se restringe la carpeta de usuario, añadir `--log-file` con ruta absoluta
escribible. No ejecutar este script durante el juego.

Generado mediante edición con ImageGen integrado. Prompt completo en
`res://assets/textures/snow_powder_v2/generation_prompt.txt`.
