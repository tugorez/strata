import 'package:test/test.dart';
import 'package:strata/strata.dart';
import 'package:strata_in_memory/strata_in_memory.dart';

import '../testing/models/account.dart';

void main() {
  late StrataRepo repo;
  late InMemoryAdapter adapter;

  setUp(() async {
    adapter = InMemoryAdapter();
    repo = StrataRepo(adapter: adapter);
    await repo.initialize();
  });

  tearDown(() async {
    await repo.close();
  });

  group('Direct Adapter Transaction Tests', () {
    test('adapter commit persists changes', () async {
      // Insert a record via adapter directly
      await adapter.insert('accounts', {'username': 'test'});

      // Start transaction and update via adapter
      await adapter.beginTransaction();

      final query = AccountQuery().whereId(1);
      await adapter.update(query, {'username': 'test_updated'});

      await adapter.commit();

      // Verify the change persists
      final results = await adapter.getAll(AccountQuery());
      expect(results.first['username'], 'test_updated');
    });

    test('repo update via manual transaction', () async {
      // Insert via repo
      final changeset = AccountChangeset({'username': 'manual'})
        ..validateRequired('username');
      final account = await repo.insert<Account>(changeset);

      // Manual transaction via adapter
      await adapter.beginTransaction();

      final query = AccountQuery().whereId(account.id);
      final updateChangeset = AccountChangeset({'username': 'manual_updated'})
        ..cast(['username']); // Need to cast the fields!
      await repo.update<Account>(query, updateChangeset);

      await adapter.commit();

      // Verify the change persists
      final result = await repo.get<Account>(
        AccountQuery().whereId(account.id),
      );
      expect(result?.username, 'manual_updated');
    });
  });
  group('Transaction Tests', () {
    test('commit successful transaction', () async {
      // Insert initial account
      final changeset = AccountChangeset({'username': 'alice'})
        ..validateRequired('username');
      final account = await repo.insert<Account>(changeset);

      // Update account within transaction
      await repo.transaction(() async {
        final query = AccountQuery().whereId(account.id);
        final updateChangeset = AccountChangeset({'username': 'alice_updated'})
          ..cast(['username']);
        await repo.update<Account>(query, updateChangeset);
      });

      // Verify the change was committed
      final query = AccountQuery().whereId(account.id);
      final updated = await repo.get<Account>(query);
      expect(updated?.username, 'alice_updated');
    });

    test('rollback on error', () async {
      // Insert initial account
      final changeset = AccountChangeset({'username': 'bob'})
        ..validateRequired('username');
      final account = await repo.insert<Account>(changeset);

      // Try to update within transaction that throws
      try {
        await repo.transaction(() async {
          final query = AccountQuery().whereId(account.id);
          final updateChangeset = AccountChangeset({'username': 'bob_updated'})
            ..cast(['username']);
          await repo.update<Account>(query, updateChangeset);

          // Throw an error to trigger rollback
          throw Exception('Something went wrong');
        });
      } catch (e) {
        // Expected
      }

      // Verify the change was rolled back
      final query = AccountQuery().whereId(account.id);
      final notUpdated = await repo.get<Account>(query);
      expect(notUpdated?.username, 'bob'); // Should still be original value
    });

    test('rollback on validation error', () async {
      // Insert initial account
      final changeset = AccountChangeset({'username': 'charlie'})
        ..validateRequired('username');
      final account = await repo.insert<Account>(changeset);

      // Try transaction with invalid changeset
      try {
        await repo.transaction(() async {
          final query = AccountQuery().whereId(account.id);
          final updateChangeset = AccountChangeset({
            'username': 'charlie_updated',
          })..cast(['username']);
          await repo.update<Account>(query, updateChangeset);

          // Try to insert invalid record
          final invalidChangeset = AccountChangeset({});
          invalidChangeset.validateRequired('username');
          await repo.insert<Account>(invalidChangeset); // Should throw
        });
      } catch (e) {
        // Expected ChangesetException
      }

      // Verify both changes were rolled back
      final query = AccountQuery().whereId(account.id);
      final notUpdated = await repo.get<Account>(query);
      expect(notUpdated?.username, 'charlie');

      // Verify no invalid account was inserted
      final allQuery = AccountQuery();
      final allAccounts = await repo.getAll<Account>(allQuery);
      expect(allAccounts.length, 1); // Only the original account
    });

    test('multiple inserts in transaction - all or nothing', () async {
      // Try to insert multiple accounts in transaction
      try {
        await repo.transaction(() async {
          // Insert first account
          final changeset1 = AccountChangeset({'username': 'dave'})
            ..validateRequired('username');
          await repo.insert<Account>(changeset1);

          // Insert second account
          final changeset2 = AccountChangeset({'username': 'eve'})
            ..validateRequired('username');
          await repo.insert<Account>(changeset2);

          // Throw error before commit
          throw Exception('Transaction failed');
        });
      } catch (e) {
        // Expected
      }

      // Verify no accounts were inserted
      final allQuery = AccountQuery();
      final allAccounts = await repo.getAll<Account>(allQuery);
      expect(allAccounts.length, 0);
    });

    test('successful multi-account transaction', () async {
      // Insert multiple accounts atomically
      await repo.transaction(() async {
        final changeset1 = AccountChangeset({'username': 'frank'})
          ..validateRequired('username');
        await repo.insert<Account>(changeset1);

        final changeset2 = AccountChangeset({'username': 'grace'})
          ..validateRequired('username');
        await repo.insert<Account>(changeset2);
      });

      // Verify both accounts were inserted
      final allQuery = AccountQuery();
      final allAccounts = await repo.getAll<Account>(allQuery);
      expect(allAccounts.length, 2);
      expect(
        allAccounts.map((a) => a.username),
        containsAll(['frank', 'grace']),
      );
    });

    test('nested operations in transaction', () async {
      // Insert and update in single transaction
      late Account account;

      await repo.transaction(() async {
        // Insert new account
        final insertChangeset = AccountChangeset({'username': 'henry'})
          ..validateRequired('username');
        account = await repo.insert<Account>(insertChangeset);

        // Immediately update it
        final query = AccountQuery().whereId(account.id);
        final updateChangeset = AccountChangeset({'username': 'henry_modified'})
          ..cast(['username']);
        await repo.update<Account>(query, updateChangeset);
      });

      // Verify final state
      final query = AccountQuery().whereId(account.id);
      final result = await repo.get<Account>(query);
      expect(result?.username, 'henry_modified');
    });

    test('transaction returns value', () async {
      final accountId = await repo.transaction(() async {
        final changeset = AccountChangeset({'username': 'iris'})
          ..validateRequired('username');
        final account = await repo.insert<Account>(changeset);
        return account.id;
      });

      expect(accountId, isA<int>());

      // Verify account was actually inserted
      final query = AccountQuery().whereId(accountId);
      final account = await repo.get<Account>(query);
      expect(account?.username, 'iris');
    });

    test('delete in transaction can be rolled back', () async {
      // Insert account
      final changeset = AccountChangeset({'username': 'jack'})
        ..validateRequired('username');
      final account = await repo.insert<Account>(changeset);

      // Try to delete in transaction that fails
      try {
        await repo.transaction(() async {
          final query = AccountQuery().whereId(account.id);
          await repo.delete<Account>(query);

          throw Exception('Oops');
        });
      } catch (e) {
        // Expected
      }

      // Verify account still exists
      final query = AccountQuery().whereId(account.id);
      final stillExists = await repo.get<Account>(query);
      expect(stillExists?.username, 'jack');
    });
  });
}
