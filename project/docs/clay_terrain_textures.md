# Texturas clay para Terrain3D

Se prepararon cuatro materiales a partir de las imágenes elegidas por el usuario:
`Grass Clay Clean`, `Cliff Clay Winter`, `Cliff Clay Sculpted` y
`Dirt Clay Sandy`. Están en
`res://assets/textures/clay_terrain/`. No sustituyen las texturas ya pintadas.

Para probarlas, arrastrar cada archivo `*_terrain3d.tres` al panel **Textures**
de Terrain3D y pintar una zona de muestra. `Grass Clay Clean` es la textura
verde sin grumos; `Cliff Clay Winter` es la gris suave; `Cliff Clay Sculpted`
conserva la roca esculpida de la tercera referencia; `Dirt Clay Sandy` es tierra
arenosa clara para senderos.

Cada carpeta contiene `source.png` intacta, `albedo.png`, `height.png` y
`normal.png` para inspección, más los pares RGBA usados por Terrain3D:
`albedo_height.png` (RGB color, alfa microaltura) y
`normal_roughness.png` (RGB normal OpenGL +Y, alfa rugosidad). La microaltura
se estima por contraste local de la imagen, no representa relieve medido.
Su normal da sombreado de detalle; no cambia geometría ni colisión.

Los seis mapas empaquetados (`albedo_height.png` y `normal_roughness.png` de
cada material) deben importarse como **VRAM Compressed**, **High Quality**,
**Normal Map: Disabled** y **Generate Mipmaps: On**, igual que las texturas
ya usadas por este Terrain3D. Tras cambiar una opción en **Import**, pulsar
**Reimport** para cada archivo. Si se añade un material sin esa coincidencia,
Terrain3D no puede reconstruir su array y todo el terreno puede verse negro.
No usar `albedo.png`, `source.png` ni `normal.png` directamente en los slots
del Terrain3DTextureAsset: los pares empaquetados conservan altura y rugosidad.

En el Inspector de cada Terrain3DTextureAsset, **UV Scale** controla el tamaño
del patrón (aumentarlo lo hace más pequeño) y **Normal Depth** controla la fuerza
del relieve aparente (`0` lo aplana). Son cambios visibles en vivo. Las imágenes
se han dimensionado a 1024 × 1024; la continuidad exacta de sus bordes procede
de la fuente y debe revisarse pintando una zona grande.

Conversión reproducible con Godot 4.6:
`Godot --headless --path project --script ../tools/build_clay_terrain_textures.gd`.
Para regenerar sólo la tierra sin tocar las otras texturas, añadir
`-- dirt_sandy` al final del comando.
No ejecutar durante el juego.
