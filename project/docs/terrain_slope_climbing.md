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
