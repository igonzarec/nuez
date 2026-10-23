# Nieve en polvo para Terrain3D

Recurso: `res://assets/textures/snow_powder/snow_powder_terrain3d.tres`.
Selecciona Terrain3D y arrástralo al panel inferior **Textures** para añadir
**Snow Powder**; después selecciónalo para pintar. No se ha cambiado ninguna
escena ni textura existente.

Variante nueva de nieve clara, granular y mate. Mapas de 1024 × 1024 RGBA8:
`snow_albedo_height.png` contiene color RGB y altura de detalle en alfa;
`snow_normal_roughness.png` contiene normal OpenGL +Y y rugosidad 0.9 en alfa.
También se conservan albedo, altura y normal separados, y `snow_source.png`.

En el Inspector del Terrain3DTextureAsset, los controles nativos se aplican
en vivo, sin regenerar geometría:

| Control | Uso |
| --- | --- |
| UV Scale | 0.5 inicial: aproximadamente una repetición cada 2 m con separación de vértices de 1 m. Aumentarlo hace el grano más pequeño y repetido. La escala del terreno también influye. |
| Albedo Color | Multiplica el color. Blanco conserva la fuente; un azul muy pálido enfría la nieve. |
| Normal Depth | 0.65 inicial. Aumentarlo acentúa el microrelieve; 0 lo aplana. |
| Roughness | Ajuste respecto al mapa de rugosidad, que parte de 0.9. Inicial 0; valores negativos dan más brillo. |
| AO Strength | Inicial 0 para evitar oscurecer artificialmente el grano. |

La altura se estima a partir de la luminancia, no es un escaneo físico.
No añade acumulación, deformación, huellas, colisión ni nieve por partículas.
Los bordes fueron suavizados con ImageGen; la diferencia máxima medida entre
bordes opuestos es 14/255. No son periódicos exactos: conviene revisar las
uniones y la repetición bajo la iluminación del nivel antes de cubrir áreas
grandes. La apariencia final en el terreno sigue pendiente de revisión visual.

Los PNG empaquetados se importan con mipmaps, compresión VRAM de alta calidad,
sin conversión especial de normales ni corrección de bordes alfa, para conservar
los canales de datos. Godot 4.6 cargó el Terrain3DTextureAsset y ambos mapas
importados a 1024 × 1024. La importación del editor terminó con avisos del
entorno por acceso a cachés/configuración; la carga puntual del recurso pasó.

Conversión reproducible desde la raíz del repositorio:
`Godot --headless --path project --script ../tools/build_snow_powder.gd`.
En entornos restringidos, añadir `--log-file` con una ruta absoluta escribible.
Este script es una herramienta de preparación, no se ejecuta en el juego.

Generación: herramienta integrada ImageGen. Prompt original:

> Use case: stylized-concept. Asset type: seamless square game terrain albedo texture, 1024x1024, for snow in Godot Terrain3D. Primary request: fresh clean slightly compacted powder snow with very subtle soft granular structure and tiny irregular shallow dimples. Style: natural material with restrained stylized softness, suitable alongside a grass carpet terrain texture in an exploration game. Orthographic straight-down flat surface, fills entire frame, equal texture density everywhere. Off-white neutral snow with extremely subtle cool variation, high key but no clipped white. Low contrast fine powder details, no large drifts or distinctive recurring landmarks. Flat diffuse color only, no directional illumination, no cast shadows, no ambient occlusion, no specular highlights or baked reflections. Seamlessly tileable with matching opposite edges, no border or vignette. No rocks, grass, objects, footprints, cracks, snowflakes, text, watermarks, scene or material sphere. Single albedo map only.

Edición final con ImageGen: conservar el material de nieve y reducir ligeramente
el contraste; igualar los cuatro bordes a un blanco azulado cercano a
RGB(231,236,242), suavizando unos 20 píxeles hacia dentro, sin marco visible.
