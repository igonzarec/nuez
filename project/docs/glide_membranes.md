# Membranas de planeo procedurales

`GlideMembranes` (`scripts/glide_membranes.gd`) dibuja las membranas de Glide
como una superficie entre costado, mano y pata, reconstruida cada frame desde
los huesos de playertest2. Sigue el clip Glide, el temblor y el recoil sin
Shape Keys. La visibilidad la sigue decidiendo `SquirrelRig` con el mismo
`glide_amount`; las membranas nunca aparecen fuera del planeo.

## Dónde están los controles

`scenes/player.tscn` → nodo **GlideMembranes** (hijo directo del jugador).
Todos los valores se actualizan en vivo, también durante el juego.

- **Source**: *Procedural* oculta las membranas de Blender y usa éstas;
  *Blender* vuelve a las de `nuez2rig.blend` sin tocar nada más.
- **Anclajes (lado izquierdo)**: cuatro esquinas en el espacio local de su hueso.
  El lado derecho se refleja solo.
  - *Shoulder / Hip Offset* (hueso `spine`): dónde nace la membrana en el costado.
  - *Wrist Offset* (`arm_left`): Y avanza por el brazo; la mano acaba hacia 0,46.
    Con X y Z en 0 la esquina queda dentro del brazo, sin el pico que asomaba
    en la versión de Blender.
  - *Ankle Offset* (`leg_left`): igual, el pie acaba hacia 0,37.
- **Forma**: curvas de los bordes exterior, delantero y trasero (positivo =
  cóncavo hacia el centro), *Billow* (abombado hacia la espalda) y
  subdivisiones *Columns / Rows*.
- **Apertura → Fold Retract**: cuánto se recogen mano y tobillo hacia el
  costado mientras la membrana abre o cierra.
- **Apariencia**: color principal, color y anchura del degradado de borde,
  rugosidad, contraluz (*Backlight*), sombra, o un material propio.
- **Vista previa en el editor**: activa *Editor Preview* para ver la ardilla
  posada con el clip *Preview Animation* en *Preview Time*. *Preview Open*
  simula la apertura y *Preview Show Blender* superpone las membranas antiguas
  para comparar. La vista previa no se guarda en la escena.

## Ejemplos

- Membrana más tensa y recta: *Outer Edge Curve* 0, *Billow* 0,03.
- Aspecto de ardilla voladora real: *Outer Edge Curve* 0,15, *Rear Edge Curve* 0,12.
- Si la membrana asoma por delante del brazo, baja *Wrist Offset* Y (0,28–0,30)
  o deja X/Z en 0.

## Límites

- Coste: una malla de (Columns+1)×(Rows+1) vértices por lado, regenerada sólo
  mientras es visible. Con los valores por defecto son 162 vértices en total.
- Los NPC no planean y siguen sin membranas procedurales.
- El sistema de toon sustituye el material al aparecer el nodo; cambiar el
  material en pleno juego puede saltarse ese reemplazo hasta reiniciar.
