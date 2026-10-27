# TODO · Lantern Trail

## Diálogos e interfaz

- [ ] Añadir a los settings del juego controles para editar la apariencia del
  cuadro de diálogo (tamaño/escala, posición, texto, colores y márgenes), con
  un preview en vivo que muestre un diálogo de ejemplo mientras se ajustan los
  valores. Guardar los ajustes y permitir restaurar los valores por defecto.

## NPC y aprendizaje de habilidades

- [ ] Crear ardillas mentoras de diferentes colores y dimensiones que enseñen
  habilidades nuevas al player. Reutilizar la base configurable de NPC. Por
  ahora: correr, trepar, planear y trepar más rápido.

## Audio

- [ ] Reemplazar los efectos de sonido provisionales generados por código en
  `project/scripts/audio.gd` por archivos de audio diseñados o grabados.
  Conservar la API actual (`audio.play("jump")`, `audio.play("land")`, etc.)
  para que el resto del juego no necesite cambios. Prioridad inicial: salto,
  aterrizaje, pasos, recolección, faroles, interfaz, error y final.
