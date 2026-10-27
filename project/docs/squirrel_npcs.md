# Peter y la base reutilizable de NPCs

**Peter** está en `res://scenes/npc/peter.tscn`. No está colocado en ningún
mapa: arrastra esa escena al escenario y sitúalo donde quieras. Es una escena
heredada de `res://scenes/npc/squirrel_npc.tscn`, preparada para crear otros
personajes sin copiar controladores.

## Qué comparte con el player

El hijo **Body** es una instancia real de `player.tscn`, con ExplorerPlayer,
SquirrelRig, Animation, la misma cápsula y el mismo GLB. Conserva caminar,
correr, salto, caída, deslizamiento, planeo y sus aterrizajes, trepa/mantle,
recoil de pared, splat y recuperación, incluyendo movimientos de cabeza,
torso y cola. Los estados siguen dependiendo de sus condiciones físicas y
de los controles habilitados en Body.

El NPC no lee el teclado del usuario. ExplorerPlayer ofrece un acceso común
a dirección y botones; para el jugador se resuelven con Input y para NPCs con
órdenes del nodo raíz. Trepa, animación de splat y polvo usan esa misma fuente,
así que pulsar salto o Sprint con el player no anima ni mueve a Peter.

El nodo raíz tiene el grupo `npcs`, y Body el grupo `npc_actors`. La señal
`feedback(kind)` del nodo raíz reenvía los eventos de Body para futuras
integraciones de audio o comportamiento. No se añade cámara, HUD ni un segundo
mezclador de audio global por cada NPC. El componente Dialogue reutiliza el
globo de conversación y el icono de interacción existentes.

## Colocarlo y modificarlo

1. Arrastra **peter.tscn** al mapa, como cualquier otra escena.
2. Selecciona **Peter** para editar identidad, recorrido, control y colores.
3. Abre **NPC · colores**: pelaje, cola, rostro/panza, manos/pies, interior de
   orejas y ojos/nariz. Los colores iniciales coinciden con los originales.
4. Los cambios de color se previsualizan en el editor y en ejecución. Guarda
   la escena local para conservarlos. Remote sólo modifica la ejecución actual.

Cada superficie tiene una copia privada de su material; no se modifica el
GLB, el player ni otras instancias. **Custom Colors Enabled** recupera los
materiales originales al apagarlo. Los detalles y demás parámetros del material
se conservan. Ojos y nariz comparten un color porque comparten material en el
GLB; rostro y panza también comparten su control.

**EditorVisual** es una copia del mismo GLB sólo para vista previa en el editor:
se oculta al ejecutar. En juego se usa únicamente el modelo del Body real.
**NPC · animación de caminar → Preview Walk Animation** permite observar el
clip sin desplazar el personaje ni alterar marcadores.

## Proporciones de cabeza, cuerpo y miembros

Selecciona **Peter → NPC · proporciones generales**. Los mismos controles
están disponibles en cualquier personaje heredado de la base de NPCs.

| Control | Inicial | Ejemplo |
| --- | --- | --- |
| Proportions Enabled | Sí | Apagar recupera las escalas originales. |
| Overall Size | 1 | Escala uniforme de todo el personaje; 0,8 lo hace un 20 % más pequeño. |
| Scale Collision With Size | Sí | Ajusta también la cápsula privada al tamaño general. |
| Head Size | 1 | 0,8 reduce la cabeza completa un 20 %, con ojos, nariz y orejas. |
| Torso Width | 1 | 1,25 ensancha el torso un 25 %. |
| Torso Depth | 1 | 1,2 engorda la panza/espalda un 20 %. |
| Torso Height | 1 | 0,95 acorta ligeramente la pieza del torso. |
| Arms Length | 1 | 0,9 acorta ambos brazos desde los hombros. |
| Arms Thickness | 1 | 1,15 hace brazos y manos más robustos. |
| Legs Length | 1 | 0,95 acorta ambas piernas desde las caderas. |
| Legs Thickness | 1 | 1,15 engrosa piernas y pies. |
| Tail Size | 1 | 0,85 reduce toda la cola desde su base. |
| Tail Length | 1 | 1,1 la alarga un 10 % adicional sobre su eje longitudinal. |
| Ears Size | 1 | 0,8 reduce las orejas respecto al tamaño de cabeza elegido. |

Son multiplicadores sin unidades: **1 conserva el modelo**, menor reduce y
mayor aumenta. No se han cambiado los valores de Peter: inicialmente conserva
las proporciones del player. Para una variante con cabeza menor y cuerpo más
gordito, prueba **Head Size 0,8**, **Torso Width 1,2** y **Torso Depth 1,15**.

**Overall Size** multiplica el conjunto, sin sobrescribir los otros ajustes.
Por ejemplo, Head Size 0,83 y Overall Size 0,8 mantienen la cabeza al 83 % de
la proporción de ese personaje, mientras todo Peter se reduce al 80 %. No cambia
los números de cabeza, torso, brazos, piernas, orejas, cola ni los colores.
Tampoco escala Route ni modifica el Transform manual del nodo raíz.

Si Scale Collision With Size está activo, radio, altura y centro de la cápsula
se escalan con el tamaño general. Cada NPC tiene su propia forma duplicada.
Al apagarlo se recupera la cápsula original. Los ajustes individuales de miembros
siguen siendo sólo visuales. El tamaño no ajusta automáticamente velocidades,
gravedad, altura de salto o rayos de trepa: se conservan los controles de Body.

Los cambios se ven en vivo en el editor y en ejecución, sin regenerar mallas.
Guarda la escena local para persistir; Remote es temporal. Preview Walk
Animation permite revisar la silueta mientras camina, sin mover los marcadores.

La cabeza escala junto a sus detalles para que los ojos, hocico y orejas no
queden separados. El tamaño propio de las orejas se multiplica por Head Size.
El torso se modifica sólo en su malla: engordarlo no aumenta el tamaño de los
brazos o de la cabeza. Los miembros conservan sus animaciones y pivotes.

En ejecución las escalas se aplican después de la animación, partiendo siempre
de sus valores originales, sin acumularlas de frame a frame. No cambian las
rotaciones/posiciones de poses ni el aplastamiento global del splat. El coste
es constante: ocho escalas de hueso y la pieza de torso por NPC y frame.
Las mallas importadas y las otras instancias permanecen intactas.

Los ajustes individuales son **visuales**: no reajustan la cápsula física ni recolocan cuello,
hombros o caderas. Un torso demasiado alto puede cruzar la cabeza; piernas
muy largas pueden hundir los pies y muy cortas dejarlos flotando. Las poses de
apoyo y las membranas de planeo tampoco se retargetean automáticamente a nuevas
longitudes. Empieza con cambios moderados y comprueba caminar, trepar, planeo
y splat antes de adoptar una silueta extrema.

## Recorrido por defecto

Peter empieza en **Control Mode = Patrol**, con cuatro puntos alrededor del
nodo raíz, a 1,6 m/s y una pausa de 1 s en cada punto. Sólo camina: los puntos
no tienen carrera, salto, planeo ni agarre activados.

**Route** es hermano de Body: se queda anclado donde colocaste la instancia,
mientras Body recorre los puntos. No pongas los marcadores debajo de Body.
Mueve **Route/Point1…Point4** para diseñar el recorrido. En una instancia del
mapa, activa **Editable Children** si necesitas editar sus nodos heredados;
también puedes abrir peter.tscn para modificar el recorrido de Peter en todas
sus instancias. Añade o elimina Marker3D para ampliar o reducir la ruta.
Los puntos se siguen en orden del árbol, con **Loop Route** o ida/vuelta.

**NPC · recorrido** ofrece activación, velocidad al caminar, pausa, radio de
llegada, modo de ruta y tiempo de espera ante un bloqueo. Walk Speed y Walk
Animation Speed del nodo raíz se aplican al Body en vivo. El resto de ajustes
físicos y visuales completos siguen en **Body** y **Body/Animation**, como en
el jugador: Sprint Speed, Jump Velocity, Gravity, Glide, Climb, Splat, etc.

La patrulla es simple: dirige al siguiente punto y comprueba bordes, pendiente
y obstáculos. No calcula caminos alrededor de objetos ni usa una navegación
precocinada. Si queda bloqueada, espera Blocked Retry Time y prueba el siguiente
punto. Diseña tramos despejados sobre la cima.

## Hablar con Peter

Peter tiene esta frase editable:

> Vaya, esta montaña está algo simplista todavía... Pero bueno, ¿quién soy yo para juzgar?

Acércate hasta que aparezca el icono y pulsa **E** en teclado o **interacción**
en mando (cuadrado en PlayStation / X en Xbox). En tierra también se acepta
la confirmación contextual Cruz/A. El mismo botón avanza o termina la frase;
**Esc/B** cierra el globo. Usa el mismo globo paginado y sistema de voz del juego.

En **Peter → NPC · diálogo**:

- **Dialogue Enabled** permite hablar; texto vacío no ofrece interacción.
- **Dialogue Text** es el texto propio de esa instancia, capturado al abrir.
- **Dialogue Reach** controla la distancia máxima, inicialmente 2,8 m.
- **Dialogue Prompt Height** controla la altura del icono y se multiplica por
  Overall Size para seguir a personajes más grandes o pequeños.
- **Face On Dialogue**, activo por defecto, hace que ambos personajes se
  orienten hacia su interlocutor al empezar a hablar.

En **Body → Mirada al interactuar** y en el nodo del player:

- **Interaction Facing Enabled** activa el giro visual de ese personaje.
- **Interaction Facing Speed Degrees** limita la velocidad del giro en grados
  por segundo: 240°/s por defecto. Bájalo a 120°/s para un giro más tranquilo;
  media vuelta tarda 1,5 s. Se ajusta por separado en **Peter → Body** y en el
  player, responde en vivo y sigue el camino angular más corto. El giro empieza
  desde la orientación actual, sin cambiarla inmediatamente al abrir el globo.
- **Interaction Facing Duration** controla el seguimiento inicial cuando se
  solicita una mirada fuera de conversación (0,35 s por defecto; 0 sólo completa
  el giro gradual). El giro pendiente puede terminar aunque expire ese tiempo.
  Durante un diálogo activo ambos mantienen la mirada hasta cerrarlo.

### Regla general para todos los NPC

Conversar mantiene el mundo, la cámara y las animaciones activos. Ambos
interlocutores se quedan en su sitio y se miran hasta terminar: el player no
puede caminar, correr o saltar, y la patrulla del NPC espera sin perder su
destino. Al cerrar, la patrulla continúa. El botón compartido de salto e
interacción sólo avanza o cierra el globo; tampoco salta al cerrarlo aunque
se mantenga pulsado. La gravedad sigue funcionando si desaparece el apoyo.

El globo posee el bloqueo de locomoción y lo libera también al salir del árbol;
no se desactiva el procesamiento de los actores. Esto se aplica igualmente
a los diálogos del juego principal. Los NPC nuevos deben heredar
`squirrel_npc.tscn` y reutilizar este comportamiento compartido.

Se selecciona el NPC habilitado más cercano con apoyo válido y línea de
visión. No se usa el origen de Route: el icono y el globo siguen al Body que
camina. Sólo se ofrece una conversación a la vez. Los NPC no se
confunden con el jugador humano al buscar el destinatario del diálogo o del
menú de pausa de escenas de trabajo.

El diálogo funciona al colocar Peter dentro de grass_terrain y ejecutar su
escena de recorrido con el player; no requiere añadir un game manager al terreno.
Una escena con sólo Peter y sin jugador no muestra el icono. Los futuros NPC
heredan el componente con texto vacío: cada uno define su propia frase y nombre.

### Aleteo de brazos al hablar

En **Peter → NPC · gestos al hablar** (también en la base para futuros NPC):

| Control | Efecto |
| --- | --- |
| Talking Gesture Enabled | Activa el gesto mientras aparece el texto hablado. |
| Talking Arm Degrees | Amplitud del aleteo; 10° por defecto. Subir a 20° lo hace más marcado. |
| Talking Arm Hz | Ciclos por segundo; 1,8 Hz por defecto. Subirlo acelera los brazos. |
| Talking Arm Open Degrees | Apertura de los brazos sobre la pose de reposo; 8° por defecto. |
| Talking Arm Min Degrees | Límite inferior de apertura al hablar; 0° por defecto evita la parte negativa del giro. Aumentarlo mantiene los brazos más separados del torso. |
| Talking Arm Max Degrees | Límite superior de apertura; 60° por defecto. Reducirlo limita el recorrido hacia fuera. |
| Talking Gesture Blend Time | Entrada y salida del gesto en segundos; 0,18 s por defecto. |
| Preview Talking Gesture | Muestra el gesto en vivo en el editor. Desactivarlo vuelve suavemente al reposo. |

Todos responden en vivo sin regenerar geometría. El gesto se mezcla sobre la
pose de brazos, conserva las proporciones y se atenúa cuando termina la voz o
se espera el avance de página. No controla el audio ni desplaza al personaje.

Los límites recortan **Open Degrees + aleteo**, simétricamente para ambos
brazos; la amplitud y la apertura personalizadas se conservan. Los nuevos
defaults 0°/60° limitan el giro sin cambiar esos ajustes existentes. Para
probar un recorrido desde cerca del torso hacia fuera, usa **Open = 25°**,
**Degrees = 15°**, **Min = 10°**, **Max = 40°**, **Hz = 1,8** y activa
**Preview Talking Gesture**. Los positivos abren hacia fuera: se corrigió el
signo del giro del rig importado, que antes los dirigía hacia dentro. Los
valores guardados se conservan, pero el sentido ahora corresponde a esta
convención. Ajusta el mínimo según el grosor del personaje. Si los
límites quedan invertidos, se ordenan al calcular; si son iguales, no hay
oscilación. Se aplican antes de la transición suave: al entrar o salir, los
brazos pasan entre reposo y el rango elegido, hasta recuperar su pose normal.

### Movimiento de cabeza durante la interacción

En **Peter → NPC · cabeza al interactuar**, la cabeza se mueve sutilmente
durante toda la conversación, también mientras espera que avances una página.
El cuerpo conserva la orientación hacia el interlocutor. Los controles también
están disponibles en la base para futuros NPC y responden en vivo:

| Control | Efecto |
| --- | --- |
| Interaction Head Enabled | Activa o desactiva el gesto de cabeza, independiente del aleteo. |
| Interaction Head Yaw Degrees | Giro lateral; 4° por defecto. |
| Interaction Head Pitch Degrees | Movimiento arriba/abajo; 2,5° por defecto. |
| Interaction Head Roll Degrees | Inclinación hacia los hombros; 1,5° por defecto. |
| Interaction Head Hz | Velocidad del ciclo; 0,6 Hz por defecto. |
| Interaction Head Blend Time | Entrada y salida suaves; 0,25 s por defecto. |

Activa **NPC · gestos al hablar → Preview Talking Gesture** para previsualizar
brazos y cabeza en el editor. Para algo más discreto, prueba Yaw 2°, Pitch 1°,
Roll 0,5° y Hz 0,4. Amplitud 0 elimina sólo ese eje. La animación no modifica
las proporciones personalizadas ni requiere regeneración de geometría.

## Elegir acciones por tramo

Los puntos incluidos tienen el script **NPCPatrolPoint**. Sus ajustes afectan
al tramo que llega a ese marcador:

| Control del punto | Acción |
| --- | --- |
| Sprint | Mantiene carrera durante el tramo. |
| Jump Before Leg | Solicita un salto al iniciar el tramo, después de la pausa anterior. |
| Glide In Air | Despliega planeo cuando ya está en el aire y lo conserva durante el tramo. |
| Climb Held | Mantiene el agarre; una vez trepando dirige verticalmente según la altura del marcador. |

La altura del marcador importa al terminar un tramo de trepa; para caminar se
compara la distancia horizontal y la física sigue el suelo. Planeo necesita
estar en el aire, salto necesita apoyo/coyote y trepa necesita una superficie
permitida: las órdenes no fuerzan estados imposibles ni teletransportan.

**Edge Safety Enabled** está activo para el paseo por cimas. Puede detener un
tramo antes de un borde aunque ese tramo pida salto o planeo. Para una ruta
aérea o de escalada que diseñes explícitamente, desactívalo y ajusta los puntos;
las colisiones físicas del actor siguen activas. Esta opción no crea proxies.

## Control directo y futura IA

En **NPC · control**, cambia a **Commands** para usar dirección global,
Sprint, Glide, Climb y **Jump Requested**. En Remote, activa Jump Requested
para solicitar un salto; se desmarca al consumirlo. En splat esa pulsación
produce el pataleo correspondiente, igual que en el player.

Una futura IA puede llamar al nodo raíz:

- `set_move_direction(Vector3)`: X/Z globales, longitud hasta 1; en trepa,
  Z negativo pide subir y positivo bajar.
- `set_action_held(action, active)`: mantener/soltar `jump`, `sprint`, `glide`
  o `climb` en modo Commands.
- `pulse_action(action)`: pulsación de un tick sin tocar Input global.

Las pulsaciones y los botones mantenidos tienen memoria de estado para que
`just_pressed` funcione igual que en el jugador. No se usan Input.action_press
ni eventos simulados que puedan afectar a otros personajes.

## Suelo, Terrain3D y límites

**Snap On Start** coloca sólo Body sobre el apoyo inicial disponible; no mueve
el nodo raíz ni reescribe el recorrido. Apágalo si quieres empezar en el aire.
El NPC usa la colisión física real del escenario, igual que el player.

Terrain3D puede cargar colisión sólo cerca de la cámara. Con **Wait For Ground
Collision** activo, Peter espera si no existe todavía apoyo físico bajo él,
y reanuda cuando aparece. También se suspende si se aproxima al suelo de una
región sin colisión. Esto conserva su velocidad/estado y evita caer a través
del relieve fuera de la zona activa; no proporciona simulación remota completa.
No se ha cambiado el modo de colisión del terreno ni se ha creado un proxy.

**Terrain Path** vacío busca un Terrain3D para consultas de altura/pendiente.
Con varios terrenos, asigna el correcto explícitamente. Sin Terrain3D se usan
rayos físicos. Los controles de pendiente, desnivel, anticipación y alcance de
rayos están en **NPC · suelo y seguridad**, con ayuda en cada propiedad.

## Caer sobre un NPC: resorte y regaño

Peter y todas las escenas heredadas de `squirrel_npc.tscn` incluyen el nodo
**StompReaction**. Selecciónalo para ajustar los grupos **Contacto y rebote**,
**Resorte visual**, **Sonido del impacto** y **Regaño**. Todos los valores
responden en vivo; sus ayudas del Inspector explican unidades y dependencias.

El player colisiona con los NPC en la **capa física 4** y con el escenario en
la capa 1. El NPC conserva su cápsula ajustada por Overall Size. Player Collision
Enabled permite atravesarlo al apagarlo; Bounce Enabled desactiva sólo la
reacción. Sólo una caída sobre la zona superior de la cápsula dispara el resorte:
los choques laterales y el ascenso del salto no cuentan. Top Normal Min y
Top Height Fraction afinan esa zona; no hay colisión detallada por oreja o cola.

Por defecto, Bounce Speed = **5 m/s**, Compression = **0,18**,
Spring Frequency = **3,5 Hz** y Spring Damping = **8** dan un impulso moderado
y una oscilación breve. Más damping elimina antes las oscilaciones; menos lo
hace más elástico. Preview Spring dispara una muestra en el editor. La
compresión es visual, mantiene los pies como origen y conserva las proporciones
personalizadas; la cápsula estable evita hundimientos y contactos repetidos.
No se genera geometría ni se altera la ruta.

El audio espacial usa `res://audio/sfx/boing drum.wav`, copia del archivo correcto
`sounds/boing drum.wav`, con un solo boing por impacto. El WAV Repeater contiene
una secuencia de golpes dentro de la propia grabación y ya no se utiliza.
Sound Volume Db = **0**, Sound Unit Size = **14 m**
y Sound Max Distance = **45 m** mantienen el efecto audible desde la cámara
habitual, que orbita a unos 14 m. Unit Size mayor reduce la atenuación con la
distancia. Se mezcla por SFX/Master (Master si no existe SFX). Puedes sustituir
Impact Sound, ajustar volumen, tono y distancia o vaciarlo para silenciarlo.

**Peter → StompReaction** sobrescribe ahora los valores suaves de la base con
Bounce Speed = **7,5 m/s**, Compression = **0,35**, Lateral Expansion = **0,6**,
Spring Frequency = **3 Hz** y Spring Damping = **5**. Con gravedad del player
de 22 m/s², el rebote sube aproximadamente **1,28 m** desde el contacto
(antes unos 0,57 m). Aumentar Bounce Speed eleva el salto; aumentar Compression
aprieta más; bajar Damping prolonga las oscilaciones; Frequency las acelera.
Estos ajustes están guardados en Peter, sin cambiar la intensidad de futuros
NPC. Preview Spring permite verlos sin ejecutar el juego.

El rebote del player no genera polvo de movimiento: se bloquea únicamente la
emisión hasta el aterrizaje. Las partículas ya emitidas permanecen visibles y
terminan su vida natural; no se ocultan, borran ni reinician. Al tocar suelo
vuelve la emisión habitual en la posición actual, conservando sus valores del
Inspector.
Los NPC usan la capa 4 para
evitar interferir con los bloqueadores de cámara, que usan la capa 3.
Mientras Bounce Enabled esté activo, apoyarse sobre la cabeza vuelve a disparar
el rebote incluso a velocidad casi cero: el NPC no sirve como plataforma para
quedarse parado. Se comprueba también el apoyo quieto, respetando el intervalo
Impact Cooldown. Las colisiones laterales no disparan el resorte.

**StompReaction → Slip Speed** (2 m/s) mantiene una separación horizontal hacia
fuera al apoyarse sobre el NPC, incluido el intervalo entre rebotes. Aumentarlo
acelera la salida; se aplica en vivo. Si se cae justo en el centro se usa la
dirección de movimiento o la orientación del player. La salida continúa hasta
alcanzar suelo real y evita mantenerse encima compensando con el stick.

Tanto el diálogo normal como el regaño exigen apoyo caminable en el escenario:
`is_on_floor()` por sí solo también acepta la cápsula del NPC. Se vuelve a validar
justo al abrir el globo. Si un NPC pasa debajo durante una conversación, ésta
se cierra para liberar al player. El polvo se detiene desde el contacto superior,
sin borrar ni ocultar partículas anteriores, y queda bloqueado durante el rebote
y el frame de aterrizaje. Sólo puede volver a emitirse al moverse sobre escenario;
las comprobaciones añaden consultas físicas cortas de apoyo, sin generar mallas.

Tras **2 impactos en 8 segundos**, el NPC pide que dejes de usarlo como
trampolín. El diálogo espera a que ambos estén apoyados y el player esté dentro
de Dialogue Reach, con línea de visión y sin otra conversación abierta. Si te
alejas, la petición caduca al terminar Count Window. Complaint Cooldown limita
los regaños a uno cada **20 s**; el rebote sigue funcionando. Complaint Text es
independiente del texto habitual y editable por NPC. El diálogo reutiliza la
mirada gradual, los gestos, el bloqueo de locomoción y la protección del botón
compartido de salto/interacción, sin pausar el mundo.

## Crear el siguiente NPC

### Permitir trepar un NPC concreto

El nodo raíz también ofrece **NPC · interacción física → Player Impact Reaction
Enabled**, desactivado por defecto para todos los NPC de la base. Así, chocar
planeando contra Peter no dispara la animación de choque, su retroceso ni su
sonido. El permiso se comprueba tanto en el contacto real como en la anticipación
del choque. Actívalo sólo en el NPC que deba provocar esa reacción; el player
debe tener Glide Recoil Enabled activo. La colisión física y el rebote al caer
encima conservan su funcionamiento; las paredes del escenario mantienen la
reacción habitual. Cambiarlo se aplica a contactos nuevos en vivo.

En el **nodo raíz del NPC → NPC · interacción física → Climbable** se decide
si su cuerpo sirve como superficie de trepa. Está **desactivado por defecto**
en la base, Peter y todos los NPC que hereden de ella. El bloqueo tiene prioridad
sobre el prototipo del player que permite trepar superficies empinadas sin etiqueta;
también se aplica a los apoyos y a la asistencia hacia la cima.

Para la futura ardilla gigante instructora, activa **Climbable sólo en esa
instancia** y conserva **StompReaction → Player Collision Enabled**. El player
debe tener su propio **Climb Enabled** activo. El permiso se consulta en vivo;
desactivarlo cancela el agarre al reevaluar el contacto. No impide que el propio
NPC trepe el escenario. La superficie sigue siendo su cápsula escalada por
Overall Size: no reproduce por separado brazos, cola u orejas. El rebote y la
salida lateral de la cabeza conservan sus controles independientes.

Crea una **nueva escena heredada de squirrel_npc.tscn**, asigna otro nombre
y paleta, y diseña su Route. Así cada personaje comparte modelo/controlador y
conserva sus propias decisiones de autoría. Hereda de Peter sólo si quieres
que ese personaje siga también las futuras personalizaciones específicas de Peter.
