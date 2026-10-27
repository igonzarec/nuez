# Soft Surface

Colección preparada desde las tres imágenes elegidas en `graphics/`, más dos
variantes de pasto con tierra generadas con ImageGen. Las fuentes se conservan.
Los recursos están en
`res://assets/textures/soft_surface/`:

| Carpeta | Nombre en Godot | Fuente |
| --- | --- | --- |
| `grass` | Soft Surface Grass | `grass carpet new.png` |
| `cliff` | Soft Surface Cliff | `maybe cliff.png` |
| `grass_semi_realistic` | Soft Surface Grass Semi Realistic | `grass carpet semi realistic.png` |
| `grass_path_dust` | Soft Surface Grass Path Dust | `soft surface grass path dust.png` |
| `grass_path_dust_green` | Soft Surface Grass Path Dust Green | `soft surface grass path dust green.png` |

Cada carpeta contiene una copia intacta `source.png`, mapas de 1024 × 1024
`albedo.png`, `normal.png` y `height.png`, y los dos mapas RGBA para Terrain3D:
`albedo_height.png` (RGB color, alfa microaltura) y `normal_roughness.png`
(RGB normal OpenGL +Y, alfa rugosidad 0.9). El tamaño coincide con las texturas
existentes del terreno. Hay una vista de conjunto en `soft_surface_preview.png`.

Se suavizan 24 píxeles junto a cada borde para igualar los bordes opuestos,
conservando el interior y la paleta. La microaltura se estima usando contraste
local, separándolo de las manchas amplias de color. Las normales son una
aproximación artística del detalle, no geometría medida; no cambian colisión
ni silueta. La variante semi realistic conserva un detalle más marcado.

## Uso y controles del Inspector

Para una malla normal, asignar el archivo `*_surface.tres` a **Material Override**
del MeshInstance3D o al material de una superficie. Es un StandardMaterial3D:

- **Albedo > Texture / Color**: imagen y tinte. Color blanco conserva la fuente.
- **Normal Map > Enabled / Scale**: activa el relieve y ajusta su intensidad.
  Valor inicial 0.6; reducirlo suaviza el detalle y 0 lo aplana.
- **Roughness**: valor inicial 0.9, mate. Aumentarlo reduce los reflejos.
- **UV1 > Scale**: repeticiones sobre las UV de la malla; aumentar X/Y hace
  más pequeño el patrón. Por ejemplo, `(2, 2, 1)` duplica las repeticiones.

Para Terrain3D, arrastrar el archivo `*_terrain3d.tres` al panel **Textures** y
pintar una zona de muestra. No se ha añadido a ningún terreno automáticamente.
Seleccionar el asset para ajustar **Normal Depth** (0.6 inicial; 0 plano),
**UV Scale** (0.5 inicial; aumentarlo reduce el tamaño del patrón),
**Albedo Color** (blanco conserva los colores) y **Roughness**
(ajuste adicional sobre el canal empaquetado). **AO Strength** empieza en 0.
Todos estos controles se actualizan en vivo y usan la ayuda integrada de Godot
y Terrain3D. No se agregan propiedades exportadas personalizadas.

Los pares empaquetados llevan configuración de importación **VRAM Compressed**,
**High Quality**, **Normal Map: Disabled**, mipmaps activos y alfa sin corrección
de bordes, igual que el resto de assets Terrain3D del proyecto. Mantener esos
ajustes comunes para evitar incompatibilidades del array de texturas. El mapa
`normal.png` independiente sí usa importación **Normal Map: Enabled** para el
StandardMaterial3D. Godot generará sus cachés al importar los recursos.

## Regeneración

Ejecutar desde la raíz con Python, Pillow y NumPy:

```powershell
python tools/build_soft_surface_textures.py
```

Opciones: `--size 1024`, `--normal-strength 3`, `--detail-gain 1.8`,
`--seam-width 24` y `--roughness 0.9`. `--help` muestra sus descripciones.
Cambiar estas opciones requiere regenerar y reimportar los mapas; no son
controles de ejecución. Mantener 1024 para combinar con el Terrain3D actual.
Por ejemplo, `--normal-strength 1.5` genera normales más suaves para las tres
variantes. La rugosidad empaquetada sí se regenera, pero un material existente
conserva el ajuste de Roughness del Inspector y debe ajustarse allí si se desea.

El generador reutiliza la copia `source.png` y actualiza únicamente los mapas
derivados y la vista de conjunto. Sólo crea materiales y ajustes de importación
si no existen, para conservar personalizaciones posteriores.

Se revisó visualmente el albedo, el normal y un mosaico 2 × 2 de cada variante,
y se comprobaron tamaños y canales. Falta comprobar el sombreado y la escala
con iluminación real dentro de Godot 4.6.

## Pasto con espolvoreado de camino

`grass_path_dust` conserva la primera mezcla de verde y tierra beige;
`grass_path_dust_green` aumenta la presencia del verde conservando polvo
difuminado. Las dos mantienen el acabado suave de Soft Surface. Se guardan
los originales de ImageGen en `graphics/` y las copias `source.png` antes
de dimensionar y suavizar los bordes para el juego.

Para regenerar sólo estas dos sin tocar las otras variantes:

```powershell
python tools/build_soft_surface_textures.py --only grass_path_dust grass_path_dust_green
```

Su comparación está en
`res://assets/textures/soft_surface/soft_surface_grass_path_dust_grass_path_dust_green_preview.png`.
Usar `grass_path_dust_terrain3d.tres` y
`grass_path_dust_green_terrain3d.tres` en el panel Textures de Terrain3D,
o sus respectivos `*_surface.tres` en mallas normales. No se modificaron los
assets del terreno ya pintado.

Prompt de la variante verde (ImageGen, edición de la primera mezcla): conservar
el grano suave, plano y difuminado; aumentar la cobertura verde aproximadamente
al 75 % y reducir el polvo beige aproximadamente al 25 %, con manchas suaves
distribuidas, sin dibujar un sendero ni agregar detalle marcado. Los porcentajes
son una guía artística para la generación, no una medición del resultado.
