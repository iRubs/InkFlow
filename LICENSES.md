# InkFlow — Licencias y avisos

Revisión de continuación: 2026-10-19. El código propio de InkFlow se publica bajo la licencia MIT de `LICENSE`, por autorización de su autor. Las dependencias, fuentes y componentes de terceros conservan sus licencias y avisos originales; en particular, los archivos de AppFlowy Editor se distribuyen bajo MPL-2.0. No se incorpora código de xnotes.

## AppFlowy Editor

Se mantiene la decisión de un proyecto Flutter propio en vez del fork completo de AppFlowy/Rust. `appflowy_editor` 6.2.0 permite elegir MPL-2.0; esa es la opción utilizada. Se conserva el archivo LICENSE original con ambas licencias y todos los avisos.

Existe una modificación local de compatibilidad con Flutter 3.47: implementación de `onFocusReceived` en `DeltaTextInputService`. Antes dependía de un cambio manual en la caché global; ahora el paquete está en `app/vendor/appflowy_editor`. Su fuente modificada se entrega bajo MPL-2.0. Véase `INKFLOW_PATCHES.md`. También se entrega un ZIP con ese código en la carpeta builds, el instalador de Windows y los assets del APK. Mantén disponible ese código y los avisos si redistribuyes binarios.

Fuentes primarias: [licencia del paquete](https://github.com/AppFlowy-IO/appflowy-editor/blob/main/LICENSE) y [documentación de licencias](https://github.com/AppFlowy-IO/AppFlowy-Docs/blob/main/documentation/appflowy-editor/licenses.md).

## Referencia xnotes

Se revisó la [licencia MIT de xnotes en su rama master](https://github.com/shardulvs/xnotes-android/blob/master/LICENSE). No se copia código ni recursos de ese proyecto; se consultó su UX y sus incidencias como referencia.

## Dependencias y recursos

Las versiones exactas están fijadas en `app/pubspec.lock`. Los textos completos obtenidos de las dependencias instaladas se incluyen en `docs/THIRD_PARTY_NOTICES.txt` y dentro de la aplicación. Corrige este documento cualquier afirmación distinta de la versión anterior: pdfrx 2.6.5 usa MIT; archive 4.5.2 usa MIT; el plugin Flutter de Digital Ink 0.16.1 usaba MIT, pero ya no forma parte de esta entrega. Se retiró el SDK Google ML Kit para cumplir cero telemetría: [sus condiciones oficiales](https://developers.google.com/ml-kit/terms) documentan envío de métricas incluso con inferencia local.

Caveat, Patrick Hand y Fira Code se acompañan de sus archivos OFL descargados del repositorio oficial [google/fonts](https://github.com/google/fonts). Los stickers heredados del proyecto se conservan como recursos propios según el historial previo; esta auditoría no acredita independientemente la autoría histórica de cada dibujo. El icono nuevo se genera con geometría original mediante `scripts/generate_icon.py`, sin copiar logos de otras apps.

El instalador añade el runtime redistribuible x64 de Visual C++ desde las herramientas de Visual Studio instaladas. Sus DLL siguen sujetas a los términos de redistribución de Microsoft; no son código de InkFlow. PDFium y sus componentes conservan sus licencias nativas, además de la licencia del wrapper pdfrx. Los avisos de Flutter también quedan incluidos en los assets generados.

Si añades dependencias o publicas la app, actualiza los avisos a partir de las versiones realmente resueltas y mantén el ZIP de AppFlowy Editor junto a los binarios.

La dependencia keyboard_height_plugin 0.1.5 se incluye tambien en app/vendor bajo MIT, con un parche de compilacion SDK 36/Java 17 y configuracion Gradle compatible. No se modifica su API Dart; los cambios estan descritos en INKFLOW_PATCHES.md.

Los 16 avisos de licencia de la distribucion binaria PDFium chromium/7811 (la misma version del hook de pdfium_dart 0.3.1) se incluyen en docs/PDFIUM_LICENSES.txt, THIRD_PARTY_NOTICES y los assets de terceros del APK.
