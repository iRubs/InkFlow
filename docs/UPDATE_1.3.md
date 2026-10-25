# InkFlow 1.3 — Hoja continua vertical y herramientas visibles

Actualización del 24 de octubre de 2026 a partir de las pruebas en tablet.

## Instalar

Abre `builds/InkFlow-1.3.0.apk` en la tablet y elige **Actualizar**. Mantiene el identificador y la clave de firma de 1.0–1.2; no desinstales para actualizar. La versión es 1.3.0, código 4.

## La hoja

Las notas nuevas tienen un ancho lógico de 820 unidades, el mismo ancho usado al exportar páginas A4 de 820 × 1160. Al abrirlas, la hoja encaja al ancho disponible con un margen de 12 píxeles a cada lado. No hay espacio de escritura encima del inicio ni fuera de sus bordes laterales: continúa hacia abajo con los dedos. Al ampliar con dos dedos puedes recorrer el ancho de la propia hoja, sin desplazarte hacia un espacio vacío exterior. El zoom mínimo vuelve al encaje de ancho.

La rotación mantiene el encaje relativo y la posición vertical. **Volver al inicio** recupera el inicio de la hoja y su ancho ajustado a pantalla. El botón **Hoja continua / Hoja A4** cambia entre escritura larga vertical y una sola hoja fija. En PDF, la hoja continua se divide hacia abajo en páginas de ancho constante; el límite de exportación sigue siendo de 200 páginas.

Las notas antiguas con contenido dentro del ancho normal se abren como hojas continuas. Si una nota antigua contiene dibujos, imágenes o texto fuera del ancho de hoja o encima del origen, se conserva como **Lienzo libre anterior**, con sus coordenadas y cámara, para no ocultar ni mover ese contenido. Su archivo original sigue siendo legible y las operaciones de deshacer conservan el modo de página. No se borra ni se comprime el contenido para adaptarlo al nuevo formato.

## Lápices y colores

La barra de escritura está arriba, fuera de la hoja y de la navegación del sistema. En pantallas estrechas se reparte en dos filas; no hace falta deslizar horizontalmente para encontrar los controles principales.

- **Lápiz** abre los tipos: bolígrafo, pluma caligráfica, lápiz grafito, pincel y resaltador.
- **Borrador** borra trazos; **Lazo** selecciona dibujos e imágenes.
- **Color**, junto al círculo que muestra la tinta actual, abre el selector HSV/HEX y las paletas guardadas. Elige un color y pulsa **Aplicar Color**.
- **Grosor** abre un control de 1 a 20 pt. Los ajustes se aplican a los trazos nuevos.
- **Más** ofrece stickers, texto, borrador de precisión y gotero.

Las imágenes y stickers nuevos se insertan y se arrastran dentro del ancho de hoja. Las imágenes conservan sus proporciones y su tamaño máximo se limita al papel al ampliarlas. Los trazos nuevos tampoco pueden continuar fuera de sus bordes laterales ni por encima del inicio.

Las opciones de regla, plantilla y exportación siguen en la barra del título; esa barra permite desplazarse horizontalmente si el dispositivo no tiene espacio para todos sus botones.

## Verificación y referencia

Las comprobaciones incluyen gestos táctiles, coordenadas del stylus con zoom, límites del papel, rotación, texto ampliado, selección real de tipo/grosor/color, recuperación del lienzo antiguo y reapertura de imágenes/cámara. La integración de Windows comprueba persistencia y renderiza un PDF de tres páginas. Estas pruebas no sustituyen la comprobación del S Pen y de los controles táctiles en la tablet física.

La referencia de interacción solicitada es el estilo de desplazamiento continuo de [Samsung Notes](https://www.samsung.com/us/support/answer/ANS10004548/). La implementación de InkFlow es propia y no utiliza código ni recursos de Samsung.
