/// Defines the structure for a database migration.
///
/// Migrations are used to evolve the database schema over time in a structured
/// and versioned manner. Each migration has a unique, increasing [version]
/// number, an [up] method to apply the changes, and a [down] method to revert them.
///
/// The generic type [T] represents the database connection object provided by
/// the specific adapter (e.g., `sqflite.Database`). This allows migration
/// logic to be adapter-specific while the overall migration process remains
/// uniform.
///
/// ## Usage
///
/// Implement this class for programmatic migrations:
///
/// ```dart
/// class CreateUsersTable extends Migration<Database> {
///   @override
///   int get version => 1;
///
///   @override
///   Future<void> up(Database db) async {
///     await db.execute('CREATE TABLE users (id INTEGER PRIMARY KEY)');
///   }
///
///   @override
///   Future<void> down(Database db) async {
///     await db.execute('DROP TABLE users');
///   }
/// }
/// ```
///
/// For file-based migrations (e.g., SQL files), use adapter-specific classes
/// like `SqlMigration` in `strata_sqlite`.
abstract class Migration<T> {
  /// A unique, increasing version number for this migration.
  ///
  /// This is used to determine which migrations need to be run.
  int get version;

  /// The logic to apply the migration and move the schema forward.
  Future<void> up(T db);

  /// The logic to revert the migration and move the schema backward.
  Future<void> down(T db);
}
