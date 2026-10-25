# InkFlow — Instalación y compilación

## Actualización vigente: 1.3.0

La entrega actual de Android es `builds/InkFlow-1.3.0.apk`, también disponible como `builds/InkFlow.apk`. Tiene código de versión 4 y la misma firma que las entregas anteriores. Elige **Actualizar** al abrirlo en Android; no desinstales para conservar los apuntes. La guía de hoja continua y herramientas está en [UPDATE_1.3.md](UPDATE_1.3.md). El instalador de Windows de esta entrega se identifica como versión 1.3.0.

Las secciones históricas de 1.1/1.2 de este documento describen esos paquetes; los APK anteriores y sus hashes se conservan en `builds/archive/`.

## Windows 10/11 x64

Ejecuta `builds/InkFlow-Setup.exe`. La instalación es por usuario en `%LOCALAPPDATA%/Programs/InkFlow` y crea un acceso en Inicio. La opción de acceso en Escritorio es voluntaria. Se incluyen Flutter, PDFium, complementos y el runtime redistribuible de Visual C++ junto al ejecutable. Desinstalar no borra los apuntes de Documentos/InkFlowData.

El instalador no tiene firma Authenticode comercial. La firma del APK y un certificado comercial de Windows son mecanismos diferentes. Revisa `builds/SHA256SUMS.txt` para comprobar la integridad de los archivos entregados. La carpeta `builds/Windows` puede usarse como versión portable conservando TODO su contenido.

## Android ARM64

Copia `builds/InkFlow.apk` a la tablet y abre el archivo con su instalador de paquetes. Android puede pedir habilitar instalación desde la aplicación que lo abre. El APK usa una clave propia y está destinado a dispositivos ARM64 con Android 7/API 24 o superior; el dispositivo solicitado es ARM64. Guarda una copia antes de reemplazar una instalación anterior firmada con otra clave: Android no permite actualizar directamente entre firmas diferentes.

Las funciones de cuadernos, tinta, archivos y exportación no necesitan una cuenta ni servidor. El reconocimiento automático está pendiente: se retiró el SDK ML Kit para cumplir el requisito de cero telemetría. Esta entrega no se ha instalado en una tablet física porque no hay una conectada.

## Entorno reproducible

- Flutter 3.47.7 estable / Dart 3.13.5.
- JDK 21. Se descargó una distribución portable de Microsoft en `.tools/jdk21` para evitar depender del JDK 26 del sistema.
- Android SDK Platform 36, Build Tools 36 y NDK 28.2.13676358. Las herramientas pueden añadir otros Build Tools requeridos por Gradle.
- Visual Studio Build Tools 2026 con C++ y Windows SDK.
- Inno Setup 6.
- Dependencias fijadas en `app/pubspec.lock`. AppFlowy Editor 6.2.0 se entrega en `app/vendor/appflowy_editor`, con el parche local de compatibilidad documentado.

Desde la carpeta del proyecto:

```powershell
.\scripts\verify.ps1
.\scripts\build_windows.ps1
.\scripts\build_android.ps1
```

Para repetir la prueba nativa: `scripts/verify.ps1 -NativeIntegration`.

## Clave Android

La clave de esta entrega está en `.signing/inkflow-release.jks`; su configuración local está en `app/android/key.properties`. Ambos están excluidos de Git. Haz un respaldo privado de estos DOS archivos. Perder la clave impide publicar actualizaciones con la misma identidad de firma. No publiques las contraseñas ni el keystore junto con el código.

En otro equipo copia la clave por un medio privado y actualiza `storeFile` de `key.properties` con su ruta real. Contiene las propiedades `storeFile`, `storePassword`, `keyAlias` y `keyPassword`. Si creas tu propia clave con `keytool -genkeypair`, usa una identidad distinta y asume que la app anterior no se podrá actualizar directamente.

El script de Android falla si falta la configuración; no vuelve silenciosamente a la firma de depuración. Los scripts comprueban códigos de salida de las herramientas nativas antes de copiar los artefactos.

## Licencias

Los avisos se incluyen en `docs/THIRD_PARTY_NOTICES.txt`, en la app y en el instalador. La copia modificada de AppFlowy Editor está disponible en el código entregado y en `appflowy-editor-source.zip`; en el APK también se incluye en `assets/flutter_assets/assets/third_party/`. Mantén estos avisos y el acceso a ese código si redistribuyes la aplicación.

Ejecuta las compilaciones e integración de forma secuencial: los comandos de Flutter regeneran registros de plugins compartidos; ejecutarlos simultáneamente puede mezclar el registro de pruebas con el APK release.

Compatibilidad Android: keyboard_height_plugin 0.1.5 esta fijado a una copia local bajo MIT con compileSdk 36. La version publicada compilaba con API 31 y fallaba con AndroidX del motor Flutter actual. Los avisos KGP de plugins de terceros se conservan en el log: indican una migracion futura, no errores del analizador Dart.

Los builds release de los scripts conservan habilitada la regeneracion de metadatos de Flutter. No agregues --no-pub a ese paso tras ejecutar pub get o integracion: en Flutter 3.47 puede conservar el registrante Android de desarrollo.


## Actualización 1.2

`InkFlow-1.2.0.apk` y `InkFlow.apk` son el mismo APK de versión 1.2.0, código 3, con la firma existente. Instalar como actualización sobre 1.0/1.1 conserva datos. No desinstales para actualizar. Los paquetes previos se conservan en `builds/archive/1.0.0/` y `builds/archive/1.1.0/`. La guía funcional está en `UPDATE_1.2.md`.
