import 'sql_migration.dart';

/// A utility class for running SQL migrations in SQLite databases.
///
/// This class handles the execution of SQL migrations, including:
/// - Creating a migrations tracking table
/// - Determining which migrations need to be run
/// - Executing migrations in order
/// - Recording which migrations have been applied
///
/// This is specific to SQL-based databases. For other database types,
/// implement a similar runner in the appropriate adapter package.
class SqlMigrationRunner {
  /// Executes a raw SQL statement.
  ///
  /// This function should execute SQL directly against your database.
  /// For SQLite, this would typically be `db.rawQuery()` or similar.
  final SqlExecutor _execute;

  final String _migrationsTable;

  /// Creates a new SQL migration runner.
  ///
  /// - [execute]: A function that executes SQL statements against the database
  /// - [migrationsTable]: The name of the table to track applied migrations (default: 'schema_migrations')
  ///
  /// Example usage:
  /// ```dart
  /// final runner = SqlMigrationRunner(
  ///   execute: (sql, args) async {
  ///     return await db.rawQuery(sql, args ?? []);
  ///   },
  /// );
  /// ```
  SqlMigrationRunner({
    required SqlExecutor execute,
    String migrationsTable = 'schema_migrations',
  }) : _execute = execute,
       _migrationsTable = migrationsTable;

  /// Runs all pending SQL migrations.
  ///
  /// This method will:
  /// 1. Create the migrations tracking table if it doesn't exist
  /// 2. Get the current version from the tracking table
  /// 3. Filter and sort migrations with versions greater than the current version
  /// 4. Run each pending migration in version order
  /// 5. Record each migration in the tracking table after execution
  ///
  /// Migrations are always executed in ascending version order, regardless of
  /// the order they appear in the provided list.
  ///
  /// - [migrations]: The list of SQL migrations to run
  Future<void> run(List<SqlMigration> migrations) async {
    // 1. Create migrations table if it doesn't exist
    await _createMigrationsTable();

    // 2. Get current version
    final currentVersion = await _getCurrentVersion();

    // 3. Filter and sort pending migrations by version
    final pending = migrations.where((m) => m.version > currentVersion).toList()
      ..sort((a, b) => a.version.compareTo(b.version));

    if (pending.isEmpty) {
      return;
    }

    // 4. Run each pending migration in order
    for (final migration in pending) {
      await _runMigration(migration);
    }
  }

  /// Creates the migrations tracking table if it doesn't exist.
  Future<void> _createMigrationsTable() async {
    final sql =
        '''
      CREATE TABLE IF NOT EXISTS $_migrationsTable (
        version INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        applied_at INTEGER NOT NULL
      )
    ''';

    await _execute(sql, null);
  }

  /// Gets the current migration version from the tracking table.
  ///
  /// Returns 0 if no migrations have been run yet.
  Future<int> _getCurrentVersion() async {
    final result = await _execute(
      'SELECT MAX(version) as max_version FROM $_migrationsTable',
      null,
    );

    if (result.isEmpty) {
      return 0;
    }

    final maxVersion = result.first['max_version'];
    return maxVersion != null ? maxVersion as int : 0;
  }

  /// Runs a single migration and records it in the tracking table.
  Future<void> _runMigration(SqlMigration migration) async {
    // Execute the migration using its up() method
    await migration.up(_execute);

    // Record the migration
    final now = DateTime.now().millisecondsSinceEpoch;
    await _execute(
      'INSERT INTO $_migrationsTable (version, name, applied_at) VALUES (?, ?, ?)',
      [migration.version, migration.name, now],
    );
  }
}
