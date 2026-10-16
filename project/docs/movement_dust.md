# Polvo de carrera

El mismo emisor también sirve para el [aterrizaje deslizante de planeo](glide_landing.md),
con fuente, anchura X, profundidad Z, densidad y tamaño propios en el grupo
**Aterrizaje de planeo** del nodo raíz del jugador.

Al correr manteniendo Sprint sobre suelo caminable, la ardilla deja
una nube de bolitas low-poly 3D blancas y redondeadas detrás de las patas. Hay
una única fuente de partículas; sus elementos se dispersan y desaparecen sin
crear nodos nuevos mientras el jugador se mueve.

Los controles viven en `SquirrelExplorer`, Inspector > **Polvo de movimiento**.
Los cambios se ven en vivo durante F6. `Run Speed` fija a partir de qué
velocidad aparece durante carrera; `Density` controla cuántas bolitas viven
a la vez. También emite al resbalar si Slide Dust Enabled está activo;
no emite durante salto, escalada ni planeo aéreo. Las bolas existentes
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

## Adaptación a pendientes

En **SquirrelExplorer > Polvo de movimiento**:

- **Movement Dust Surface Follow Enabled**: activado por defecto. Proyecta la
  fuente sobre el plano de suelo, comprueba terreno bajo ella y orienta la
  emisión y su dispersión según la normal local. Actúa en Sprint y aterrizaje
  de planeo, sin cambiar Source Offset, tamaño, densidad ni otros ajustes guardados.
- **Movement Dust Surface Clearance**: 0,03 m adicionales sobre el suelo.
  Aumentarlo separa la fuente; se suma a Source Offset Y.
- **Movement Dust Surface Probe Distance**: 1 m de búsqueda a ambos lados
  del punto de emisión a lo largo de la normal. Una consulta por frame mientras
  emite; si no encuentra suelo caminable usa el plano bajo los pies.
- **Movement Dust Surface Lift Speed**: 0,6 m/s de velocidad inicial hacia
  fuera de la superficie. Drift Speed sigue siendo la componente hacia atrás,
  ahora tangente al suelo; Rise Acceleration conserva la flotación vertical.

Todos se guardan con la escena y responden en vivo. Los cambios de orientación
y fuente afectan nuevas partículas; las anteriores siguen en espacio global,
sin arrastrarse con el personaje. No hay colisión individual de partículas:
crestas, superficies curvas, tamaños finales grandes o Spread alto aún pueden
cruzar parcialmente el terreno. Aumentar ligeramente Clearance/Lift Speed o
reducir tamaño/Spread permite afinar esos casos, sin alterar la montaña.

## Resbalamiento en pendientes

En **SquirrelExplorer > Deslizamiento en pendientes**:

- **Slide Max Speed**: límite de velocidad por la pendiente, inicialmente
  3 m/s; 0 permite anular el desplazamiento tangencial de este estado.
- **Slide Acceleration**: rapidez con la que alcanza esa velocidad,
  inicialmente 7 m/s². Más bajo produce una bajada gradual.
- **Slide Steering**: control lateral, sin permitir empujar cuesta arriba.
- **Slide Dust Enabled**: activo inicialmente. Reutiliza el polvo de correr,
  sin necesitar Sprint ni superar Movement Dust Run Speed.
- **Slide Dust Min Speed**: 0,3 m/s tangenciales; umbral independiente para
  no emitir quieto. Usa velocidad sobre la superficie, no sólo horizontal.

Los controles se guardan con la escena y se consultan en vivo. Se conservan
los valores actuales de velocidad, aceleración y dirección. El polvo comparte
color, tamaño y densidad de carrera y requiere **Movement Dust Enabled**.
Con Surface Follow Enabled utiliza la normal de la pendiente no caminable,
inclina la fuente y deja la estela detrás de la dirección de resbalamiento,
aunque la ardilla mire hacia otro lado. No afecta el agarre ni Surface Assist.
