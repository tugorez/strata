import 'package:strata/strata.dart';
import 'package:strata_in_memory/strata_in_memory.dart';
import 'package:test/test.dart';

/// Test-only schema class
class TestUser with Schema {
  final int id;
  final String username;

  TestUser({required this.id, required this.username});

  static TestUser fromMap(Map<String, dynamic> map) {
    return TestUser(id: map['id'] as int, username: map['username'] as String);
  }
}

/// Helper to create a simple query for tests
Query<TestUser> testUserQuery() => Query<TestUser>('users', TestUser.fromMap);

void main() {
  group('InMemoryAdapter', () {
    late InMemoryAdapter adapter;

    setUp(() async {
      adapter = InMemoryAdapter();
      await adapter.initialize();
    });

    tearDown(() async {
      await adapter.close();
    });

    test('initializes successfully and is open', () {
      // Verify adapter can perform operations after initialization
      expect(() => adapter.insert('test_table', {'id': 1}), returnsNormally);
    });

    test('exports InMemoryAdapter publicly', () {
      // This test ensures the export is working
      expect(InMemoryAdapter, isNotNull);
    });
  });

  group('InMemoryAdapter Transactions', () {
    late InMemoryAdapter adapter;

    setUp(() async {
      adapter = InMemoryAdapter();
      await adapter.initialize();
    });

    tearDown(() async {
      await adapter.close();
    });

    test('commit persists changes', () async {
      // Insert a record
      await adapter.insert('users', {'username': 'alice'});

      // Start transaction and update
      await adapter.beginTransaction();

      final query = testUserQuery();
      query.whereClauses.add(WhereClause('id', '=', 1));
      await adapter.update(query, {'username': 'alice_updated'});

      await adapter.commit();

      // Verify the change persists
      final results = await adapter.getAll(testUserQuery());
      expect(results.first['username'], 'alice_updated');
    });

    test('rollback reverts changes', () async {
      // Insert a record
      await adapter.insert('users', {'username': 'bob'});

      // Start transaction and update
      await adapter.beginTransaction();

      final query = testUserQuery();
      query.whereClauses.add(WhereClause('id', '=', 1));
      await adapter.update(query, {'username': 'bob_updated'});

      await adapter.rollback();

      // Verify the change was reverted
      final results = await adapter.getAll(testUserQuery());
      expect(results.first['username'], 'bob');
    });

    test('rollback reverts inserts', () async {
      // Start transaction and insert
      await adapter.beginTransaction();
      await adapter.insert('users', {'username': 'charlie'});
      await adapter.rollback();

      // Verify the insert was reverted
      final results = await adapter.getAll(testUserQuery());
      expect(results, isEmpty);
    });

    test('rollback reverts deletes', () async {
      // Insert a record outside transaction
      await adapter.insert('users', {'username': 'dave'});

      // Start transaction and delete
      await adapter.beginTransaction();
      final query = testUserQuery();
      query.whereClauses.add(WhereClause('id', '=', 1));
      await adapter.delete(query);
      await adapter.rollback();

      // Verify the delete was reverted
      final results = await adapter.getAll(testUserQuery());
      expect(results.length, 1);
      expect(results.first['username'], 'dave');
    });
  });
}
