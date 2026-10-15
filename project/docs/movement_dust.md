# Polvo de carrera

Al correr manteniendo Sprint sobre suelo caminable, la ardilla deja
una nube de bolitas low-poly 3D blancas y redondeadas detrás de las patas. Hay
una única fuente de partículas; sus elementos se dispersan y desaparecen sin
crear nodos nuevos mientras el jugador se mueve.

Los controles viven en `SquirrelExplorer`, Inspector > **Polvo de movimiento**.
Los cambios se ven en vivo durante F6. `Run Speed` fija a partir de qué
velocidad aparece durante carrera; `Density` controla cuántas bolitas viven
a la vez. No emite en Slide, salto, escalada ni planeo. Las bolas existentes
terminan su vida al dejar de correr. `Source Offset` mueve la única fuente
y `Spread Degrees` abre o concentra la nube.

Cada bola nace con diámetro aleatorio entre `Size Min/Max`, inicialmente opaca
(`Opacity = 1`). `Final Size Min/Max` fija el diámetro final en metros de forma
independiente: empieza con 0,07–0,33 m y acaba en 0,88–1,31 m. La variación de
forma puede estirar estos diámetros por eje. `Fade Start`
indica cuándo empieza a perder opacidad. Las bolas no giran; `Shape Variation`
varía suavemente sus proporciones y `Lifetime Randomness` escalona su duración.
Los valores iniciales permiten desvanecimiento tras el primer 20 %
de vida. Las partículas usan coordenadas
globales para quedarse atrás mientras la ardilla avanza; no siguen sus giros.

La opacidad predeterminada cambia a 1 para este comportamiento. Cualquier
override guardado en una escena se conserva: ajústalo a 1 si antes lo bajaste.

El emisor GPU reserva 288 partículas y cambia `amount_ratio` al variar la
densidad desde el Inspector. Así no reinicia la simulación ni borra las
bolas existentes en cada transición. La reserva tiene un coste fijo pequeño;
no aumentes su capacidad sin medir. Cambiar Lifetime durante la ejecución
puede reiniciar el ciclo; los cambios habituales de estado no lo cambian.

El sombreado artístico usa dos tonos y no depende de las luces de escena:
`Light Color` y `Shadow Color` eligen colores; `Shadow Strength` controla
contraste; `Shadow Threshold` amplía la región sombreada; `Shadow Softness = 0`
da un borde duro (default), y 0,03 una transición estrecha. `Light Direction` orienta la
luz artística en ejes del mundo. Es sombra sobre las bolas, no proyectada al
suelo. Todo se actualiza en vivo, incluidos tamaños de partículas ya visibles.

Los defaults del script reflejan el ajuste aprobado y guardado en
`3D_playground.tscn`: densidad 96, vida 1,2 s, deriva 2,4 m/s, apertura 10°,
fuente (0; 0,1; 0,555) m, anchura 0,2 m y altura 0,08 m. Los colores de luz
y sombra también se copiaron de esa escena, con intensidad 1, umbral 0,55 y
suavidad 0. Los overrides de las escenas se conservan.

Para una nube compacta con volumen, usa `Scatter Width` (anchura total de la
fuente) y `Scatter Height` (altura por encima de Source Offset). Ambos están
en metros y distribuyen posiciones aleatorias de nacimiento en X/Y sin añadir
dispersión en Z. La fuente sigue siendo una sola. `Rise Acceleration` controla
la flotación posterior, independiente de Drift Speed. Los defaults usan
Width 0,2 m, Height 0,08 m y Rise 0,3 m/s². Spread Degrees
sigue abriendo las velocidades de salida; con Drift bajo su efecto es menor.
