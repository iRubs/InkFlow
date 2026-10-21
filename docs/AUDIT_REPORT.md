# InkFlow — Auditoría de continuación

Fecha: 2026-10-19. Actualizado el 2026-10-20 para 1.2.0+3; consulta `UPDATE_1.2.md`. Proyecto recibido al terminar la fase 5. La versión original `Escritorio/InkFlow` se conserva. La continuación está en `Escritorio/InkFlow-Continuacion`.

Se revisaron código, persistencia, importación/exportación, entradas de lápiz y ratón, dependencias, licencias, tests y empaquetado. Se priorizaron pérdidas de datos y resultados engañosos. `BUGLOG.md` enumera causa, solución y verificación por incidencia.

## Qué se ha comprobado

- Base SQLite con cascadas; respaldo y restauración de cuadernos, archivos y referencias.
- Recuperación JSON tras truncamiento y escrituras concurrentes; proceso terminado durante guardado de 5.000 trazos.
- Rechazo de rutas ZIP peligrosas y hashes inválidos sin modificar el destino.
- Punteros de lápiz, palma y ratón; zoom 2x; borrado de segmentos; deshacer/rehacer; pantalla estrecha.
- PNG con píxeles reales de imágenes y stickers; Markdown con tablas reales del editor.
- PDFium nativo: abrir PDF de dos páginas, anotar, guardar, reabrir y exportar todas las páginas.
- Solicitud de cierre del editor con una transacción que aún no había alcanzado el debounce.

Las salidas exactas y artefactos están en `logs/` y se resumen en `VERIFICATION.md`. El test de JSON de 1.500 trazos tardó aproximadamente 0,1 s en este equipo; no es una medición de latencia S Pen ni de fps.

## Decisiones importantes

La prioridad de cero telemetría obligó a retirar Google ML Kit: [Google documenta envío de métricas de uso](https://developers.google.com/ml-kit/terms). La conversión automática de escritura a texto queda sin implementar en esta entrega. Se mantienen transcripción manual y composición tipográfica, sin respuestas fingidas. No se ha añadido otro servicio remoto como sustituto.

Para corregir exportaciones incompletas se prioriza conservar todo el aspecto de la nota. Los PDF de lienzo se exportan aplanados a 108 dpi y los PDF anotados a 144 dpi; no conservan texto seleccionable. El editor exporta una representación de texto en PDF y Markdown. No se promete maquetación idéntica de todos los bloques.

## Revisión de incidencias de referencia

- [AppFlowy #8577](https://github.com/AppFlowy-IO/AppFlowy/issues/8577): caída al arrancar una instalación Windows. InkFlow no integra aquel core Rust/servicios, pero se verifica igualmente su arranque e instalación; no se certifica Windows 10 sin disponer de una máquina Windows 10.
- [xnotes #289](https://github.com/shardulvs/xnotes-android/issues/289): bloqueo al recorrer PDFs. La nueva vista mantiene una página y serializa sus cambios; la prueba nativa ejercita navegación y reapertura. Hace falta medir documentos extensos en tablet.
- [xnotes #291](https://github.com/shardulvs/xnotes-android/issues/291): exportaciones grandes. Se documenta el coste del aplanado; no se afirma resolver el tamaño óptimo de documentos largos. Exportar 1000 páginas puede requerir streaming adicional.
- [xnotes #287](https://github.com/shardulvs/xnotes-android/issues/287): front buffering. InkFlow usa Flutter/CustomPainter, no aquel pipeline. Las pruebas sintéticas no permiten descartar problemas de latencia del controlador Samsung.

## Lo que todavía falta del encargo original

OCR automático privado; biblioteca completa de plantillas y editor de plantillas; ordenar/filtrar tablas y vistas de base de datos; adjuntos arbitrarios; transformaciones completas del lazo; doble toque de S Pen, predicción de tinta y transportador; sincronización con fusión de conflictos.

El usuario probó la entrega 1.0 en su tablet y reportó problemas de imágenes y espacio de escritura, corregidos en 1.1. No hay una tablet física conectada al entorno de desarrollo. No están certificados presión/inclinación del dispositivo, rechazo de palma Samsung, 60/120 fps, rotación nativa, TalkBack, memoria de documentos enormes ni instalación física del APK. La app sigue siendo una continuación funcional con auditoría y distribución local, no el cumplimiento total de toda la lista de producto.


## Actualización 1.1

Se añadieron importación de imágenes sin ruta local, proporciones reales y posición visible; cámara de lienzo infinito con coordenadas abiertas, A4 encuadrado, navegación táctil y persistencia; exportación por área ocupada con PDF multipágina y PNG con memoria acotada. Límites y controles en `UPDATE_1.1.md`. Las mediciones físicas de Samsung siguen pendientes de validación por el usuario.


## Actualización 1.2

Organización de páginas y paletas personales ya implementadas: biblioteca por sección/global, búsqueda Unicode y por etiquetas, filtros, favoritos, renombrado, papelera y restauración. Eliminación definitiva confirmada con preparación/recuperación de archivos propios y conservación de imágenes compartidas. Paletas/recientes guardadas en JSON e incluidas en respaldos. Las notas existentes conservan sus rutas e identificadores; SQLite mantiene esquema 1.

También se corrigieron la actividad reciente tras guardar, las fechas de cuadernos dependientes de inicialización intl y el selector HSV horizontal. La integración nativa verifica respaldo/restauración de etiquetas, favoritos y paletas y confirma que cancelar una eliminación no cambia datos. Se añadieron regresiones de rutas, rollback, Unicode e interfaz estrecha. Resultados en `VERIFICATION.md`.
