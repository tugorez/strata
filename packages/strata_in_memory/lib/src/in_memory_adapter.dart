import 'package:strata/strata.dart';

/// An in-memory implementation of [StrataAdapter] for testing and prototyping.
///
/// This adapter stores all data in memory using simple `Map` and `List` structures.
/// It's perfect for unit testing because:
/// - No database setup required
/// - Fast and isolated
/// - Automatically cleaned up between tests
/// - Implements the full `StrataAdapter` contract
///
/// ## Example Usage
///
/// ```dart
/// void main() {
///   late StrataRepo repo;
///
///   setUp(() async {
///     final adapter = InMemoryAdapter();
///     repo = StrataRepo(adapter: adapter);
///     await repo.initialize();
///   });
///
///   tearDown(() async {
///     await repo.close();
///   });
///
///   test('can insert and query data', () async {
///     final changeset = UserChangeset({'username': 'alice'})
///       ..validateRequired('username');
///
///     final user = await repo.insert(changeset);
///     expect(user.username, 'alice');
///
///     final query = UserQuery()..whereUsername('alice');
///     final found = await repo.get(query);
///     expect(found, isNotNull);
///   });
/// }
/// ```
class InMemoryAdapter implements StrataAdapter {
  /// A simple in-memory "database" represented as a map where keys are table names
  /// and values are lists of row maps.
  final Map<String, List<Map<String, dynamic>>> _memoryDB = {};

  /// A simple in-memory sequence generator for auto-incrementing IDs.
  ///
  /// Keys are table names and values are the last assigned ID for that table.
  /// This simulates primary key generation.
  final Map<String, int> _sequences = {};

  /// A snapshot of the database state taken at the start of a transaction.
  ///
  /// When a transaction is rolled back, the database is restored to this snapshot.
  /// This is `null` when there is no active transaction.
  Map<String, List<Map<String, dynamic>>>? _transactionSnapshot;

  /// A snapshot of the sequence state taken at the start of a transaction.
  Map<String, int>? _sequenceSnapshot;

  bool _isOpen = false;

  @override
  Future<void> initialize() async {
    _memoryDB.clear();
    _sequences.clear();
    _isOpen = true;
  }

  @override
  Future<void> close() async {
    _isOpen = false;
  }

  @override
  Future<Map<String, dynamic>> insert(
    String table,
    Map<String, dynamic> changes,
  ) async {
    if (!_isOpen) throw Exception('Adapter is closed');

    // Ensure table exists
    _memoryDB.putIfAbsent(table, () => []);

    // Simulate auto-incrementing ID
    final id = (_sequences[table] ?? 0) + 1;
    _sequences[table] = id;

    // Create the persisted record
    // Assumes all tables have an 'id' field
    final Map<String, dynamic> newRecord = {...changes, 'id': id};

    // Save it to the in-memory database
    final tableDB = _memoryDB[table]!;
    tableDB.add(newRecord);

    return newRecord;
  }

  @override
  Future<Map<String, dynamic>?> getOne(Query query) async {
    final results = await getAll(query);
    return results.isEmpty ? null : results.first;
  }

  @override
  Future<List<Map<String, dynamic>>> getAll(Query query) async {
    if (!_isOpen) throw Exception('Adapter is closed');

    final table = _memoryDB[query.table] ?? [];
    if (table.isEmpty) return [];

    // Simple query engine that evaluates WHERE clauses
    var results = table.where((row) => _matchesQuery(row, query)).toList();

    // Apply LIMIT if specified
    if (query.limitCount != null) {
      results = results.take(query.limitCount!).toList();
    }

    return results;
  }

  @override
  Future<List<Map<String, dynamic>>> update(
    Query query,
    Map<String, dynamic> changes,
  ) async {
    if (!_isOpen) throw Exception('Adapter is closed');

    final table = _memoryDB[query.table] ?? [];
    if (table.isEmpty) return [];

    final updated = <Map<String, dynamic>>[];

    // Find all records matching the query and update them
    for (var i = 0; i < table.length; i++) {
      final row = table[i];

      // Check if this row matches the query
      if (_matchesQuery(row, query)) {
        // Create updated record by merging changes
        final updatedRecord = {...row, ...changes};
        table[i] = updatedRecord;
        updated.add(updatedRecord);
      }
    }

    return updated;
  }

  @override
  Future<int> delete(Query query) async {
    if (!_isOpen) throw Exception('Adapter is closed');

    final table = _memoryDB[query.table];
    if (table == null || table.isEmpty) return 0;

    var deletedCount = 0;

    // Remove records matching the query (iterate backwards to safely remove)
    for (var i = table.length - 1; i >= 0; i--) {
      final row = table[i];

      // Check if this row matches the query using helper
      if (_matchesQuery(row, query)) {
        table.removeAt(i);
        deletedCount++;
      }
    }

    return deletedCount;
  }

  /// Checks if a row matches the WHERE clauses in a query.
  bool _matchesQuery(Map<String, dynamic> row, Query query) {
    // Apply WHERE clauses
    for (final clause in query.whereClauses) {
      if (!row.containsKey(clause.field)) return false;

      final fieldValue = row[clause.field];
      final clauseValue = clause.value;

      // Evaluate operator
      switch (clause.operator) {
        case '=':
          if (fieldValue != clauseValue) return false;
          break;
        case '!=':
          if (fieldValue == clauseValue) return false;
          break;
        case '>':
          if (!(fieldValue is num && clauseValue is num)) return false;
          if (!(fieldValue > clauseValue)) return false;
          break;
        case '>=':
          if (!(fieldValue is num && clauseValue is num)) return false;
          if (!(fieldValue >= clauseValue)) return false;
          break;
        case '<':
          if (!(fieldValue is num && clauseValue is num)) return false;
          if (!(fieldValue < clauseValue)) return false;
          break;
        case '<=':
          if (!(fieldValue is num && clauseValue is num)) return false;
          if (!(fieldValue <= clauseValue)) return false;
          break;
        case 'IN':
          if (clauseValue is! List) return false;
          if (!clauseValue.contains(fieldValue)) return false;
          break;
        case 'NOT IN':
          if (clauseValue is! List) return false;
          if (clauseValue.contains(fieldValue)) return false;
          break;
        case 'LIKE':
          if (!(fieldValue is String && clauseValue is String)) return false;
          // Simple LIKE implementation: convert SQL LIKE pattern to RegExp
          // % matches any sequence, _ matches any single character
          // First, escape the pattern, then replace the escaped wildcards
          var pattern = clauseValue;
          // Escape special regex characters except % and _
          pattern = pattern.replaceAllMapped(
            RegExp(r'[.^$*+?{}[\]\\|()]'),
            (m) => '\\${m[0]}',
          );
          // Now convert SQL wildcards to regex
          pattern = pattern.replaceAll('%', '.*').replaceAll('_', '.');
          if (!RegExp('^$pattern\$').hasMatch(fieldValue)) return false;
          break;
        default:
          throw UnsupportedError('Operator ${clause.operator} not supported');
      }
    }
    return true;
  }

  @override
  Future<void> beginTransaction() async {
    if (!_isOpen) throw Exception('Adapter is closed');
    if (_transactionSnapshot != null) {
      throw StateError('Transaction already in progress');
    }

    // Create deep copies of the database and sequences
    _transactionSnapshot = {};
    for (final entry in _memoryDB.entries) {
      _transactionSnapshot![entry.key] = entry.value
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    }

    _sequenceSnapshot = Map<String, int>.from(_sequences);
  }

  @override
  Future<void> commit() async {
    if (!_isOpen) throw Exception('Adapter is closed');
    if (_transactionSnapshot == null) {
      throw StateError('No transaction in progress');
    }

    // Clear snapshots - changes are already in _memoryDB
    _transactionSnapshot = null;
    _sequenceSnapshot = null;
  }

  @override
  Future<void> rollback() async {
    if (!_isOpen) throw Exception('Adapter is closed');
    if (_transactionSnapshot == null) {
      throw StateError('No transaction in progress');
    }

    // Restore database and sequences from snapshots
    _memoryDB.clear();
    _memoryDB.addAll(_transactionSnapshot!);

    _sequences.clear();
    _sequences.addAll(_sequenceSnapshot!);

    // Clear snapshots
    _transactionSnapshot = null;
    _sequenceSnapshot = null;
  }
}
