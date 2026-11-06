# OBS Clip Auto-Router

Organiza los clips del Replay Buffer de OBS Studio en carpetas por juego. Script Lua para **Windows de 64 bits**, integrado en OBS, sin procesos externos ni ventanas de consola.

**Versión 2.0.0.** No es un plugin oficial de OBS. La interfaz está en español.

## Funciones

- Movimiento sin sobrescrituras: añade ` (1)`, ` (2)`, etc. cuando un nombre existe.
- Detección mediante el ejecutable configurado en Game Capture y, como respaldo, la ventana activa reconocida.
- Casos ambiguos enviados a una carpeta configurable para clasificar después.
- Cola JSON persistente, recuperación al recargar y reintentos limitados.
- Reglas de juegos editables en las propiedades del script y reclasificación manual.
- Comprobación del Replay Buffer, resumen de pendientes e historial limitado.
- Inicio opcional del Replay Buffer al cargar el script.

## Instalación

1. Descarga este repositorio con **Code → Download ZIP** y extrae los archivos en una carpeta donde puedas escribir.
2. En OBS, abre **Herramientas → Scripts → +** y selecciona `obs_replay_organizer.lua`.
3. Configura la **carpeta base**. El valor inicial es `D:\Videos`; cámbialo si no corresponde a tu equipo. Debe estar en la misma unidad local que los clips originales.
4. Habilita y configura el Replay Buffer en **Ajustes → Salida** y asigna un atajo para guardar repeticiones.
5. Guarda un clip. Comprueba su carpeta y usa **Actualizar estado** para revisar el resultado.

Para actualizar una instalación existente, respalda el Lua y la cola JSON, reemplaza el Lua y pulsa **Recargar**. Conserva el nombre y la ubicación del script para mantener sus ajustes. No cargues dos copias ni ejecutes otro organizador sobre los mismos clips.

## Agregar un juego

En las propiedades del script, introduce el ejecutable y la carpeta y pulsa **Guardar regla y reclasificar**. También puedes editar directamente la lista de reglas:

```text
nuevo-juego.exe = Mi juego
otro-juego.exe = Otro juego
```

Para un clip ambiguo: selecciona **Clip a corregir**, escribe la carpeta y pulsa **Asignar carpeta al clip seleccionado**. Una asignación manual no crea una regla para un ejecutable desconocido.

## Alcance y límites

- Lee el objetivo **configurado** de Game Capture; no prueba que el juego esté enganchado. Conflictos entre capturas o con la ventana activa se dejan sin clasificar.
- Solo organiza nuevos eventos de replay y pendientes de esta versión. No escanea una biblioteca anterior.
- Solo permite movimientos en la misma unidad local. No copia videos entre unidades desde OBS.
- La cola registra movimientos; no es una copia de seguridad del video ni repara grabaciones incompletas.
- Si no puede guardar la cola, suspende los movimientos. Los errores conservan el archivo en origen cuando no se ha movido.
- Los eventos y temporizadores reducen trabajo innecesario, pero no significan consumo cero ni ejecución en otro hilo.
- El estado se actualiza al pulsar **Actualizar estado**, no continuamente.

No usa red, cuentas ni telemetría. Crea `obs_organizer_state.json` y su respaldo `.bak` junto al script. Esos archivos contienen rutas locales y quedan excluidos de Git.

## Pruebas

Requiere Windows x64, Python de 64 bits y OBS Studio instalado. Python solo es necesario para ejecutar las pruebas, no para usar el script.

```powershell
python tests/run_lua.py tests/test_organizer.lua
```

Si OBS está en otra ubicación:

```powershell
$env:OBS_BIN = 'E:\Apps\obs-studio\bin\64bit'
python tests/run_lua.py tests/test_organizer.lua
```

Las pruebas usan LuaJIT y libobs de la instalación local, movimientos reales de archivos temporales y JSON real. La interfaz, las escenas y los eventos de OBS se simulan. Cubren colisiones, archivos ocupados, límite de reintentos, recarga, fallo de persistencia, reclasificación, duplicados, interrupción después de mover y rechazo entre unidades.

**Pendiente de validación:** un replay real en OBS y mediciones de rendimiento durante una partida. El proyecto no afirma estar libre de fallos.

[Guía detallada](docs/GUIA.md) · [Cambios](CHANGELOG.md)

## Licencia

MIT. Copyright © 2026 Rena148. Las dependencias OBS y LuaJIT no se redistribuyen en este repositorio y conservan sus propias licencias.
