# InkFlow — Verificación de la continuación

## Actualización 1.3 — 2026-10-24

- **79 pruebas automatizadas** aprobadas (`logs/tests-1.3.log`). Las cinco nuevas comprueban límites de papel, navegación vertical, duplicado junto al borde, selección efectiva de tipo/grosor/color, rotación, texto ampliado y renderizado de la barra en tablet.
- Analizador sin incidencias (`logs/analyze-1.3.log`) y formato: **445 archivos, cero cambios** (`logs/format-1.3.log`).
- Integración nativa del lienzo aprobada en Windows: importación y movimiento de imagen, selección de bolígrafo, tinta, persistencia del modo vertical y cámara, reapertura y exportación/renderizado real de tres páginas PDF (`logs/integration-canvas-1.3.log`).
- Se inspeccionaron las capturas `logs/canvas-1.3-vertical.png` (motor nativo) y `logs/vertical-canvas-1.3.png` (formato de tablet 800 × 1200). Son datos sintéticos de prueba.
- Las notas antiguas con coordenadas exteriores conservan su modo libre y cámara; las pruebas heredadas de exportación de coordenadas negativas siguen pasando. Las notas nuevas y las antiguas sin contenido exterior usan ancho 820 y continuidad vertical.
- El APK es ARM64, versión 1.3.0/código 4, y mantiene la clave de firma anterior. Los detalles de empaquetado y comprobación se conservan en los registros `build-android-1.3.log` y `apk-verification-1.3.log`.

El S Pen, el rechazo de palma específico de Samsung y la instalación física en la tablet siguen pendientes de comprobación en el dispositivo del usuario. Las cuatro integraciones nativas de 1.2 descritas más abajo corresponden a esa entrega; en 1.3 se repitió la del lienzo afectado por estos cambios.

Fecha de cierre: 2026-10-19. Entorno real: Flutter 3.47.7, Dart 3.13.5, Windows 11, Visual Studio Build Tools 2026, JDK 21 y Android SDK 36.

## Auditoría automatizada

```text
flutter analyze
No issues found!

dart format --set-exit-if-changed .
Formatted 433 files (0 changed).

flutter test
+50: All tests passed!

flutter test integration_test/offline_workflow_test.dart -d windows
+2: All tests passed!

dart run scripts/crash_recovery_test.dart
PASS: proceso terminado durante guardado continuo;
revision recuperada 0, 5000 trazos completos.
```

Los 433 archivos incluyen las copias locales de dependencias; el analizador del proyecto excluye el código upstream de vendor de sus lints. AppFlowy conserva su parche local documentado. El plugin de teclado mantiene su API y adapta la configuración de compilación Android.

Las 50 pruebas incluyen SQLite y restauración reales, integridad de archivos, ZIP malicioso, JSON truncado, escrituras concurrentes, 1.500 trazos serializados, borrador por segmentos, ratón/palma/lápiz, zoom, atajos y render de imágenes/stickers. La prueba de 1.500 trazos mide guardado/lectura (~0,1 s en este equipo), no latencia visual.

Las dos integraciones usan motor nativo Windows: anotación y exportación PDF de dos páginas con reapertura; y transacción del editor guardada al solicitar cierre antes del debounce. `logs/pdf-integration.png` se revisó visualmente y `logs/pdf-integration.pdf` contiene las dos páginas.

## Instalador Windows

La prueba de instalación aislada confirmó: archivos de Flutter/PDFium y runtime x64 presentes, arranque, prevención de segunda instancia, cierre normal y desinstalación sin borrar los datos de usuario. Registro: `logs/installer-smoke.txt`.

## Entorno y límites

`flutter doctor -v` reconoce Android SDK 36, licencias aceptadas, JDK 21 y Visual Studio. Chrome no está instalado; no es un destino del proyecto. En la ejecución documentada hubo avisos temporales de resolución DNS en recursos de red; se comprobó el repositorio oficial y se reintentaron las descargas sin cambiar la configuración de red.

Gradle emite un aviso de futura migración a Built-in Kotlin para plugins upstream. No se oculta. No equivale a un error del analizador Dart ni a una certificación de compatibilidad con futuras versiones de Flutter. Las versiones se fijan en el lockfile.

No se ha instalado el APK en hardware físico. Quedan pendientes pruebas en Galaxy Tab S10 Lite: S Pen real, latencia/fps, presión/inclinación, botón, rotación, memoria extrema y TalkBack. No se ha probado una máquina Windows 10 independiente. El reconocimiento automático está pendiente de un motor privado y los PDF exportados se aplanan, según `AUDIT_REPORT.md`.

## Archivos de evidencia

- `logs/doctor.log`, `analyze.log`, `format.log`, `tests.log`.
- `logs/integration-windows.log`, `pdf-integration.png`, `pdf-integration.pdf`.
- `logs/crash-recovery.log`.
- `logs/windows-package.log`, `installer-smoke.log`, `installer-smoke.txt`.
- Logs finales de build, firma y permisos indicados en la sección de empaquetado añadida al cerrar la entrega.

## Empaquetado final comprobado

```text
flutter build apk --release --target-platform android-arm64
Built build/app/outputs/flutter-apk/app-release.apk (32.1MB)

apksigner verify --verbose --print-certs builds/InkFlow.apk
Verifies
Verified using v2 scheme: true
Signer key: RSA, 4096 bits

aapt dump badging builds/InkFlow.apk
sdkVersion: 24
targetSdkVersion: 36
native-code: arm64-v8a

aapt dump permissions builds/InkFlow.apk
Sin android.permission.INTERNET

flutter build windows --release
Built build/windows/x64/runner/Release/inkflow.exe

ISCC scripts/inkflow.iss
Successful compile
```

La copia final de Windows volvió a pasar instalación en carpeta aislada, presencia de DLLs/avisos, arranque, prevención de segunda instancia, cierre normal y desinstalación. Evidencia: `logs/installer-smoke-final.txt` y `installer-smoke-final.log`.

El APK final contiene las fuentes modificadas de AppFlowy Editor y los 16 avisos de licencia de la distribución PDFium chromium/7811. Su firma, permisos y arquitectura se verificaron con las herramientas oficiales del SDK, y están en `apk-signature.log`, `apk-permissions.log`, `apk-metadata.log` y `apk-audit.txt`. Esto verifica el paquete; no sustituye instalarlo en la tablet.

También se repitieron las diez pruebas de lienzo tras el ajuste final de capas y modo A4 (`logs/canvas-regression.log`). El formato final comprende 433 archivos sin cambios. La evidencia de los builds definitivos está en `android-build-final.log`, `windows-build-final.log` e `installer-build-final.log`.

Los hashes de binarios y código fuente están en `builds/SHA256SUMS.txt`. Los archivos y carpetas creados/modificados se inventarían en `docs/CHANGED_FILES.txt`. La carpeta fuente conserva las claves de firma privadas excluidas de Git; el ZIP de código no incluye secretos ni apuntes.


## Actualización 1.1.0+2 — 2026-10-19

- `flutter analyze --no-pub`: sin incidencias; resultado inicial en `logs/analyze-1.1.log`, repetido por los scripts de build.
- `flutter test --no-pub`: 55 pruebas aprobadas. Las cinco nuevas prueban importación sin ruta y con cámara al 10 %, proporciones, centrado, deshacer/rehacer, escritura lejana a zoom 2×, navegación/pellizco, normalización a 2048 píxeles, formatos inválidos, píxeles exportados en coordenadas negativas y reapertura de imágenes/cámara.
- `dart format --set-exit-if-changed app`: 437 archivos, ninguno modificado (`logs/format-1.1.log`).
- `flutter test integration_test/canvas_workflow_test.dart -d windows`: una integración aprobada con motor nativo. Inserta imagen desde selector simulado sin ruta, la mueve con zoom 1.5×, escribe fuera del área inicial, verifica JSON guardado, reabre la nota con cámara e imagen y abre/renderiza las tres páginas de un PDF con PDFium. Evidencia en `logs/native-canvas-1.1.log` y `logs/canvas-1.1-infinite.png`, revisada visualmente.
- Las dos integraciones anteriores de PDF/editor se repitieron y aprobaron (`logs/native-regression-1.1.log`).
- APK release ARM64 construido, versión 1.1.0/código 2. `apksigner` verifica la firma y su certificado coincide con el APK anterior; `aapt` confirma la arquitectura y ausencia de INTERNET. Registros en `logs/build-android-1.1.log`, `apk-signature-1.1.log`, `apk-metadata-1.1.log` y `apk-permissions-1.1.log`.

La incidencia detectada durante la prueba al 10 % se corrigió antes de la compilación final: la escala Z=1 de una matriz no debe usarse para calcular la escala 2D reducida. No se oculta la diferencia entre el selector simulado usado en integración y el selector real de Android, que sigue requiriendo prueba del usuario en tablet.


El build release de Windows 1.1.0+2 y el instalador Inno Setup también finalizaron correctamente (`logs/build-windows-1.1.log`). El instalador final volvió a pasar instalación aislada, comprobación de versión/runtime/avisos, arranque, instancia única, cierre normal y desinstalación (`logs/installer-smoke-1.1.txt` y `.log`). `builds/archive/1.0.0/` conserva los paquetes anteriores; `builds/InkFlow-1.1.0.apk` es una copia del APK estable de esta actualización. Los hashes actualizados se entregan en `builds/SHA256SUMS.txt`.


## Actualización 1.2.0+3 — 2026-10-20

- Análisis sin incidencias, repetido por los scripts de build. El registro de revisión está en `logs/analyze-1.2.log`.
- **74 pruebas** aprobadas en la suite completa, incluyendo 19 regresiones nuevas de biblioteca/paletas/actividad/fechas y adaptación horizontal. El resultado definitivo de la suite se incluye en `logs/build-android-1.2.log` y en el build de Windows.
- Formato: **444 archivos, cero cambios** (`logs/format-1.2.log`).
- **Cuatro integraciones nativas aprobadas**: una nueva de organización, eliminación confirmada y respaldo/restauración real de etiquetas/favoritos/paletas (`logs/native-library-1.2.log`); la de imágenes/lienzo/PDF multipágina (`native-canvas-1.2.log`); y las dos de PDF/editor repetidas (`native-regression-1.2.log`).
- Las capturas `logs/library-1.2.png` y `logs/palettes-1.2.png` se inspeccionaron visualmente. La primera ejecución detectó dos fallos corregidos antes de la entrega: datos intl/es no inicializados en la tarjeta de cuaderno y selector HSV que elegía un diseño horizontal más ancho que el diálogo.
- Las pruebas de archivos usan directorios temporales propios y bases SQLite aisladas. Cubren fallo forzado de la transacción de borrado, recuperación antes/después del commit, rutas manipuladas, conservación de referencias compartidas y externas, exclusión de carpetas de purga de los respaldos y protección de preferencias no recuperables.
- La actividad de páginas/cuadernos se actualiza después de guardar; la prueba compara instantes UTC/epoch para no depender de la zona horaria del equipo. El esquema SQLite sigue siendo 1.

Las pruebas de hardware Samsung, OCR y otras funciones de producto pendientes siguen limitadas según `AUDIT_REPORT.md`. La integración nativa y la prueba de respaldo son locales en Windows; no se ha utilizado un servicio remoto ni modificado apuntes reales para probar eliminaciones.


Empaquetado final 1.2 comprobado: APK ARM64 release, paquete `com.inkflow.inkflow`, versión 1.2.0/código 3, certificado igual al APK 1.1 y ausencia de INTERNET (`apk-signature-1.2.log`, `apk-metadata-1.2.log`, `apk-permissions-1.2.log`). `build-windows-1.2.log` confirma build release e instalador Inno Setup; ambos scripts repiten análisis y las 74 pruebas. El instalador final pasó instalación aislada, versión 1.2.0+3, archivos/runtime/avisos, arranque, instancia única, cierre normal y desinstalación (`installer-smoke-1.2.txt` y `.log`). Los hashes de entrega están en `builds/SHA256SUMS.txt`.
