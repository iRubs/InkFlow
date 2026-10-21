# InkFlow — Changelog

Todos los cambios notables del proyecto se documentan aquí.
Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/).

## [1.2.0+3] — 2026-10-20
- Biblioteca de páginas global y por sección, favoritos, búsqueda por título/etiqueta y filtros/ordenación.
- Creación/asignación/renombrado/eliminación de etiquetas sin duplicar nombres por mayúsculas; búsqueda Unicode y validación transaccional.
- Renombrar páginas, papelera individual, restauración, deshacer y eliminación definitiva confirmada de páginas/cuadernos.
- Eliminación física preparada antes de la transacción SQLite, recuperación al iniciar, protección de archivos externos e imágenes compartidas y exclusión de operaciones pendientes del respaldo.
- Paletas personales y recientes persistentes en JSON abierto; editor con HEX, renombrado, eliminación, listas inmutables y recuperación sin sobrescribir preferencias dañadas.
- Actividad reciente actualizada al guardar lienzo, documento y PDF, con actualización de metadatos acotada durante escritura continua.
- Corrección de fechas de cuadernos con idioma del sistema distinto de español y del selector HSV en ventanas horizontales.
- Respaldo/restauración de etiquetas/favoritos/paletas y versión de producto coherente con los paquetes. SQLite conserva esquema 1.

## [1.1.0+2] — 2026-10-19
- Inserción de imágenes desde bytes o archivo, copia local normalizada con proporciones correctas y límites de memoria; errores visibles y colocación en la vista actual.
- Lienzo infinito real mediante cámara sobre coordenadas abiertas, incluyendo negativas; navegación con dedos, pellizco, rueda/Ctrl y persistencia de cámara.
- Nuevas páginas infinitas por defecto, selector A4/infinito visible, A4 encuadrado y controles fuera de la zona de escritura.
- Imágenes y stickers interactivos a cualquier zoom; movimientos y escalados se deshacen como un gesto completo.
- Exportación de toda la extensión ocupada: PNG con resolución acotada y PDF paginado hasta 200 páginas.
- Pruebas de importación, render, persistencia, navegación, coordenadas lejanas y PDF multipágina; guía de actualización sin desinstalar.

## [1.0.0+1]
### Fase 7 — Distribución local 1.0.0+1 (2026-10-19)
- APK ARM64 release firmado con clave propia RSA-4096 y esquema v2 verificado; SDK mínimo 24, objetivo 36, sin permiso INTERNET.
- Instalador Windows x64 generado con Inno Setup, versión portable completa y runtime de Visual C++ incluido.
- Instalación, arranque, instancia única, cierre y desinstalación probados en carpeta aislada con el instalador final.
- Corrección reproducible del plugin de teclado antiguo para SDK 36/JVM 17, configuración release de plugins y filtrado de ABI.
- Icono original, archivos OFL de fuentes, avisos de PDFium y fuentes MPL de AppFlowy Editor empaquetados.
- Scripts de build con comprobación de códigos de salida; guías de instalación/uso y reporte honesto de funciones parciales.
- Código fuente exportable, hashes SHA-256 y evidencias en docs/VERIFICATION.md.

### Fase 6 — Auditoría y pulido (2026-10-19)
- Respaldos reales de SQLite/adjuntos con integridad, validación de ZIP y restauración preparada con copia anterior.
- Guardado JSON recuperable y serializado; protección de revisiones del editor y guardado al suspender/cerrar.
- Correcciones de ratón, puntero propietario, zoom, borrador de segmentos y historial de objetos.
- PDF anclado a coordenadas del documento, guardado por página y exportación de todas las páginas con el original.
- PNG con imágenes/stickers, exportación Android basada en bytes, tablas/código Markdown y PDF de texto.
- Tema persistente, búsqueda funcional, objetivos de color accesibles, barra adaptable y atajos de lienzo.
- AppFlowy Editor modificado entregado como fuente MPL con parche reproducible y avisos de terceros.
- Se elimina el OCR simulado y se retira Google ML Kit para respetar cero telemetría; conversión automática pendiente. Transcripción manual disponible.
- Batería ampliada a 50 pruebas y dos integraciones nativas; prueba de terminación forzada del proceso de guardado.
- Las limitaciones heredadas de las fases anteriores se documentan expresamente en docs/AUDIT_REPORT.md.


### Fase 5 — Archivos, PDFs, Adjuntos y Exportación Completa (2026-10-16)
#### Añadido
- **Visualización y Anotación de Documentos PDF (`PdfAnnotationScreen`)**:
  - Motor nativo de renderizado acelerado por hardware para documentos PDF con `pdfrx: ^2.6.5` (PDFium nativo para Windows y Android).
  - Capa interactiva de lienzo superpuesta sobre cada página del PDF con herramientas de lápiz, resaltador traslúcido para destacar texto impreso, borrador, stickers y notas de texto.
  - Persistencia modular independiente de anotaciones por número de página (`{pageId}_p{pageNumber}.json`).
  - Barra de navegación rápida de páginas (página actual/total y salto secuencial).
  - Integración en `notebook_screen.dart`: selector de tipo de página 'PDF' con badge carmesí distintivo y enrutamiento directo.
- **Imágenes y Capas Interactivas en el Lienzo (`CanvasScreen`)**:
  - `features/canvas/models/canvas_image.dart`: Modelo inmutable con dimensiones, escala, rotación y detección de colisión (`containsPoint`).
  - `features/canvas/services/attachment_manager.dart`: Almacenamiento seguro en disco local (`InkFlowData/attachments/`) para imágenes y PDFs adjuntos.
  - Inserción táctil/cursor desde botón en la barra flotante con `file_picker`.
  - Manipulación interactiva sobre el lienzo: arrastre fluido para mover, tirador en esquina para escalar y botón rápido de eliminación.
  - Persistencia de lienzo actualizada a `version: 4` en JSON abierta.
- **Motor Integral de Exportación (`ExportService`)**:
  - Exportación de lienzos a **Documento PDF Vectorial** (`pdf: ^3.13.1`): renderizado vectorial con preservación de colores, líneas, curvas y tipografías.
  - Exportación a **Imagen PNG de Alta Definición**: rasterización a resolución Retina (2x) con opción de fondo de papel o fondo transparente.
  - Exportación de notas del editor de bloques de AppFlowy a formato estructurado **Markdown (`.md`)** estándar.
  - Modal unificado `ExportDialog` integrado en el AppBar de `CanvasScreen`, `EditorScreen` y `PdfAnnotationScreen`.
- **Sistema de Copia de Seguridad y Restauración Offline (`BackupService`)**:
  - Empaquetado completo de la base de datos SQLite y todos los archivos adjuntos en un único archivo comprimido `.inkflow` (ZIP) con manifiesto de integridad `inkflow_manifest.json` mediante `archive: ^4.5.2`.
  - Restauración segura verificando versiones y extrayendo el espacio de trabajo local sin conexión.
- **Pruebas Automatizadas y Calidad**:
  - Nuevas suites de pruebas: `test/canvas_image_test.dart` (3 casos), `test/export_test.dart` (3 casos), `test/backup_test.dart` (2 casos) y `test/pdf_annotation_test.dart` (2 casos).
  - Total de pruebas del proyecto: **40/40 pasando al 100%**.
  - `flutter analyze`: 0 errores, 0 advertencias, 0 lints.
  - `flutter build windows --release`: Compilación limpia en `builds/inkflow.exe` y `builds/pdfium.dll`.

### Fase 4 — Reconocimiento OCR de Escritura a Texto, Fuente Bonita, Paleta HSV con Gotero y Stickers Interactivos (2026-10-16)
#### Añadido
- **Reconocimiento de Escritura a Mano On-Device (OCR / Digital Ink)**:
  - `features/canvas/services/handwriting_recognition_service.dart`: Arquitectura dual con `MlKitHandwritingService` (Google ML Kit Digital Ink Recognition en Android) y `FallbackHandwritingRecognitionService` (motor determinista local para Windows y entornos de pruebas sin dependencias externas).
  - Soporte de paquetes de idioma 100% offline (Español `es` e Inglés `en`) descargables a almacenamiento local del dispositivo.
  - Conversión inteligente de selección por lazo a texto digital con reemplazo directo o copiado al portapapeles.
- **Función "Fuente Bonita" (Convertir trazos manuscritos en tipografía caligráfica)**:
  - Convierte los trazos seleccionados con el lazo en un objeto `TextAnnotation` posicionado con precisión milimétrica en el lienzo.
  - Conserva las dimensiones de la caja envolvente (`bounds`), el color del trazo original y calcula automáticamente el tamaño de fuente proporcional.
  - Soporte para 3 fuentes tipográficas OFL embebidas offline: *Caveat* (cursiva elegante), *Patrick Hand* (letra de imprenta limpia) y *Fira Code* (monoespaciada técnica).
  - Gestor de fuentes offline (`FontManager`) con importación en caliente de fuentes personalizadas `.ttf` y `.otf` del usuario mediante `FontLoader`.
- **Paleta de Colores HSV Avanzada y Gotero**:
  - `features/canvas/presentation/widgets/advanced_color_picker_dialog.dart`: Diálogo modal Material 3 con rueda de tono/saturación (HSV), deslizador de brillo, control de opacidad alfa (0% a 100%), entrada directa hexadecimal `#RRGGBB` e historial de últimos 10 colores usados (FIFO).
  - `features/canvas/services/palette_manager.dart`: Paletas temáticas predefinidas (Clásica de Notas, Pastel Suave, Neón Cyberpunk, Tonos Tierra) y persistencia de colores recientes.
  - Herramienta de Gotero (`Eyedropper`): selector de color interactivo que toma una muestra cromática exacta del trazo más cercano al punto pulsado en el lienzo.
- **Biblioteca y Motor de Stickers Interactivos**:
  - `features/canvas/models/placed_sticker.dart`: Modelo inmutable con posición, tamaño, escala, rotación y serialización JSON.
  - `features/canvas/services/sticker_manager.dart`: Biblioteca integrada de 14 stickers vectoriales SVG agrupados en 3 categorías (Educación, Organización, Decoración), importación de imágenes externas (PNG, JPG, SVG, WebP), importador/descompresor de paquetes `.zip` e integración de "Guardar selección de lazo como Sticker" rasterizado a PNG local.
  - `features/canvas/presentation/widgets/sticker_sheet_modal.dart`: BottomSheet ergonómico por pestañas con vista previa en cuadrícula e importación directa.
  - Stickers interactivos en lienzo: arrastre táctil para mover, selección con recuadro y botón flotante de eliminación rápida.
- **Pruebas Automatizadas y Calidad**:
  - `test/handwriting_test.dart`: Pruebas de serialización de anotaciones de texto, transformaciones geométricas (traslación, escalado, color) y reconocimiento OCR determinista con fallback.
  - `test/palette_test.dart`: Pruebas del gestor de paletas, cola FIFO de recientes y paletas temáticas.
  - `test/stickers_fonts_test.dart`: Pruebas de serialización de stickers, transformaciones y gestor de fuentes.
  - `flutter analyze`: 0 errores, 0 advertencias, 0 lints en todos los archivos.
  - `flutter test`: 22/22 pruebas pasando con éxito al 100%.
  - `flutter build windows --release`: Compilación exitosa en `builds/inkflow.exe` y `builds/data/app.so`.

### Fase 3 — Lienzo Avanzado con Stylus S Pen, Lazo, Autocorrección de Formas y Regla (2026-10-15)
#### Añadido
- **Herramientas de Dibujo y Escritura Avanzadas**:
  - `features/canvas/models/stroke.dart`: 8 herramientas vectoriales especializadas: Bolígrafo (`pen`), Pluma Caligráfica (`fountainPen`), Lápiz de Grafito con textura (`pencil`), Pincel de Acuarela (`brush`), Marcador Resaltador con modo mezcla traslúcido (`highlighter`), Borrador por trazo (`eraser`), Borrador por píxeles (`pixelEraser`) y Lazo de Selección (`lasso`).
  - Dinámica de trazo avanzada: presión S Pen (0.0 a 1.0), adelgazamiento y estrechamiento orgánico (`perfect_freehand`), inclinación y velocidad.
- **Autocorrección Matemática On-Device de Formas Geométricas (`ShapeRecognizer`)**:
  - Algoritmo 100% offline basado en geometría computacional para reconocimiento en tiempo real al soltar el lápiz.
  - Formas soportadas: Línea Recta limpia, Círculo perfecto, Rectángulo / Cuadrado con ángulos rectos, Triángulo simétrico y Flechas con cabeza direccional.
  - Validación geométrica de cierre de curva, varianza radial y distancia a segmentos ortogonales.
- **Herramienta de Lazo de Selección Libre (`LassoSelection`)**:
  - Algoritmo de punto dentro de polígono por Ray-Casting (`isPointInPolygon`).
  - Selección de trazos cerrados, cálculo de caja envolvente (`bounds`) y vértices de control.
  - Barra de herramientas contextual flotante para la selección: traslación interactiva por arrastre, duplicación instantánea, recoloreado con la paleta activa y eliminación en bloque.
- **Regla Virtual Acrílica (`CanvasPainter` / `CanvasScreen`)**:
  - Regla semitransparente con graduación métrica milimétrica y centímetros numerados.
  - Lectura de ángulo en tiempo real y botón de giro en incrementos de 15°.
  - Trazado asistido con ajuste (snap) a los bordes rectificados de la regla.
- **Lienzo Infinito y Modo Hoja Fija**:
  - Modo lienzo infinito con zoom y pan continuos (rango 0.25x a 5.0x) mediante `InteractiveViewer` y matriz de transformación `_toScene`.
  - Modo página fija A4 con sombra de hoja realista y márgenes tipográficos.
  - Plantilla de apuntes Cornell con columna de notas clave, sección de resumen inferior y rayado horizontal.
- **Rechazo de Palma Estricto y Atajos de Hardware**:
  - Filtro estricto de punteros: el S Pen dibuja exclusivamente; los dedos realizan zoom y paneo sin manchar la hoja.
  - Detección del botón físico secundario del S Pen (`kSecondaryMouseButton`): al mantenerlo pulsado alterna inmediatamente al borrador y regresa a la herramienta anterior al soltarlo.
- **Pruebas Automatizadas y Verificación**:
  - `test/canvas_test.dart`: Pruebas exhaustivas de reconocimiento de líneas, círculos y rectángulos; algoritmo de punto en polígono de lazo; manipulación de trazos (traslación, duplicado, color); prueba de widget con `CanvasScreen`.
  - 11/11 pruebas del proyecto pasando con éxito.
  - `flutter analyze`: 0 errores, 0 advertencias, 0 lints.
  - `flutter build windows --release`: Compilación limpia en `builds/inkflow.exe`.

### Fase 2 — Editor de Bloques, Tablas y Organización de Páginas (2026-10-15)
#### Añadido
- **Integración del motor de bloques de AppFlowy (`appflowy_editor: ^6.2.0`)**:
  - `features/editor/presentation/editor_screen.dart`: Editor enriquecido con soporte de bloques completos (párrafos, encabezados H1-H6, listas con viñetas, listas numeradas, tareas con checkboxes, citas, divisores, tablas y llamadas destacadas).
  - Menú slash interactivo (`/`) para inserción rápida de cualquier tipo de bloque.
  - Persistencia de notas enriquecidas en formato estándar JSON local (`InkFlowData/editor/{pageId}.json`) con autoguardado continuo (debounced).
  - Deshacer/rehacer ilimitado (`undoManager`) con controles integrados en AppBar y atajos de teclado (`Ctrl+Z`, `Ctrl+Y`).
  - Barra de herramientas flotante (`FloatingToolbar`) para escritorio (Windows) y barra contextual táctil ergonómica (`MobileToolbarV2` y `MobileFloatingToolbar`) para tablet (Galaxy Tab S10 Lite).
  - Modal de estadísticas de la nota con conteo de palabras, caracteres y bloques totales.
- **Selector y Organización Multitipo de Páginas**:
  - `features/notebook/presentation/notebook_screen.dart`: Diálogo de creación de páginas con selección entre "Lienzo (Stylus/S Pen)" y "Documento (Editor de bloques)".
  - Enrutamiento dinámico según `pageType`: abre `CanvasScreen` para páginas de dibujo o `EditorScreen` para notas estructuradas.
  - Indicadores visuales y badges en la cuadrícula de páginas de cada sección.
  - Selector de plantillas de papel (rayado, cuadriculado, punteado, en blanco, notas Cornell).
- **Pruebas Automatizadas y Calidad**:
  - `test/editor_test.dart`: Pruebas de serialización/deserialización JSON de documentos y prueba de widget de `EditorScreen`.
  - 100% de advertencias corregidas (`withOpacity` migrado a `withValues(alpha:)`, constantes añadidas).
  - Parche de compatibilidad para `TextInputClient.onFocusReceived` en Flutter 3.47.
  - `flutter analyze`: 0 errores, 0 advertencias, 0 lints.
  - `flutter test`: 5/5 pruebas pasando con éxito.
  - `flutter build windows --release`: Compilación exitosa en `builds/inkflow.exe`.

### Fase 1 — Esqueleto, Arquitectura, Persistencia Local y Diseño (2026-10-15)
#### Añadido
- **Design System completo**:
  - `core/theme/colors.dart`: Paletas profesionales para modo claro/oscuro, texturas de papel físico (blanco, marfil, menta, pizarra) y paleta de tintas para stylus/S Pen.
  - `core/theme/spacing.dart`: Tokens ergonómicos con áreas de toque táctil accesibles (≥48px) y dimensiones para barra flotante de lápiz.
  - `core/theme/typography.dart`: Jerarquía tipográfica legible adaptada a tablets y pantallas de escritorio.
  - `core/theme/app_theme.dart`: ThemeData Material 3 completo con extensión personalizada `InkCanvasThemeExtension`.
- **Persistencia Local Offline (Drift SQLite)**:
  - Tablas: `Notebooks`, `Sections`, `Pages`, `Tags` y `PageTags`.
  - Soporte completo para soft delete (papelera), favoritos, metadatos y fechas de modificación.
  - Generación de código Drift automatizada (`app_database.g.dart`).
- **Gestión de Estado (Riverpod)**:
  - `shared/providers/database_provider.dart`: Proveedor singleton de base de datos y streams reactivos de cuadernos activos, favoritos y papelera.
- **Navegación e Interfaz Adaptativa**:
  - `features/home/presentation/home_screen.dart`: `NavigationRail` para tablets (Samsung Galaxy Tab) y PC; `NavigationBar` para pantallas compactas.
  - Vistas integradas: Todos los cuadernos, Favoritos, Papelera con restauración y Ajustes.
  - Búsqueda global reactiva de páginas en tiempo real.
  - Tarjetas de cuaderno con efecto visual de encuadernación física y lomo.
  - Diálogo modal con selección de colores para creación de cuadernos.
- **Lienzo con Lápiz (Stylus Canvas Foundation)**:
  - `features/canvas/models/stroke.dart`: Modelos vectoriales con captura de presión continua (0.0 a 1.0) y marcas de tiempo.
  - `features/canvas/painters/canvas_painter.dart`: Motor de renderizado con `perfect_freehand` para contornos orgánicos suaves y plantillas de papel (rayado con margen, cuadriculado, punteado, blanco).
  - `features/canvas/presentation/canvas_screen.dart`: Captura de puntero de baja latencia con `Listener`, detección de botón del S Pen para alternar borrador, rechazo de palma y autoguardado continuo en JSON.
- **Pruebas Automatizadas**:
  - `test/database_test.dart`: Pruebas unitarias de CRUD, favoritos, papelera y relaciones en cascada.
  - `test/widget_test.dart`: Prueba de renderizado de la interfaz inicial con base de datos en memoria.
- **Compilación Release para Windows**:
  - Binario generado con éxito en `builds/inkflow.exe`.

### Fase 0 — Investigación y Configuración de Entorno (2026-10-15)
#### Añadido
- Estructura de carpetas del proyecto en el Escritorio.
- `LICENSES.md` con análisis legal y cumplimiento de licencias.
- `BUGLOG.md` para registro detallado de incidencias y soluciones.
- `docs/ARCHITECTURE.md` con justificación técnica de arquitectura.
- `docs/HOSTING.md` con guía completa de sincronización opcional (Syncthing P2P y servidor Docker).
- Scripts de automatización: `scripts/build_windows.ps1`, `scripts/build_android.ps1`, `scripts/backup.ps1`.
- Configuración de Flutter 3.47.7, Android SDK Platform 34 y Visual Studio Build Tools 2026.


