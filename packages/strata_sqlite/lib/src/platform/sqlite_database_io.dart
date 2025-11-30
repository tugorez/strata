import 'package:sqlite3/common.dart';
import 'package:sqlite3/sqlite3.dart';

/// Initializes the web SQLite environment.
///
/// On native platforms (iOS, Android, macOS, Windows, Linux), this function
/// is a no-op since SQLite is loaded via FFI and doesn't need initialization.
///
/// This function exists to provide a consistent API across platforms, allowing
/// the same initialization code to work on both native and web.
Future<void> initializeWebSqlite({
  Uri? wasmUri,
  String dbName = 'strata_sqlite',
}) async {
  // No-op on native platforms - SQLite is loaded via FFI
}

/// Opens a SQLite database at the given [path] using the native FFI bindings.
///
/// On native platforms (iOS, Android, macOS, Windows, Linux), this uses
/// dart:ffi to access SQLite directly.
CommonDatabase openSqliteDatabase(String path) {
  return sqlite3.open(path);
}

/// Opens an in-memory SQLite database using the native FFI bindings.
///
/// On native platforms (iOS, Android, macOS, Windows, Linux), this uses
/// dart:ffi to access SQLite directly.
CommonDatabase openSqliteInMemory() {
  return sqlite3.openInMemory();
}
