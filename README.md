# InkFlow

App Flutter de apuntes locales para Windows y Android. Proyecto de código abierto bajo MIT; los componentes de terceros conservan sus propias licencias.

- [Actualización 1.2: organización y paletas guardadas](docs/UPDATE_1.2.md)
- [Actualización 1.1: imágenes y lienzo infinito](docs/UPDATE_1.1.md)
- [Instalación y builds](docs/INSTALLATION.md)
- [Guía de uso](docs/USER_GUIDE.md)
- [Resultados y límites](docs/AUDIT_REPORT.md)
- [Verificación](docs/VERIFICATION.md)
- [Arquitectura](docs/ARCHITECTURE.md)
- [Bugs](BUGLOG.md) · [Cambios](CHANGELOG.md) · [Licencias](LICENSES.md)

Desde `app/`: `flutter pub get`, `flutter analyze`, `flutter test`.

Los scripts de `scripts/` verifican códigos de salida y construyen los paquetes de `builds/`. Consulta la guía antes de manejar la clave de firma local. No ejecutes integración y builds nativos en paralelo.

## Privacidad y contribuciones

Los apuntes se guardan localmente. Este repositorio contiene únicamente código, recursos y documentación: no incluye apuntes, bases de datos, contraseñas ni claves privadas de firma.

Para contribuir, ejecuta `flutter pub get`, `flutter analyze` y `flutter test` desde `app/`. No incluyas datos personales ni credenciales en commits o incidencias. Consulta [las licencias de terceros](LICENSES.md) y [la configuración de firma](docs/INSTALLATION.md) antes de distribuir binarios.
