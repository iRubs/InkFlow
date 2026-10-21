import 'package:drift/drift.dart';

/// Tabla de Cuadernos (Notebooks)
class Notebooks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get coverColor => text().withDefault(const Constant('#2563EB'))();
  TextColumn get coverImagePath => text().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Tabla de Secciones dentro de un cuaderno (capítulos o divisores)
class Sections extends Table {
  TextColumn get id => text()();
  TextColumn get notebookId => text().customConstraint(
    'NOT NULL REFERENCES notebooks(id) ON DELETE CASCADE',
  )();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Tabla de Páginas (hojas individuales de un cuaderno/sección)
class Pages extends Table {
  TextColumn get id => text()();
  TextColumn get sectionId => text().customConstraint(
    'NOT NULL REFERENCES sections(id) ON DELETE CASCADE',
  )();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get pageType => text().withDefault(
    const Constant('canvas'),
  )(); // 'canvas', 'text', 'mixed', 'pdf'
  TextColumn get templateId => text().withDefault(
    const Constant('ruled'),
  )(); // 'blank', 'ruled', 'grid', 'dotted', 'cornell'
  TextColumn get paperColor => text().withDefault(const Constant('#FFFFFF'))();
  TextColumn get orientation => text().withDefault(
    const Constant('portrait'),
  )(); // 'portrait', 'landscape'
  TextColumn get paperSize =>
      text().withDefault(const Constant('A4'))(); // 'A4', 'Letter', 'Infinite'
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Tabla de Etiquetas (Tags) para búsqueda y organización
class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().unique()();
  TextColumn get color => text().withDefault(const Constant('#6366F1'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Tabla intermedia de relación Páginas <-> Etiquetas
class PageTags extends Table {
  TextColumn get pageId => text().customConstraint(
    'NOT NULL REFERENCES pages(id) ON DELETE CASCADE',
  )();
  TextColumn get tagId => text().customConstraint(
    'NOT NULL REFERENCES tags(id) ON DELETE CASCADE',
  )();

  @override
  Set<Column> get primaryKey => {pageId, tagId};
}
