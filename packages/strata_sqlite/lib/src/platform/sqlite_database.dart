/// Conditional export for platform-specific SQLite database implementation.
///
/// This file uses conditional imports to provide the correct SQLite
/// implementation based on the platform:
/// - Native (FFI) on iOS, Android, macOS, Windows, Linux
/// - WebAssembly on web browsers
export 'sqlite_database_stub.dart'
    if (dart.library.io) 'sqlite_database_io.dart'
    if (dart.library.js_interop) 'sqlite_database_web.dart';
