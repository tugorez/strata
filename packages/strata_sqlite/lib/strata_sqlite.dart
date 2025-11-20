/// SQLite adapter for the Strata data mapping library.
///
/// This library provides a concrete implementation of [StrataAdapter] that
/// works with SQLite databases. It handles database connections, migrations,
/// and translates Strata queries into SQL.
///
/// ## Usage
///
/// ```dart
/// import 'package:strata/strata.dart';
/// import 'package:strata_sqlite/strata_sqlite.dart';
///
/// final adapter = SqliteAdapter(path: 'my_database.db');
/// final repo = StrataRepo(adapter: adapter);
///
/// await repo.initialize();
/// ```
library;

export 'src/sqlite_adapter.dart';
export 'src/sql_migration.dart';
export 'src/sql_migration_runner.dart';
