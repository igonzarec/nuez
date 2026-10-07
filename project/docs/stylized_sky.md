# Cielo y nubes editables

En `terrain_snow_playground.tscn`, selecciona **StylizedSky** en el árbol de
escena. El Inspector reúne ambiente, distribución de nubes y viento. La escena
reutilizable está en `res://scenes/sky/stylized_sky.tscn`; puede instanciarse en
otro nivel. No hay un reloj ni un ciclo automático.

## Ambiente manual

`Primary Profile` es el ambiente principal; `Secondary Profile` es el destino.
`Profile Blend` va de 0 a 1 y mezcla colores, iluminación, niebla y dirección del
sol. Los cambios se ven en el editor y también funcionan durante el juego.
Para cambiar durante una partida, edita el nodo **Remote**, no el **Local**.

Carga uno de estos recursos desde `res://resources/sky/`:

| Archivo | Ambiente |
| --- | --- |
| day.tres | Azul vivo y nubes blancas; luz inicial de intensidad 0,65. |
| dawn.tres | Amanecer rosado y sol bajo desde el lado opuesto. |
| sunset.tres | Horizonte cálido, cielo violeta y sol bajo. |
| night.tres | Cielo oscuro, luz directa apagada y ambiente azul tenue. |
| overcast.tres | Cielo gris, luz directa tenue y sombras menos marcadas. |

Expande el recurso para editar sus propiedades. Si quieres una variante para
una sola escena, usa **Make Unique** o guarda una copia: editar el recurso
compartido afecta a todas sus referencias. El perfil nublado modifica el
ambiente; la cantidad de nubes sigue siendo una decisión independiente.

`Zenith` es el color sobre la cabeza y `Horizon` el del horizonte.
`Sun Elevation/Azimuth` controlan altura y dirección del sol. `Sun Energy`
ilumina el terreno; `Ambient Energy` aporta luz general. `Shadow Opacity`
reduce la intensidad de las sombras, sin cambiar su resolución geométrica.
`Fog Density = 0` apaga la niebla normal; no se usa niebla volumétrica.
La noche no incorpora aún luna, estrellas ni ciclo automático.

## Nubes

**Live Preview** está activado por defecto en StylizedSky y en las nubes
individuales. Las propiedades que indican «regenerar» se reconstruyen
automáticamente en el editor cuando dejas de modificarlas durante **Preview
Delay** (0,35 s). Al arrastrar un slider se conserva la última malla hasta ese
momento. Colores, dimensiones y proporciones siguen actualizándose inmediatamente.

Desactiva Live Preview para hacer varios ajustes y aplicar todo con **Regenerate
Clouds** o **Regenerate Shape**. Al reactivarlo se aplican los cambios pendientes.
El preview sólo reconstruye en el editor, no automáticamente durante una partida.
Cantidades altas y Roundness elevado pueden causar una pausa al reconstruir;
la espera agrupa cambios, pero no elimina el coste de generación.

Cada nube es ahora una única superficie opaca, extraída de una unión suave de
volúmenes elipsoidales. Los lóbulos son controles de forma, no esferas visibles
superpuestas. Las normales continuas suavizan la luz a través de las uniones.
El sombreado es artístico blanco/azulado. No tienen colisión ni niebla interior.

La forma usa un núcleo alargado, lóbulos en la base y cumbres de distintas
alturas. Sustituye el antiguo anillo simétrico. Una cumbre dominante puede
quedar desplazada hacia un lado, como en la referencia de nube abultada.

| Control | Uso y actualización |
| --- | --- |
| Clouds Enabled | Oculta/muestra el conjunto inmediatamente. |
| Cloud Count | Cantidad deseada; pulsa **Regenerate Clouds**. |
| Distribution Seed | Misma semilla = mismas posiciones y anchuras al regenerar. |
| Distribution Radius | Radio horizontal alrededor del nodo; regenerar. |
| Minimum Spacing | Separación de centros; regenerar. Puede generar menos si no caben. |
| Altitude Range | Altura mínima/máxima relativa al nodo; regenerar. |
| Size Range | Rango de anchuras en metros; regenerar. |
| Cloud Proportions | Altura y profundidad respecto a la anchura; cambia en vivo. |
| Lobes / Irregularity | Complejidad y variación de la forma; regenerar. |
| Shape Seed | Semilla de formas independiente de las posiciones y anchuras; regenerar. |
| Proportion Variation | Diferencia de altura/profundidad entre nubes; cambia en vivo. |
| Lobe Count Variation | Cantidad aleatoria de lóbulos alrededor de Lobes; regenerar. |
| Asymmetry | Desplazamiento de la cumbre dominante hacia un lado; regenerar. |
| Lobe Size Variation | Diferencia de tamaño entre lóbulos; regenerar. |
| Peak Height / Peak Variation | Altura de cumbres y variación entre nubes; regenerar. |
| Base Flatness | Alineación inferior de los lóbulos de base; regenerar. |
| Roundness | Resolución de la superficie fusionada; regenerar. |
| Fusion Softness | Radio de unión suave; mayor valor suaviza hendiduras. Regenerar. |
| Shading Softness | Suavidad de la transición luz/sombra; cambia en vivo. |
| Wind Direction / Speed | Dirección y velocidad en metros/segundo; cambia en vivo. |
| Preview Wind | Anima también en el editor; apagado por defecto. |

Punto de partida para la referencia: Asymmetry 0,65, Lobe Size Variation 0,6,
Peak Height 0,85, Base Flatness 0,75, Proportion Variation 0,35 y Lobe Count
Variation 3. Son los nuevos defaults. Pulsa **Regenerate Clouds** para ver la
nueva geometría en una escena ya abierta. Fusion Softness empieza en 0,14:
prueba 0,18–0,22 para una masa más unificada o 0,08–0,12 para conservar más
abultamientos. Valores altos también engrosan ligeramente la nube. Roundness
28 es el nuevo punto de partida; 36–40 mejora el contorno al acercarse.
La superficie es opaca: la suavidad del borde en pantalla depende también del
antialiasing y el desenfoque, no simula el borde transparente de un volumen.

En una nube individual están Asymmetry, Lobe Size Variation, Peak Height y
Base Flatness. La variación entre nubes pertenece al generador. **Regenerate
Shape** reconstruye sólo esa nube y conserva su posición, rotación y escala.

La distribución no sigue a la cámara: son objetos 3D a una altura real y tienen
paralaje al caminar o volar. El viento los recircula al borde del radio; sitúa
ese borde lejos de las rutas visibles para evitar apariciones perceptibles.
El desenfoque existente afecta a las nubes por su profundidad. No se han cambiado
los valores de blur, nieve, audio ni cámara. Ajusta Blur Strength/Start si las
nubes quedan demasiado difusas.

Para colocar nubes manualmente, arrastra `res://scenes/sky/stylized_cloud.tscn`
al nivel. Mueve, rota y escala su nodo raíz. `Dimensions`, colores y suavidad
se ven en vivo; cambios de semilla, lóbulos o redondez necesitan **Regenerate
Shape**. Las nubes individuales tienen sus propios colores; no reciben los
perfiles del generador automáticamente. Las nubes automáticas son temporales
y regenerarlas reemplaza todo el conjunto: usa la escena individual para
colocaciones que quieras conservar.

## Rendimiento y límites

El punto de partida es 12 nubes, unos 9 lóbulos y Roundness 28. Cada nube tiene
una única malla exterior; ya no se dibujan superficies internas superpuestas.
La extracción muestrea una rejilla y triangula su superficie con tetraedros.
Duplicar Roundness multiplica aproximadamente por ocho las muestras durante
la regeneración; más lóbulos aumentan el coste de evaluar cada muestra.
Durante el juego la malla queda estática: sólo se mueve con el viento. No se
recalcula cada frame. Más nubes aumentan llamadas de dibujo y más resolución
aumenta los triángulos. No proyectan sombras reales sobre el terreno.

Cambiar colores cuesta poco. Regenerar reconstruye geometría y puede producir
una pausa con cantidades altas. Cambiar el perfil puede actualizar el cielo
y sus reflejos; se omiten actualizaciones cuando los valores no cambian.
Conviene empezar con 8–20 nubes y subir la calidad tras revisar rendimiento.

En la escena de nieve se reutilizan WorldEnvironment y Sunlight mediante rutas
del nodo, conservando la configuración de sombras existente. Mientras el cielo
está activo controla sus colores, energías y niebla: edítalos desde el perfil.
En otra escena asigna esas rutas si ya tienes entorno/sol para evitar duplicados.
Con rutas vacías el cielo genera los suyos.

Validación realizada: arranque headless en Godot 4.6 sin errores de scripts.
La compilación gráfica y la revisión visual quedan al usuario en Compatibility:
cielo desde suelo y vuelo,
mezcla 0/0,5/1, nubes manuales, regeneración y visibilidad con blur. Atravesar
nubes no crea todavía una transición de niebla interior.
