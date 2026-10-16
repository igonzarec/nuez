# Escalada temporal por pendiente de Terrain3D

Durante la exploración de rutas, la ardilla puede agarrarse a superficies
empinadas sin pintar una máscara. Esto sirve para esculpir una ladera en
Terrain3D y probar de inmediato si comunica bien una ruta vertical.

Los controles están en el nodo `SquirrelExplorer`, Inspector > **Escalada**:

- **Climb Untagged Steep Surfaces Enabled** activa el modo. Al apagarlo, sólo
  funcionan los objetos del grupo `climbable`, como los acantilados
  procedurales existentes.
- **Untagged Min/Max Slope Degrees** definen la inclinación desde horizontal
  que permite el agarre. El valor inicial de 65° a 89° deja 48°–65° como zona
  de deslizamiento y reserva las caras más verticales para escalar.

El jugador debe estar cerca, mirar hacia la pared y mantener Brincar. Las
zonas `climbable` existentes conservan sus propios límites y nunca se anulan
por este modo.

## Escalada completamente procedural

## Conservar agarre y salir a la cima

### Salida asistida siguiendo la superficie (actual)

Con **Climb Mantle Enabled** y **Climb Mantle Surface Assist Enabled** activos,
la detección de suelo delante inicia un avance automático siguiendo contactos
físicos reales. No recorre los tres segmentos antiguos ni usa Clearance para
elevar al jugador. Al confirmar suelo caminable y completar las vueltas mínimas,
mezcla la pose procedural con caminar y se incorpora durante Stand Duration.
Soltar Brincar cancela como en la escalada normal. No hay teletransporte ni IK.

Controles en **SquirrelExplorer > Escalada · continuidad y cima**:

| Control | Inicial | Uso |
| --- | --- | --- |
| Climb Mantle Surface Assist Enabled | Sí | Nueva asistencia; No recupera el Mantle antiguo. Requiere Mantle Enabled. |
| Climb Mantle Surface Speed | 1,5 m/s | Avance automático, independiente de la velocidad de los miembros. |
| Climb Mantle Surface Max Distance | 3 m | Límite de recorrido; al agotarse devuelve control de trepa. |
| Climb Mantle Surface Timeout | 4 s | Límite de tiempo contra bloqueos y atasco. |
| Climb Mantle Surface Contact Speed | 1 m/s | Presión hacia el contacto; aumentar puede frenar en esquinas. |
| Climb Mantle Surface Offset Start / End | −0,11 / −0,11 m | Offset visual a lo largo de la normal; se interpola durante la incorporación. Negativo hunde, no mueve colisión. |

**Climb Mantle Extra Cycles** determina las vueltas mínimas antes de incorporarse;
**Climb Mantle Cycle Speed** determina sus Hz. Se detienen si no hay movimiento.
Ejemplo: dos vueltas a 2,4 Hz requieren unos 0,83 s en movimiento, más el apoyo
y la incorporación. Los límites de recorrido y tiempo prevalecen: pedir muchas
vueltas con poco recorrido puede cancelar la asistencia antes de terminar.
Todos los controles nuevos se consultan en vivo salvo la cantidad de vueltas,
capturada al iniciar. No se sobrescribieron los valores guardados de escenas.

La búsqueda mantiene Min Reach, Forward Reach, Extension y Samples; detecta
que hay una posible cima, pero no permite atravesar el espacio entre ambos
puntos. Más muestras incrementan consultas físicas al buscar. Ya en asistencia
se consultan contacto frontal y suelo bajo los pies en cada tick físico.
Clearance, Floor Margin, Surface Blend y Duration de Mantle siguen disponibles
para el modo antiguo, no controlan la nueva trayectoria sobre superficie.

### Revisión del terreno guardado (15 octubre 2026)

El plugin instalado es **Terrain3D 1.0.2**, no se encontró “Terrain Sweety”.
Se midió `grass_terrain.tscn` y `terrain_data_grass` sin modificar sus datos,
usando `tools/inspect_climb_terrain.gd`. Espaciado: 1 m; regiones: 256 muestras.
En una cuadrícula de muestreo cada 8 vértices hubo 23.552 puntos válidos:
756 superan 48°; entre ellos, 136 cambian más de 15° en alguna sección axial
entre intervalos consecutivos de un metro. El máximo cambio axial medido fue
152,5° cerca de (50,0; 32,74; 138,0). Son diferencias de pendiente axial,
no ángulos entre normales de colisión; no constituyen una prueba de todas las
rutas ni miden el lugar exacto del usuario. Cambios no guardados del editor
no entran en esta medición.

Conclusión: el terreno sirve para rutas de escalada, pero no cualquier detalle
esculpido es una buena superficie de gameplay. Picos, valles cortos y crestas
cambian el contacto a escala de la cápsula (0,84 m de ancho). Conviene suavizar
selectivamente rutas y salidas, manteniendo detalle fuera de ellas. También
hay límites del controlador: rayos puntuales y cápsula vertical, sin manos/pies
con IK; no todo problema es culpa del terreno. Antes de producir colisión
alternativa, decidir con el usuario si conservar la actual o crear un proxy.
No se modificaron montañas ni colisiones en esta revisión.

### Seguir la inclinación de la superficie

En **SquirrelExplorer > Escalada**, **Climb Surface Follow Enabled** adapta
el cuerpo a la normal real de la roca: en una pared vertical conserva la pose
erguida y en una pendiente suave inclina el cuerpo para acompañarla. Además,
la separación física deja de ser 0,5 m en todas las pendientes: se interpola
entre Wall Distance y Floor Distance según la componente vertical de la
normal, evitando mantener al personaje suspendido sobre una ladera suave.

| Control | Inicial | Efecto |
| --- | --- | --- |
| Climb Surface Follow Enabled | Sí | Activa adaptación visual y de separación. Apagado recupera el comportamiento fijo. |
| Climb Surface Follow Strength | 1 | 0 sin adaptación, 1 completa. |
| Climb Surface Follow Response | 10 s⁻¹ | Mayor valor sigue más rápido los cambios; menor suaviza. |
| Climb Surface Max Lean Degrees | 80° | Máximo de inclinación añadida por la pendiente. |
| Climb Surface Floor Distance | 0,02 m | Separación objetivo de pies al aproximarse a horizontal. |

Todos se actualizan en vivo. **Climb Body Lean Degrees** sigue sumándose como
ajuste artístico, así que conviene mantenerlo pequeño si la pendiente ya
inclina mucho el cuerpo. **Climb Visual Wall Offset** sigue la normal de la
superficie: negativo acerca y positivo separa. Para una respuesta más suave,
prueba **Follow Response = 6**; para reducir la inclinación, **Strength = 0,7**.
No se sobrescriben los ajustes existentes de agarre ni los offsets guardados.
Esto sigue siendo adaptación por plano de contacto, no IK de manos y pies ni
colisión exacta de la malla visual sobre cada irregularidad.

### Detección y transición de cima

La salida predeterminada es ahora **natural**: **Climb Mantle Enabled = No**.
No usa Clearance ni una trayectoria automática hacia arriba o hacia dentro.
El movimiento solicitado sigue el plano real de contacto; al desaparecer el
contacto del pecho puede continuar sobre suelo cercano bajo los pies. La
cápsula debe confirmar apoyo físico caminable antes de incorporarse. No se
salvan huecos ni repisas verticales sin superficie continua.

En **SquirrelExplorer > Escalada · continuidad y cima**:

- **Climb Finish Max Slope Degrees** limita qué pendiente permite terminar,
  siempre respetando además el límite caminable del personaje.
- **Climb Finish Support Time**: 0,12 s iniciales de apoyo continuo. Aumentarlo
  evita incorporarse por un roce fugaz; perder apoyo reinicia la confirmación.
- **Climb Finish Stand Duration**: 0,30 s iniciales de incorporación visual.
  Aumentarlo suaviza el cambio, sin desplazar la cápsula automáticamente.
- **Climb Finish Visual Height**: −0,11 m iniciales. Altura visual final que
  sustituye gradualmente al offset de la pared; no vuelve obligatoriamente a
  cero al incorporarse. Negativo acerca/hunde el modelo y positivo lo levanta.
  Se conserva mientras permanece en suelo después de la salida natural.
- **Climb Finish Visual Response**: 12 s⁻¹. Suaviza ajustes de esa altura y su
  retorno a cero en el aire. Ambos controles se actualizan en vivo y no cambian
  la colisión; un hundimiento excesivo puede atravesar visualmente el terreno.

La cápsula física sigue siendo vertical (radio 0,42 m, altura 1,42 m).
Es el volumen invisible que resuelve choques, no la malla animada. Al pasar un
borde su parte redonda puede elevar el cuerpo físico aunque no haya asistencia.
La altura visual permite afinar apariencia, pero no elimina ese contacto físico.

Estos ajustes se consultan en vivo. El ciclo sigue el desplazamiento real,
sin imponer vueltas extra, y la pose se mezcla gradualmente con reposo.
**Climb Mantle Enabled** permite recuperar explícitamente la asistencia antigua
para repisas: sólo entonces actúan Clearance, alcance, vueltas y duración de
Mantle. Los valores guardados de esos controles se conservan.

En **SquirrelExplorer > Escalada · continuidad y cima** se separa el umbral
de entrada del umbral de agarre sostenido. La entrada sigue usando los límites
de **Escalada**; una vez agarrado se permiten pendientes más suaves. En objetos
marcados se siguen respetando sus zonas Disabled. Al avanzar sobre una cara
inclinada, la dirección de subida se proyecta sobre la superficie en lugar de
empujar verticalmente contra ella.

| Control | Inicial | Efecto |
| --- | --- | --- |
| Climb Sustain Enabled | Sí | Activa el límite relajado sólo una vez agarrado. |
| Climb Sustain Min Slope Degrees | 40° | Menor valor conserva el agarre en transiciones más suaves. |
| Climb Mantle Enabled | No | Opcional: activa la trayectoria asistida sobre el borde al mantener arriba. |
| Climb Finish Max Slope Degrees | 25° | Máxima inclinación para considerar tierra firme e incorporarse; menor exige suelo más plano. |
| Climb Mantle Extra Cycles | 2 | Vueltas adicionales completas de brazos y piernas durante la salida. |
| Climb Mantle Surface Blend Start | 0,1 | Progreso de salida donde empieza a pasar de la normal de pared a la del suelo superior. |
| Climb Mantle Surface Blend End | 0,7 | Progreso donde termina esa adaptación; después se incorpora. |
| Climb Mantle Forward Reach | 1 m | Distancia horizontal donde busca suelo superior. |
| Climb Mantle Search Min Reach | 0,5 m | Primera distancia de búsqueda. |
| Climb Mantle Search Extension | 0,5 m | Extiende la última muestra más allá de Forward Reach. |
| Climb Mantle Search Samples | 5 | Cantidad de distancias exploradas; más muestras cuestan más rayos y barridos. |
| Climb Mantle Retry Interval | 0,05 s | Pausa entre búsquedas fallidas. |
| Climb Mantle Contact Grace | 0,18 s | Tolerancia de pérdida de contacto mientras busca salida. |
| Climb Mantle Status | Diagnóstico | Último resultado visible en Remote, actualizado automáticamente. |
| Climb Mantle Max Height | 1,4 m | Altura máxima de búsqueda sobre los pies. |
| Climb Mantle Max Drop | 0,3 m | Búsqueda permitida por debajo de los pies. |
| Climb Mantle Clearance | 0,08 m | Altura libre extra para pasar la cápsula sobre el borde. |
| Climb Mantle Floor Margin | 0,03 m | Separación final antes de asentarse sobre el suelo. |
| Climb Mantle Cycle Speed | 2,4 ciclos/s | Ritmo máximo de las vueltas finales, independiente del ritmo de trepar. |
| Climb Mantle Duration | 0,55 s | Duración mínima; se amplía para completar las vueltas al ritmo Cycle Speed. |
| Climb Mantle Body Lean Degrees | 35° | Inclinación adicional hacia el apoyo durante el esfuerzo. |
| Climb Mantle Arm Reach Degrees | 25° | Elevación extra de manos durante el alcance. |
| Climb Mantle Leg Tuck Degrees | 20° | Recogida de pies desde la cadera, sin flexión real de rodillas. |

Clearance admite de -0,5 a 0,5 m y Floor Margin de -0,25 a 0,25 m, en pasos
de 0,005 m. Puedes probar 0 y valores negativos para bajar el trayecto o el
destino; no cambian los defaults ni los valores guardados. Ambos afectan la
trayectoria física, así que un valor negativo que atraviese la superficie
puede hacer que la búsqueda descarte ese candidato por colisión. Revisa
Climb Mantle Status al experimentar; no se desactivan las colisiones.

Para una cima más gradual, prueba **Sustain Min Slope Degrees = 35°**. Para
una salida pausada, usa **Mantle Duration = 0,75 s**. Los controles responden
en vivo, excepto la geometría del recorrido y su duración, que se capturan al
iniciar la salida. Durante ella se continúa la fase actual del ciclo para
completar Extra Cycles vueltas, se inclina el cuerpo y se elevan manos y pies.
El último 15 % del recorrido incorpora al personaje después de las vueltas.
Durante la salida, la postura sigue también la inclinación del apoyo superior:
combina la normal inicial de pared con la del destino y actualiza esta última
con un rayo bajo el personaje cuando ya tiene suelo firme debajo. Surface
Blend Start/End regulan la transición y se capturan al iniciar; Surface Follow
Response conserva su suavizado. La inclinación extra de esfuerzo se reduce
al aproximarse a horizontal para no sumar dos veces el mismo cabeceo. La
trayectoria física sigue validando la cápsula; la adaptación cambia la pose y
el offset visual, no elimina colisiones ni crea contacto IK de manos/pies.
Los sonidos siguen la misma fase. Con Extra Cycles 0 se recupera la salida
sin vueltas. El ritmo final se controla con Mantle Cycle Speed, no con Climb
Member Speed: dos vueltas a 2,4 ciclos/s dan una salida de aproximadamente
0,98 s, incluyendo la incorporación. Mayor Cycle Speed la acelera sin cambiar
la trepada normal. La elevación de seguridad se redujo de 0,15 a 0,08 m y el
margen final de 0,06 a 0,03 m para evitar una separación excesiva del apoyo;
los overrides existentes en escenas se conservan.

La búsqueda ya no depende de un único punto a 1 m: explora entre Search Min
Reach y Forward Reach + Search Extension, eligiendo el primer destino con
suelo firme y los tres tramos libres. Con los defaults son cinco distancias
entre 0,5 y 1,5 m. Si un candidato está bloqueado, prueba el siguiente.
Durante Contact Grace puede seguir subiendo brevemente con move_and_slide;
no atraviesa obstáculos, no permite entrar en zonas Disabled y soltar Brincar
cancela inmediatamente. Al recuperar contacto reinicia la tolerancia, y cada
salida exitosa reinicia etapa, temporizador, recorrido y fase capturada.

Para diagnosticar, abre **Remote > SquirrelExplorer > Escalada · continuidad
y cima > Climb Mantle Status**. Muestra cuántas muestras no tienen suelo,
cuántas exceden la pendiente y cuántas fallan por colisión, con el último
tramo bloqueado (1 subir, 2 pasar, 3 asentarse). También informa si la salida
se inició, se completó o chocó durante el movimiento. Es un diagnóstico de
la última búsqueda, no un control de autoría. El mensaje incluye el ángulo
efectivo: aumentar Finish Max Slope por encima de Walkable Slope Degrees no
lo amplía. Los valores personalizados de pendiente se conservan.

La salida busca suelo firme usando Finish Max Slope Degrees, limitado también
por Walkable Slope Degrees, y vuelve a comprobar apoyo bajo los pies al terminar.
Para exigir una cima más plana prueba 15°; para incorporarse antes prueba 35°.
Mantén Sustain Min Slope Degrees suficientemente bajo para poder llegar a ese
umbral. Los valores ya elegidos por el usuario no se sobrescriben.
Comprueba espacio para la cápsula en tres tramos (subir, pasar y asentarse)
antes de empezar y usa move_and_collide durante el recorrido: un techo o una
colisión nueva cancela la subida. Soltar Brincar también cancela. Si ya hay
apoyo caminable bajo los pies se recupera la locomoción terrestre sin impulso
de desprendimiento. Sigue siendo una búsqueda local de apoyo, no una solución
para cualquier geometría de borde: afina Reach/Height según las repisas.

## Postura y ciclo procedural

La escalada usa el reposo y los huesos del rig importado, pero **no reproduce
la acción Climb de Blender**. El GLB y sus acciones permanecen intactos.
Todos los ajustes visuales vigentes están en el nodo raíz **SquirrelExplorer**,
Inspector > **Escalada procedural**. Los controles físicos siguen en
**Escalada**; no se cambian las colisiones ni las reglas de agarre.

El hombro o cadera conserva su posición de reposo. Cada extremidad recibe una
dirección calculada con elevación y apertura lateral, más dos componentes
sinusoidales a un cuarto de ciclo de distancia: subida/bajada y alcance
interior/exterior. Esto dibuja una órbita angular alrededor del pivote fijo,
no una traslación de la pieza. La inclinación del recorrido rota esa órbita.
El torso se inclina hacia la pared y el modelo admite un desplazamiento visual
independiente de la cápsula para afinar la separación.

| Control | Inicial | Efecto |
| --- | --- | --- |
| Climb Procedural Enabled | Sí | Desactiva sólo el gesto; apagado queda la pose base sin usar Blender. |
| Climb Reverse Cycle | Sí | Sentido corregido del recorrido de brazos y piernas; apagado recupera el sentido anterior. |
| Climb Member Speed | 0,4 ciclos/m | Ritmo según distancia real recorrida sobre la pared. 0 congela el ciclo. |
| Climb Pose Response | 14 s⁻¹ | Mayor valor entra y responde más rápido; menor suaviza los huesos. |
| Climb Body Lean Degrees | 5° | Inclinación del cuerpo hacia la pared. |
| Climb Visual Wall Offset | 0 m | Positivo aleja el modelo; negativo lo acerca. No mueve la cápsula. |
| Climb Arm Base Elevation Degrees | 81° | Desde brazos abajo: 90° horizontal; más alto levanta las manos. |
| Climb Arm Base Spread Degrees | 42,5° | Desde el frente hacia los lados: mayor valor abre las manos. |
| Climb Arm Vertical Degrees | 20° | Amplitud de subida y bajada. |
| Climb Arm Depth Degrees | 45° | Amplitud de alcance y retorno interior/exterior. |
| Climb Arm Path Tilt Degrees | 20° | Orientación del recorrido orbital. |
| Climb Arm Phase | 0 | Desfase de brazos en fracciones de ciclo. |
| Climb Leg Base Elevation Degrees | 50,5° | Eleva y adelanta los pies desde la postura hacia abajo. |
| Climb Leg Base Spread Degrees | 28° | Apertura lateral de pies. |
| Climb Leg Vertical Degrees | 15° | Amplitud vertical del pie. |
| Climb Leg Depth Degrees | 12° | Amplitud de alcance y retorno del pie. |
| Climb Leg Path Tilt Degrees | 15° | Inclinación del recorrido de piernas. |
| Climb Leg Phase | 0,5 | Alternancia respecto a brazos; 0 los coordina en el mismo sentido. |
| Climb Opposite Side Phase | 0,5 | Alternancia entre izquierda y derecha. 0 sincroniza ambos lados. |
| Climb Sound Enabled | Sí | Un apoyo al agarrarse y dos por ciclo. |
| Climb Sound Phase | 0,23 | Un solo punto del recorrido local aplicado a cada brazo. |
| Climb Head Sway Enabled | Sí | Activa el balanceo lateral de cabeza. |
| Climb Head Sway Degrees | 8° | Inclinación máxima hacia cada lado. |
| Climb Head Sway Phase | 0,5 | Desfase de cabeza respecto al brazo izquierdo. |
| Climb Tail Sway Enabled | Sí | Activa el balanceo lateral desde la base de la cola. |
| Climb Tail Sway Degrees | 14,5° | Amplitud lateral de cola alrededor del eje vertical del cuerpo. |
| Climb Tail Sway Phase | 0 | Desfase de cola respecto al brazo izquierdo. |
| Climb Torso Motion Enabled | Sí | Activa los tres giros del tronco. |
| Climb Torso Twist Degrees / Phase | 8° / 0 | Torsión sobre el eje cadera-cabeza (Y): alterna qué hombro se acerca a la pared. |
| Climb Torso Side Lean Degrees / Phase | 0° / 0 | Inclinación sobre el eje espalda-pecho (Z): ladea el cuerpo entre apoyos. |
| Climb Torso Forward Lean Degrees / Phase | 0° / 0 | Inclinación sobre el eje hombro-hombro (X): cabecea hacia la pared y hacia fuera. |

Todos se actualizan en vivo desde **Remote**. Guarda después los valores en
**Local** para conservarlos. Como punto de partida, aumenta **Arm Depth
Degrees** a 25° para más alcance, reduce **Arm Base Spread Degrees** a 30°
para juntar las manos o aumenta **Leg Vertical Degrees** a 20° para elevar más
los pies. Cambiar **Phase** en 0,5 invierte alcance y retorno. **Path Tilt
Degrees** cambia la orientación del arco sin modificar el pivote.

Para acercar el personaje a la roca usa **Climb Visual Wall Offset**, por
ejemplo -0,04 o -0,06 m. Esto mueve sólo el modelo, conservando la cápsula.
El desplazamiento vuelve gradualmente a cero al incorporarse al final para
no tirar del cuerpo hacia la pared desde tierra firme. En **Escalada**, **Climb
Wall Distance** es la separación física del controlador: 0,46 m lo acerca
respecto a 0,5 m, conservando algo de margen sobre el radio de cápsula 0,42 m.
Ninguno fija manos o pies mediante IK: el contacto sigue siendo visual y los
valores extremos pueden atravesar la roca.

El ciclo sólo avanza con desplazamiento tangencial a la pared: una corrección
de distancia contra la roca no genera zancadas ni sonidos por sí sola. Al
quedar quieto se congela el ciclo y los huesos terminan de alcanzar suavemente
esa pose. Al soltarse, las poses aéreas o el clip terrestre recuperan el
control con mezcla desde los últimos huesos visibles. No se reproduce Run
durante el agarre.

El audio conserva `audio/Gentle Stone Drop.wav`, el volumen de escalada del
menú y el bus SFX. Los contactos se calculan desde el mismo ciclo procedural,
sin depender de fotogramas de Blender. Un ciclo completo emite dos apoyos.

**Climb Sound Phase** usa el mismo punto para los dos brazos: 0 es el inicio
del recorrido, 0,25 un cuarto y 0,5 la mitad. Los desfases de brazos y el
sentido invertido se aplican automáticamente. Prueba 0,15 y afina en pasos
de 0,005 hasta que coincida con el apoyo visual. La mezcla de huesos puede
añadir un pequeño retraso visual; se afina desde este mismo valor. El sonido
de entrada sigue siendo independiente. Los antiguos X/Y quedan ocultos como
datos; en 3D_playground se ha conservado el primer apoyo anterior migrándolo
al valor local 0,515, y el segundo pasa a seguir el desfase del otro brazo.

La cabeza se inclina suavemente a izquierda/derecha al ritmo de la trepada.
**Head Sway Degrees = 0** o **Head Sway Enabled** apagado lo desactiva;
**Head Sway Phase = 0,5** invierte el balanceo. Se congela junto con el ciclo
al no desplazarse y vuelve a la pose correspondiente al abandonar la escalada.

Cola y tronco usan el mismo reloj congelable y la misma respuesta suave.
Sus fases son relativas al brazo izquierdo, como la cabeza; 0,5 invierte el
sentido temporal. La cola se mueve desde `tail_base` y el tronco desde `spine`,
conservando los pivotes y longitudes. Los ejes se definen respecto al cuerpo y
se convierten a los ejes reales del hueso, sin depender de cómo quedó orientado
en Blender. Cabeza y brazos heredan los giros del tronco; las piernas no.

Los defaults recogen los valores guardados en player.tscn y 3D_playground.tscn,
sin cambiar sus overrides. Climb Grab Distance también adopta 1,15 m.
La configuración elegida activa torsión de ±8° y cola de ±14,5°. Los otros dos
giros quedan en 0° para probarlos independientemente. Para transferencia de
peso prueba **Torso Side Lean Degrees = 3°**; para esfuerzo de subida prueba
**Torso Forward Lean Degrees = 2°**. El cabeceo es oscilante y se suma a
**Climb Body Lean Degrees**, que es la inclinación base constante del modelo.
Todos estos ajustes se actualizan en vivo y 0° anula el giro correspondiente.

Los controles antiguos de capas, giros y offsets están ocultos del Inspector
mediante `@export_storage`; sus valores personalizados de las escenas quedan
serializados, pero no se consultan para generar la nueva postura. La acción
Climb se conserva en el GLB como respaldo de autoría, no como modo activo.

El rig actual sólo tiene una pieza por brazo y pierna: no hay flexión
independiente de codo o rodilla ni IK de contacto con la roca. Los ángulos
extremos pueden cruzar el torso o la pared. La pose parte del reposo real
del rig, conserva las longitudes de huesos y limita la elevación calculada
a 0–175°. El coste es calcular cuatro direcciones y mezclar los huesos por
frame durante la escalada, sin regenerar geometría.

Este es un prototipo deliberadamente amplio: también puede hacer escalables
otros objetos verticales que no estén en el grupo `climbable`. Cuando el nivel
incluya edificios, árboles u objetos similares, desactiva el modo o sustitúyelo
por una máscara de escalada. El material visual —incluido `low poly cobble
fine`— no decide el gameplay.
