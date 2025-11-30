import 'package:sqlite3/common.dart';
import 'package:sqlite3/wasm.dart';

/// The WebAssembly SQLite instance, initialized lazily.
WasmSqlite3? _wasmSqlite;

/// The default virtual file system for web databases.
IndexedDbFileSystem? _defaultFileSystem;

/// Whether the web SQLite environment has been initialized.
bool _initialized = false;

/// Initializes the web SQLite environment.
///
/// This must be called before using [openSqliteDatabase] on the web.
/// It loads the WebAssembly module and sets up the virtual file system.
///
/// Parameters:
/// - [wasmUri]: URI to the sqlite3.wasm file (default: 'sqlite3.wasm')
/// - [dbName]: Name for the IndexedDB database used for persistence
///   (default: 'strata_sqlite')
///
/// Example:
/// ```dart
/// await initializeWebSqlite(
///   wasmUri: Uri.parse('assets/sqlite3.wasm'),
///   dbName: 'my_app_db',
/// );
/// ```
Future<void> initializeWebSqlite({
  Uri? wasmUri,
  String dbName = 'strata_sqlite',
}) async {
  if (_initialized) return;

  _wasmSqlite = await WasmSqlite3.loadFromUrl(
    wasmUri ?? Uri.parse('sqlite3.wasm'),
  );

  _defaultFileSystem = await IndexedDbFileSystem.open(dbName: dbName);
  _wasmSqlite!.registerVirtualFileSystem(
    _defaultFileSystem!,
    makeDefault: true,
  );

  _initialized = true;
}

/// Opens a SQLite database at the given [path] using WebAssembly.
///
/// On web platforms, this uses a WebAssembly build of SQLite with
/// IndexedDB for persistence.
///
/// **Important**: You must call [initializeWebSqlite] before using this
/// function on the web.
///
/// The [path] is a virtual path within the IndexedDB-backed file system.
CommonDatabase openSqliteDatabase(String path) {
  if (!_initialized || _wasmSqlite == null) {
    throw StateError(
      'Web SQLite not initialized. Call initializeWebSqlite() first.',
    );
  }
  return _wasmSqlite!.open(path);
}

/// Opens an in-memory SQLite database using WebAssembly.
///
/// On web platforms, this uses a WebAssembly build of SQLite.
/// In-memory databases do not persist across page reloads.
///
/// **Important**: You must call [initializeWebSqlite] before using this
/// function on the web.
CommonDatabase openSqliteInMemory() {
  if (!_initialized || _wasmSqlite == null) {
    throw StateError(
      'Web SQLite not initialized. Call initializeWebSqlite() first.',
    );
  }
  return _wasmSqlite!.openInMemory();
}

/// Returns whether the web SQLite environment has been initialized.
bool get isWebSqliteInitialized => _initialized;
