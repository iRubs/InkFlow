# InkFlow 1.1 — Imágenes y espacio para escribir

Actualización del 19 de octubre de 2026, a partir de las pruebas del usuario en su tablet.

## Instalar la actualización

Copia `builds/InkFlow.apk` a la tablet, ábrelo desde Mis archivos y elige **Actualizar**. Conserva el identificador de aplicación y la misma clave de firma de la entrega anterior; la versión aumenta a 1.1.0 (código 2). No hace falta desinstalar la versión anterior. Las notas existentes se leen sin borrar ni convertir sus trazos. El instalador de Windows también actualiza la versión anterior.

## Añadir una imagen

Pulsa el botón de imagen situado arriba del lienzo. Selecciona una imagen desde el selector de Android. Se admiten imágenes proporcionadas como bytes aunque no tengan una ruta local disponible. Los formatos recomendados son PNG, JPG y WebP. Si el selector se cancela, no se modifica la nota; los errores de lectura o formato se muestran en pantalla.

La imagen aparece centrada en la zona que estás viendo, con sus proporciones originales. La herramienta cambia al lazo para que puedas arrastrarla y usar la esquina inferior derecha para cambiar su tamaño. Pulsa el bolígrafo para volver a escribir encima. Puedes deshacer y rehacer tanto la inserción como un movimiento o cambio de tamaño completo.

La app conserva una copia PNG local independiente del archivo de origen. Para reducir la memoria utilizada en tablet, su lado mayor se limita a 2048 píxeles. La entrada se limita a 40 MB; una imagen animada se importa como imagen estática. No se añade acceso a Internet ni permisos generales sobre el almacenamiento.

## Usar el lienzo infinito

Las nuevas páginas de notas usan lienzo infinito. Las páginas existentes mantienen su modo anterior; pulsa **Hoja A4** para cambiarlas a **Lienzo infinito**, sin eliminar contenido.

- Escribe con el S Pen; desplaza la vista con los dedos y pellizca con dos dedos para ampliar o reducir (10–500 %).
- Puedes continuar hacia abajo, arriba o los lados, incluso en coordenadas negativas. No se crea una imagen gigantesca en memoria: se pinta la zona visible de un espacio de coordenadas abierto.
- El botón **Ver todas las anotaciones** encuadra el contenido; **Volver al inicio** lleva al origen. La posición y el zoom se guardan al terminar de navegar o guardar la nota.
- En Windows, la rueda desplaza la vista y Ctrl + rueda cambia el zoom. El ratón permite escribir o mover objetos con el lazo.
- La hoja A4 se encuadra en pantalla y conserva un fondo exterior diferenciado. Las barras de controles quedan fuera de la zona de escritura.

## Exportar una nota larga

La exportación del lienzo infinito calcula el área ocupada por trazos, texto, imágenes y stickers, incluyendo posiciones negativas. El PDF la divide en páginas de 820 × 1160 puntos, de izquierda a derecha y después hacia abajo. Su límite actual es de 200 páginas por exportación; no se descarta contenido silenciosamente. El PNG incluye toda el área y reduce la resolución si es necesario para limitar la memoria a aproximadamente 16 megapíxeles y 16000 píxeles por lado. Los PDF del lienzo siguen siendo aplanados, a 108 dpi por página.

La extensión de la nota depende de la memoria y del almacenamiento disponibles; «infinito» describe el espacio de trabajo, no recursos físicos ilimitados.

## Alcance de la comprobación

Las pruebas nuevas cubren selección sin ruta, tamaño y proporciones, inserción en una zona alejada del origen, deshacer/rehacer, navegación táctil y pellizco, escritura con zoom, persistencia de imágenes/cámara y exportación de coordenadas negativas. La integración nativa usa un selector simulado para suministrar la imagen y el motor real para decodificarla, guardarla y renderizarla. No sustituye comprobar el selector y el S Pen de Samsung en el dispositivo del usuario. Los resultados finales están en `VERIFICATION.md`.
