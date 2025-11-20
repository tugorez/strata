import 'package:strata/strata.dart';
import 'package:strata_in_memory/strata_in_memory.dart';
import 'package:test/test.dart';

import '../testing/models/account.dart';

void main() {
  late StrataRepo repo;

  setUp(() async {
    final adapter = InMemoryAdapter();
    repo = StrataRepo(adapter: adapter);
    await repo.initialize();
  });

  tearDown(() async {
    await repo.close();
  });

  test('repo.insert() with valid changeset returns a new Account', () async {
    final params = {'username': 'testuser'};
    final changeset = AccountChangeset(params)..validateRequired('username');

    final account = await repo.insert<Account>(changeset);

    expect(account, isA<Account>());
    expect(account.id, 1);
    expect(account.username, 'testuser');
  });

  test(
    'repo.insert() with invalid changeset throws ChangesetException',
    () async {
      final changeset = AccountChangeset({'username': ''})
        ..validateRequired('username');

      expect(
        () => repo.insert<Account>(changeset),
        throwsA(isA<ChangesetException>()),
      );

      expect(await repo.getAll(AccountQuery()), isEmpty);
    },
  );

  test('repo.get() returns a record that was inserted', () async {
    final changeset = AccountChangeset({'username': 'getme'})
      ..validateRequired('username');
    final insertedAccount = await repo.insert<Account>(changeset);
    final query = AccountQuery().whereId(insertedAccount.id);
    final foundAccount = await repo.get(query);

    expect(foundAccount, isNotNull);
    expect(foundAccount!.id, insertedAccount.id);
    expect(foundAccount.username, 'getme');
  });

  test('repo.get() returns null when no record is found', () async {
    final query = AccountQuery().whereId(999);
    final foundAccount = await repo.get(query);

    expect(foundAccount, isNull);
  });

  test('repo.update() updates matching records and returns them', () async {
    // Insert two accounts
    final changeset1 = AccountChangeset({'username': 'user1'})
      ..validateRequired('username');
    final account1 = await repo.insert<Account>(changeset1);

    final changeset2 = AccountChangeset({'username': 'user2'})
      ..validateRequired('username');
    await repo.insert<Account>(changeset2);

    // Update only account1
    final query = AccountQuery().whereId(account1.id);
    final updateChangeset = AccountChangeset({'username': 'updated_user1'})
      ..validateRequired('username');

    final updatedAccounts = await repo.update(query, updateChangeset);

    expect(updatedAccounts.length, 1);
    expect(updatedAccounts.first.id, account1.id);
    expect(updatedAccounts.first.username, 'updated_user1');

    // Verify the change persisted
    final fetched = await repo.get(AccountQuery().whereId(account1.id));
    expect(fetched!.username, 'updated_user1');
  });

  test('repo.update() returns empty list when no records match', () async {
    final query = AccountQuery().whereId(999);
    final updateChangeset = AccountChangeset({'username': 'doesnotmatter'})
      ..validateRequired('username');

    final updated = await repo.update(query, updateChangeset);

    expect(updated, isEmpty);
  });

  test(
    'repo.update() throws ChangesetException when changeset is invalid',
    () async {
      final changeset1 = AccountChangeset({'username': 'user1'})
        ..validateRequired('username');
      final account = await repo.insert<Account>(changeset1);

      final query = AccountQuery().whereId(account.id);
      final invalidChangeset = AccountChangeset({'username': ''})
        ..validateRequired('username');

      expect(
        () => repo.update(query, invalidChangeset),
        throwsA(isA<ChangesetException>()),
      );
    },
  );

  test('repo.delete() deletes matching records and returns count', () async {
    // Insert three accounts
    final changeset1 = AccountChangeset({'username': 'user1'})
      ..validateRequired('username');
    final account1 = await repo.insert<Account>(changeset1);

    final changeset2 = AccountChangeset({'username': 'user2'})
      ..validateRequired('username');
    await repo.insert<Account>(changeset2);

    final changeset3 = AccountChangeset({'username': 'user3'})
      ..validateRequired('username');
    await repo.insert<Account>(changeset3);

    // Delete only account1
    final query = AccountQuery().whereId(account1.id);
    final deletedCount = await repo.delete(query);

    expect(deletedCount, 1);

    // Verify it's gone
    final fetched = await repo.get(AccountQuery().whereId(account1.id));
    expect(fetched, isNull);

    // Verify others still exist
    final remaining = await repo.getAll(AccountQuery());
    expect(remaining.length, 2);
  });

  test('repo.delete() returns 0 when no records match', () async {
    final query = AccountQuery().whereId(999);
    final deletedCount = await repo.delete(query);

    expect(deletedCount, 0);
  });

  test('repo.delete() can delete multiple records', () async {
    // Insert multiple accounts with same username
    for (var i = 0; i < 3; i++) {
      final changeset = AccountChangeset({'username': 'duplicate'})
        ..validateRequired('username');
      await repo.insert<Account>(changeset);
    }

    // Delete all with that username
    final query = AccountQuery().whereUsername('duplicate');
    final deletedCount = await repo.delete(query);

    expect(deletedCount, 3);
    expect(await repo.getAll(AccountQuery()), isEmpty);
  });
}
