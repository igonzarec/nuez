# Patinaje sobre hielo

Al pisar una textura de hielo pintada en Terrain3D, la ardilla entra en el estado
`skate`. Cambian la física (inercia, curvas abiertas, frenada en «T») y la pose
procedural (zancadas laterales alternas con las manos a la espalda). Hay sonidos
de cuchilla y un reflejo ligero sobre el hielo. Al saltar se usa el aire normal,
y al aterrizar sobre hielo vuelve a patinar.

## Probarlo

Abre `scenes/ice_playground.tscn` y ejecútala con F6. Es una variante heredada de
`3D_playground.tscn` que carga `scenes/ice_terrain.tscn`: una pradera con una
pista ovalada de hielo y una rampa helada suave al oeste. R reaparece.

Con **pies manuales** (opción por defecto):
- **L2 / Z**: empuje con el pie izquierdo. **R2 / C**: empuje con el derecho.
  Hay que alternarlos. Alternar deprisa da un patinaje rápido y fluido; alternar
  despacio, uno lento. Cada empujón suma menos al acercarse a la velocidad
  máxima.
- **Racha**: cada empujón bien alternado poco después del anterior (dentro de
  `Skate Streak Window`) sube un multiplicador. Ese multiplicador eleva el
  impulso y el techo de velocidad, así que manteniendo el ritmo la velocidad
  se acumula. Con los valores por defecto y empujando cada 0,35 s, pasa de
  9 m/s sin racha a unos 19 m/s. Parar de empujar, sostener la pierna más que
  la ventana, repetir pie o caer reinicia la racha. A más velocidad, la ardilla
  va más agachada y alarga la zancada.
- **Saltar patinando** conserva la velocidad: en el aire sólo se curva el rumbo
  y frena muy poco. Cuanto más rápido vas, más alto saltas (a 19 m/s, unos 3 m
  en vez de 2). La racha se mantiene en el aire: si aterrizas sobre hielo
  sigues acumulando, y si aterrizas fuera se reinicia.
- **Mantener un gatillo** deja esa pierna elevada en el punto más abierto del
  empujón: la ardilla desliza sobre la otra pierna hasta que sueltas. Mantenerla
  no da más impulso. Para empujar con el otro pie, suelta antes, o el solape
  cuenta como fallo.
  Si la sostienes hasta casi detenerte (por debajo de `Skate Hold Fall Speed`
  durante `Skate Hold Fall Delay`), pierde el equilibrio y se cae.
- **Stick / WASD**: sólo dirige. El rumbo gira poco a poco, y más despacio cuanto
  más rápido vas. Si se empuja contra el rumbo, hace una frenada de hockey.
- **Fallos**: repetir el mismo pie, o mantener ambos gatillos pulsados más
  tiempo del que permite la ventana de dificultad, hace que la ardilla se caiga.
  Se queda sentada, resbala sin control un rato y luego se levanta.
- Recentrar la cámara se hace con R3 (clic del stick derecho) o V; R2 y C quedan sólo para los pies.

Con `Skate Manual Feet` apagado, el stick impulsa con zancadas automáticas y
Sprint aumenta la velocidad. Los NPC siempre usan zancadas automáticas.

## Añadir hielo a otro terreno (p. ej. `automatic_cliff_playground`)

1. Selecciona el nodo `Terrain3D` › Assets › Textures y añade un slot nuevo.
   Carga `assets/textures/ice/ice_albedo_height.png` como Albedo y
   `ice_normal_roughness.png` como Normal. También puedes partir de
   `assets/textures/ice/ice_terrain3d.tres`. **El nombre del slot debe contener
   «ice»**.
2. Añade como hijo de `Terrain3D` un `Node` con el script
   `scripts/terrain/terrain_ice_surface.gd` (clase `TerrainIceSurface`).
3. Pinta el slot con la herramienta Paint de Terrain3D. El player patina donde
   la cobertura del hielo (base o mezcla de overlay) supera `Minimum Coverage`.

Si el slot se llama de otra forma, pon su ID en `Extra Texture Ids`. El audio y
el reflejo ya vienen en `player.tscn`, así que no hace falta añadirlos.

## Controles en el Inspector

**TerrainIceSurface** (nodo hijo de Terrain3D), grupo *Detección*:
- `Enabled`, `Terrain` (vacío usa el padre), `Texture Name Match`,
  `Extra Texture Ids`. Los slots se resuelven al iniciar; si añades slots durante
  el juego, llama a `refresh_texture_ids()`.
- `Minimum Coverage`: cuánto hielo hace falta en los bordes difuminados.
- `Contact Tolerance`: evita patinar sobre objetos situados encima del hielo.
- `Maximum Slope Degrees`: por encima se usa el movimiento normal.

**ExplorerPlayer** (`SquirrelExplorer`):
- *Patinaje sobre hielo · física*: velocidades de crucero y sprint (modo
  automático), aceleración, `Stroke Pulse`, rozamientos, giro y su atenuación a
  alta velocidad, frenada y giro visual al frenar, gravedad en rampas, giro del
  cuerpo y `Contact Grace`.
- *Patinaje sobre hielo · zancadas*: ritmo (Hz) del modo automático,
  multiplicador con sprint y mezcla entre zancada y deslizamiento.
- *Patinaje sobre hielo · pies (L2/R2)*: `Skate Manual Feet`, `Push Impulse`,
  `Manual Max Speed`, `Push Duration`, `Skate Hold Leg Enabled` (pierna
  elevada al mantener el gatillo), `Skate Hold Response`, y la caída al
  sostenerla casi parada: `Skate Hold Fall Enabled`, `Skate Hold Fall Speed`
  (0,8 m/s) y `Skate Hold Fall Delay` (0,3 s).
  - **`Skate Feet Difficulty`** (0–1): estrecha la ventana de solape tolerada
    entre gatillos, de 0,35 s a 0,04 s.
  - `High Speed Window Scale`: cuánto se estrecha además esa ventana a alta
    velocidad.
  - `Same Foot Memory`: tras este tiempo sin empujar, se puede repetir el mismo
    pie sin caer.
  - `Fall Min Speed`: por debajo de esta velocidad, un fallo no tumba; sirve
    para arrancar.
- *Patinaje sobre hielo · racha*: `Skate Streak Enabled`, `Skate Streak Gain`
  (subida por empujón), `Skate Streak Max Multiplier` (×2,5),
  `Skate Streak Window` (0,9 s entre empujones) y `Skate Streak Max Speed`
  (techo absoluto, 20 m/s).
- *Patinaje sobre hielo · salto*: `Skate Jump Keep Speed`, `Skate Air Drag`
  (frenado en el aire), `Skate Air Turn Rate Degrees` (giro en el aire),
  `Skate Jump Keep Streak` y `Skate Jump Speed Lift` (impulso vertical extra a
  máxima velocidad).
- *Patinaje sobre hielo · caída*: activación, duración, recuperación,
  rozamiento al resbalar caído y `Skate Fall Scream Enabled` (grito del splat).

**SquirrelAnimator** (nodo hijo `Animation` del player):
- *Patinaje · postura*, *manos atrás*, *zancadas* y *estilo*: pose, brazos,
  piernas, inclinación en curvas, cola, orejas, balanceo y frenada.
- *Patinaje · velocidad*: inclinación extra y alargamiento de la zancada con la
  velocidad, y la velocidad a la que llegan al máximo (`Speed Pose Full Speed`).
- *Patinaje · pierna sostenida*: elevación y apertura extra de la pierna
  mantenida, e inclinación del cuerpo para equilibrarla.
- *Patinaje · caída*: inclinación hacia atrás, descenso hasta quedar sentada,
  vuelco lateral, piernas arriba y pataleo, brazos en aspaviento, frecuencia y
  cabeza.

**IceSkateAudio** (hijo del player): slots `AudioStream` sustituibles para el
empujón, el siseo de deslizamiento (loop según velocidad), la frenada (loop) y el
aterrizaje sobre hielo. Cada uno tiene volumen; además hay variación de tono,
rango de velocidad y de tono, fundido, bus y atenuación 3D. Los sonidos
provisionales se sintetizan en `audio/ice_skate/`. Sobre hielo, el aterrizaje
normal de nieve o tierra se sustituye por el de hielo.

**IceReflection** (hijo del player): `Opacity`, `Fade Depth` (cuánto cuerpo se
refleja), `Max Height` (reflejo al saltar), `Response`, `Tint`, `Tint Amount`,
`Brightness`, `Rescan Interval` y `Depth Lift`.

Todo se actualiza en vivo, también desde el Remote del editor durante F6.

## Cómo funciona

- `TerrainIceSurface.ice_contact()` lee `Terrain3DData.get_texture_id()`
  (base, overlay y mezcla) y sigue el patrón de `snow_contact()`.
  `ExplorerPlayer.ice_contact_at()` consulta todos los receptores del grupo
  `ice_surface_receivers`.
- `_skate_planar()` sustituye la aceleración terrestre. En modo manual,
  `_tick_skate_feet()` suma `impulso · (1 − (v/vmax)²)` en cada empujón válido.
  Así la velocidad de equilibrio depende del ritmo frente al rozamiento.
- `SquirrelRig._apply_procedural_skate()` construye la pose desde el reposo del
  rig, sin clips de Blender. Cada empujón manual recorre media fase de la
  zancada de su pierna, y la caída se mezcla con `skate_fall_weight()`.
- **Reflejo**: el proyecto usa el renderer Compatibility, sin SSR.
  `IceReflection` copia las mallas rígidas del modelo, incluidos los
  accesorios, y las refleja respecto al plano del hielo. El shader
  `shaders/ice_reflection.gdshader` mezcla el color con la imagen del hielo y
  escribe la profundidad del punto del plano que atraviesa la mirada. Así lo que
  está delante tapa el reflejo y las partes solapadas no se suman. No refleja
  mallas con skin (las membranas de planeo).
- Las piernas son rígidas: con aperturas grandes, el pie que empuja se levanta
  del hielo. Es intencional para mantener la lectura de la zancada.

## Regenerar recursos

```bash
godot --headless --path project --script res://tools/generate_ice_textures.gd
```

```bash
godot --headless --path project --script res://tools/generate_ice_skate_sounds.gd
```

```bash
godot --headless --path project --script res://tools/build_ice_playground_terrain.gd
```

El último script sobrescribe sólo `terrain_data/ice_playground`.
