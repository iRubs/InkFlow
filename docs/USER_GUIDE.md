# InkFlow — Guía de uso

Esta continuación mantiene el proyecto anterior separado. El código está en `InkFlow-Continuacion/app`; los instaladores se entregan en `InkFlow-Continuacion/builds`.

## Empezar

1. Abre InkFlow y pulsa **Nuevo Cuaderno**. Elige título y color. Se crea una sección General y la primera página.
2. Dentro del cuaderno puedes crear secciones y páginas de lienzo, texto o PDF.
3. La búsqueda de la pantalla inicial busca títulos y permite abrir el resultado. Excluye cuadernos en la papelera.
4. En Ajustes elige tema claro, oscuro o del sistema. La preferencia se guarda localmente.

## Lienzo y lápiz

El lápiz y el ratón escriben. Con rechazo de palma activado, los dedos desplazan y amplían la página. La barra inferior se puede desplazar horizontalmente si la pantalla es estrecha. Incluye las herramientas de tinta, borradores, lazo, colores, texto, stickers e imágenes.

Usa **Lazo** para manipular imágenes y stickers sin moverlos al escribir encima. El borrador de precisión corta los segmentos sin volver a unir el hueco. Deshacer y rehacer conservan también borrados, imágenes, stickers y texto durante la sesión; el historial no se conserva al cerrar la página. La inclinación se registra, pero no se garantiza una simulación física completa de cada herramienta.

La conversión automática de escritura está pendiente de un motor local sin telemetría. La auditoría retiró Google ML Kit porque sus condiciones documentan envío de métricas a Google. Para conservar cero SDK de telemetría, **Transcribir selección** permite introducir manualmente el texto y **Fuente bonita** lo coloca con la tipografía elegida, respetando la zona seleccionada. No se presentan respuestas simuladas como reconocimiento real. El APK final no solicita permiso INTERNET.

## Editor de texto

El editor AppFlowy incluye bloques y tablas editables. Usa `/` para insertar bloques y su barra de formato. El autoguardado se programa tras 1,5 segundos de inactividad y, si continúas escribiendo, cada cinco segundos. Al suspender o solicitar cierre normal se intenta completar el guardado. El almacenamiento conserva una revisión anterior para recuperación; ante un cierre forzado se recupera la última revisión válida, no necesariamente las últimas teclas aún pendientes.

## PDF

Crea una página PDF e importa un archivo local. Se copia al almacenamiento de la app. Los botones inferiores cambian de página; dedos y rueda/gestos permiten navegar y ampliar. El lápiz y el ratón anotan. Las coordenadas se guardan en puntos PDF, de modo que el trazo permanece anclado al documento al ampliar o cambiar el tamaño de ventana.

La exportación recorre todas las páginas e incluye el original y las anotaciones. El PDF compartido queda aplanado a 144 dpi: mantiene el aspecto, pero el texto del PDF original ya no es seleccionable en esa copia exportada. El original y los trazos editables siguen almacenados en InkFlow. Las anotaciones antiguas de fase 5 usaban coordenadas de ventana; no existe una conversión automática fiable si no conocemos el tamaño original de aquella ventana.

## Exportar

El botón Compartir abre PDF, PNG o Markdown según el tipo de nota. PNG incluye tinta, imágenes, stickers y plantilla, con fondo de papel o transparente. El PDF del editor presenta el contenido estructurado en una representación de texto; no promete reproducir toda la maquetación del editor. Markdown conserva tablas básicas, listas, código multilínea y parte del formato en línea. El lienzo se exporta por el área A4 configurada; el lienzo infinito aún no calcula automáticamente todos los límites del contenido.

## Respaldar y restaurar

Desde **Ajustes → Crear respaldo completo**, guarda un archivo `.inkflow` fuera de la carpeta de datos. También está disponible en el diálogo de exportación. Incluye una instantánea coherente de SQLite, notas, fuentes y adjuntos; el manifiesto registra hashes SHA-256. El formato es ZIP estándar, JSON y SQLite. No está cifrado: guárdalo en una ubicación privada si contiene apuntes sensibles.

Para recuperar, abre **Ajustes → Restaurar respaldo**, selecciona el archivo y confirma el reemplazo. Se validan manifiesto, rutas, hashes y SQLite antes de sustituir la carpeta. Se conserva la carpeta anterior junto a `InkFlowData` con sufijo `.before-restore-...`. No elimines esa copia hasta comprobar tus notas. Los respaldos incompletos de fase 5 no se aceptan como respaldos completos de versión 2; sus archivos se pueden inspeccionar como ZIP y recuperar manualmente conservando los originales.

En Windows los datos están en Documentos/InkFlowData (Documentos puede estar redirigido a OneDrive). La base anterior `Documentos/inkflow.sqlite` se migra mediante una instantánea y se conserva como origen. El nuevo archivo es `InkFlowData/inkflow.sqlite`. No copies solamente el `.exe` para mover apuntes: utiliza el respaldo.

`scripts/backup.ps1` crea una copia en frío `.zip` con la app cerrada, para recuperación manual. Conserva también el SQLite antiguo si existe. Para recuperarla: cierra InkFlow, guarda una copia aparte de los datos actuales y extrae el contenido en una carpeta temporal; revisa `InkFlowData` y los archivos SQLite antes de sustituirlos. Nunca mezcles archivos SQLite y sus WAL de dos copias diferentes. Es preferible usar la restauración validada de la app.

## Límites que siguen pendientes

El programa no cubre todavía toda la lista original: faltan el catálogo completo de plantillas y su editor, vistas de base de datos con ordenar/filtrar, gestión completa de etiquetas/favoritos/papelera de páginas, adjuntos arbitrarios, transferidor, predicción de tinta, doble toque de S Pen, transformaciones completas del lazo y sincronización con fusión de conflictos. Las paletas personalizadas tienen modelo de datos pero su interfaz y persistencia completa siguen pendientes.

Las pruebas automatizadas con punteros no sustituyen una prueba en Galaxy Tab S10 Lite. La latencia real, 60/120 fps, rechazo de palma del controlador Samsung, botón físico, inclinación, accesibilidad con TalkBack y rotación nativa requieren verificación en ese dispositivo. No se ofrece garantía de esos resultados sin esa prueba.


## Imágenes y lienzo infinito (1.1)

Consulta [la guía de actualización](UPDATE_1.1.md) para insertar/mover/escalar imágenes, alternar A4 e infinito, navegar con dedos y exportar notas largas. La actualización conserva las notas existentes y la firma del APK anterior.


## Organización y paletas (1.2)

Consulta [la guía 1.2](UPDATE_1.2.md) para gestionar páginas, etiquetas, favoritos y papelera, y crear paletas que se conservan al cerrar la app. La actualización se instala sobre la anterior sin desinstalar.
