# Ajustar la animación de la ardilla

## Dónde están los controles

1. En **FileSystem** de Godot, abre **res://scenes/player.tscn**.
2. En el árbol **Scene**, selecciona el hijo **Animation**.
3. En **Inspector**, despliega los grupos de animación descritos abajo.
4. Cambia un valor, guarda la escena con **Ctrl+S** y ejecuta el juego con **F5**.

Los valores del nodo raíz **SquirrelExplorer** controlan velocidad, aceleración, gravedad y salto. Los del hijo **Animation** controlan la apariencia del movimiento. No necesitas editar el GLB.

Para experimentar mientras juegas: cambia el árbol a **Remote**, busca **LanternTrail → MountainTrail → SquirrelExplorer → Animation** y modifica sus valores. Verás el cambio durante la ejecución. **Los cambios en Remote se pierden al detener el juego**: apunta los valores elegidos y aplícalos después al nodo Animation de la escena local, guardándola.

## Controles principales

Los ángulos que incluyen **Degrees** se expresan en grados; alturas y desplazamientos, en unidades del juego. Los controles Left/Right permiten ajustar cada lado por separado.

| Grupo del Inspector | Campo | Inicial | Qué cambia |
| --- | --- | --- | --- |
| Ritmo y transiciones | Stride Length | 2,1 | Distancia por ciclo completo. Más alto: menos ciclos y una carrera más pausada visualmente. |
| Ritmo y transiciones | Cadence Multiplier | 1 | Multiplica el ritmo de patas, brazos y pasos; no cambia la velocidad de desplazamiento. |
| Ritmo y transiciones | Blend Speed | 14 | Rapidez al mezclar reposo, carrera y poses. Más bajo: transiciones más suaves y lentas. |
| Patas y apoyo | Step Height | 0,10 | Cuánto sube la pata durante el paso. La rodilla se flexiona para alcanzar esa posición. |
| Patas y apoyo | Step Reach | 0,19 | Cuánto avanza y retrocede cada pata respecto al cuerpo. |
| Patas y apoyo | Stance Ratio | 0,56 | Fracción del ciclo dedicada al apoyo; el resto es el arco de recuperación. |
| Patas y apoyo | Run Crouch | 0,045 | Cuánto baja el cuerpo al correr; aumenta la flexión de rodillas. |
| Patas y apoyo | Foot Roll Degrees | 6 | Inclinación de las patas al despegar y recuperarse. |
| Patas y apoyo | Left / Right Leg Multiplier | 1 / 1 | Intensidad de alcance y elevación de cada pata. |
| Brazos y codos | Arm Swing Degrees | 28 | Amplitud hacia delante y atrás de los brazos. |
| Brazos y codos | Arm Spread Degrees | 5 | Separación lateral de los brazos. |
| Brazos y codos | Elbow Bend Degrees | 18 | Flexión base de los codos durante la carrera. |
| Brazos y codos | Elbow Swing Degrees | 16 | Flexión adicional cuando el brazo avanza. |
| Brazos y codos | Arm Phase Offset | 0,06 | Retraso de brazos respecto a patas, en fracciones de ciclo. |
| Brazos y codos | Left / Right Arm Multiplier | 1 / 1 | Intensidad del balanceo y flexión de cada brazo; cero suprime su ciclo de carrera. |
| Cuerpo y cabeza | Body Bounce | 0,022 | Pequeño rebote vertical acompasado con los apoyos. |
| Cuerpo y cabeza | Body Sway | 0,014 | Desplazamiento lateral del peso. |
| Cuerpo y cabeza | Body Roll Degrees | 2,5 | Inclinación lateral del torso al alternar pasos. |
| Cuerpo y cabeza | Torso Twist Degrees | 4 | Giro alterno del pecho respecto a las caderas. |
| Cuerpo y cabeza | Run Lean Degrees | 3 | Inclinación hacia delante durante la carrera. |
| Cuerpo y cabeza | Head Stabilization | 0,75 | Cuánto compensa la cabeza los giros e inclinaciones del torso. |
| Cuerpo y cabeza | Run Squash | 0,012 | Compresión/estiramiento muy leve del cuerpo durante el ciclo. |
| Cuerpo y cabeza | Sprint Exaggeration | 1,18 | Refuerzo de brazos, elevación de patas, torso y rebote al correr rápido. |
| Salto y aterrizaje | Landing Duration | 0,16 | Duración de la reacción al aterrizar, en segundos. |
| Salto y aterrizaje | Landing Squash | 0,09 | Compresión máxima del aterrizaje, graduada según el impacto. |
| Inclinacion y cola | Acceleration Lean | 0,045 | Inclinación adicional al acelerar/frenar, en radianes. |
| Inclinacion y cola | Turn Lean | 0,055 | Inclinación máxima al girar, en radianes. |
| Inclinacion y cola | Tail Stiffness | 65 | Rapidez con que la cola persigue su pose objetivo. |
| Inclinacion y cola | Tail Damping | 16 | Cuánto se amortigua su oscilación. |
| Inclinacion y cola | Tail Limit | 0,18 | Límite de giro secundario de la cola, en radianes. |
| Inclinacion y cola | Tail Run Sway Degrees | 2,5 | Balanceo de cola asociado a los pasos, antes de la amortiguación. |
| Inclinacion y cola | Tail Turn Pull | 0,16 | Flexión lateral del extremo grande, contraria al giro real del cuerpo. Cero desactiva el desplazamiento lateral. |
| Cola elastica en salto | Tail Air Drop | 0,16 | Cuánto baja el extremo grande al subir y cuánto se eleva al caer. |
| Cola elastica en salto | Tail Air Stretch | 0,16 | Intensidad del estiramiento/compresión; cero desactiva el cambio de escala, no la flexión. |
| Cola elastica en salto | Tail Air Response | 12 | Rapidez de respuesta a la velocidad vertical. Menor valor: más retraso suave. |

## Pendientes y desenfoque

### Brazos durante el salto

En **player.tscn → Animation → Brazos elasticos en salto**:

- **Arm Air Lift Degrees = 110°**: elevación durante la caída; 90° los deja aproximadamente horizontales y 110° los levanta por encima de los hombros. Se mantienen abiertos hasta recuperar apoyo.
- **Arm Fall Elbow Degrees = 5°**: flexión de codos al caer. 0° los extiende, 5° deja una curva leve y 25° los dobla más.
- **Arm Air Drop = 0,035**: desplazamiento elástico de los antebrazos; bajan al subir y se elevan al caer.
- **Arm Air Stretch = 0,08**: estiramiento suave al subir y caer, con compensación de volumen.
- **Arm Air Response = 12**: rapidez de respuesta; valores menores añaden retraso. Las manos siguen un poco después de los hombros.

El efecto se mezcla con carrera e interacción y se desvanece al aterrizar. No modifica el salto ni los controles.

Los pesos de brazos y antebrazos están separados del abdomen: elevar o estirar los brazos no debe levantar ni ensanchar la panza. El archivo original permanece intacto; esta corrección está en los modelos optimizados.

En **player.tscn → SquirrelExplorer → Deslizamiento en pendientes**:

- **Slide Acceleration = 7**: aceleración suave cuesta abajo.
- **Slide Max Speed = 3**: velocidad máxima del deslizamiento.
- **Slide Steering = 0,2**: control lateral mientras resbala; no permite forzar la subida.
- **Ground contact → Walkable Slope Degrees = 48°**: inclinación máxima caminable. Se aplica al iniciar la escena.

Una pendiente no caminable activa una pose de deslizamiento, sin ciclo de carrera ni pasos. Puedes dirigirla lateralmente o saltar para separarte. Las pendientes normales siguen teniendo apoyo estable, sin resbalones en reposo.

En **camera_rig.tscn → nodo raíz → Desenfoque de distancia**:

- **Distant Blur Enabled**: activa/desactiva el efecto.
- **Blur Start = 18**: distancia desde la cámara a partir de la cual empieza.
- **Blur Transition = 12**: distancia adicional para alcanzar la intensidad completa.
- **Blur Strength = 3**: radio máximo del filtro, en píxeles de renderizado.

El efecto es progresivo, compatible con el renderizador Compatibility y no desenfoca la interfaz. No cambia la distancia fija de cámara ni captura el cursor. La cola recupera su forma al aterrizar: la deformación es reversible y no modifica el GLB original.

## Cómo afinarla

### Planeo con segunda pulsación de salto

En el nodo raíz de **player.tscn → Planeo**:

- **Glide Enabled**: permite desplegar con una nueva pulsación en el aire; otra pulsación recoge.
- **Glide Fall Speed = 2,6**: descenso máximo estable; 2 baja más despacio y 4 más rápido.
- **Glide Gravity Scale = 0,3**: gravedad durante el descenso planeando; no modifica la subida del salto.
- **Glide Braking = 30**: suavidad del frenado al abrir durante una caída rápida.
- **Glide Air Control = 0,7**: control horizontal durante el planeo.

En **Animation → Postura de planeo**:

- **Glide Arm Degrees = 95°**: apertura de los brazos; no sobrescribe Arm Air Lift Degrees del salto normal.
- **Glide Leg Degrees = 28°**: apertura de las piernas.
- **Glide Lean Degrees = 20°**: inclinación del cuerpo hacia delante.
- **Glide Blend Speed = 12**: rapidez de despliegue y recogida.

Las membranas son una malla visual independiente, unida a la postura de manos y patas. Los brazos tubulares no comparten triángulos ni pesos con el torso: no aparece una membrana accidental en saltos normales. Los huesos del hombro proporcionan el giro principal y los codos una flexión secundaria.

Empieza por **Arm Swing Degrees**, **Elbow Bend Degrees** y **Step Height**. Después ajusta el cuerpo con **Body Bounce** y **Torso Twist Degrees**. Cambia un parámetro cada vez para reconocer su efecto.

Para una carrera algo más expresiva, prueba brazos **34°**, codos **22°**, torso **5°** y rebote **0,028**. Para una carrera más contenida, prueba brazos **22°**, torso **2°** y rebote **0,015**. Son puntos de partida, no presets obligatorios.

Mantén inicialmente ambos lados en **1**. Una diferencia leve, por ejemplo **0,95 / 1**, aporta asimetría; una diferencia grande parece cojera. El modelo tiene patas cortas: amplitudes extremas de Step Reach o Step Height pueden deformarlas aunque el controlador siga funcionando.

La carrera usa un esqueleto de 15 huesos con torso y codos articulados. Brazos y piernas se alternan, los apoyos tienen una fase distinta al movimiento aéreo, la cabeza compensa parte del torso y la cola responde con retraso. Es una animación procedural ajustable, no clips extraídos de Animal Crossing.

La cola ahora combina giro con flexión lateral de su extremo pesado: tarda en seguir los cambios de dirección y vuelve al centro con amortiguación. **Tail Stiffness** y **Tail Damping** también controlan esta respuesta. Se basa en el giro real de la ardilla, no en mover la cámara estando quieta; funciona junto con la deformación vertical del salto.
