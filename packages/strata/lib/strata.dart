/// Strata - An Ecto-inspired data mapping and changeset validation library for Dart.
///
/// This library provides a database-agnostic approach to data persistence,
/// inspired by Elixir's Ecto. It offers:
///
/// - **Type-safe queries**: Generated query builders with compile-time safety
/// - **Changeset validation**: Validate and transform data before persistence
/// - **Adapter pattern**: Pluggable database backends (SQLite, PostgreSQL, etc.)
/// - **Code generation**: Automatic generation of boilerplate code
///
/// ## Usage
///
/// ```dart
/// import 'package:strata/strata.dart';
///
/// @StrataSchema(table: 'users')
/// class User with Schema {
///   final int id;
///   final String username;
///
///   User({required this.id, required this.username});
/// }
/// ```
///
/// See the README for more detailed examples and documentation.
library;

// Public API
export 'src/strata_repo.dart';

// Abstractions (needed by users and adapters)
export 'src/annotations.dart';
export 'src/strata_adapter.dart';
export 'src/schema.dart';
export 'src/query.dart';
export 'src/query_parts.dart';
export 'src/changeset.dart';
export 'src/migration.dart';

// Utilities (needed by users)
export 'src/exceptions.dart';
