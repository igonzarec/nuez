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

## Animación de escalada

La postura visual usa la acción `Climb` de `assets/playertest2/playertest2.glb`.
El controlador reproduce el clip en bucle mientras la ardilla se desplaza por
la pared; el final del clip debe repetir exactamente su primer fotograma para
que el ciclo no salte. En `SquirrelExplorer`, Inspector > **Escalada**,
**Climb Member Speed** multiplica ese ritmo en vivo: 0 lo congela y un valor
mayor lo acelera sin modificar la velocidad física ni las colisiones. **Climb
Member Degrees** queda como ajuste de respaldo sólo para versiones antiguas
del modelo que no incluyan la acción `Climb`.

El audio usa `audio/Gentle Stone Drop.wav`: al entrar en escalada reproduce
un único sonido de agarre. Luego suena en las fases 0 y 0,5 del reloj real del clip (frames
1 y 13), sin otro golpe en el frame 25. Al detener la animación no se generan
nuevos apoyos; cada muestra ya iniciada termina naturalmente.
En Inspector > **Escalada**, **Climb Sound Enabled** activa el efecto,
**Climb Sound Phases** permite desplazar ambos contactos en vivo. Por ejemplo,
(0.05, 0.55) retrasa ambos apoyos un 5 % del ciclo. El volumen conserva el
control de escalada del menú de audio y el bus SFX.

Este es un prototipo deliberadamente amplio: también puede hacer escalables
otros objetos verticales que no estén en el grupo `climbable`. Cuando el nivel
incluya edificios, árboles u objetos similares, desactiva el modo o sustitúyelo
por una máscara de escalada. El material visual —incluido `low poly cobble
fine`— no decide el gameplay.
