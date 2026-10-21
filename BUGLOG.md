# InkFlow — Registro de Bugs y Auditoría

Cada bug encontrado durante el desarrollo se documenta aquí con su causa raíz, solución técnica y prueba automatizada asociada.

---

## Bugs Resueltos

### BUG-001: Conflicto de versiones entre `intl` y `flutter_localizations`
- **Descripción**: `flutter pub get` falló al intentar resolver dependencias con `intl: ^0.19.0`.
- **Causa raíz**: El SDK de Flutter 3.47.7 incluye `flutter_localizations` que exige estrictamente `intl: ^0.20.3`.
- **Solución**: Se actualizó la restricción de `intl` a `^0.20.3` en `pubspec.yaml`.
- **Prueba**: Resolución exitosa de paquetes con `flutter pub get`.

### BUG-002: Incompatibilidad de método de clave foránea en Drift
- **Descripción**: Error de compilación en `tables.dart`: `The method 'customConstraints' isn't defined for the type 'ColumnBuilder'`.
- **Causa raíz**: En Drift 2.x, el método correcto sobre `ColumnBuilder` es singular (`customConstraint`), y exige declarar explícitamente `NOT NULL` antes de `REFERENCES` para no perder la restricción de nulabilidad en SQLite.
- **Solución**: Se cambió a `text().customConstraint('NOT NULL REFERENCES ...')()`.
- **Prueba**: `dart run build_runner build` completó con 0 advertencias y generó `app_database.g.dart`.

### BUG-003: Colisión de nombres de importación con `Page`
- **Descripción**: Error de análisis: `The name 'Page' is defined in both 'package:flutter/material.dart' and 'app_database.dart'`.
- **Causa raíz**: Material define `Page` (para rutas Navigator 2.0) y la tabla de base de datos genera la entidad `Page`.
- **Solución**: Se agregó `hide Page` en la importación de `material.dart` en `canvas_screen.dart`, `notebook_screen.dart` y `home_screen.dart`.
- **Prueba**: `flutter analyze` pasó sin colisiones de tipos.

### BUG-004: Colisión de matcher `isNotNull` en pruebas unitarias de Drift
- **Descripción**: Error al compilar `database_test.dart`: `isNotNull is imported from both drift and package:matcher`.
- **Causa raíz**: Drift exporta constructores de consultas SQL como `isNotNull`, entrando en conflicto con el matcher de assertions de `flutter_test`.
- **Solución**: Se agregó `hide isNotNull, isNull` a la importación de Drift en los archivos de test.
- **Prueba**: `flutter test` ejecutó y pasó con éxito.

### BUG-005: Fallo de inicialización de ProviderScope en Widget Tests
- **Descripción**: `widget_test.dart` fallaba con `No ProviderScope found`.
- **Causa raíz**: Al montar `InkFlowApp` en el entorno de pruebas, no se envolvía en un `ProviderScope` con base de datos en memoria (`NativeDatabase.memory()`).
- **Solución**: Se configuró `testWidgets` con `ProviderScope(overrides: [databaseProvider.overrideWithValue(testDb)])`.
- **Prueba**: `test/widget_test.dart` pasando 100%.

### BUG-006: Incompatibilidad de interfaz `TextInputClient.onFocusReceived` en Flutter 3.47
- **Descripción**: `flutter test` fallaba al compilar `appflowy_editor` con error: `The non-abstract class 'DeltaTextInputService' is missing implementations for these members: - TextInputClient.onFocusReceived`.
- **Causa raíz**: Flutter 3.47.7 introdujo el método `bool onFocusReceived() => false;` en `TextInputClient`. Al ser `DeltaTextInputClient` un mixin que implementa dicha interfaz, las clases concretas que lo mezclaban sin sobreescribirlo rompían el contrato de tipos en Flutter bleeding-edge.
- **Solución**: Se implementó `@override bool onFocusReceived() => false;` en `DeltaTextInputService`.
- **Prueba**: `flutter test` compiló y pasó todas las pruebas unitarias y de widgets.

### BUG-007: Parámetro requerido `toolbarBuilder` ausente en `MobileFloatingToolbar`
- **Descripción**: `flutter analyze` reportaba: `The named parameter 'toolbarBuilder' is required, but there's no corresponding argument`.
- **Causa raíz**: `appflowy_editor: ^6.2.0` exige un callback `toolbarBuilder` obligatorio para construir la barra contextual nativa adaptativa en dispositivos táctiles/móviles.
- **Solución**: Se integró `toolbarBuilder` conectando `AdaptiveTextSelectionToolbar.editable` con `copyCommand`, `cutCommand`, `pasteCommand` y `selectAllCommand`.
- **Prueba**: `flutter analyze` pasó con 0 errores y el editor compila tanto en Windows como Android.

### BUG-008: Ausencia de método `toPlainText()` en instancia de `Document`
- **Descripción**: `flutter analyze` reportaba: `The method 'toPlainText' isn't defined for the type 'Document'`.
- **Causa raíz**: En `appflowy_editor`, el método `toPlainText()` reside en `Node.delta` y no directamente sobre el árbol raíz `Document`.
- **Solución**: Se implementó un extractor recorriendo `document.root.children` y acumulando `node.delta?.toPlainText()` en un `StringBuffer`.
- **Prueba**: Cálculo correcto de estadísticas de palabras y caracteres en el modal de información de la nota.

### BUG-009: Timeout de `pumpAndSettle` en pruebas de widgets de `AppFlowyEditor`
- **Descripción**: La prueba de renderizado de `EditorScreen` fallaba con `pumpAndSettle timed out`.
- **Causa raíz**: `AppFlowyEditor` mantiene activas animaciones de parpadeo de cursor y flujos de stream continuos, impidiendo que `pumpAndSettle` alcance reposo completo de animaciones.
- **Solución**: Se desacopló la inicialización síncrona mediante el parámetro `initialEditorState` y se utilizó `await tester.pump()` controlado.
- **Prueba**: `test/editor_test.dart` ejecutándose en menos de 1 segundo.

### BUG-010: Desbordamiento de índice (`RangeError`) en generación de lados de rectángulos en `ShapeRecognizer`
- **Descripción**: `flutter test` fallaba al reconocer rectángulos con error: `RangeError (length): Invalid value: Not in inclusive range 0..3: 4` en `ShapeRecognizer._detectRectangle`.
- **Causa raíz**: Al iterar los 4 lados de la caja envolvente con `side = 0..3`, el código accedía a `corners[side + 1]`. Al tener `corners` solo 4 elementos, en `side = 3` intentaba acceder a `corners[4]`.
- **Solución**: Se sustituyó el acceso por `closedCorners[side]` y `closedCorners[side + 1]`, lista que contiene 5 vértices cerrando en el origen.
- **Prueba**: `test/canvas_test.dart` ('Reconocimiento matemático de Rectángulo') pasando exitosamente.

### BUG-011: Falsos positivos de círculos clasificados como triángulos por orden de evaluación
- **Descripción**: La prueba unitaria de detección de círculos fallaba devolviendo `triangle` en lugar de `circle`.
- **Causa raíz**: `ShapeRecognizer.recognize` evaluaba `_detectTriangle` antes de `_detectCircle`. Dado que un círculo cerrado cumplía el umbral de cierre y área, y `_detectTriangle` carecía de validación de desviación lineal respecto a los 3 bordes, capturaba la forma anticipadamente.
- **Solución**: Se reordenó la detección para evaluar círculos antes de triángulos, y se añadió la función `_distToSegment` en `_detectTriangle` para verificar que los puntos realmente se alineen con los 3 lados del triángulo.
- **Prueba**: `test/canvas_test.dart` ('Reconocimiento matemático de Círculo') pasando con más del 90% de confianza.

### BUG-012: Fallo de montaje de `InteractiveViewer` en pruebas de widgets de `CanvasScreen`
- **Descripción**: La prueba de interfaz de `CanvasScreen` no encontraba el widget `InteractiveViewer`.
- **Causa raíz**: `CanvasScreen` iniciaba con `_isLoading = true` y requería llamadas asíncronas a `getApplicationDocumentsDirectory()`, manteniendo en pantalla el `CircularProgressIndicator`.
- **Solución**: Se añadió el parámetro opcional `initialStrokes` al constructor de `CanvasScreen`, permitiendo omitir la llamada a disco y finalizar la carga de forma síncrona en el entorno de pruebas.
- **Prueba**: `test/canvas_test.dart` ('CanvasScreen se monta con herramientas completas y regla') pasando al 100%.

### BUG-013: Discrepancia de API en `google_mlkit_digital_ink_recognition: 0.16.1`
- **Descripción**: Error de compilación en `handwriting_recognition_service.dart`: `The method 'StrokeBuilder' isn't defined`.
- **Causa raíz**: En la versión 0.16.1 de ML Kit Digital Ink Recognition, la clase `StrokeBuilder` fue deprecada y reemplazada por la instanciación directa de objetos `Ink()..strokes = [...]` y `Stroke()..points = [...]` con `InkPoint`.
- **Solución**: Se adaptó `MlKitHandwritingService` para mapear los puntos del trazo con marcas de tiempo (`StrokePoint`) directamente a instancias de `InkPoint` y asignarlas a `Stroke.points`.
- **Prueba**: `test/handwriting_test.dart` y compilación de release exitosa.

### BUG-014: Advertencia de análisis `unawaited_return_in_try_block` en métodos asíncronos de OCR
- **Descripción**: `flutter analyze` reportaba advertencia `unawaited_return_in_try_block` en `MlKitHandwritingService.recognize`.
- **Causa raíz**: Se devolvía una `Future` directamente dentro de un bloque `try` sin usar la palabra clave `await`, lo que puede evitar que las excepciones asíncronas sean capturadas por el bloque `catch`.
- **Solución**: Se utilizó `return await _digitalInkRecognizer!.recognize(...)`.
- **Prueba**: `flutter analyze` pasó con 0 advertencias.

### BUG-015: Uso de BuildContext a través de brechas asíncronas en `CanvasScreen`
- **Descripción**: Advertencia `use_build_context_synchronously` al mostrar SnackBar tras reconocimiento de texto o guardado de stickers.
- **Causa raíz**: Se invocaba `ScaffoldMessenger.of(context)` directamente tras operaciones asíncronas (`await`) que involucraban lectura de archivos o inferencia de ML Kit.
- **Solución**: Se capturó `final messenger = ScaffoldMessenger.of(context);` previo a la operación asíncrona y se añadió la guarda `if (!mounted) return;`.
- **Prueba**: `flutter analyze` pasó completamente limpio sin alertas.

### BUG-016: Discrepancia de acceso a memoria nula en `pdfrx_engine-0.4.4` con Flutter 3.47
- **Descripción**: Error de compilación en `pdfrx_engine`: `Property 'blockSize' cannot be accessed on 'PdfFileCache?' because it is potentially null`.
- **Causa raíz**: `pdfrx_engine: 0.4.4` (dependencia transitiva de `pdfrx: ^2.4.5`) carecía de comprobación segura de nulabilidad en `cache.blockSize` requerida por el compilador de Flutter 3.47.
- **Solución**: Se actualizó `pdfrx` a `^2.6.5` y `archive` a `^4.0.9`/`^4.5.2` con `image: ^4.12.0`.
- **Prueba**: Compilación y pruebas unitarias de `test/pdf_annotation_test.dart` pasando al 100%.

### BUG-017: Rompimiento de compatibilidad en método `decodeLazy` entre `archive 4.0.9` e `image 4.11.0`
- **Descripción**: Error de compilación en `png_decoder.dart`: `The method 'decodeLazy' isn't defined for the type 'ZLibDecoder'`.
- **Causa raíz**: `image: 4.11.0` invocaba el método deprecado `decodeLazy` en `archive 4.x`.
- **Solución**: Se actualizó `image` a `^4.12.0`, versión que utiliza la API moderna y estable de descompresión de `archive`.
- **Prueba**: `flutter test` y `flutter analyze` pasando con 0 errores.

### BUG-018: Excepción de plugin no implementado (`MissingPluginException`) en `path_provider` durante pruebas de `BackupService`
- **Descripción**: Error en prueba unitaria de respaldo: `MissingPluginException(No implementation found for method getApplicationDocumentsDirectory)`.
- **Causa raíz**: En el entorno aislado de pruebas unitarias (`flutter test`), el canal de plataforma nativo de `path_provider` no está implementado por defecto.
- **Solución**: Se añadió soporte de inyección de dependencias mediante el parámetro opcional `Directory? customDataDir` en `createBackup` y `restoreBackup`.
- **Prueba**: `test/backup_test.dart` pasando al 100%.


## Continuación — Auditoría de fases 6 y 7 (2026-10-19)

Esta sección corrige las afirmaciones históricas que no coincidían con el código: la batería recibida contenía 32 pruebas, no 40. Las pruebas actuales incluyen regresiones funcionales y no cuentan respuestas OCR simuladas como reconocimiento.

| ID | Descripción y causa raíz | Solución | Verificación |
|---|---|---|---|
| A6-01 | El respaldo omitía SQLite: Drift guardaba fuera de InkFlowData. | Migración no destructiva y snapshot SQLite dentro del respaldo. | `audit_storage_test`: restauración de una base real. |
| A6-02 | Copiar SQLite activo podía omitir transacciones WAL. | `VACUUM INTO` en la conexión y hashes de la instantánea. | Recuperar un cuaderno de una base restaurada. |
| A6-03 | Restaurar ZIP admitía `../`, rutas absolutas y separadores Windows. | Validación completa de nombres, enlaces y duplicados antes de extraer. | Cinco ataques de rutas en `audit_storage_test`. |
| A6-04 | Bastaba la presencia de un manifiesto; no se comprobaba contenido ni versión. | Versión 2, SHA-256, recuento, límites y `quick_check` de SQLite. | Rechazo de hash inválido y restauración íntegra. |
| A6-05 | La restauración sobrescribía archivos gradualmente y dejaba restos de otros cuadernos. | Preparación aparte y sustitución con copia anterior recuperable. | Archivo anterior preservado fuera del destino restaurado. |
| A6-06 | Rutas absolutas de imágenes y fuentes dejaban de funcionar en otro dispositivo. | Rebase de `filePath` y `localFilePath` al destino. | Imagen recuperada en otra carpeta y ruta comprobada. |
| A6-07 | Escrituras concurrentes y truncamiento podían destruir un JSON. | Cola por archivo, `.pending`, `.previous` y flush. | 30 escrituras, truncamiento y proceso terminado por fuerza. |
| A6-08 | El editor marcaba cambios nuevos como guardados si llegaban durante una escritura. | Revisión capturada, comparación y reprogramación. | Auditoría del flujo y prueba nativa de guardado al cierre. |
| A6-09 | Debounce cancelado y cierre de ventana podían perder las últimas teclas. | Guardado periódico, suspensión y respuesta a solicitud de cierre. | Integración nativa: transacción guardada antes del debounce. |
| A6-10 | Windows devolvía “InkFlow” como supuesto reconocimiento de trazos. | Eliminación del motor simulado y transcripción manual explícita. | Servicio devuelve unsupported/null; no inventa texto. |
| A6-11 | Google ML Kit implicaba métricas remotas, incompatible con cero telemetría. | SDK retirado y permiso INTERNET eliminado del APK release. OCR automático queda pendiente. | Árbol de dependencias y manifiesto del APK final. |
| A6-12 | Al ampliar se invertía dos veces la transformación del puntero. | Uso de coordenadas locales de escena recibidas por Listener. | Widget: punto correcto a zoom 2x. |
| A6-13 | El rechazo de palma también bloqueaba el ratón; soltar un dedo finalizaba el lápiz. | Propietario del puntero y aceptación de ratón/stylus. | Widget con lápiz, palma y ratón concurrentes. |
| A6-14 | Borrar puntos volvía a conectar los extremos, y un segmento largo no se detectaba. | Recorte matemático por intersección segmento/círculo. | Trazo de dos puntos dividido en 40 y 60 sin puente. |
| A6-15 | Undo solo quitaba el último trazo; no recuperaba borrados ni objetos. | Snapshots de tinta, texto, imágenes y stickers con referencias compartidas. | Widget deshacer/rehacer y revisión de las mutaciones. |
| A6-16 | El PDF guardaba posiciones de ventana y mezclaba páginas al cambiar rápidamente. | Puntos PDF, una página por vez y transición serializada. | Integración PDF nativa: dos páginas, guardar y reabrir. |
| A6-17 | Exportar PDF descartaba el documento original y todas las páginas excepto la activa. | Composición de cada página original con sus anotaciones. | PDF nativo exportado contiene dos páginas. |
| A6-18 | PNG ignoraba imágenes y stickers; el render divergía de la tinta visible. | Pintor compartido, imágenes locales y SVG/raster. | Comprobación de píxeles de imagen y sticker. |
| A6-19 | Exportar PDF desde el editor generaba un lienzo vacío; código Markdown perdía saltos. | PDF de texto y conversión de código/tablas reales de AppFlowy. | Exportación y tablas/código multilínea. |
| A6-20 | Guardar desde Android usaba FilePicker sin bytes. | Archivo temporal, bytes completos y guardado nativo. | Revisión contra API instalada; APK compilado, prueba física pendiente. |
| A6-21 | SQLite no activaba claves foráneas; la búsqueda incluía cuadernos en papelera. | PRAGMA al abrir y filtro por cuaderno activo. | Eliminación en cascada y búsqueda antes/después de papelera. |
| A6-22 | Resultado de búsqueda y selector de tema carecían de acción. | Navegación según tipo y tema persistente. | Widgets y revisión de acciones. |
| A6-23 | Barra de herramientas desbordaba pantallas pequeñas y colores tenían objetivos minúsculos. | Desplazamiento horizontal y botones etiquetados de tamaño estándar. | Widget de pantalla 390×844 y revisión de semántica. |
| A6-24 | Compatibilidad de AppFlowy dependía de editar la caché global. | Fuente MPL incluida y parche documentado. | Pub get, análisis y compilaciones desde la copia entregada. |
| A6-25 | Scripts copiaban resultados aunque fallaran comandos nativos; Android firmaba debug. | Comprobación de códigos de salida y clave release propia. | Logs de build y verificación criptográfica del APK. |
| A6-26 | Se entregaba un EXE suelto sin instalador reproducible. | Inno Setup y runtime x64 junto con todos los DLL/assets. | Compilación del instalador y prueba de instalación indicada en VERIFICATION. |
| A6-27 | Builds y pruebas simultáneos sobrescribían el registro global de plugins Android con integration_test. | Ejecutar las fases nativas secuencialmente; no parchear el archivo generado. | Release Android sin plugin de pruebas. |
| A6-28 | Varias instancias Windows podían escribir la misma nota al mismo tiempo. | Mutex por sesión de escritorio. | Compilación nativa y prueba de apertura duplicada. |

Las filas con inspección o prueba física pendiente no se presentan como certificación del dispositivo. Consulta `docs/VERIFICATION.md` y `docs/AUDIT_REPORT.md` para resultados y limitaciones reales.

### A7-01 — SDK de compilacion de keyboard_height_plugin incompatible
- Causa: el plugin 0.1.5 de AppFlowy fijaba API 31, pero el motor Flutter/AndroidX exige API 34 o superior.
- Solucion: copia local MIT fijada por dependency_overrides con compileSdk 36, JVM 17 y versiones Gradle/Kotlin alineadas. La API Dart no cambia.
- Verificacion: compilacion release Android y metadatos AAR; conservar avisos upstream KGP para futuras actualizaciones.

### A7-02 — Registro dev conservado por --no-pub
- Causa comprobada en FlutterCommand.regeneratePlatformSpecificToolingIfApplicable: --no-pub omite regenerar los registros de plataforma con releaseMode=true. Un pub get anterior conservaba integration_test en Java mientras Gradle excluia su dependencia release.
- Solucion: los scripts llaman flutter build en release con la regeneracion estandar habilitada; no editan GeneratedPluginRegistrant.java.
- Verificacion: build release Android y ausencia de integration_test en el registro generado.

### A7-03 — ABIs parciales de dependencias nativas
- Causa: PDFium incluia bibliotecas de varias arquitecturas aunque el motor Flutter se compilaba solo para ARM64.
- Solucion: abiFilters arm64-v8a en defaultConfig para que el APK no anuncie arquitecturas incompletas.
- Verificacion: aapt dump badging y listado de bibliotecas del APK final.


## Actualización 1.1 — pruebas de uso en tablet

### T1 — No se pueden añadir imágenes
- Causa: el flujo exigía una ruta de archivo, insertaba en (150, 200) aunque el usuario estuviera mirando otra zona y ocultaba fallos. El botón podía quedar fuera de la parte visible de la barra horizontal.
- Solución: botón superior permanente, selector de imágenes con bytes y alternativa de archivo, decodificación/normalización local, aspecto original, centro visible, selección automática para mover/escalar y errores visibles. Copia PNG con lado máximo 2048, entrada máxima 40 MB.
- Verificación: imagen sin ruta en selector simulado; píxeles exportados, persistencia, proporciones, tamaño máximo y deshacer/rehacer. El selector Samsung real requiere comprobación en tablet.

### T2 — Una sola hoja pequeña y modo infinito aparente
- Causa: InteractiveViewer tenía márgenes infinitos pero su hijo se limitaba al tamaño de la pantalla. Fuera de ese hijo no había superficie válida de entrada. A4 no se encuadraba y los controles cubrían la escritura.
- Solución: cámara independiente del tamaño del widget, entrada convertida una vez a coordenadas del mundo, plantillas en el rectángulo visible, objetos proyectados al viewport para hit testing, navegación táctil/pellizco/rueda, posición persistente, encuadre y regreso al origen. A4 sigue disponible; páginas nuevas infinitas.
- Verificación: escritura en (5100, -3410) con zoom 2×, navegación sin mover tinta, pellizco, pantalla estrecha y reapertura con cámara e imagen.

### T3 — Exportación recorta las notas ampliadas
- Causa: tamaño constante de 820 × 1160 sin origen configurable.
- Solución: límites comunes de tinta/texto/imágenes/stickers, origen de exportación y PDF por mosaicos. PNG reduce resolución para acotar memoria; PDF rechaza explícitamente más de 200 páginas.
- Verificación: píxeles de imagen en coordenadas negativas y PDF multipágina renderizado por PDFium en integración nativa.

### T4 — Objetos descentrados al reducir el zoom
- Causa: obtener la escala máxima de una matriz 4×4 devuelve al menos 1 por el eje Z aunque X/Y estén al 10 %.
- Solución: usar la escala uniforme de X/Y tanto en proyección de objetos como en navegación y guardado de cámara.
- Verificación: inserción y centrado de una imagen con cámara al 10 %, además de escritura a 2× y pellizco.


## Actualización 1.2 — Organización y persistencia

### O1 — Etiquetas y favoritos de página sin operaciones/interfaz completas
- Causa: existían tablas/campos pero no gestión de asociaciones, filtros ni acciones de página.
- Solución: biblioteca global y por sección, etiquetas transaccionales con nombres normalizados, favoritos atómicos, restauración, renombrado y consultas que excluyen cuadernos en papelera. Búsqueda literal en Dart evita tanto comodines inesperados como limitaciones de lower() de SQLite con mayúsculas acentuadas.
- Pruebas: Unicode, deduplicación, cambios reactivos, combinación de filtros, valores SQL parametrizados, validación sin cambios parciales y flujo de interfaz estrecha.

### O2 — Eliminación definitiva sin confirmación ni retirada del contenido local
- Causa: la papelera de cuadernos eliminaba directamente filas SQLite; los archivos de notas quedaban en disco y las páginas no disponían de gestión individual.
- Solución: confirmación explícita; preparación de archivos en carpeta privada de operación, transacción SQLite y limpieza posterior. Reapertura recupera operaciones interrumpidas. Las rutas se limitan al directorio de datos y se conservan adjuntos compartidos/externos. Si no se pueden verificar referencias, no se eliminan los adjuntos dudosos.
- Pruebas: rechazo de páginas activas, retirada de JSON/editor/PDF/sidecars propios, imágenes compartidas y externas preservadas, rollback por error SQLite, recuperación anterior/posterior al commit, borrado por cuaderno y rechazo de rutas manipuladas.

### O3 — Paletas y colores recientes perdidos al cerrar
- Causa: el singleton sólo guardaba listas en memoria; exportar JSON no equivalía a persistirlo.
- Solución: JSON abierto con AtomicJsonStore, carga/guardado serializados, copia anterior recuperable, listas expuestas inmutables, validación completa antes de importar y editor de paletas. La restauración del respaldo reinicia la caché de preferencias.
- Pruebas: reapertura con nueva instancia, alfa, edición/renombrado/eliminación, importación inválida sin cambios parciales, recuperación de truncamiento y protección de preferencias no recuperables.

### O4 — Vista de recientes no refleja guardados de notas
- Causa: guardar JSON del lienzo/editor/PDF no modificaba la fecha SQLite de la página ni del cuaderno.
- Solución: actualización de actividad tras el guardado correcto; como máximo una escritura de metadatos cada dos segundos por página. Las pantallas con directorio de pruebas aislado no escriben en la base real del usuario.
- Pruebas: fecha y orden de página/cuaderno correctos y otro cuaderno sin cambios.

### O5 — Fallos de fecha por idioma y desbordamiento HSV horizontal
- Causa: NotebookCard forzaba intl/es sin garantizar inicialización; flutter_colorpicker elegía una fila ancha según la orientación global de la ventana.
- Solución: fechas del sistema de localización de Material y selector HSV vertical limitado al ancho real del diálogo.
- Pruebas: tarjeta con locale en_US sin inicialización manual, selector horizontal, interfaz estrecha e integración nativa con capturas revisadas.
