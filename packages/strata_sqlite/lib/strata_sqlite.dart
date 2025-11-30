/// SQLite adapter for the Strata data mapping library.
///
/// This library provides a concrete implementation of [StrataAdapter] that
/// works with SQLite databases. It handles database connections, migrations,
/// and translates Strata queries into SQL.
///
/// This package supports both native platforms (iOS, Android, macOS, Windows,
/// Linux) and web browsers through conditional imports.
///
/// ## Native Usage
///
/// On native platforms, no additional setup is required:
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
///
/// ## Web Usage
///
/// On web platforms, you must first initialize the WebAssembly SQLite
/// environment before creating a `SqliteAdapter`:
///
/// ```dart
/// import 'package:strata/strata.dart';
/// import 'package:strata_sqlite/strata_sqlite.dart';
///
/// // Initialize WebAssembly SQLite (do this once at app startup)
/// await initializeWebSqlite(
///   wasmUri: Uri.parse('sqlite3.wasm'),
///   dbName: 'my_app',
/// );
///
/// // Then use SqliteAdapter as normal
/// final adapter = SqliteAdapter(path: '/my_database.db');
/// final repo = StrataRepo(adapter: adapter);
///
/// await repo.initialize();
/// ```
///
/// Note: You must download `sqlite3.wasm` from the sqlite3 package releases
/// and place it in your web directory. See the sqlite3 package documentation
/// for details.
library;

export 'src/sqlite_adapter.dart';
export 'src/sql_migration.dart';
export 'src/sql_migration_runner.dart';
// Export web initialization function (only available on web)
export 'src/platform/sqlite_database.dart' show initializeWebSqlite;
