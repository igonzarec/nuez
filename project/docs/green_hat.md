# green hat

Gorro nuevo diseñado a partir de las referencias: verde apagado, borde grueso
blanco cálido, orejas cubiertas y borde junto a los ojos. La punta cae hacia la
espalda por gravedad. No reutiliza la geometría ni la estructura del gorro anterior.

## Uso y escenas

- Arrastra `scenes/accessories/green_hat_pickup.tscn` a cualquier nivel con
  `player.tscn`. Coloca el nodo raíz donde quieras que vuelva al quitarlo.
  El playground ya incluye una instancia en la colocación que tenía el objeto
  anterior, con `Spawn Id = green_hat_playground`.
- Acércate y pulsa E, X de Xbox o cruz de PlayStation. Aparece el prompt común
  de NPC/carteles y después el selector Equipar / Quitar / Cancelar.
- Equipar retira el cuerpo del mundo: oculta visual e interacción, congela la
  física y desactiva capas/máscaras. La instancia equipada es independiente.
- Para quitarlo, abre pausa y elige la entrada de green hat. El objeto vuelve
  al origen, nunca se suelta en un precipicio junto al jugador. Si el nivel de
  origen no está cargado, reaparecerá al cargarlo. Cancelar no cambia nada.

## Inspector: forma y ajuste

**Vista previa en el editor:** al abrir `player.tscn`, GreenHatEquipped muestra
la ardilla con el gorro y su física (gravedad incluida). **Head Offset**, **Head
Rotation Degrees**, **Hat Scale** y el estilo se aplican en vivo. Es sólo de
editor: no se guarda ni existe en juego. **Editor Preview** la apaga;
**Editor Preview In Levels** la muestra también en niveles que instancian al jugador.

En `player.tscn → GreenHatEquipped → Posición respecto al jugador`, **Head Offset** ajusta el encaje en metros:
Y = 0,63 baja el gorro hasta justo encima de los ojos; Z = -0,03 lo adelanta
hacia la cara para que el frente quede pegado. **Head Rotation Degrees** usa
Y = 180 porque el modelo importado mira hacia +Z y la cola cae hacia el +Z del
visual; no cambiarlo a cero o el pompón irá a la cara. X = 4 baja apenas la
parte trasera. Con estos valores y Brim Radii 0,57 × 0,54, el borde inferior
queda a entre +1 cm y -2 cm de la cabeza en todo el contorno (medido con rayos
contra la malla de la cabeza); antes el frente quedaba 12 cm separado. Si
cambias la cabeza, reajusta primero Z y Brim Radii. **Hat Scale** modifica el tamaño;
**Hide Ears** oculta las mallas `nuez_oreja*` mediante `visible` y restaura su
estado anterior al quitar. No usa Shape Keys.

**Corte de la cabeza** (GreenHatEquipped): mientras el gorro está puesto, la malla
`nuez_cabeza` se recorta por encima de un plano a la altura del borde, así la cabeza
nunca asoma a través de la tela. **Cut Height** (0 = media altura del borde; negativo
corta más abajo) y **Cut Tilt Degrees** (X adelante/atrás, Z lateral) ajustan el plano;
**Cut Mesh Names** elige las mallas. Sólo cambia la malla visible: no toca la colisión
ni el GLB, y al quitar el gorro se restaura la original. También se ve en la vista
previa del editor. Si el corte asoma por debajo del borde, baja Cut Height.

**Style** apunta a `resources/accessories/green_hat_style.tres`, compartido por
ambas presentaciones. Edita ese recurso o hazlo único para separar variantes:

| Grupo | Controles y efecto |
| --- | --- |
| Borde | Brim Radii (0,57 / 0,54): radios X/Z; Brim Height: alto del acolchado; Brim Thickness: grosor radial. Aumentar radios envuelve una cabeza mayor. La sección es un rectángulo de cantos redondeados con la cara exterior vertical. Live Preview. |
| Cono | Crown Offset: mueve todo lo verde (copa, cola, pompón y su física) respecto al borde blanco; Z negativo lo adelanta hacia la cara, Y lo sube o hunde dentro del borde. Útil al inclinar mucho Backward Angle Degrees. Cone Length (1,5): largo del cono recto antes de doblarse; Backward Angle Degrees (24): inclinación hacia atrás en reposo, que decide hacia dónde lo dobla la gravedad; Tip Direction Degrees: 0 atrás, ±90 lateral; Crown Fullness: cúpula sobre el borde; Tip Ratio y Taper Power: grosor y estrechamiento de la cola; Folds: pliegues pintados (0,004). La base de la copa siempre se apoya plana dentro del borde y gira hasta seguir la inclinación a lo largo de la parte rígida, así que el frente nunca deja un hueco sobre el borde. Live Preview. |
| Gravedad y física de la cola | Ver la sección siguiente. En vivo salvo Rigid Ratio y Tail Bones (Live Preview). |
| Pompón | Pom Radius, Pom Scale y Pom Backward Offset (separación a lo largo de la cola). Live Preview. |
| Acabado | Body Color, Trim Color, Roughness. Segments y Length Rings aumentan suavidad y coste geométrico. Live Preview. |

Abre `scenes/accessories/green_hat_visual.tscn` para previsualizar: con
**Simulate In Editor** la gravedad dobla la cola también en el editor.
**Live Preview** agrupa las regeneraciones cada 0,2 s, también en ejecución.
No modifica el GLB ni sobrescribe colocaciones del nivel.

## Gravedad y física de la cola

La curva no se dibuja. El gorro en reposo es un cono recto inclinado hacia
atrás; la parte que abraza la cabeza (**Rigid Ratio**, 0,36 del largo) es la
copa, que sólo cede lo que le transmite la cola (**Crown Transmission**). Desde
ahí la cola es una cadena articulada: en cada articulación el peso de toda la
tela que cuelga, más el pompón, genera un par que un resorte de flexión resiste.
La cola es rígida salvo en una zona blanda, que forma un único doblez.

La misma física mueve el gorro al jugar: la inercia de acelerar, frenar y girar
la cabeza, y el aire al correr o planear, empujan la cola; inclinar la cabeza
cambia hacia dónde cae. Corre en el tick de física, después del movimiento del
personaje, y la pausa la detiene.

| Control | Efecto |
| --- | --- |
| Tail Physics | Activa la simulación; apagado deja el cono recto. |
| Rigid Ratio (0,36) | Largo de la copa (cuerpo verde que abraza la cabeza); la cola empieza aquí. Live Preview. |
| Crown Transmission (0,5) | Cuánto del movimiento de la cola se transmite a la copa. 0 la deja rígida; 1 la deja ceder como una tela el doble de rígida que la cola. El borde nunca se mueve. |
| Crown Transition (2) | Cómo se reparte esa transmisión: 1 lineal desde la cola hasta el borde; mayor la concentra junto a la cola; menor la extiende hacia el borde. |
| Tail Stiffness (12) | Rigidez de la cola fuera del doblez: mayor la mantiene recta y se balancea menos. Es también la base de la rigidez transmitida a la copa. |
| Fold Position (0,3) | Dónde está el único doblez: 0 justo tras la copa, 1 junto al pompón. |
| Fold Strength (0,9) | Qué tan pronunciado es: 0 no dobla; 1 cae casi en vertical. |
| Fold Spread (0,8) | Anchura del doblez: menor da un pliegue corto y marcado; mayor, una curva amplia. |
| Tip Softness (0) | Ablandamiento extra de la punta. 0 evita un segundo pliegue; súbelo sólo si quieres que la punta cuelgue sola. |
| Pom Weight (1) | Peso extra del pompón; mayor baja la punta. |
| Gravity Scale | Multiplica la gravedad del proyecto. |
| Damping Ratio (1) | Amortiguación relativa a la crítica: 1 se asienta sin rebotar; 0,3 rebota varias veces; más de 1, tela pesada y lenta. |
| Air Drag (1,2) | Cuánto se queda atrás la cola al correr o planear. |
| Inertia (1) | Respuesta a aceleraciones y giros de la cabeza; 0 la lleva rígida. |
| Max Inertia (30 m/s²) | Limita sacudidas de aterrizajes y teletransportes. |
| Max Bend Degrees (55) | Ángulo máximo por articulación. |
| Collision Margin (1) | Grosor de la tela que se mantiene fuera de la esfera de la cabeza. 1 evita que la cabeza asome a través de lo verde; menor deja la tela más pegada. La copa y la cola nunca se hunden más de lo que están en reposo. |
| Collision Center / Radius | Esfera de cabeza y borde sobre la que descansa la cola. Si la cola nace dentro de ella, la empuja hacia arriba: mantenla bajo la copa. |

Un solo doblez: la cola es rígida (Tail Stiffness) salvo en una única zona blanda
con forma de campana alrededor de Fold Position; antes y después de ella la tela
sigue recta, así que no aparece un segundo pliegue. Todo se lee en vivo. El resorte
y la amortiguación se integran de forma implícita, estables con cualquier rigidez.

Todas las rigideces son relativas al peso que sostiene cada articulación: con 1,
la tela horizontal se dobla unos 57° por articulación. Se leen en vivo.

Ejemplos: pliegue alto y marcado, Fold Position 0,15, Fold Strength 0,95 y Fold
Spread 0,4; curva amplia y caída, Fold Position 0,3 y Fold Spread 0,8; cola más
tiesa, Tail Stiffness 20. Medido al frenar en seco desde 7 m/s: la cola se asienta
sin oscilar con Damping Ratio 1, y la copa gira hasta 0,8° por articulación con
Crown Transmission 0,5 (1,7° con 1). El gorro tirado activa además el apoyo de la
cola en el suelo (**Ground Collision** del visual, un rayo por tick).

## Inspector: objeto del mundo

El nodo raíz es el ancla; **Spawn Transform** es el transform local inicial
del cuerpo. **Spawn Id** debe ser único y estable; vacío usa escena + ruta del
nodo, por lo que renombrarlo tras guardar cambia su identidad.

**Ground Snap**, **Ground Search** y **Ground Clearance** ajustan la búsqueda
de suelo. Si la colisión del terreno aún no existe, espera congelado y sin
interacción hasta encontrarla. **Recovery Depth** devuelve un cuerpo que cae
fuera del nivel. No persiste la posición física frame a frame.

La forma de colisión es un cilindro simple, con **Collision Radius/Height**,
**Mass**, **Friction**, **Bounce**, amortiguación y capas/máscaras editables.
**Keep Upright** bloquea vuelcos X/Z, conservando gravedad y contactos reales.
**Physics Enabled** congela/descongela el cuerpo; **Enabled** desactiva todo el
pickup. Por defecto colisiona con terreno, sin bloquear al jugador.

**Visual Offset**, **Visual Rotation Degrees** y **Visual Scale** ajustan cómo
descansa la malla dentro del cuerpo: el valor inicial inclina ligeramente el
borde para no enterrar el pompón. Si cambias mucho la forma, reajusta también
la colisión; no se recalcula a partir de cada pliegue.

**Interaction Distance** y **Prompt Height** ajustan alcance y altura de la
burbuja habitual. Los recursos **Equip Sound / Unequip Sound** permiten cambiar
muestra, volumen, tono o desactivación. Los WAV nuevos son señales breves
sintetizadas; no dependen de un servicio ni de recursos externos.

## Guardado y duplicados

Se conserva `christmas_hat` como ID interno para compatibilidad; el nombre
visible es **green hat**. `TrailWardrobe` guarda `owned`, `equipped` y `origins`
en `user://wardrobe.json`, usando escritura temporal antes del reemplazo. No
se mezcla con el avance de la expedición ni se borra al iniciar otra partida.

Sólo el origen autorizado puede mostrar el pickup. Las copias accidentales
con el mismo ID no crean gorros físicos adicionales. Los guardados anteriores
sin origen adoptan el primer pickup cargado; se persiste en la siguiente
elección. Un fallo de escritura revierte el cambio en memoria y muestra aviso.

Los archivos antiguos del gorro permanecen disponibles, pero `player.tscn` y
`3D_playground.tscn` ya no los instancian. Para otros niveles, usa la escena
nueva; no coloques ambas implementaciones juntas.
