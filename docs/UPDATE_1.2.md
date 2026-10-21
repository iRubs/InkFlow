# InkFlow 1.2 — Organización de páginas y paletas guardadas

Actualización del 20 de octubre de 2026. Continúa las mejoras de imágenes y lienzo infinito de la versión 1.1.

## Actualizar

Instala `builds/InkFlow-1.2.0.apk` sobre la versión anterior y elige **Actualizar**. No hace falta desinstalar. Se conserva el identificador de aplicación y la misma firma; la versión es 1.2.0, código 3. Windows dispone del instalador actualizado `builds/InkFlow-Setup.exe`. Los paquetes anteriores se conservan en `builds/archive/`.

Las notas existentes mantienen sus identificadores y archivos. No se cambia el esquema de SQLite: los respaldos anteriores siguen siendo compatibles.

## Encontrar y organizar las páginas

En **Cuadernos**, **Favoritos** y **Papelera** puedes alternar entre **Cuadernos** y **Páginas**. Dentro de un cuaderno, cada sección también muestra la biblioteca de páginas.

- Busca por título o etiqueta. Se distinguen los acentos, pero no las mayúsculas: «ÁLGEBRA» y «álgebra» coinciden.
- Ordena por actividad reciente, título, antigüedad u orden del cuaderno.
- Pulsa una etiqueta para filtrar; pulsa **Todas** para quitar el filtro.
- La estrella marca o desmarca una página favorita.
- El menú de cada página permite renombrarla, editar sus etiquetas o enviarla a la papelera. Al moverla a la papelera aparece **Deshacer**.
- Los guardados del lienzo, editor y anotaciones PDF actualizan la actividad de la página y su cuaderno. Durante escritura continua se limita la frecuencia de actualización de estos metadatos.

Las páginas de un cuaderno eliminado no aparecen en las vistas activas ni en la papelera individual de páginas. Primero restaura su cuaderno. Restaurar el cuaderno conserva el estado previo de cada página: una página eliminada por separado sigue en su papelera.

## Etiquetas

Desde **Editar etiquetas**, escribe nombres separados por comas o selecciona etiquetas existentes. Cada página admite hasta 12 etiquetas de 40 caracteres. Los espacios repetidos y las diferencias de mayúsculas no crean etiquetas nuevas equivalentes.

El botón **Gestionar etiquetas** permite renombrarlas en todas sus páginas o eliminarlas. Eliminar una etiqueta conserva los apuntes y las páginas. Renombrar a un nombre ya existente muestra un error y conserva las asociaciones anteriores.

## Papelera y eliminación definitiva

En **Papelera → Páginas** puedes restaurar una nota. Su menú permite eliminarla definitivamente después de una confirmación. Los cuadernos también requieren confirmación para su eliminación definitiva.

La eliminación definitiva retira los archivos propios de la nota y sus referencias en la biblioteca. Conserva las imágenes compartidas con otras páginas, los archivos de origen que estén fuera de InkFlow y los respaldos creados previamente. Si alguna referencia local está dañada y no puede comprobarse, se conservan los posibles adjuntos compartidos antes de arriesgarse a borrar contenido ajeno.

Si la app se interrumpe durante una eliminación, revisa la operación al volver a iniciar: recupera los archivos si la eliminación de la biblioteca no llegó a confirmarse, o completa su retirada si ya se confirmó. No se sobrescribe un archivo existente al recuperar.

## Paletas personales

En el lienzo, abre el selector de color y entra en **Mis paletas**:

1. Pulsa **Crear paleta**, escribe un nombre y añade colores.
2. Puedes usar el color actual o escribir códigos `#RRGGBB` y `#AARRGGBB` (los dos primeros dígitos de este último son la transparencia).
3. Guarda la paleta. Se conservan sus colores, el nombre y los diez colores recientes al cerrar la app.
4. Los botones de lápiz y papelera permiten editar, renombrar o eliminar una paleta. Esto no cambia los colores de las notas existentes.

Cada paleta admite hasta 64 colores y un nombre de 60 caracteres. Se guardan localmente en `InkFlowData/preferences/palettes.json`, un JSON abierto incluido en los respaldos. Un archivo de preferencias dañado se recupera desde la última copia válida si existe; si no puede recuperarse, se conserva sin sobrescribirlo y se informa del error.

## Qué sigue pendiente

Esta versión completa la organización de páginas y las paletas personales. Siguen pendientes OCR automático privado, biblioteca/editor completo de plantillas, tablas avanzadas, adjuntos de cualquier tipo, transformaciones completas del lazo, funciones avanzadas de S Pen y sincronización con resolución de conflictos. Los límites de exportación y de pruebas en hardware se detallan en `AUDIT_REPORT.md`.
