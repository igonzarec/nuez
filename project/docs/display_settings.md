# Ajustes de pantalla

Los controles están en **Ajustes** desde el título o el menú de pausa.

- **Pantalla completa** usa el modo de pantalla completa sin bordes del sistema y
  conserva la resolución nativa del monitor.
- **Resolución** está disponible en modo ventana y se aplica al instante. Las
  opciones son 1280×720, 1366×768, 1600×900, 1920×1080, 2560×1440 y
  3840×2160 (4K). La elección se guarda al salir de Ajustes.
  Si la ventana elegida no cabe en el área útil del monitor, se reduce
  proporcionalmente para mantener accesibles el menú y la barra de título.
  La preferencia original se conserva. El selector se desactiva mientras
  esté activa la pantalla completa.
  Cada opción incluye un nombre: HD (720p), HD portátil (768p), HD+ (900p),
  Full HD (1080p), QHD (1440p) o 4K UHD (2160p). El nombre es solo presentación:
  las preferencias existentes siguen usando los mismos identificadores.
  Debajo del selector se muestra el tamaño real aplicado a la ventana.

El lienzo lógico se define en Project Settings, por separado del tamaño de la
ventana. La referencia de diseño original es 1280×720; cambiarla afecta al tamaño
relativo de la interfaz, y no equivale a elegir una resolución de salida.
Godot conserva sus
proporciones al cambiar el tamaño de la ventana: una pantalla que no sea 16:9
puede mostrar bandas laterales o superiores antes que estirar menús, diálogos o
HUD. El mundo 3D se dibuja a la resolución seleccionada; aumentar la resolución
mejora la nitidez, pero también aumenta el coste de GPU.

Las preferencias de pantalla se aplican de forma diferida para evitar que la
configuración de arranque de Godot las sobrescriba después de `_ready`.
Una preferencia guardada tiene prioridad sobre Window Width/Height Override y
el modo inicial del proyecto. En pantalla completa el tamaño sigue siendo el
nativo del monitor. Si el juego está integrado en el editor, el panel de juego
controla su presentación: usa una ventana independiente para comprobar tamaños.

En el editor, el lienzo y las bandas se configuran en **Project Settings →
Display → Window → Size / Stretch**: Viewport Width/Height = 1280/720,
Mode = canvas_items y Aspect = keep. Las seis opciones del menú y su validación
comparten `TrailDisplay.RESOLUTIONS`, en `scripts/core/display_settings.gd`.
Por ejemplo, selecciona 1920×1080 en ventana o activa pantalla completa para
usar los 3840×2160 nativos de un monitor 4K. Los cambios de volumen o sensibilidad
no alteran la posición ni el tamaño de la ventana.
