import 'package:strata/strata.dart';

/// Represents a SQL migration parsed from a `.sql` file.
///
/// This class implements [Migration] to provide a consistent interface for
/// all migrations in Strata, following Ecto's migration design pattern.
///
/// Instances are typically created by the `strata_builder` code generator
/// when it scans the `migrations/` directory for `.sql` files.
///
/// The [up] method executes the SQL statements against the database.
/// The [down] method is not implemented by default for file-based migrations,
/// but can be added by creating separate rollback SQL files if needed.
///
/// ## Example
///
/// ```dart
/// final migration = SqlMigration(
///   version: 1,
///   name: 'create_users_table',
///   statements: [
///     'CREATE TABLE users (id INTEGER PRIMARY KEY, username TEXT NOT NULL)',
///     'CREATE INDEX idx_users_username ON users(username)',
///   ],
/// );
///
/// // Execute the migration
/// await migration.up(executeFunction);
/// ```
class SqlMigration implements Migration<SqlExecutor> {
  @override
  final int version;

  /// The descriptive name of this migration.
  ///
  /// Typically derived from the migration filename, e.g.,
  /// `20241115100000_create_users_table.sql` → `create_users_table`.
  final String name;

  /// The list of SQL statements to execute when applying the migration (up).
  ///
  /// Each statement should be a complete, valid SQL command.
  /// Statements are executed in order during [up].
  final List<String> upStatements;

  /// The optional list of SQL statements to execute when rolling back (down).
  ///
  /// If not provided, [down] will throw an [UnimplementedError].
  /// Each statement should be a complete, valid SQL command.
  final List<String>? downStatements;

  /// Creates a SQL migration with the given version, name, and statements.
  ///
  /// - [upStatements]: Required SQL statements for the migration
  /// - [downStatements]: Optional SQL statements for rollback
  const SqlMigration({
    required this.version,
    required this.name,
    required this.upStatements,
    this.downStatements,
  });

  /// Executes the migration by running all SQL statements in order.
  ///
  /// The [executor] function should execute a SQL statement and return results.
  /// For example, in SQLite: `(sql, args) => db.rawQuery(sql, args ?? [])`
  @override
  Future<void> up(SqlExecutor executor) async {
    for (final statement in upStatements) {
      await executor(statement, null);
    }
  }

  /// Rolls back the migration by running all down SQL statements.
  ///
  /// If no down statements were provided, this method does nothing.
  /// Like Ecto, down migrations are optional - migrations without down logic
  /// are considered irreversible.
  ///
  /// To support rollback, include a `-- @Down()` section in your migration file.
  @override
  Future<void> down(SqlExecutor executor) async {
    // Like Ecto, down statements are optional
    // If not provided, the migration is simply irreversible
    if (downStatements == null || downStatements!.isEmpty) {
      return;
    }

    for (final statement in downStatements!) {
      await executor(statement, null);
    }
  }

  @override
  String toString() => 'SqlMigration(version: $version, name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SqlMigration &&
          runtimeType == other.runtimeType &&
          version == other.version &&
          name == other.name;

  @override
  int get hashCode => version.hashCode ^ name.hashCode;
}

/// A function type for executing SQL statements.
///
/// Takes a SQL string and optional list of arguments, and returns
/// a future that completes with the query results.
///
/// Example:
/// ```dart
/// SqlExecutor executor = (sql, args) async {
///   return await db.rawQuery(sql, args ?? []);
/// };
/// ```
typedef SqlExecutor =
    Future<List<Map<String, dynamic>>> Function(
      String sql,
      List<Object?>? arguments,
    );
