# strata_in_memory

An in-memory adapter for the [strata](https://pub.dev/packages/strata) data mapping library, perfect for testing and prototyping.

## Why Use This?

When testing your application that uses Strata, you don't want to set up a real database. This adapter:

- ✅ **No database setup required** - Works entirely in memory
- ✅ **Fast** - No I/O overhead
- ✅ **Isolated** - Each test gets a clean state
- ✅ **Complete** - Implements the full `StrataAdapter` contract
- ✅ **Simple** - Drop-in replacement for testing

## Installation

Add to your `pubspec.yaml`:

```yaml
dev_dependencies:
  strata_in_memory: ^0.1.0
  test: ^1.25.0
```

## Usage

### Basic Testing Setup

```dart
import 'package:strata/strata.dart';
import 'package:strata_in_memory/strata_in_memory.dart';
import 'package:test/test.dart';

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

  test('can insert and retrieve users', () async {
    final changeset = UserChangeset({'username': 'alice', 'email': 'alice@example.com'})
      ..validateRequired('username')
      ..validateRequired('email');

    final user = await repo.insert(changeset);
    expect(user.username, 'alice');

    final query = UserQuery().whereUsername('alice');
    final found = await repo.get(query);
    expect(found, isNotNull);
    expect(found!.email, 'alice@example.com');
  });

  test('can update users', () async {
    // Insert a user
    final insertChangeset = UserChangeset({'username': 'bob', 'email': 'bob@example.com'})
      ..validateRequired('username')
      ..validateRequired('email');
    final user = await repo.insert(insertChangeset);

    // Update the email
    final query = UserQuery().whereId(user.id);
    final updateChangeset = UserChangeset({'email': 'newemail@example.com'})
      ..validateRequired('email');
    
    final updated = await repo.update(query, updateChangeset);
    expect(updated.first.email, 'newemail@example.com');
  });

  test('can delete users', () async {
    // Insert a user
    final changeset = UserChangeset({'username': 'charlie', 'email': 'charlie@example.com'})
      ..validateRequired('username')
      ..validateRequired('email');
    final user = await repo.insert(changeset);

    // Delete the user
    final query = UserQuery().whereId(user.id);
    final deletedCount = await repo.delete(query);
    expect(deletedCount, 1);

    // Verify it's gone
    final found = await repo.get(query);
    expect(found, isNull);
  });
}
```

### Simple Testing (No Migrations Needed)

The InMemoryAdapter is designed for testing and doesn't require migrations for most use cases. Simply initialize and start testing:

```dart
import 'package:strata/strata.dart';
import 'package:strata_in_memory/strata_in_memory.dart';
import 'package:test/test.dart';

void main() {
  late StrataRepo repo;

  setUp(() async {
    final adapter = InMemoryAdapter();
    repo = StrataRepo(adapter: adapter);
    await repo.initialize();
  });

  test('can use any table without migrations', () async {
    // Tables are created automatically as you insert data
    final changeset = UserChangeset({'username': 'alice'})
      ..validateRequired('username');
    
    final user = await repo.insert(changeset);
    expect(user.username, 'alice');
  });
}
```

## Features

### Supported Operations

- ✅ **CRUD Operations**: insert, get, getAll, update, delete
- ✅ **Transactions**: beginTransaction, commit, rollback
- ✅ **Query Operators**: `=`, `!=`, `>`, `>=`, `<`, `<=`, `IN`, `NOT IN`, `LIKE`
- ✅ **LIMIT**: Query result limiting
- ✅ **Auto-increment IDs**: Simulates database ID generation

### Transaction Support

The InMemoryAdapter fully supports transactions with snapshot-based rollback:

```dart
test('transaction rollback reverts changes', () async {
  // Insert a user
  final changeset = UserChangeset({'username': 'alice'})
    ..validateRequired('username');
  final user = await repo.insert(changeset);

  // Start a transaction that will fail
  try {
    await repo.transaction(() async {
      // Update the user
      final query = UserQuery().whereId(user.id);
      final updateChangeset = UserChangeset({'username': 'bob'})
        ..cast(['username']);
      await repo.update(query, updateChangeset);

      // Throw an error
      throw Exception('Something went wrong');
    });
  } catch (e) {
    // Expected
  }

  // The update was rolled back
  final found = await repo.get(UserQuery().whereId(user.id));
  expect(found?.username, 'alice');  // Still alice, not bob
});
```

## Comparison with Real Adapters

| Feature | InMemoryAdapter | SqliteAdapter | PostgresAdapter |
|---------|----------------|---------------|-----------------|
| Setup Required | ❌ No | ✅ Yes | ✅ Yes |
| Speed | ⚡ Fastest | 🚀 Fast | 🐢 Slower |
| Persistence | ❌ No | ✅ Yes | ✅ Yes |
| Transactions | ✅ Yes | ✅ Yes | ✅ Yes |
| Use Case | Testing | Development/Production | Production |

## When NOT to Use

- **Integration tests** - Use a real database adapter
- **Production code** - Use SqliteAdapter, PostgresAdapter, etc.
- **Data persistence** - All data is lost when the process ends

## Architecture

```
┌─────────────────┐
│   Your Tests    │
├─────────────────┤
│  StrataRepo     │  ← Same API as production
├─────────────────┤
│ InMemoryAdapter │  ← This package
├─────────────────┤
│   Map/List      │  ← Simple Dart data structures
└─────────────────┘
```

## Contributing

Contributions are welcome! This package is part of the Strata monorepo. Please submit issues and pull requests to the [main repository](https://github.com/tugorez/strata).

## License

See the LICENSE file in the main repository.
