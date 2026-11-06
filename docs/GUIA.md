# OBS Clip Auto-Router 2.0

Organizador Lua para el Replay Buffer de OBS. No requiere instalar paquetes ni lanzar PowerShell para organizar clips.

## Activar

Una vez sustituido el archivo original, abre OBS. Si ya estaba abierto, ve a Herramientas → Scripts, selecciona `obs_replay_organizer.lua` y pulsa Recargar (flecha circular). Debe aparecer **OBS Clip Auto-Router 2.0**. No agregues una segunda copia del script.

Los ajustes existentes mantienen sus nombres: carpeta base, carpeta sin juego, subcarpetas por fecha y autoarranque del Replay Buffer. Si antes usabas **Otros**, se conserva; puedes cambiarlo a **Por clasificar**. El script incluye todas las asociaciones de ejecutables del original.

## Agregar un juego

En las propiedades del script escribe su ejecutable, por ejemplo `nuevo.exe`, y el nombre deseado de carpeta. Pulsa **Guardar regla y reclasificar**. También puedes editar la lista **Juegos**, una asociación `ejecutable.exe = Carpeta` por línea. Borrar una línea elimina la asociación. Reglas inválidas detienen nuevos movimientos hasta corregirlas.

El estado muestra el ejecutable detectado de los clips pendientes. Para un clip ambiguo, pulsa Actualizar estado, selecciónalo en **Clip a corregir**, escribe la carpeta y pulsa **Asignar carpeta al clip seleccionado**. Esto corrige ese clip, sin inventar una regla de detección. Para guardar una regla reutilizable necesitas conocer el ejecutable.

## Detección

Se consultan fuentes Game Capture visibles de la escena de programa, incluyendo escenas anidadas y grupos. Una fuente configurada para ventana específica aporta el ejecutable objetivo. Esto indica su configuración, no garantiza que OBS haya enganchado efectivamente el juego. Si hay varias capturas o conflicto con otro juego reconocido en primer plano, no se adivina.

Sin objetivo específico se usa el ejecutable de la ventana activa si está en las reglas. No se escanean todos los procesos ni se mantiene un sondeo continuo. Cambiar a otra ventana al guardar puede dejar el clip sin clasificar. La regla heredada `javaw.exe = Minecraft` identifica ese ejecutable genérico: elimínala si usas otras aplicaciones Java.

## Protección y recuperación

- El movimiento nativo nunca permite reemplazar un archivo existente; las colisiones reciben sufijos.
- Se registra la intención antes de mover; una interrupción después del movimiento se reconcilia al recargar.
- La cola se guarda junto al script en `obs_organizer_state.json`, con respaldo `.bak`. No borres estos archivos si hay pendientes.
- Archivos ocupados se reintentan hasta seis veces, con pausas crecientes. Errores permanentes quedan bloqueados y conservan el archivo original.
- Tras corregir una carpeta, permisos o regla, pulsa **Reintentar pendientes y aplicar reglas**.
- Si no se puede guardar la cola, se suspenden los movimientos. Si ambos JSON son ilegibles, se conservan sin sobrescribir; hay que revisar el archivo y recargar.
- Solo mueve dentro de la misma unidad local. Otra unidad, una unidad de red o un punto de montaje a otro volumen pueden producir un bloqueo deliberado: el original permanece en origen. No se copian videos grandes desde un temporizador de OBS.
- No realiza un escaneo retroactivo de clips anteriores. Solo procesa eventos nuevos y pendientes guardados por esta versión.
- Conserva hasta 80 mensajes de historial y 100 comprobantes completados. No descarta pendientes sin resolver.

## Estado

Pulsa **Actualizar estado** para ver el resumen, los errores y los últimos eventos. El registro completo de esta sesión también aparece en **Script Log** de OBS. No hay un temporizador dedicado a refrescar constantemente la interfaz.

El autoarranque comprueba si el Replay Buffer está activo; si no lo está, informa del fallo. Debe estar habilitado y configurado en los ajustes de salida de OBS.

## Comprobación real pendiente

1. Abre un juego y selecciona su ventana en Game Capture.
2. Guarda un replay y comprueba su carpeta.
3. Pulsa Actualizar estado y revisa que no haya errores.
4. Comprueba que la grabación abre y se reproduce normalmente.

Se probó con LuaJIT y libobs instalados en esta PC: movimientos reales de archivos de prueba, colisiones, bloqueo exclusivo, límite de reintentos, persistencia JSON y recarga, reglas inválidas, detección ambigua simulada, reclasificación manual y rechazo entre unidades. La escena, eventos y controles de OBS se simularon; no se ha validado todavía un replay real ni medido FPS en juego.

## Restaurar

Cierra OBS, repón tu copia anterior con el nombre `obs_replay_organizer.lua` en la carpeta de instalación y vuelve a abrir OBS. Conserva el JSON de pendientes para no perder el registro. No ejecutes simultáneamente el organizador PowerShell antiguo sobre los mismos clips.

Referencias de implementación: [scripting de OBS](https://docs.obsproject.com/scripting), [persistencia JSON](https://docs.obsproject.com/reference-settings), [Game Capture](https://github.com/obsproject/obs-studio/blob/master/plugins/win-capture/game-capture.c).
