# Pasto alfombra: dos alternativas

Preparado para Godot 4.6 y Terrain3D 1.0.2. Son recursos independientes: todavía no están incorporados a las montañas ni cambian el sistema de nieve, huellas o pasos.

## Comparar primero

Abre `res://scenes/grass_carpet_comparison.tscn` y pulsa **F6**.

- Izquierda: textura de base más hojas 3D opacas.
- Derecha: la misma base, únicamente textura y normal.
- Clic derecho y arrastrar: orbitar. Rueda: acercar/alejar.
- **1** activa/desactiva las hojas izquierdas; permite comparar exactamente la misma superficie.
- **2** activa/desactiva el normal derecho.
- **3** acerca al pasto 3D; **4** a la textura; **5** vuelve a ver ambos.

La escena es un visor de materiales, sin personaje ni colisión. Selecciona `Grass3D`, `BaseUnder3D` o `TextureOnly` para editar sus controles; durante F6 se pueden modificar desde Remote (esos ajustes no se guardan). Para conservar ajustes, modifica la escena en el editor. Luz, cielo y cámara son editables. El visor usa MSAA 4x por defecto para suavizar hojas finas; se puede apagar en el nodo raíz y tiene coste de GPU.

## Pasto 3D

Instancia `res://scenes/props/grass_carpet_3d.tscn`. Selecciona su raíz para ver:

| Grupo | Uso |
| --- | --- |
| Preview | Enabled oculta las hojas; Live Preview agrupa regeneraciones cada 0.3 s; botón Regenerate Grass para reconstruir manualmente. |
| Distribution | Área X/Z en metros, densidad de matas/m², límite total, semilla reproducible y tamaño de bloques para descarte por distancia. |
| Blade Shape | Altura, ancho, hojas por mata, radio de raíces, curvatura y variación de tamaño. |
| Palette | Array Colors: cambia su tamaño de 1 a 32; tres verdes iniciales. Colores de raíz/punta y variación de luminosidad. |
| Lighting | Rugosidad, normales orientadas hacia arriba, luz transmitida y sombras individuales opcionales. |
| Distance | Inicio/fin de reducción de tamaño por distancia. Los bloques lejanos dejan de dibujarse. |
| Optional Wind | Desactivado inicialmente; intensidad, velocidad y dirección disponibles. |
| Terrain3D Placement | Terrain Path, pendiente máxima, alineación, desplazamiento de raíces y filtro por textura pintada. |

Colors vacío usa un verde de respaldo; si agregas más de 32 entradas, solo se usan las primeras 32. Cada color tiene la misma probabilidad por mata. Cambiar la paleta actualiza el material sin redistribuir las plantas. La distribución aleatoria queda estable con la misma semilla y parámetros.

Los controles de material, viento, visibilidad y distancia se actualizan en vivo en editor y juego. Cambiar geometría/distribución regenera automáticamente en el editor con Live Preview activo. En ejecución, llama a `regenerate()` después de modificar esos parámetros. Los hijos generados son transitorios y no se guardan; se recrean al abrir/ejecutar. Nunca se borran hijos colocados manualmente.

Valores iniciales: 12 cm de altura, 2.8 cm de ancho, cuatro hojas por mata y 140 matas/m². Un parche de 12×12 m tiene 20,160 matas y aproximadamente 241,920 triángulos antes del descarte; cada hoja tiene tres triángulos. Es una muestra densa para comparar, no un presupuesto recomendado para cubrir todo un mundo. Para bajar coste, reduce Density, Blades Per Tuft y Fade End. Las sombras están desactivadas. No se ha medido un presupuesto de FPS.

### Usarlo después en Terrain3D

1. Instancia el parche y colócalo sobre la zona deseada. Mantén escala (1,1,1) y rotación sin inclinación para que área/densidad sigan siendo métricas.
2. Asigna el nodo Terrain3D en **Terrain Path**. Se muestrea altura y normal sin depender de la colisión dinámica.
3. Define área, densidad y pendiente máxima. Los huecos y posiciones sin datos se omiten.
4. Si quieres limitarlo al pasto pintado, asigna su ID en **Required Texture ID** y ajusta Minimum Texture Weight. El valor -1 acepta todas las superficies, también nieve. Este filtro no pretende reproducir la cobertura procedural del Auto Shader.
5. Pulsa **Regenerate Grass** después de esculpir/pintar el terreno. Esos cambios externos no disparan regeneración continua.

El parche cubre un área fija: no sigue al jugador ni hace streaming infinito. La distancia reduce el coste de dibujo, pero no libera los datos de instancias. Usa varios parches acotados. La textura de base debe existir debajo para que la transición a distancia resulte suave. Los materiales base y hojas tienen controles independientes.

## Textura y normal

La escena `res://scenes/props/grass_carpet_texture.tscn` ofrece un plano editable con todos los controles agrupados y ayudas en Inspector: tamaño, repeticiones por metro, mapas, Tint, Recolor, contraste, brillo, variación amplia, intensidad de normal y rugosidad. Se actualiza cada 0.2 s.

**Tint** sí permite cambiar el color de la textura. Con **Recolor = 1** se reemplaza su color conservando el detalle; con **Recolor = 0** se multiplica el color original por Tint (usa blanco para ver el original). El parámetro Contrast afecta al modo recoloreado. El normal solo altera la iluminación: no añade hojas, silueta ni colisión.

Para una malla con UVs usa `res://materials/grass_carpet_surface.tres` como material. Hazlo único para editar una copia independiente. Sus Shader Parameters exponen las mismas variables visuales: Texture Scale es repetición por UV, y Tile Size puede convertirla a metros si conoces las dimensiones. Las UVs de una malla arbitraria no garantizan escala métrica ni proyección sin estiramiento.

### Archivos para Terrain3D

En `res://assets/textures/grass_carpet/`:

- `grass_terrain3d.tres`: color verde original, listo como Terrain3DTextureAsset.
- `grass_terrain3d_tintable.tres`: base neutra para cambiar libremente **Albedo Color**, incluida otra gama de colores.
- `grass_albedo.png` y `grass_normal.png`: mapas separados para materiales habituales.
- `grass_albedo_height.png`: RGB color, alfa altura de detalle.
- `grass_neutral_albedo_height.png`: RGB neutro, alfa altura.
- `grass_normal_roughness.png`: RGB normal +Y, alfa rugosidad 0.9.
- `grass_height.png`: altura aproximada de detalle; no es el mapa de alturas de la montaña.
- `grass_source.png`: imagen generada original conservada.

Puedes agregar el recurso `.tres` a la lista de texturas de Terrain3D, asignarle un ID libre y pintar. Si cargas los PNG manualmente, usa los **empaquetados** en Albedo Texture y Normal Texture. Para cambiar apariencia usa Albedo Color, UV Scale y Normal Depth; Roughness=0 en el recurso es el ajuste neutro sobre la rugosidad ya empaquetada. El shader personalizado del plano no sustituye al shader de Terrain3D: esa variante utiliza sus controles nativos y puede verse algo distinta.

Los mapas finales son 1024×1024; los empaquetados usan compresión VRAM de alta calidad, mipmaps y conversión de normal desactivada para preservar el canal alfa. El normal se calcula con diferencias de luminancia del albedo, por lo que es una aproximación artística de microrrelieve, no una medición física. Se pidió repetición continua al generador; no hay garantía matemática de ausencia de costuras, y un terreno muy grande puede revelar repetición. La escala y el contraste ayudan a ajustarlo.

## Procedencia y reproducción

Albedo generado con la herramienta integrada ImageGen, usando las imágenes del usuario como orientación estética (pasto corto, denso, estilizado). Prompt final:

> Use case: stylized-concept. Asset type: seamless square game terrain albedo texture, short carpet grass for a friendly low-poly cartoon game. Create a top-down orthographic evenly lit full-frame dense lawn of very short fine grass, soft moss/apple green palette, small subtle interwoven tapered blade marks, low contrast, no individual large clumps. Reference aesthetic: soft green carpet hills, readable simple stylized surface, not photographic. Texture only, no landscape, no perspective, no sky, no trees, no text, no borders, no shadows or specular lighting baked in, no bare soil, no stones, no flowers. Uniform detail and brightness across image with seamless tiling on both axes. 1024 square.

Conversión técnica y empaquetado reproducible, desde la raíz del repositorio:

```powershell
Godot_v4.6-stable_mono_win64_console.exe --headless --path project --script ../tools/build_grass_textures.gd
```

Este comando reconstruye únicamente los mapas derivados en la carpeta grass_carpet a partir de grass_source.png; sobrescribe esos derivados. No genera arte nuevo ni modifica el original.

Referencias de integración: [Terrain3DData](https://terrain3d.readthedocs.io/en/stable/api/class_terrain3ddata.html), [MultiMesh en Godot 4.6](https://docs.godotengine.org/en/4.6/classes/class_multimesh.html).

Verificación: carga y captura real de la escena de comparación con Godot 4.6/OpenGL Compatibility. Se revisaron vistas general y cercana; no se ejecutaron suites de tests. La adaptación al terreno y la integración de pasos/huellas según superficie quedan por validar al incorporar los recursos a las montañas.
