# Volumen de pasos

Selecciona **SquirrelExplorer** en el árbol **Local** y abre **Audio de pasos**
en el Inspector. Los controles pertenecen al personaje, no al nodo de audio
creado durante el juego. Guarda la escena con Ctrl+S para conservar los ajustes.

- **Step Volume Db = -14 dB** conserva el nivel anterior. Probar **-10 dB**
  para subir todos los pasos 4 dB: caminar, correr y Mantle Surface Assist.
- **Running Step Gain Db = 3 dB** añade ganancia sólo al correr con pasos
  genéricos. La nieve mantiene su propio **Run Gain Db** y **Volume Db**.

La nieve también recibe la diferencia del volumen general respecto a -14 dB,
sin reemplazar su mezcla local. SFX y Master siguen aplicándose. No cambia
el volumen de trepa normal, saltos ni aterrizajes. Valores mayores suenan más;
subir demasiado puede activar el limitador y perder dinámica.

Se actualiza en vivo para nuevos pasos. Los cambios de Local se guardan con la
escena; los de Remote siguen siendo temporales. TrailAudio consulta los valores
del personaje enlazado y sólo usa sus propios valores como fallback sin jugador.
No se alteraron los niveles personalizados ni los defaults anteriores.
