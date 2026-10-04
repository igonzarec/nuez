# Referencia · Montaña 3D, escalada y nieve

Esta guía define una dirección técnica inicial para construir la montaña de
Lantern Trail. No es una lista de tareas inmediata: sirve como referencia para
cuando el prototipo de movimiento esté suficientemente estable.

## Blender y Godot: responsabilidades

Usar un flujo híbrido:

- **Blender:** forma artística de la montaña y assets como rocas, pinos,
  puentes, cuevas y monumentos.
- **Godot:** composición del nivel, colocación de objetos, colisiones,
  iluminación, interacción, zonas escalables y reglas de gameplay.

La pregunta práctica es:

- “¿Cómo se ve esta roca o ladera?” → Blender.
- “¿Dónde está y qué función cumple en la exploración?” → Godot.
- “¿Se puede escalar, hablar ahí o desbloquear algo?” → Godot.

Evitar una única malla gigantesca que contenga todo el nivel terminado: dificulta
mover rutas, objetos y puntos de interés durante el diseño.

## Escala y exportación

Una montaña importada se puede escalar desde Godot durante el prototipo. Para la
versión final, la práctica preferida es trabajar en Blender con una escala
razonable (idealmente 1 unidad ≈ 1 metro), aplicar transformaciones con
`Ctrl + A → Scale` y exportar el GLB con escala `1, 1, 1`.

Evitar escalas no uniformes permanentes, por ejemplo X=2, Y=0.7, Z=3, porque
vuelven menos intuitivas las colisiones, distancias, escalada y colocación de
objetos.

### Escala de referencia de la ardilla

La escala actual del personaje jugable sirve como referencia para modelar la
montaña y sus elementos. El modelo visual `assets/playertest2/playertest2.glb`,
medido en su pose base e incluyendo orejas y cola, ocupa aproximadamente:

| Medida | Tamaño |
| --- | ---: |
| Alto | 1,84 m |
| Ancho | 1,01 m |
| Profundidad | 1,16 m |

La cápsula de colisión del jugador tiene un radio de **0,42 m** y una altura de
**1,42 m**. La ardilla está planteada como un personaje antropomórfico; estas
medidas no intentan representar el tamaño de una ardilla real. Para el diseño
del entorno, puertas, repisas, rocas y espacios de paso deben sentirse
proporcionados a esta escala.

## Rendimiento y optimización

Una montaña low-poly bien hecha no tiene por qué ser pesada. Como orientación
inicial, una montaña principal de aproximadamente 5 mil a 30 mil triángulos
puede ser razonable; no es un límite universal.

El rendimiento depende también de:

- cantidad de objetos separados y materiales;
- sombras en tiempo real;
- pinos, rocas y partículas visibles;
- complejidad de colisiones;
- distancia de dibujo de la cámara.

Dirección futura:

- usar una malla visual bonita y una colisión más simple;
- reutilizar assets de pinos y rocas;
- simplificar u ocultar objetos lejanos;
- limitar materiales por asset;
- medir el rendimiento antes de optimizar agresivamente.

Primero se diseña una montaña divertida de explorar; después se mide qué cuesta
realmente.

## Escalada según inclinación

La normal de la superficie permite conocer su inclinación:

| Ángulo respecto a arriba | Ejemplo |
| --- | --- |
| 0° | Suelo plano |
| 48° | Límite aproximado actual para caminar |
| 65° | Ladera muy empinada |
| 90° | Pared vertical |

Una regla posible:

> Una superficie puede escalarse si pertenece a la categoría física
> `climbable`, su inclinación está entre 65° y 100°, el jugador está cerca,
> mirando hacia ella y mantiene Brincar/A.

No conviene usar sólo inclinación: de lo contrario también podrían escalarse
casas, faroles, letreros o árboles. Marcar el acantilado entero como `climbable`
permite escalada natural sin tener que pintar zonas pequeñas una por una.

## Nieve y huellas

La nieve debe vivir principalmente en Godot: materiales, intensidad según
altura, partículas, viento, niebla y cambios de estado. Blender puede aportar
la montaña, UVs, materiales base y máscaras pintadas para zonas específicas.

### Nivel 1 · Huellas visuales

Al apoyar una pata en nieve, aparece una pequeña huella plana sobre la
superficie. Es la opción recomendada para empezar: controlable, ligera y
adecuada para el estilo low-poly. Puede desaparecer con el tiempo.

### Nivel 2 · Máscara de nieve dinámica

Un shader de Godot pinta una textura dinámica al caminar. Esa máscara modifica
el color o relieve visual de la nieve y permite huellas continuas, caminos y
desvanecimiento gradual.

### Nivel 3 · Deformación de malla

La geometría de la nieve se hunde realmente. Es posible, pero no recomendada
para este proyecto por ahora: es más costosa y compleja de lo necesario.

Las huellas pueden ser visuales sin cambiar colisiones; es el enfoque normal en
muchos juegos.

## Orden recomendado de aprendizaje e implementación

1. Crear una montaña low-poly base en Blender.
2. Prepararla y exportarla como GLB.
3. Importarla en Godot y crear colisión simple.
4. Separar roca, nieve y senderos mediante materiales.
5. Definir superficies caminables, resbalosas y escalables.
6. Añadir nieve decorativa.
7. Añadir huellas visuales simples.
8. Evaluar una máscara de nieve dinámica sólo si el resultado lo justifica.
