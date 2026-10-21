# InkFlow — Arquitectura de la continuación

## Decisión heredada y mantenida

Se mantiene un proyecto Flutter propio con `appflowy_editor` 6.2.0, bajo su opción MPL-2.0. No se importa el core Rust ni AppFlowy Cloud. Esto limita la superficie de compilación a Flutter y plugins nativos de Android/Windows. La copia del editor está en `app/vendor` para que el parche de compatibilidad de Flutter 3.47 sea reproducible; no se modifica la caché global durante el build.

## Organización

`core` contiene diseño y almacenamiento recuperable; `data/database` contiene Drift/SQLite; `features` agrupa cuadernos, editor, lienzo, PDF, exportación y respaldo. Riverpod 2.6.1 proporciona la base de datos y los streams de navegación. La base está en esquema 1 y activa las claves foráneas al abrir cada conexión.

Los datos residen en Documentos/InkFlowData: `inkflow.sqlite`, `editor/*.json`, `strokes/*.json`, `attachments/`, `fonts/`, `stickers/` y `settings.json`. La antigua base `Documentos/inkflow.sqlite` se migra mediante `VACUUM INTO` y se conserva. No se requiere servidor, cuenta ni pago.

## Guardado y recuperación

`AtomicJsonStore` captura el JSON antes de cualquier espera y serializa escrituras por ruta. Escribe y vacía `.pending`, conserva el archivo anterior como `.previous` y renombra la nueva revisión. Al leer busca una revisión válida en principal, pendiente y anterior. Un archivo sin ninguna revisión válida muestra un error sin convertirlo silenciosamente en una nota vacía.

El editor compara revisiones para no marcar como guardados cambios producidos durante una escritura. Guarda por inactividad, periódicamente si se sigue escribiendo y al suspender/solicitar cierre normal. Los widgets de editor, lienzo y PDF participan en la solicitud de salida. Una terminación forzada recupera la última revisión completa; no garantiza preservar eventos todavía en memoria. Windows añade una instancia por sesión para reducir escrituras concurrentes de dos procesos.

## Tinta y PDF

La captura identifica el puntero dueño del trazo. Los dedos no finalizan el lápiz y el ratón funciona en escritorio. El Listener recibe coordenadas ya transformadas por Flutter; no vuelve a invertir el zoom. Los contornos de trazos terminados se cachean con claves débiles. El historial comparte objetos y conserva snapshots de tinta, texto, imágenes y stickers durante la sesión. El borrador de precisión recorta segmentos geométricamente, sin puentear los huecos.

PDF presenta una página cada vez usando PDFium/pdfrx. Las anotaciones se expresan en puntos del documento y se amplían junto a la página. Cambiar de página espera el guardado y bloquea cambios simultáneos. La exportación procesa todas las páginas, incluyendo su fondo original y sus anotaciones. El resultado se aplana a imágenes a 144 dpi; no mantiene texto seleccionable. Los originales y anotaciones editables se conservan.

PNG y PDF de lienzo utilizan el mismo pintor de tinta y cargan las imágenes y stickers locales. Las exportaciones se generan primero en un directorio temporal y después pasan sus bytes al selector nativo, incluyendo Android SAF. El editor exporta Markdown y una representación de texto en PDF.

## Respaldo

El formato `.inkflow` versión 2 es ZIP estándar. Contiene la instantánea SQLite, los archivos y un manifiesto con tamaños lógicos, esquema y hashes SHA-256. Se validan rutas, duplicados, enlaces, versión, hashes, integridad de SQLite y tablas antes de sustituir datos. La extracción se prepara en una carpeta hermana y la anterior se conserva para recuperación. La conexión SQLite se cierra antes de restaurar y los proveedores se reinician después.

Las referencias a archivos de notas y fuentes se ajustan al destino. Restaurar reemplaza el espacio de trabajo; no fusiona conflictos entre dispositivos. Se limita la restauración a 512 MiB comprimidos y 1 GiB declarados sin comprimir. El ZIP se procesa en memoria: archivos muy grandes requieren más trabajo de streaming y perfiles de memoria.

## Privacidad y reconocimiento

No se configura analytics, cuentas ni servicios remotos. Se retiró el SDK Google ML Kit porque [sus términos](https://developers.google.com/ml-kit/terms) indican que envía métricas; eso contradice el requisito de cero telemetría aunque la inferencia sea local. El manifiesto release de Android elimina INTERNET. La conversión automática a texto queda pendiente de un motor sin telemetría; actualmente se ofrece transcripción manual y selección de fuentes. No hay resultados simulados en producción.

## Calidad y límites

Pruebas unitarias y de widgets cubren recuperación, respaldos reales, archivos manipulados, cascadas, búsqueda, render de exportaciones, geometría, punteros y zoom. La integración nativa comprueba PDFium y cierre del editor. El cierre forzado se prueba sobre un proceso que usa el mismo almacenamiento. Los comandos y salidas están en `logs/` y el resumen está en `docs/VERIFICATION.md`.

La lista de funciones todavía incompletas se mantiene en `USER_GUIDE.md` y `AUDIT_REPORT.md`. La medición real de fps, presión, palma Samsung y rotación de la tablet requiere hardware; las pruebas sintéticas no certifican esas propiedades.


## Biblioteca y preferencias (1.2)

`AppDatabase.watchPageLibrary` observa páginas/secciones/cuadernos/etiquetas/asociaciones, aplica filtros parametrizados y deduplica páginas. La coincidencia de texto se hace en Dart para respetar minúsculas Unicode y búsquedas literales. Los cambios de etiquetas son transaccionales; las consultas activas excluyen cuadernos eliminados. El esquema no cambia.

`PageDeletionService` prepara payloads conocidos y adjuntos propios no compartidos dentro de `.purge-<uuid>` con un manifiesto previo. Si SQLite confirma la eliminación se purga esa carpeta; si no, se devuelven los archivos. Al iniciar Home se recuperan operaciones pendientes antes de habilitar la biblioteca. La recuperación rechaza rutas externas y no sobrescribe archivos existentes. El respaldo no copia esas carpetas temporales. Un JSON de referencias ilegible hace que se conserven los posibles adjuntos compartidos.

`PaletteManager` carga y persiste paletas y recientes mediante AtomicJsonStore en `preferences/palettes.json`, espera la inicialización antes de persistir mutaciones, valida la carga y expone copias inmutables. La restauración reinicia el singleton; el archivo se incluye en la copia de datos. Las pantallas actualizan actividad SQLite tras guardar sus archivos, con una frecuencia máxima de una actualización por dos segundos/página.
