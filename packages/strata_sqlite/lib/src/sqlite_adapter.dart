import 'package:sqlite3/common.dart';
import 'package:strata/strata.dart';
import 'platform/sqlite_database.dart';
import 'sql_migration.dart';

/// A SQLite implementation of the [StrataAdapter] contract.
///
/// This adapter provides the database-specific implementation for all CRUD
/// operations, connection management, and migration support when using SQLite
/// as the backend for Strata.
///
/// This adapter works on both native platforms (iOS, Android, macOS, Windows,
/// Linux) and web browsers through conditional imports.
///
/// ## Usage
///
/// ### Native platforms
/// ```dart
/// final adapter = SqliteAdapter(path: 'app.db');
/// final repo = StrataRepo(adapter: adapter);
/// await repo.initialize();
/// ```
///
/// ### Web platforms
/// Before creating a SqliteAdapter on the web, you must initialize the
/// WebAssembly SQLite environment:
///
/// ```dart
/// // In your web app initialization
/// await initializeWebSqlite(
///   wasmUri: Uri.parse('sqlite3.wasm'),
///   dbName: 'my_app',
/// );
///
/// // Then use SqliteAdapter normally
/// final adapter = SqliteAdapter(path: '/my_database.db');
/// ```
class SqliteAdapter implements StrataAdapter {
  final String path;
  CommonDatabase? _db;

  /// Creates a new SQLite adapter.
  ///
  /// - [path]: The file path to the SQLite database, or ':memory:' for in-memory
  SqliteAdapter({required this.path});

  /// Returns the underlying SQLite database connection.
  ///
  /// Throws if [initialize] has not been called.
  CommonDatabase get database {
    if (_db == null) {
      throw StateError(
        'SqliteAdapter not initialized. Call initialize() first.',
      );
    }
    return _db!;
  }

  /// Returns a [SqlExecutor] function for running migrations.
  ///
  /// This getter provides the idiomatic way to connect [SqlMigrationRunner]
  /// to this adapter. The returned function executes SQL statements against
  /// the adapter's database connection.
  ///
  /// ## Usage
  ///
  /// ```dart
  /// final adapter = SqliteAdapter(path: 'app.db');
  /// await adapter.initialize();
  ///
  /// final runner = SqlMigrationRunner(execute: adapter.executor);
  /// await runner.run(Migrations.all);
  /// ```
  SqlExecutor get executor => (sql, args) async {
    // For DDL statements (CREATE, DROP, ALTER, etc.), use execute
    // For SELECT and PRAGMA statements, use select to return rows
    final upperSql = sql.trimLeft().toUpperCase();
    if (upperSql.startsWith('SELECT') || upperSql.startsWith('PRAGMA')) {
      return database.select(sql, args ?? []);
    } else {
      database.execute(sql, args ?? []);
      return [];
    }
  };

  @override
  Future<void> initialize() async {
    if (_db != null) return;
    if (path == ':memory:') {
      _db = openSqliteInMemory();
    } else {
      _db = openSqliteDatabase(path);
    }
  }

  @override
  Future<void> close() async {
    _db?.close();
    _db = null;
  }

  @override
  Future<Map<String, dynamic>?> getOne(Query query) async {
    final sql = _buildSelectQuery(query, limit: 1);
    final params = _extractWhereParams(query);

    final result = database.select(sql, params);

    if (result.isEmpty) return null;
    return result.first;
  }

  @override
  Future<List<Map<String, dynamic>>> getAll(Query query) async {
    final sql = _buildSelectQuery(query);
    final params = _extractWhereParams(query);

    final result = database.select(sql, params);

    return result.toList();
  }

  @override
  Future<Map<String, dynamic>> insert(
    String table,
    Map<String, dynamic> changes,
  ) async {
    final fields = changes.keys.toList();
    final values = changes.values.toList();

    final placeholders = List.filled(fields.length, '?').join(', ');
    final fieldsList = fields.join(', ');

    final sql = 'INSERT INTO $table ($fieldsList) VALUES ($placeholders)';

    database.execute(sql, values);

    // Get the last inserted row ID and return the full record
    final lastId = database.lastInsertRowId;
    final selectSql = 'SELECT * FROM $table WHERE rowid = ?';
    final result = database.select(selectSql, [lastId]);

    return result.first;
  }

  @override
  Future<List<Map<String, dynamic>>> update(
    Query query,
    Map<String, dynamic> changes,
  ) async {
    final table = query.table;
    final fields = changes.keys.toList();
    final values = changes.values.toList();

    // Build WHERE clause
    final whereClause = _buildWhereClause(query);
    final whereParams = _extractWhereParams(query);

    // First, get the rowids of records that match the WHERE clause
    // This is necessary because after UPDATE, the WHERE clause might no longer match
    // Note: We use 'rowid AS _rowid' to explicitly get the rowid value
    final selectRowidsSql = 'SELECT rowid AS _rowid FROM $table$whereClause';
    final rowidsResult = database.select(selectRowidsSql, whereParams);
    final rowids = rowidsResult.map((row) => row['_rowid']).toList();

    if (rowids.isEmpty) return [];

    // Build SET clause
    final setClause = fields.map((field) => '$field = ?').join(', ');

    // Combine all parameters: SET values + WHERE values
    final allParams = [...values, ...whereParams];

    // Perform the UPDATE
    final updateSql = 'UPDATE $table SET $setClause$whereClause';
    database.execute(updateSql, allParams);

    // Return the updated records by querying with the saved rowids
    final rowidPlaceholders = List.filled(rowids.length, '?').join(', ');
    final selectUpdatedSql =
        'SELECT * FROM $table WHERE rowid IN ($rowidPlaceholders)';
    final result = database.select(selectUpdatedSql, rowids);

    return result.toList();
  }

  @override
  Future<int> delete(Query query) async {
    final table = query.table;
    final whereClause = _buildWhereClause(query);
    final whereParams = _extractWhereParams(query);

    final sql = 'DELETE FROM $table$whereClause';

    database.execute(sql, whereParams);

    // SQLite's changes() function returns the number of affected rows
    final result = database.select('SELECT changes() as count');
    return result.first['count'] as int;
  }

  @override
  Future<void> beginTransaction() async {
    database.execute('BEGIN TRANSACTION');
  }

  @override
  Future<void> commit() async {
    database.execute('COMMIT');
  }

  @override
  Future<void> rollback() async {
    database.execute('ROLLBACK');
  }

  /// Builds a SELECT query from a [Query] object.
  String _buildSelectQuery(Query query, {int? limit}) {
    final table = query.table;
    final whereClause = _buildWhereClause(query);
    final orderByClause = _buildOrderByClause(query);

    var sql = 'SELECT * FROM $table$whereClause$orderByClause';

    if (limit != null) {
      sql += ' LIMIT $limit';
    }

    return sql;
  }

  /// Builds a WHERE clause from the query's conditions.
  String _buildWhereClause(Query query) {
    if (query.whereClauses.isEmpty) return '';

    final conditions = query.whereClauses
        .map((clause) {
          final operator = _sqlOperator(clause.operator);

          // Handle IN and NOT IN operators which accept lists
          if (operator == 'IN' || operator == 'NOT IN') {
            final list = clause.value as List;
            if (list.isEmpty) {
              // Empty list in IN clause should match nothing
              // Empty list in NOT IN clause should match everything
              return operator == 'IN' ? '1 = 0' : '1 = 1';
            }
            final placeholders = List.filled(list.length, '?').join(', ');
            return '${clause.field} $operator ($placeholders)';
          }

          return '${clause.field} $operator ?';
        })
        .join(' AND ');

    return ' WHERE $conditions';
  }

  /// Builds an ORDER BY clause from the query's ordering.
  String _buildOrderByClause(Query query) {
    if (query.orderByClauses.isEmpty) return '';

    final orderings = query.orderByClauses
        .map((clause) {
          final direction = clause.ascending ? 'ASC' : 'DESC';
          return '${clause.field} $direction';
        })
        .join(', ');

    return ' ORDER BY $orderings';
  }

  /// Extracts parameter values from WHERE clauses in order.
  List<Object?> _extractWhereParams(Query query) {
    final params = <Object?>[];

    for (final clause in query.whereClauses) {
      final operator = _sqlOperator(clause.operator);

      // Handle IN and NOT IN operators which accept lists
      if (operator == 'IN' || operator == 'NOT IN') {
        final list = clause.value as List;
        if (list.isNotEmpty) {
          params.addAll(list); // Expand the list into individual parameters
        }
      } else {
        params.add(clause.value);
      }
    }

    return params;
  }

  /// Converts a query operator to SQL operator.
  String _sqlOperator(String operator) {
    switch (operator) {
      case '=':
        return '=';
      case '!=':
        return '!=';
      case '>':
        return '>';
      case '>=':
        return '>=';
      case '<':
        return '<';
      case '<=':
        return '<=';
      case 'IN':
        return 'IN';
      case 'NOT IN':
        return 'NOT IN';
      case 'LIKE':
        return 'LIKE';
      default:
        throw ArgumentError('Unsupported operator: $operator');
    }
  }
}
