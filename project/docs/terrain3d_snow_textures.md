# Nieve de Playground para Terrain3D

Recurso listo: `res://assets/textures/snow_playground/snow_playground.tres`.
Con Terrain3D seleccionado, arrastrar el recurso al panel inferior Textures.
Si se configura una entrada manualmente, usar snow_albedo_height.png en
Albedo Texture y snow_normal_roughness.png en Normal Texture.

Basado en la escena terrain_snow_playground.tscn guardada el 2026-10-06:
SnowTerrain usa Material Style Original, terrain_snow.tres, color
(0.88, 0.94, 0.98), grain_enabled=false, roughness=0 y sin detalle mediano.
La descripcion anterior de nieve mate no correspondia a estos valores.

El albedo es una aproximacion generada con ImageGen integrado. La normal
plana y rugosidad negra representan el acabado liso; altura gris neutra.
Los mapas empaquetados RGBA8 son 1024x1024: RGB color / A altura;
RGB normal OpenGL / A rugosidad. Se conservaron tambien los mapas separados.
El alfa de la normal es cero porque guarda rugosidad: que un visor lo muestre
transparente es normal. No activar correccion de bordes transparentes ni
compresion especial de normales: estos canales son datos.

En el Inspector del asset: UV Scale mayor repite mas veces la textura
(0.1 inicial equivale a unos 10 m por repeticion); Albedo Color multiplica el
color; Roughness aumenta la rugosidad respecto al mapa negro (0 conserva el
valor original, 0.8 permite comparar un acabado mate). Normal Depth esta en 0
porque el mapa es plano. AO Strength=0 evita oscurecimiento artificial.
Estos controles cambian la apariencia en vivo, sin regenerar geometria.

La textura no incorpora monticulos, huellas, cobertura por altura/pendiente,
colision ni el microrelieve dependiente de la vista del shader original.
La respuesta especular y la iluminacion de Terrain3D pueden verse diferentes.
Se verifico el empaquetado con Godot 4.6; diferencia maxima entre bordes
opuestos del albedo: 4/255. No es periodicidad matematica exacta; conviene
revisar repeticion y brillo al colocarla en la escena. No se modifico la escena
que el usuario esta editando. Falta la comparacion visual en su iluminacion.

Fuente generada: snow_albedo.png. Prompt usado con la herramienta integrada:
"Use case: stylized-concept. Asset type: single tileable game terrain ALBEDO texture, square 1024x1024. Create an extremely subtle smooth clean snow color map based on an existing Godot shader: base sRGB RGB(224,240,250), no fine grain (disabled in source), only softly interpolated broad noise causing approximately plus/minus 1 percent color variation. Flat orthographic texture filling entire image edge to edge, seamless periodic edges. No directional illumination, shadows, highlights, relief shading, rocks, scene, objects, footprints, crystals, text, border or vignette. This is a plain nearly uniform very pale blue-white snow albedo, not a photograph of snow or a material sphere. Slight broad cloudy variation is almost imperceptible. Surface gloss will be supplied separately in the engine, don't paint reflections."

Empaquetado reproducible: tools/pack_playground_snow.gd desde la raiz del repo,
con Godot --headless --path project --script ../tools/pack_playground_snow.gd.
Utiliza Terrain3DUtil.pack_image y solo sustituye los mapas derivados de esta
carpeta. La fuente generada se conserva.
