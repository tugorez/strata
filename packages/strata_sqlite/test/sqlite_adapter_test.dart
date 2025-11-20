import 'package:test/test.dart';
import 'package:strata/strata.dart';
import 'package:strata_sqlite/strata_sqlite.dart';

import 'models/user.dart';

void main() {
  late SqliteAdapter adapter;
  late StrataRepo repo;

  setUp(() async {
    // Use in-memory database for tests
    adapter = SqliteAdapter(path: ':memory:');
    repo = StrataRepo(adapter: adapter);
    await repo.initialize();

    // Create the users table
    adapter.database.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL,
        age INTEGER NOT NULL
      )
    ''');
  });

  tearDown(() async {
    await repo.close();
  });

  group('SqliteAdapter CRUD Operations', () {
    test('insert creates a new record', () async {
      final data = {'name': 'Alice', 'email': 'alice@example.com', 'age': 30};

      final result = await adapter.insert('users', data);

      expect(result['name'], equals('Alice'));
      expect(result['email'], equals('alice@example.com'));
      expect(result['age'], equals(30));
      expect(result['id'], isNotNull);
    });

    test('getOne retrieves a single record', () async {
      // Insert test data
      await adapter.insert('users', {
        'name': 'Bob',
        'email': 'bob@example.com',
        'age': 25,
      });

      final query = UserQuery().whereName('Bob');
      final result = await adapter.getOne(query);

      expect(result, isNotNull);
      expect(result!['name'], equals('Bob'));
      expect(result['age'], equals(25));
    });

    test('getOne returns null when no match', () async {
      final query = UserQuery().whereName('NonExistent');
      final result = await adapter.getOne(query);

      expect(result, isNull);
    });

    test('getAll retrieves multiple records', () async {
      // Insert test data
      await adapter.insert('users', {
        'name': 'Alice',
        'email': 'alice@example.com',
        'age': 30,
      });
      await adapter.insert('users', {
        'name': 'Bob',
        'email': 'bob@example.com',
        'age': 25,
      });
      await adapter.insert('users', {
        'name': 'Charlie',
        'email': 'charlie@example.com',
        'age': 35,
      });

      final query = UserQuery();
      final results = await adapter.getAll(query);

      expect(results.length, equals(3));
      expect(
        results.map((r) => r['name']),
        containsAll(['Alice', 'Bob', 'Charlie']),
      );
    });

    test('getAll with WHERE clause filters results', () async {
      // Insert test data
      await adapter.insert('users', {
        'name': 'Alice',
        'email': 'alice@example.com',
        'age': 30,
      });
      await adapter.insert('users', {
        'name': 'Bob',
        'email': 'bob@example.com',
        'age': 25,
      });
      await adapter.insert('users', {
        'name': 'Charlie',
        'email': 'charlie@example.com',
        'age': 35,
      });

      final query = UserQuery().whereAgeGreaterThan(30);
      final results = await adapter.getAll(query);

      expect(results.length, equals(1));
      expect(results.first['name'], equals('Charlie'));
    });

    test('getAll with ORDER BY sorts results', () async {
      // Insert test data in random order
      await adapter.insert('users', {
        'name': 'Charlie',
        'email': 'charlie@example.com',
        'age': 35,
      });
      await adapter.insert('users', {
        'name': 'Alice',
        'email': 'alice@example.com',
        'age': 30,
      });
      await adapter.insert('users', {
        'name': 'Bob',
        'email': 'bob@example.com',
        'age': 25,
      });

      final query = UserQuery();
      // TODO: Add orderBy support to immutable queries
      // For now, we can't directly manipulate orderByClauses
      query.orderByClauses.add(OrderByClause('name', ascending: true));
      final results = await adapter.getAll(query);

      expect(results[0]['name'], equals('Alice'));
      expect(results[1]['name'], equals('Bob'));
      expect(results[2]['name'], equals('Charlie'));
    });

    test('update modifies matching records', () async {
      // Insert test data
      await adapter.insert('users', {
        'name': 'Alice',
        'email': 'alice@example.com',
        'age': 30,
      });

      final query = UserQuery().whereName('Alice');
      final changes = {'age': 31};
      final updated = await adapter.update(query, changes);

      expect(updated.length, equals(1));
      expect(updated.first['name'], equals('Alice'));
      expect(updated.first['age'], equals(31));
    });

    test('update affects multiple records', () async {
      // Insert test data with same age
      await adapter.insert('users', {
        'name': 'Alice',
        'email': 'alice@example.com',
        'age': 30,
      });
      await adapter.insert('users', {
        'name': 'Bob',
        'email': 'bob@example.com',
        'age': 30,
      });

      final query = UserQuery().whereAge(30);
      final changes = {'age': 31};
      final updated = await adapter.update(query, changes);

      expect(updated.length, equals(2));
      expect(updated.every((u) => u['age'] == 31), isTrue);
    });

    test('delete removes matching records', () async {
      // Insert test data
      await adapter.insert('users', {
        'name': 'Alice',
        'email': 'alice@example.com',
        'age': 30,
      });
      await adapter.insert('users', {
        'name': 'Bob',
        'email': 'bob@example.com',
        'age': 25,
      });

      final query = UserQuery().whereName('Alice');
      final count = await adapter.delete(query);

      expect(count, equals(1));

      // Verify deletion
      final remaining = await adapter.getAll(UserQuery());
      expect(remaining.length, equals(1));
      expect(remaining.first['name'], equals('Bob'));
    });

    test('delete with no WHERE clause removes all records', () async {
      // Insert test data
      await adapter.insert('users', {
        'name': 'Alice',
        'email': 'alice@example.com',
        'age': 30,
      });
      await adapter.insert('users', {
        'name': 'Bob',
        'email': 'bob@example.com',
        'age': 25,
      });

      final query = UserQuery();
      final count = await adapter.delete(query);

      expect(count, equals(2));

      // Verify all deleted
      final remaining = await adapter.getAll(UserQuery());
      expect(remaining.length, equals(0));
    });
  });

  group('SqliteAdapter with StrataRepo', () {
    test('repo.get uses adapter correctly', () async {
      await adapter.insert('users', {
        'name': 'Alice',
        'email': 'alice@example.com',
        'age': 30,
      });

      final query = UserQuery().whereName('Alice');
      final user = await repo.get(query);

      expect(user, isNotNull);
      expect(user!.name, equals('Alice'));
      expect(user.age, equals(30));
    });

    test('repo.getAll uses adapter correctly', () async {
      await adapter.insert('users', {
        'name': 'Alice',
        'email': 'alice@example.com',
        'age': 30,
      });
      await adapter.insert('users', {
        'name': 'Bob',
        'email': 'bob@example.com',
        'age': 25,
      });

      final query = UserQuery();
      final users = await repo.getAll(query);

      expect(users.length, equals(2));
      expect(users.map((u) => u.name), containsAll(['Alice', 'Bob']));
    });

    test('repo.insert uses adapter correctly', () async {
      final changeset =
          UserChangeset({
              'name': 'Alice',
              'email': 'alice@example.com',
              'age': 30,
            })
            ..validateRequired('name')
            ..validateRequired('email')
            ..validateRequired('age');

      final user = await repo.insert(changeset);

      expect(user.name, equals('Alice'));
      expect(user.age, equals(30));
      expect(user.id, isNotNull);
    });

    test('repo.update uses adapter correctly', () async {
      // Insert initial data
      await adapter.insert('users', {
        'name': 'Alice',
        'email': 'alice@example.com',
        'age': 30,
      });

      final query = UserQuery().whereName('Alice');
      final changeset = UserChangeset({'age': 31})..validateRequired('age');

      final users = await repo.update(query, changeset);

      expect(users.length, equals(1));
      expect(users.first.age, equals(31));
    });

    test('repo.delete uses adapter correctly', () async {
      // Insert test data
      await adapter.insert('users', {
        'name': 'Alice',
        'email': 'alice@example.com',
        'age': 30,
      });

      final query = UserQuery().whereName('Alice');
      final count = await repo.delete(query);

      expect(count, equals(1));

      // Verify deletion
      final user = await repo.get(query);
      expect(user, isNull);
    });
  });

  group('SqliteAdapter Transaction Operations', () {
    test('commit persists changes', () async {
      // Insert a record
      await adapter.insert('users', {
        'name': 'TransactionUser',
        'email': 'tx@example.com',
        'age': 25,
      });

      // Start transaction and update
      await adapter.beginTransaction();

      final query = UserQuery().whereId(1);
      await adapter.update(query, {'name': 'UpdatedUser'});

      await adapter.commit();

      // Verify the change persists
      final result = await adapter.getOne(UserQuery().whereId(1));
      expect(result?['name'], 'UpdatedUser');
    });

    test('rollback reverts changes', () async {
      // Insert a record
      await adapter.insert('users', {
        'name': 'RollbackUser',
        'email': 'rollback@example.com',
        'age': 30,
      });

      // Start transaction and update
      await adapter.beginTransaction();

      final query = UserQuery().whereId(1);
      await adapter.update(query, {'name': 'ShouldBeReverted'});

      await adapter.rollback();

      // Verify the change was reverted
      final result = await adapter.getOne(UserQuery().whereId(1));
      expect(result?['name'], 'RollbackUser');
    });

    test('rollback reverts inserts', () async {
      // Start transaction and insert
      await adapter.beginTransaction();
      await adapter.insert('users', {
        'name': 'ShouldNotExist',
        'email': 'ghost@example.com',
        'age': 99,
      });
      await adapter.rollback();

      // Verify the insert was reverted
      final results = await adapter.getAll(UserQuery());
      expect(results, isEmpty);
    });

    test('rollback reverts deletes', () async {
      // Insert a record outside transaction
      await adapter.insert('users', {
        'name': 'KeepMe',
        'email': 'keep@example.com',
        'age': 40,
      });

      // Start transaction and delete
      await adapter.beginTransaction();
      final query = UserQuery().whereId(1);
      await adapter.delete(query);
      await adapter.rollback();

      // Verify the delete was reverted
      final results = await adapter.getAll(UserQuery());
      expect(results.length, 1);
      expect(results.first['name'], 'KeepMe');
    });

    test('repo.transaction commits on success', () async {
      // Insert a record
      final changeset = UserChangeset({
        'name': 'TxRepoUser',
        'email': 'txrepo@example.com',
        'age': 35,
      })..cast(['name', 'email', 'age']);
      await repo.insert(changeset);

      // Update within transaction
      await repo.transaction(() async {
        final query = UserQuery().whereId(1);
        final updateChangeset = UserChangeset({'name': 'TxRepoUpdated'})
          ..cast(['name']);
        await repo.update(query, updateChangeset);
      });

      // Verify the change was committed
      final result = await repo.get(UserQuery().whereId(1));
      expect(result?.name, 'TxRepoUpdated');
    });

    test('repo.transaction rolls back on error', () async {
      // Insert a record
      final changeset = UserChangeset({
        'name': 'TxRollbackUser',
        'email': 'txrollback@example.com',
        'age': 45,
      })..cast(['name', 'email', 'age']);
      await repo.insert(changeset);

      // Try to update within transaction that throws
      try {
        await repo.transaction(() async {
          final query = UserQuery().whereId(1);
          final updateChangeset = UserChangeset({'name': 'ShouldRevert'})
            ..cast(['name']);
          await repo.update(query, updateChangeset);

          throw Exception('Force rollback');
        });
      } catch (e) {
        // Expected
      }

      // Verify the change was rolled back
      final result = await repo.get(UserQuery().whereId(1));
      expect(result?.name, 'TxRollbackUser');
    });
  });
}
