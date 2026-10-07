# Pasto vivo por particulas

Tercera opcion de pasto, junto al parche de hojas 3D (`GrassCarpet3D`) y las
tarjetas pintadas con el Instancer. Escena: `res://scenes/grass_terrain_particles.tscn`.

Deriva del ejemplo `Terrain3DParticles` del addon. La logica de rejilla es la
misma; lo que cambia es que todo lo que el ejemplo dejaba escrito a mano en el
shader o enterrado en el material se expone en el Inspector.

## Como funciona

Una cuadricula de emisores `GPUParticles3D` sigue a la camara. El shader de
particulas lee los mapas de altura, control y color de Terrain3D y coloca cada
hoja sobre el relieve, en la GPU, cada fotograma.

Consecuencias practicas:

- **No hay nada que pintar ni que guardar.** El pasto aparece solo sobre todo el
  terreno dentro del alcance. Tampoco se puede decidir mata a mata donde va: para
  eso estan los otros dos sistemas.
- **Se adapta solo** al esculpir o pintar: los mapas se releen cada fotograma.
- **Sigue a la camara**, asi que el alcance es un radio movil, no un area fija.

## Controles

Selecciona `Terrain3D/GrassParticles`. Todos se aplican en vivo.

| Grupo | Que controla |
| --- | --- |
| Terreno | Nodo Terrain3D (se asigna solo si es hijo suyo) y Enabled para apagarlo todo. |
| Vista previa en el editor | Editor Preview dibuja el pasto dentro del editor y lo actualiza al tocar cualquier control, siguiendo la camara del viewport. Desactivalo si el editor va lento: el pasto sigue apareciendo al ejecutar. Los emisores se crean sin owner, asi que nunca se guardan en la escena. |
| Densidad y alcance | Density en matas/m2, Draw Distance en metros, Grid Width (celdas por lado, impar), Max Particles como tope de seguridad y Particle Count informativo. |
| Forma de la hoja | Uniform Height con Blade Height para una altura unica, o Height Min y Height Max en metros, Blade Width, Taper Curve (perfil de ancho; por defecto triangulo), Blade Sections, Cross Shape, Pinch y Base Offset. |
| Manchas y variacion | Patch Frequency, Patch Start y Patch Full definen donde hay calvas; Clump Boost con Clump Start y Clump Full crean penachos mas altos; Random Spacing y Random Rotation rompen la rejilla. |
| Colocacion en el terreno | Align To Normal y Normal Strength para seguir la pendiente, Maximum Slope en grados, Slope Dither, Distance Fade y Excluded Texture ID. |
| Color | Root Color, Tip Color, Tip Highlight, Root Shading y Color Variation. |
| Iluminacion | Roughness, Specular, Backlight y Cast Shadows. |
| Viento | Wind Enabled, Strength, Speed, Direction en grados, Scale, Dithering, Wobble Amount y Wobble Speed. |
| Rendimiento | Process FPS: veces por segundo que se recalcula el viento. |

### De donde viene la variacion de altura

Tres cosas distintas cambian el alto de cada mata, y por eso igualar Height Min y
Height Max no bastaba para tener un pasto parejo:

1. El valor al azar entre **Height Min** y **Height Max**.
2. **Clump Boost**, que suma altura extra donde el ruido tiene nucleos: son los
   penachos destacados.
3. **Patch Start / Patch Full**, que escalan la mata entera cerca de las calvas.
   Una mata a medio tamano es tambien una mata mas baja.

**Uniform Height** desactiva las tres de golpe y usa **Blade Height** para todas.
El borde de las calvas se vuelve un corte limpio, porque ya no hay tamanos
intermedios. Mientras este activo, el Inspector oculta los controles que quedan
sin efecto.

### Densidad y el tope de particulas

**Density** son matas por metro cuadrado y es lo que mas cuesta: el total crece
con el cuadrado del valor. Internamente se convierte a separacion entre
instancias, limitada entre 0.125 m y 2 m por el shader, asi que valores por
encima de 64 o por debajo de 0.25 se recortan.

**Max Particles** (400.000 por defecto) evita congelar el editor: si densidad y
alcance piden mas, se reduce la densidad efectiva antes que el alcance, porque
perder densidad se nota menos que ver aparecer el pasto a pocos metros.
**Particle Count** muestra el total real.

### Diferencia respecto al ejemplo del addon

El shader original filtraba la textura con ID 0 escrita a mano en el codigo, lo
que dejaba el terreno sin pasto en cuanto esa textura era la del suelo. Ahora es
**Excluded Texture ID**, y con -1 el filtro queda desactivado. Ponle el ID de un
camino o de roca si quieres que el pasto lo respete.

El material de la hoja tambien tenia el color escrito a mano. Ahora el degradado
entre Root Color y Tip Color, el aclarado de la punta y la variacion aleatoria
son propiedades.

## Limites conocidos

- **No se ha medido rendimiento** en el nivel. El valor inicial de densidad es
  conservador a proposito; subelo mirando los fotogramas.
- Las sombras de las hojas estan desactivadas: con mucha densidad son de lo mas
  caro que hay.
- El pasto no tiene colision ni afecta a los pasos ni a las huellas.
- El viento del pasto es independiente del viento del cielo: hoy no comparten
  direccion y hay que ajustarlos a mano.
- Se ha verificado por lectura del codigo y el shader, no por ejecucion.

Referencias: [Terrain3DData](https://terrain3d.readthedocs.io/en/stable/api/class_terrain3ddata.html),
[GPUParticles3D](https://docs.godotengine.org/en/4.6/classes/class_gpuparticles3d.html).
