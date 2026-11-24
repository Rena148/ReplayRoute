# Guía de usuario de ReplayRoute

[English](GUIDE.md) · [Español](#carga-o-actualización)

## Carga o actualización

En **OBS → Herramientas → Scripts**, agrega `obs_replay_organizer.lua` o selecciona el script existente y pulsa **Recargar (`↻`)**. La descripción debe mostrar **ReplayRoute 2.3.1**.

Conserva el mismo nombre de archivo y ubicación al actualizar para mantener tus ajustes y la cola pendiente. Configura **Base folder** en una carpeta local con permisos de escritura dentro de la misma unidad y volumen que tus clips originales. Se admiten tanto raíces de unidad como `D:\` como carpetas ocultas como `D:\.clips`. Las instalaciones nuevas usan `Unclassified` para clips ambiguos.

## Reglas y reclasificación

### Carpetas automáticas para juegos nuevos

La opción **Auto-create game folders** viene activada por defecto. Abre un juego con una fuente **Game Capture** visible y guarda un replay. Si OBS identifica `newgame.exe`, ReplayRoute elimina sufijos técnicos comunes (`-win64-shipping`, `_dx12`, etc.), reutiliza una subcarpeta coincidente única si ya existe en **Base folder**, o crea una carpeta nueva con el nombre limpio y añade la regla a tu lista después de mover el clip. Si ya tienes una regla explícita para ese ejecutable, se usa tu carpeta configurada.

Una ventana desconocida en primer plano o una captura de **Window Capture** normal no registran juegos nuevos automáticamente. Capturas en conflicto o nombres de ejecutable inseguros van a tu carpeta `Unclassified`. Los nombres automáticos están limitados a 120 bytes.

Abre **Manage games and settings** para editar reglas o reclasificar clips. Los clips en seguimiento se conservan entre recargas. Para ver juegos aprendidos mientras la ventana de Scripts estaba abierta, pulsa **Refresh status**. Si estabas editando la lista, aplica primero tu borrador: ReplayRoute combina tus cambios con los juegos aprendidos mientras editabas.

Cada regla asocia un ejecutable a un único nombre de carpeta:

```text
newgame.exe = My Game
```

Usa **Executable** y **Folder** y pulsa **Save rule and reclassify**. Para modificar varias reglas a la vez, edita **Game list** y pulsa **Apply game list and retry**. Ambas acciones validan el borrador antes de guardarlo; hasta entonces los replays nuevos siguen usando las reglas guardadas. Si hay líneas inválidas o duplicadas, se conservan las reglas anteriores. Al recargar el script se descartan borradores no aplicados. Las subcarpetas vacías que queden dentro de **Base folder** tras reclasificar clips se eliminan automáticamente (tu carpeta original de clips y `Unclassified` nunca se borran).

Selecciona un clip en **Clip to reclassify** para autocompletar su ejecutable cuando esté disponible. Escribe una carpeta y pulsa **Assign to selected clip** para mover únicamente ese clip. El selector muestra 50 elementos por página, del más reciente al más antiguo; usa el botón de página para ver clips anteriores.

Si borraste manualmente de tu disco clips en estado `unclassified` o `auto_routed`, ReplayRoute los quita automáticamente de **Clip to reclassify** y del conteo al abrir **Scripts**, expandir **Manage games and settings**, pulsar **Refresh status** o pulsar **Apply game list and retry** (siempre que **Base folder** siga disponible).

Pulsa **Apply game list and retry** después de corregir una ruta, permisos o regla bloqueada.

## Detección del juego

ReplayRoute revisa las fuentes visibles de **Game Capture** y **Window Capture** en la escena de programa actual, incluidos grupos y escenas anidadas. Un hook activo de Game Capture identifica el ejecutable incluso en pantalla completa. Un Window Capture vivo puede identificar un juego que ya esté en tu lista. Si dos capturas visibles apuntan a juegos distintos, el clip va a `Unclassified`.

Si Game Capture pierde el hook al hacer Alt-Tab, ReplayRoute recuerda el último ejecutable confirmado en esa fuente durante 45 segundos. Solo consulta la lista de procesos de Windows cuando un replay guardado necesita usar ese respaldo. Cambiar la escena de programa u ocultar la fuente borra el juego recordado. Sin hook vivo, una captura configurada por ventana específica en Game Capture sigue aportando un candidato incluso en fuentes sin señal de hook. Cualquier desacuerdo entre candidatos o con un juego conocido en primer plano deja el clip sin clasificar. Un juego conocido en primer plano puede identificar el clip cuando no hay otro candidato de captura.

Deadlock (`project8.exe` y `deadlock.exe`) viene incluido por defecto para que el nombre interno de Valve apunte limpio a `Deadlock`. Todos los demás juegos se aprenden automáticamente desde **Game Capture** o se añaden en **Game list**.

## Protección de archivos

El movimiento nativo nunca permite sobrescribir un archivo ya existente en el destino. Los conflictos de nombre se resuelven añadiendo sufijos numéricos, y la llamada nativa rechaza el reemplazo si aparece otro archivo entre la comprobación y el movimiento.

La cola registra la intención antes de mover, por lo que una interrupción tras renombrar puede reconciliarse al recargar. Las entradas se guardan en `obs_organizer_state.json`, con respaldo `.bak`, junto al script. Conserva estos archivos si actualizas o cambias de carpeta el script.

Los archivos bloqueados reciben hasta seis reintentos con pausas crecientes. Los errores permanentes quedan en estado `blocked` para revisión manual. Antes de mover, ReplayRoute verifica que origen y destino estén en el mismo volumen local, incluidos puntos de montaje dentro de una misma letra de unidad.

Si falla el guardado de la cola JSON, los movimientos se pausan. Si tanto el archivo principal como el respaldo quedan ilegibles, se conservan intactos para que puedas inspeccionarlos sin sobrescribirlos. Repara el archivo y recarga el script.

La cola no es una copia de seguridad de video: no repara grabaciones inconclusas de OBS, no vigila cada cambio externo en disco ni protege ante fallos de hardware.

## Estado e historial

Pulsa **Refresh status** para ver el estado del Búfer de reproducción, los contadores (`Pending`, `Blocked`, `Unclassified`, `Auto-routed`) y los eventos recientes. **Script Log** también muestra los mensajes de la sesión. No hay temporizadores continuos refrescando la interfaz en segundo plano.

El inicio automático del Búfer de reproducción solo se solicita cuando está activado en opciones, comprobando después su estado real. Activa y configura primero el Búfer de reproducción en **OBS → Ajustes → Salida**.

El historial conserva hasta 80 mensajes y 100 registros completados recientes. Abre **Manage games and settings** para consultar el historial reciente. Si los clips auto-clasificados de meses anteriores ya están en su carpeta final, usa **Finish tracking** para marcarlos como completados sin mover archivos y evitar que futuros renombrados de reglas los muevan. Los clips del mes actual, los bloqueados y los no clasificados permanecen disponibles.

## Comprobación inicial

1. Abre un juego con **Game Capture → Capturar cualquier aplicación a pantalla completa** visible en tu escena activa.
2. Guarda un replay y comprueba la carpeta, reproducción y ejecutable mostrados con **Refresh status**.
3. Con el juego aún abierto, haz Alt-Tab a otra ventana y guarda un segundo replay dentro de los primeros 45 segundos; confirma que ambos clips terminan en la carpeta del mismo juego.

## Cómo revertir una actualización

Cierra OBS, restaura tu copia de respaldo de `obs_replay_organizer.lua` con su nombre original y vuelve a abrir OBS. Conserva `obs_organizer_state.json` si aún tiene clips pendientes o sin resolver. No uses el script antiguo de PowerShell al mismo tiempo sobre los mismos clips.

## Referencias de implementación

- [OBS scripting](https://docs.obsproject.com/scripting)
- [OBS JSON settings API](https://docs.obsproject.com/reference-settings)
- [OBS Game Capture implementation](https://github.com/obsproject/obs-studio/blob/master/plugins/win-capture/game-capture.c)
