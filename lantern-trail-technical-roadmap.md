# Lantern Trail / Explorer Squirrel — roadmap técnico

## 0. Regla de alcance

El primer objetivo no es un juego grande: es una **vertical slice** terminada de una montaña invernal pequeña, jugable de principio a fin. Incluye ardilla, correr/saltar, cámara third-person elevada, un NPC, diálogo, Light Seeds, tres linternas, HUD, pausa, guardado/carga y cierre. No añadir combate, inventario complejo, planeo, escalada, generación procedural ni mapa grande hasta que esta versión esté cerrada.

## 1. Arquitectura y flujo de trabajo base (días 1–3)

### Qué aprender

- Escena (`.tscn`) frente a script (`.gd`), nodos, `PackedScene`, recursos (`.tres`) y autoloads.
- La separación: **gameplay** decide estado; **UI/audio/VFX** reacciona; la UI nunca contiene reglas del juego.
- Git: un commit por cambio verificable y una rama/backup antes de cambios grandes generados por IA.

### Estructura inicial

```
res://
  scenes/{player,world,npc,props,ui}/
  scripts/{player,world,ui}/
  components/
  systems/
  autoload/{game_state,save_data}.gd
  resources/
  assets/{models,textures,audio}/
  ui/
  docs/{DESIGN,ART_BIBLE,TECH_RULES,TODO}.md
```

### Contratos arquitectónicos

1. Entrada/detección → llamada directa determinista → cambio de estado autoritativo → señal de evento completado → reacciones.
2. Una señal anuncia algo que ya ocurrió; no ordena que ocurra algo.
3. Un script/nodo tiene una responsabilidad. `PlayerController` no guarda partidas ni actualiza HUD.
4. Los datos persistentes viven en `SaveData`/`GameState`, no dispersos por nodos de escenas.
5. La animación presenta el estado; no determina la lógica de salto, recolección o encendido.

### IA: cómo pedirlo

Antes de cualquier cambio: “Inspecciona primero los archivos relevantes. Resume la arquitectura existente, propón un plan mínimo y espera mi aprobación antes de editar.”

Al aprobar: “Implementa sólo X. Conserva las APIs existentes. No refactorices archivos ajenos. Enumera archivos modificados, riesgos y cómo probarlo manualmente en Godot.”

### Hecho cuando

- El proyecto abre sin errores.
- Hay una escena `TestLevel` y una `Main` que arranca el juego.
- Existe un commit limpio etiquetable como `foundation`.

## 2. Prototipo de movimiento y cámara (semana 1)

### Qué aprender

- `CharacterBody3D`, `move_and_slide()`, gravedad, `is_on_floor()` y `velocity`.
- `InputMap`: acciones (`move_left`, `move_right`, `move_forward`, `move_back`, `jump`, `interact`, `pause`), nunca teclas hardcodeadas.
- Vectores locales/mundiales; movimiento relativo a la cámara; `Basis`; interpolación (`lerp`, `lerp_angle`).
- `SpringArm3D`, `Camera3D`, raycast/colisión de cámara.

### Implementación paso a paso

1. Crea `Player.tscn`: `CharacterBody3D` → `CollisionShape3D` (cápsula) + `MeshInstance3D` (cápsula de prueba) + `Pivot` → `SpringArm3D` → `Camera3D`.
2. Implementa caminar, correr sólo si es parte del diseño, gravedad y salto. Usa aceleración y desaceleración, no cambios instantáneos de velocidad.
3. Convierte input 2D en dirección 3D respecto a la orientación horizontal de cámara.
4. Rota visualmente la ardilla hacia la dirección de desplazamiento con suavizado; no rotes la cámara por accidente.
5. Añade suelo irregular, pendientes, escalones bajos, un hueco y una plataforma para comprobar física real.
6. Ajusta feeling antes de crear arte: velocidad, altura de salto, aceleración, fricción aérea, distancia/FOV de cámara.

### IA: entregables por separado

- implementación del controlador;
- revisión de movimiento con una tabla de parámetros exportados;
- cámara anti-clipping;
- una checklist de pruebas manuales.

No pidas esas cuatro cosas en un solo prompt.

### Hecho cuando

- Es divertido correr y saltar diez minutos sobre un greybox.
- La cámara no atraviesa de manera grave una pared y no marea.
- Cambiar números exportados en Inspector basta para afinar el movimiento.

## 3. Mundo greybox y navegación (semana 2)

### Qué aprender

- Greybox: geometría de prueba que valida tamaño, rutas, visibilidad y ritmo antes del arte.
- `StaticBody3D`/`CollisionShape3D`, capas y máscaras de colisión.
- Transformaciones, unidades y pivotes: 1 unidad Godot = 1 metro; pies de personaje sobre Y=0.
- Luz direccional, WorldEnvironment, fog y exposición a nivel básico.

### Implementación

1. Bloquea una ruta de 5–10 minutos: inicio → subida → NPC → área de semillas → las tres linternas → vista/final.
2. Diseña cada linterna para que se vea desde una distancia relevante y tenga una ruta clara pero no idéntica.
3. Añade hitos visuales y pequeñas elevaciones; no construyas un bosque denso todavía.
4. Prueba la ruta sin texturas y corrige distancias, caídas, cámara y zonas confusas.
5. Crea una escena `Lantern.tscn` y una `LightSeed.tscn`, aun con meshes primitivas.

### Hecho cuando

Una persona entiende qué hacer sin instrucciones largas, llega al final y no se pierde por geometría mal leída.

## 4. Loop jugable: interactuar, recolectar, encender (semana 3)

### Qué aprender

- Composición con componentes, interfaces prácticas mediante grupos o métodos explícitos, y señales de notificación.
- Estado persistente frente a estado de escena.
- `Area3D` para proximidad y `RayCast3D` si necesitas confirmar un objetivo visible.

### Sistemas

**InteractionController**: detecta el mejor objetivo cercano, muestra una sugerencia y llama `interact(player)`.

**LightSeed**: se recoge una vez; notifica a `GameState`; desaparece y reproduce feedback.

**Lantern**: tiene identificador estable, requisito de semillas y estado `unlit/lit`. Al encenderse actualiza persistencia, cambia luz/material/VFX y emite `lit`.

**GameState**: número de semillas y estados de linternas. No conoce nodos visuales concretos.

### Orden

1. Interactúa con un cubo.
2. Recoge una semilla.
3. Muestra contador HUD reaccionando al estado.
4. Enciende una linterna sólo con las semillas requeridas.
5. Persiste la linterna al recargar la escena.
6. Desbloquea cierre después de la tercera.

### Hecho cuando

Cerrar y abrir el nivel no duplica semillas ni apaga una linterna ya encendida.

## 5. UI, diálogo, flujo y guardado (semana 4)

### Qué aprender

- `CanvasLayer`, `Control`, anchors/containers, focus de teclado y pausa mediante `SceneTree.paused`.
- Serialización en diccionario/JSON, versionado del formato de guardado y manejo de archivos inexistentes/corruptos.
- Flujo de escenas: título → nueva/continuar → juego → pausa → final → título.

### Guardado mínimo versionado

```
{
  "version": 1,
  "checkpoint_id": "mountain_start",
  "player_position": {"x": 0.0, "y": 0.0, "z": 0.0},
  "light_seed_count": 4,
  "lit_lantern_ids": ["lantern_north", "lantern_ridge"]
}
```

No serialices nodos enteros ni rutas internas de escena. Guarda datos simples e IDs estables.

### IA: revisión requerida

Pídele revisar específicamente: “Busca estados no guardados, restauración parcial, duplicación tras cargar, referencias de nodos frágiles y errores cuando no exista archivo de guardado.”

### Hecho cuando

Nueva partida, continuar, pausar, volver al título y terminar el juego funcionan en una instalación limpia.

## 6. Pipeline de assets 3D (semana 5)

### Principio

Blender es tu fuente de verdad. Godot recibe `.glb` terminados para assets estables; conserva también `.blend`, texturas y el prompt/origen del modelo. No edites el archivo importado por Godot como si fuera el original.

### Convención técnica

- Escala aplicada en Blender: `1,1,1`.
- Transformaciones aplicadas antes de exportar.
- Pivot correcto: objetos en el suelo; puertas en bisagra; props centrados de forma útil.
- Nombres claros: `SM_Rock_A`, `SM_Lantern_01`, `SK_Squirrel`.
- Colisiones simples y separadas; no malla visual compleja como colisión.
- Materiales PBR mínimos y compartidos; no una textura de 4K por objeto pequeño.

### Uso inteligente de IA

1. Genera concept art/turnarounds para fijar forma y paleta.
2. Para rocas, troncos, bancos, faroles y props: Meshy puede generar base.
3. Abre cada modelo en Blender: escala, pivote, malla, materiales, texturas, nombres y triángulos.
4. Corrige o descarta el que no lea bien desde cámara de juego.
5. Exporta, importa en un `AssetTest.tscn` y revisa luz, sombra, colisión y escala antes de usarlo en mundo.

No generes 100 assets antes de aprobar un kit de 8–12 objetos compatibles.

## 7. Personaje principal, rig y animación (semanas 6–7)

### Lo que sí debes aprender en Blender

- Edit Mode, simetría/mirror y proporciones.
- Armature: huesos, jerarquía, poses y Actions.
- Weight paint: qué partes de la malla siguen cada hueso.
- Shape keys sólo después, si realmente hacen falta.
- NLA/Actions y exportación de clips.

### Orden correcto

1. Cierra la silueta de la ardilla en reposo; revísala en la cámara real del juego.
2. Haz un rig con cola como cadena de huesos propia. No aceptes que el rig automático decida solo cómo se comporta la cola.
3. Comprueba deformaciones: hombros, cadera, patas, cuello, cola.
4. Crea clips mínimos: `idle`, `walk`, `run`, `jump_start`, `jump_air`, `land`, `interact`.
5. Importa y configura `AnimationTree`/state machine: el código comunica variables (`speed`, `on_floor`, `just_landed`); las animaciones no deciden física.
6. Ajusta velocidad visual versus velocidad real para evitar patinaje de patas.

### IA: el papel correcto

IA puede generar base de personaje, referencias, clips de prueba y diagnósticos. Para la ardilla final, úsala como acelerador, no como autor final: cola, manos/patas y silueta son lo que vende el personaje.

### Hecho cuando

Las patas no patinan notablemente, la cola no atraviesa el cuerpo de forma constante y los clips cambian de modo limpio.

## 8. Arte del nivel, iluminación, sonido y feedback (semanas 8–9)

### Orden

1. Kit modular de terreno/rocas/árboles.
2. Materiales y paleta consistente.
3. Iluminación general y niebla; después luces de las linternas.
4. Partículas pequeñas: nieve, polvo de aterrizaje, destello de semilla, llama/halo de linterna.
5. Sonido: pasos, salto, recogida, encendido, ambiente y UI.
6. Ajuste de contraste para que semillas, linternas e interactuables siempre se lean.

Haz cada VFX como escena independiente instanciable. Así no llenas los scripts de gameplay de nodos temporales ni ajustes visuales.

## 9. QA, rendimiento y cierre (semana 10)

### Checklist funcional

- Arranque sin save y continuar con save.
- Recolectar una semilla, morir/reiniciar/cargar y verificar estado.
- Encender cada linterna en distinto orden.
- Pausa durante interacción, salto y diálogo.
- Llegar al final con save nuevo y con save previo.
- Cambiar resolución/controles si se incluyen ajustes.

### Rendimiento

- Mide antes de optimizar: FPS, frame time, draw calls, memoria y nodos visibles.
- Reutiliza materiales y meshes; instancia follaje/rocas repetidas.
- Reduce sombras y luces dinámicas donde no cambien la experiencia.
- Mantén colisiones simples y evita física/IA innecesaria fuera de cámara.

### IA: auditoría final

Pide una revisión en tres pasos: (1) dependencias frágiles y errores potenciales, (2) discrepancias entre diseño y código, (3) plan de refactor mínimo. Sólo autoriza cambios después de revisar el informe.

## Cadencia semanal realista

Por cada funcionalidad: **definir resultado → pedir plan a IA → aprobar → cambio pequeño → abrir Godot y probar → anotar bug → corregir → commit**.

No avances de fase hasta cumplir su “hecho cuando”. Si se rompe algo, vuelve al último commit estable y reduce el alcance de la tarea; no intentes arreglar diez sistemas en el mismo prompt.

## Prompts operativos reutilizables

### Planificación

> Actúa como ingeniero senior de Godot 4. Inspecciona el proyecto sin editar. Para implementar [FEATURE], identifica escenas, scripts, autoloads y dependencias afectados. Propón el cambio mínimo, contratos públicos, riesgos y una checklist de pruebas manuales. Respeta: gameplay no actualiza UI directamente; señales sólo notifican eventos terminados; persistencia sólo en SaveData/GameState.

### Implementación controlada

> Implementa únicamente [FEATURE] siguiendo el plan aprobado. No cambies sistemas no relacionados ni renombres APIs existentes. Usa componentes o escenas reutilizables cuando aplique. Añade comentarios sólo donde aclaren una decisión no obvia. Al terminar, lista archivos modificados, el flujo de datos y pasos exactos para probar en Godot.

### Revisión de un bug

> Analiza este bug de Godot 4: [OBSERVACIÓN + pasos para reproducir]. No edites aún. Da tres hipótesis ordenadas por probabilidad, qué evidencia en el código o Inspector las confirmaría y el cambio mínimo para resolver cada una.

### Revisión de asset

> Revisa este asset 3D para Godot 4 y enumera únicamente problemas verificables de escala, pivote, transformaciones sin aplicar, materiales/texturas, geometría, rig, clips, colisiones y compatibilidad de importación. Propón correcciones concretas en Blender antes de exportar GLB.

## Qué no delegar a la IA

- La decisión de si el movimiento “se siente bien”.
- La dirección artística final y qué assets pertenecen al mismo mundo.
- Verificar el juego en ejecución y decidir si un bug está realmente resuelto.
- Hacer un refactor grande sin que entiendas y apruebes el plan.

Tu función no es escribir cada línea: es mantener el diseño, el alcance y los criterios de aceptación. La IA debe producir piezas revisables; tú ensamblas un juego coherente.
