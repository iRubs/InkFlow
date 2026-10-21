# InkFlow — Sincronización opcional

InkFlow funciona localmente y no necesita hosting. No se ha activado ni instalado ningún servidor de sincronización.

La transferencia soportada entre Windows y Android es exportar un respaldo `.inkflow`, copiarlo por USB, una carpeta personal o Syncthing y restaurarlo en el otro dispositivo. Guarda versiones y fechas de los respaldos y conserva siempre una copia anterior.

No sincronices SQLite abierto ni mezcles directamente las carpetas de dos dispositivos que estén editando simultáneamente. El formato actual no incorpora fusión automática de cambios. Si ambos dispositivos han cambiado, conserva ambos respaldos, exporta las notas necesarias a formatos abiertos y decide explícitamente qué respaldo restaurar. Restaurar reemplaza un espacio de trabajo, no combina dos bases.

Si se usa Syncthing, limita la carpeta compartida a archivos de respaldo cerrados. Activa versionado de archivos y prueba una restauración periódicamente. Un mini PC doméstico o NAS puede servir como copia adicional, pero no es una dependencia de la app. No se promete disponibilidad permanente de ningún equipo o servicio.

Un servidor con Docker, HTTPS, túneles, monitoreo y restauración probada solo tendría sentido en una futura implementación de sincronización. AppFlowy Cloud no es un backend intercambiable con esta base SQLite y no se presenta como una función ya implementada.
