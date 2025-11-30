import 'package:sqlite3/common.dart';

/// Initializes the web SQLite environment.
///
/// This is a stub implementation that throws on unsupported platforms.
/// On web platforms, this function loads the WebAssembly module and sets up
/// the virtual file system.
Future<void> initializeWebSqlite({
  Uri? wasmUri,
  String dbName = 'strata_sqlite',
}) async {
  throw UnsupportedError('SQLite is not supported on this platform.');
}

/// Opens a SQLite database at the given [path].
///
/// This is a stub implementation that throws on unsupported platforms.
CommonDatabase openSqliteDatabase(String path) {
  throw UnsupportedError('SQLite is not supported on this platform.');
}

/// Opens an in-memory SQLite database.
///
/// This is a stub implementation that throws on unsupported platforms.
CommonDatabase openSqliteInMemory() {
  throw UnsupportedError('SQLite is not supported on this platform.');
}
