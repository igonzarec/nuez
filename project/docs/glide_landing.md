# Aterrizaje deslizante de planeo

En `res://scenes/player.tscn`, selecciona el nodo raíz **SquirrelExplorer**.
Los controles están en Inspector > **Aterrizaje de planeo**. Se pueden afinar
en **Remote** durante el juego; copia después los valores a **Local** y guarda.

Al tocar suelo caminable mientras Glide está activo, se conserva la postura
del clip y se usa **Animation > Postura de planeo > Glide Lean Degrees** como
inclinación: no se suman los extras de movimiento ni de Sprint y se elimina
el banking de giro durante el roce. El clip queda pausado brevemente, con
las membranas visibles, mientras la inercia horizontal desliza al personaje.
No se aplica la contracción del aterrizaje normal ni se generan pasos de
carrera durante este estado. El audio de vuelo termina al tocar suelo.

| Control | Inicial | Qué ajusta |
| --- | --- | --- |
| Glide Landing Enabled | Sí | Activa el comportamiento; apagarlo termina el estado actual. |
| Glide Landing Duration | 0,35 s | Duración máxima, capturada al aterrizar. 0 desactiva el efecto. |
| Glide Landing Pose Delay | 0,06 s | Tiempo conservando la inclinación de llegada antes de cambiarla. |
| Glide Landing Pose Blend Duration | 0,16 s | Transición gradual hacia el ángulo normal de Glide. |
| Glide Landing Contact Grace | 0,06 s | Tolera pérdidas breves de contacto sin abandonar la pose; la gravedad sigue actuando. |
| Glide Landing Speed Retention | 0,8 | Fracción de velocidad horizontal retenida al contacto. Se captura al aterrizar. |
| Glide Landing Braking | 10 m/s² | Frenado continuo; mayor valor acorta la distancia deslizada. |
| Glide Landing Clearance Enabled | Sí | Activa la separación visual de torso y cabeza respecto al suelo. |
| Glide Landing Clearance Margin | 0 m | Margen mínimo sobre el plano de apoyo. |
| Glide Landing Belly Sink | 0,25 m | Resta margen sólo al torso para permitir hundir la panza. El deslizador admite hasta 1 m y se pueden escribir valores mayores. No obliga a bajar el modelo si otras piezas requieren separación. |
| Glide Landing Clearance Max Lift | 0 m | Límite de elevación visual para corregir penetración. |
| Glide Landing Clearance Recovery | 12 s⁻¹ | Rapidez al recuperar la altura visual normal. |
| Glide Landing Dust Enabled | Sí | Activa el polvo durante el roce; requiere Movement Dust Enabled. |
| Glide Landing Dust Source Offset | (0; 0,1; 0) m | Centro de la emisión respecto al jugador: X lateral, Y arriba, +Z detrás. |
| Glide Landing Dust Width | 0,9 m | Anchura total X bajo el cuerpo. |
| Glide Landing Dust Depth | 0,25 m | Profundidad total Z de la zona de roce. |
| Glide Landing Dust Height | 0,05 m | Altura de emisión desde Source Offset. |
| Glide Landing Dust Density | 48 | Densidad nominal del efecto. |
| Glide Landing Dust Size Multiplier | 0,8 | Multiplica los tamaños iniciales y finales del polvo de carrera. |

El resto de los valores se consulta en vivo. Ejemplos: **Duration = 0,5 s** y
**Braking = 6** prolongan el deslizamiento. **Dust Width = 1,2 m** y **Depth =
0,4 m** distribuyen la nube bajo una zona más extensa. Ajustar **Source Offset
X** desplaza el centro a un lado; **Width** es lo que reparte el polvo entre
ambos lados. Mantén **Source Offset Y** cerca del suelo.

Los defaults de margen, hundimiento y elevación máxima recogen los valores
elegidos y guardados en `player.tscn`. Con **Max Lift = 0** no se aplica
elevación correctora automática; Margin y Belly Sink vuelven a influir si
se aumenta ese límite.

La protección contra el suelo comprueba las ocho esquinas de las cajas de
torso y cabeza y eleva sólo `BodyPivot`, dejando el polvo cerca del suelo y
la cápsula sin cambios. Usa el plano obtenido por un rayo bajo el jugador;
cuesta un rayo por paso físico durante el roce y dieciséis comprobaciones de
esquinas por frame. Es conservadora y puede dejar un pequeño espacio visible.
No es una colisión exacta de la malla: no cubre otras extremidades ni una roca
o cambio brusco de relieve fuera del plano central. Si alcanza Max Lift aún
puede existir penetración; afina el ángulo normal y el margen según el modelo.
Al terminar el roce, la elevación visual se desvanece con Recovery.

**Belly Sink** permite penetración sólo para la caja del torso. Por ejemplo,
con **Margin = 0,02 m** y **Belly Sink = 0,05 m**, se toleran hasta 0,03 m
bajo el plano para esa caja. La cabeza conserva el margen positivo y puede
seguir obligando a elevar el modelo. Esta opción permite penetrar; no fuerza
un descenso por debajo de la altura base de la cápsula.

La inclinación ya no cambia instantáneamente: mantiene la de llegada durante
Pose Delay y después usa una curva suave durante Pose Blend Duration.
Para una transición más pausada prueba 0,08 s y 0,2 s respectivamente, con
Duration de al menos 0,35 s. Contact Grace añade histéresis de salida para no
abandonar la pose por un único paso físico sin apoyo; el polvo no emite sin
suelo y un salto voluntario sigue cancelando inmediatamente.

El polvo reutiliza el emisor de `movement_dust.gd` y sus colores, textura de
sombreado, duración, opacidad, dispersión y deriva. La configuración de carrera
conserva su fuente y anchura originales. No se añade otro emisor: se mantiene
la reserva existente de 288 partículas. Los tamaños compartidos pueden
actualizar también partículas que ya estén vivas al cambiar de modo.
Sólo emite mientras hay desplazamiento sobre suelo; las bolas ya emitidas
terminan su vida al detenerse.

Durante este breve estado se conserva la dirección de llegada y no se dirige
con el stick. Al acabar, caminar o correr recuperan el control. Una nueva
pulsación de salto, perder el suelo más allá de Contact Grace o entrar a una pendiente no caminable
cancelan el estado; respawn también limpia su temporizador. El desplazamiento
usa `move_and_slide` y conserva las colisiones, sin teletransportar ni cambiar
la cápsula del personaje. No se activa al aterrizar sin Glide.
## Adaptación de la pose a pendientes

En **SquirrelExplorer > Aterrizaje de planeo**, **Glide Landing Surface Follow
Enabled** adapta la orientación visual a la normal del apoyo, incluyendo
inclinación lateral, antes de aplicar el ángulo normal de Glide. Respeta
**Pose Delay / Pose Blend Duration**, y no usa la inclinación extra de sprint.

- **Surface Follow Strength**: 1 inicial; 0 no añade inclinación del terreno.
- **Surface Follow Response**: 18 s⁻¹; mayor responde antes y menor suaviza.
- **Surface Max Tilt Degrees**: 55°; limita el ángulo añadido por la pendiente.
- **Slope Clearance Max Lift**: 0,30 m; amplía el máximo de corrección visual
  sólo en pendiente, con Clearance Enabled y Surface Follow Enabled activos.
  0 conserva el máximo anterior. No cambia la altura máxima de suelo plano.

Todos se guardan con la escena y se consultan en vivo. Se conservan los valores
previos de **Belly Sink** (permite hundimiento del torso), **Clearance Margin**
y **Clearance Max Lift**. La corrección usa cajas de mallas contra el plano
de apoyo, no una colisión exacta con cada irregularidad. No gira la cápsula
ni modifica el movimiento físico. Durante la transición o en crestas abruptas
puede persistir algo de cruce; para reducirlo aumentar Response/Max Lift o
reducir Belly Sink, sin sobrescribir automáticamente los ajustes artísticos.

## Transición simple al tocar pendiente

Se retiró el experimento Visual Sink: no se necesita hundir el modelo para
suavizar el cambio de orientación al llegar desde el aire. No se modificaron
los valores anteriores de Belly Sink ni de separación.

Los tres controles principales siguen en **Aterrizaje de planeo**:

- **Glide Landing Pose Delay** conserva brevemente la orientación completa
  con la que llega planeando (incluidos giros laterales).
- **Glide Landing Pose Blend Duration** determina cuánto tarda en mezclar
  esa orientación con la pose de Glide normal adaptada al plano de suelo.
- **Glide Landing Contact Grace** tolera pérdidas breves de apoyo para no
  abandonar y reiniciar la transición en cada irregularidad. La gravedad sigue
  actuando: esta tolerancia no crea apoyo invisible.

Se mezcla la rotación completa con cuaterniones, evitando dos transiciones
independientes de pitch y pendiente. Surface Follow Response sigue suavizando
cambios de normal del destino, no reemplaza la duración de la transición.
No se añadieron controles nuevos. Para una llegada más lenta aumentar Blend
Duration; Duration total del aterrizaje debe permitir completar Delay + Blend.
