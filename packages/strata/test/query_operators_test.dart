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
      AccountChangeset({'username': 'alice'})..validateRequired('username'),
    );
    await repo.insert(
      AccountChangeset({'username': 'bob'})..validateRequired('username'),
    );
    await repo.insert(
      AccountChangeset({'username': 'charlie'})..validateRequired('username'),
    );
    await repo.insert(
      AccountChangeset({'username': 'admin'})..validateRequired('username'),
    );
  });

  tearDown(() async {
    await repo.close();
  });

  group('Query Operators', () {
    test('whereIdGreaterThan filters correctly', () async {
      final query = AccountQuery().whereIdGreaterThan(2);
      final accounts = await repo.getAll(query);

      expect(accounts.length, equals(2));
      expect(accounts.map((a) => a.id), containsAll([3, 4]));
    });

    test('whereIdLessThan filters correctly', () async {
      final query = AccountQuery().whereIdLessThan(3);
      final accounts = await repo.getAll(query);

      expect(accounts.length, equals(2));
      expect(accounts.map((a) => a.id), containsAll([1, 2]));
    });

    test('whereIdGreaterThanOrEq filters correctly', () async {
      final query = AccountQuery().whereIdGreaterThanOrEq(3);
      final accounts = await repo.getAll(query);

      expect(accounts.length, equals(2));
      expect(accounts.map((a) => a.id), containsAll([3, 4]));
    });

    test('whereIdLessThanOrEq filters correctly', () async {
      final query = AccountQuery().whereIdLessThanOrEq(2);
      final accounts = await repo.getAll(query);

      expect(accounts.length, equals(2));
      expect(accounts.map((a) => a.id), containsAll([1, 2]));
    });

    test('whereUsernameNotEq filters correctly', () async {
      final query = AccountQuery().whereUsernameNotEq('admin');
      final accounts = await repo.getAll(query);

      expect(accounts.length, equals(3));
      expect(
        accounts.map((a) => a.username),
        containsAll(['alice', 'bob', 'charlie']),
      );
    });

    test('whereIdIn filters with list', () async {
      final query = AccountQuery().whereIdIn([1, 3]);
      final accounts = await repo.getAll(query);

      expect(accounts.length, equals(2));
      expect(accounts.map((a) => a.id), containsAll([1, 3]));
      expect(
        accounts.map((a) => a.username),
        containsAll(['alice', 'charlie']),
      );
    });

    test('whereIdNotIn filters with list', () async {
      final query = AccountQuery().whereIdNotIn([1, 3]);
      final accounts = await repo.getAll(query);

      expect(accounts.length, equals(2));
      expect(accounts.map((a) => a.id), containsAll([2, 4]));
      expect(accounts.map((a) => a.username), containsAll(['bob', 'admin']));
    });

    test('whereUsernameIn filters with list', () async {
      final query = AccountQuery().whereUsernameIn(['alice', 'charlie']);
      final accounts = await repo.getAll(query);

      expect(accounts.length, equals(2));
      expect(
        accounts.map((a) => a.username),
        containsAll(['alice', 'charlie']),
      );
    });

    test('whereUsernameNotIn filters with list', () async {
      final query = AccountQuery().whereUsernameNotIn(['alice', 'charlie']);
      final accounts = await repo.getAll(query);

      expect(accounts.length, equals(2));
      expect(accounts.map((a) => a.username), containsAll(['bob', 'admin']));
    });

    test('whereUsernameLike filters with pattern', () async {
      final query = AccountQuery().whereUsernameLike('%li%');
      final accounts = await repo.getAll(query);

      expect(accounts.length, equals(2));
      expect(
        accounts.map((a) => a.username),
        containsAll(['alice', 'charlie']),
      );
    });

    test('whereUsernameLike with prefix pattern', () async {
      final query = AccountQuery().whereUsernameLike('a%');
      final accounts = await repo.getAll(query);

      expect(accounts.length, equals(2));
      expect(accounts.map((a) => a.username), containsAll(['alice', 'admin']));
    });

    test('multiple operators can be chained', () async {
      final query = AccountQuery().whereIdGreaterThan(1).whereIdLessThan(4);
      final accounts = await repo.getAll(query);

      expect(accounts.length, equals(2));
      expect(accounts.map((a) => a.id), containsAll([2, 3]));
    });

    test('IN with empty list returns no results', () async {
      final query = AccountQuery().whereIdIn([]);
      final accounts = await repo.getAll(query);

      expect(accounts.length, equals(0));
    });

    test('NOT IN with empty list returns all results', () async {
      final query = AccountQuery().whereIdNotIn([]);
      final accounts = await repo.getAll(query);

      expect(accounts.length, equals(4));
    });
  });
}
