# Volumen de pasos

Selecciona **SquirrelExplorer** en el árbol **Local** y abre **Audio de pasos**
en el Inspector. Los controles pertenecen al personaje, no al nodo de audio
creado durante el juego. Guarda la escena con Ctrl+S para conservar los ajustes.

- **Step Volume Db = -14 dB** conserva el nivel anterior. Probar **-10 dB**
  para subir todos los pasos 4 dB: caminar, correr y Mantle Surface Assist.
- **Running Step Gain Db = 3 dB** añade ganancia sólo al correr fuera de las
  zonas de nieve. En nieve se usan **Run Gain Db** y **Volume Db** de SnowStepAudio.

TrailAudio usa `snow_step_06_mid.wav` como única muestra predeterminada para
pasos y aterrizajes en todas las escenas; ya no genera un tono para esos
contactos. SnowStepAudio usa el mismo archivo en la nieve y puede cambiar su
cadencia sin cambiar el timbre. Step Volume Db modifica también los aterrizajes
fuera de nieve; los de nieve mantienen la mezcla local. SFX y Master siguen
aplicándose. Trepa y saltos conservan sus efectos propios.

Si ajustas el audio desde el Inspector remoto de TrailAudio, **Step Sample**
selecciona el archivo para la próxima ejecución y **Step Sample Gain Db** suma
volumen al siguiente paso o aterrizaje. El valor inicial de −6,5 dB iguala la
mezcla base de SnowStepAudio. Para un cambio persistente de volumen general,
ajusta **Step Volume Db** en SquirrelExplorer y guarda la escena.

Se actualiza en vivo para nuevos pasos. Los cambios de Local se guardan con la
escena; los de Remote siguen siendo temporales. TrailAudio consulta los valores
del personaje enlazado y sólo usa sus propios valores como fallback sin jugador.
No se alteraron los niveles personalizados ni los defaults anteriores.
