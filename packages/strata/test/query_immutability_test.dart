import 'package:test/test.dart';
import 'package:strata/strata.dart';
import 'package:strata_in_memory/strata_in_memory.dart';

import '../testing/models/account.dart';

void main() {
  late StrataRepo repo;

  setUp(() async {
    final adapter = InMemoryAdapter();
    repo = StrataRepo(adapter: adapter);
    await repo.initialize();

    // Insert test data
    await repo.insert(
      AccountChangeset({'username': 'alice', 'id': 1})
        ..validateRequired('username'),
    );
    await repo.insert(
      AccountChangeset({'username': 'bob', 'id': 2})
        ..validateRequired('username'),
    );
    await repo.insert(
      AccountChangeset({'username': 'charlie', 'id': 3})
        ..validateRequired('username'),
    );
  });

  tearDown(() async {
    await repo.close();
  });

  group('Query Immutability', () {
    test('base query is not modified when building a new query', () async {
      final baseQuery = AccountQuery();
      final query1 = baseQuery.whereId(1);
      final query2 = baseQuery.whereId(2);

      // baseQuery should have no where clauses
      expect(baseQuery.whereClauses.length, equals(0));

      // query1 should have 1 where clause
      expect(query1.whereClauses.length, equals(1));
      expect(query1.whereClauses[0].field, equals('id'));
      expect(query1.whereClauses[0].value, equals(1));

      // query2 should have 1 where clause (not 2!)
      expect(query2.whereClauses.length, equals(1));
      expect(query2.whereClauses[0].field, equals('id'));
      expect(query2.whereClauses[0].value, equals(2));

      // Verify actual results
      final results1 = await repo.getAll(query1);
      expect(results1.length, equals(1));
      expect(results1[0].id, equals(1));

      final results2 = await repo.getAll(query2);
      expect(results2.length, equals(1));
      expect(results2[0].id, equals(2));
    });

    test('queries can be composed without side effects', () async {
      final activeQuery = AccountQuery().whereIdGreaterThan(1);

      // Branch from activeQuery without modifying it
      final query1 = activeQuery.whereUsername('bob');
      final query2 = activeQuery.whereUsername('charlie');

      // activeQuery should only have 1 where clause
      expect(activeQuery.whereClauses.length, equals(1));

      // query1 should have 2 where clauses
      expect(query1.whereClauses.length, equals(2));

      // query2 should have 2 where clauses (not 3!)
      expect(query2.whereClauses.length, equals(2));

      // Verify results
      final results1 = await repo.getAll(query1);
      expect(results1.length, equals(1));
      expect(results1[0].username, equals('bob'));

      final results2 = await repo.getAll(query2);
      expect(results2.length, equals(1));
      expect(results2[0].username, equals('charlie'));
    });

    test('chained query methods create new instances', () async {
      final query1 = AccountQuery();
      final query2 = query1.whereId(1);
      final query3 = query2.whereUsername('alice');

      // Each should be a different instance
      expect(identical(query1, query2), isFalse);
      expect(identical(query2, query3), isFalse);
      expect(identical(query1, query3), isFalse);

      // Each should have different number of where clauses
      expect(query1.whereClauses.length, equals(0));
      expect(query2.whereClauses.length, equals(1));
      expect(query3.whereClauses.length, equals(2));
    });

    test('queries with the same conditions are equal', () async {
      final activeQuery = AccountQuery().whereId(1);
      final query1 = activeQuery.whereUsername('alice');
      final query2 = activeQuery.whereUsername('alice');

      // Different instances but equal
      expect(identical(query1, query2), isFalse);
      expect(query1, equals(query2));
      expect(query1.hashCode, equals(query2.hashCode));
    });

    test('queries with different conditions are not equal', () async {
      final query1 = AccountQuery().whereId(1).whereUsername('alice');
      final query2 = AccountQuery().whereId(1).whereUsername('bob');
      final query3 = AccountQuery().whereId(2).whereUsername('alice');

      expect(query1, isNot(equals(query2)));
      expect(query1, isNot(equals(query3)));
      expect(query2, isNot(equals(query3)));
    });

    test('queries with different order of conditions are not equal', () async {
      final query1 = AccountQuery().whereId(1).whereUsername('alice');
      final query2 = AccountQuery().whereUsername('alice').whereId(1);

      // Order matters for equality
      expect(query1, isNot(equals(query2)));
    });
  });
}
