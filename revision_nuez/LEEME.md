# Nuez modular: revisión en Blender

Abre `../nuez_modular_final.blend`. El archivo incluye las texturas y la imagen de referencia; no necesita descargarlas ni buscarlas fuera del proyecto.

## Verlo moverse

- Pulsa **Espacio** en la vista 3D: reproduce la prueba de articulaciones.
- Fotogramas: **1** reposo, **21** codos flexionados, **41** brazos elevados, **61** rodillas flexionadas, **81** cabeza y cola, **101** reposo.
- En el Editor de acciones también están `Nuez_Correr` y `Nuez_Salto`. Son demostraciones para revisar la deformación, no animaciones finales para el juego.
- `prueba_articulaciones.mp4` muestra la prueba sin tener que abrir Blender.

## Posarlo manualmente

1. Detén la reproducción y vuelve al fotograma 1.
2. Selecciona `Nuez_Rig` en la colección **02 Nuez — esqueleto**.
3. Entra a **Pose Mode**, selecciona un hueso y usa **R** para girarlo.
4. Usa **Alt+R** para restablecer su rotación.

La traslación y la escala de los huesos individuales están bloqueadas para evitar separarlos accidentalmente. El hueso `root` permite mover todo Nuez con **G**. Al cambiar de fotograma, la acción activa vuelve a aplicar su pose: crea una acción nueva si quieres guardar tu propia animación.

## Qué se conservó y qué se refinó

- Los 15 huesos originales conservan sus nombres, posiciones y jerarquía.
- Se mantienen los objetos modulares originales. La cabeza y el cuerpo reutilizan su malla original; las articulaciones incorporan anillos de apoyo. La boca añade dos objetos pequeños.
- Las fronteras de codos, muñecas, rodillas y tobillos comparten posiciones y pesos. Las piezas son editables por separado y permanecen en contacto al doblarse.
- Los hombros, caderas, cuello y raíz de cola se conectan visualmente por volúmenes que se solapan.
- Cara, orejas, nariz y boca siguen al hueso `head`.
- Los colores de cara, barriga y cola usan texturas empaquetadas. Para verlos, utiliza **Material Preview** o renderizado.
- La colección **03 Referencias — ocultas** conserva la imagen de referencia. El Tripo de alta densidad permanece en los archivos anteriores, no en esta entrega ligera.
- La colección **04 Estudio — cámaras y luces** sirve para las vistas de revisión.

## Verificación

`validacion.json` registra 27 poses de las tres acciones, continuidad de las ocho uniones entre piezas, contacto de las extremidades y el torso, normalización de pesos y conservación del esqueleto. Los renders permiten revisar también la forma; una separación numéricamente nula no garantiza por sí sola una deformación agradable.

La malla visible suma 1.716 triángulos. El proyecto Godot no se ha modificado.
