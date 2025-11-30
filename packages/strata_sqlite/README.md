# strata_sqlite

The official SQLite adapter for the [strata](https://github.com/tugorez/strata) data mapping library.

This package provides the concrete implementation of the `StrataAdapter` contract, allowing your `StrataRepo` to use SQLite as its database backend.

## Features

* Full implementation of the `StrataAdapter` contract for CRUD operations
* Database connection and lifecycle management
* Built-in migration runner for versioning your database schema
* Type-safe query translation from Strata Query objects to SQL
* Support for `WHERE`, `ORDER BY`, and `LIMIT` clauses

## Installation

Add `strata`, `strata_sqlite`, and `sqlite3` to your `pubspec.yaml`:

```yaml
dependencies:
  strata: ^0.1.0
  strata_sqlite: ^0.1.0
  sqlite3: ^2.9.0

dev_dependencies:
  build_runner: ^2.4.13
  strata_builder: ^0.1.0
```

## Quick Start

### 1. Define Your Schema

```dart
// lib/models/account.dart
import 'package:strata/strata.dart';

part 'account.g.dart';

@StrataSchema(table: 'accounts')
class Account with Schema {
  final int id;
  final String username;
  final String email;

  Account({
    required this.id,
    required this.username,
    required this.email,
  });
}
```

### 2. Generate Helper Code

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 3. Create Migrations

Create SQL migration files using the CLI tool:

```bash
dart run strata_builder:create_migration create_accounts_table
```

This creates `migrations/20241115100000_create_accounts_table.sql`:

```sql
-- @Up()
CREATE TABLE accounts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT NOT NULL UNIQUE,
  email TEXT NOT NULL
);

-- @Down()
DROP TABLE IF EXISTS accounts;
```

Then generate the Dart code:

```bash
dart run build_runner build
```

### 4. Initialize and Use

```dart
import 'package:strata/strata.dart';
import 'package:strata_sqlite/strata_sqlite.dart';
import 'models/account.dart';
import 'migrations.dart'; // Generated from SQL files (committed)

void main() async {
  // Initialize the adapter and repository
  final adapter = SqliteAdapter(path: 'my_app.db');
  final repo = StrataRepo(adapter: adapter);
  
  await repo.initialize();
  
  // Run migrations using SqlMigrationRunner
  final runner = SqlMigrationRunner(execute: adapter.executor);
  await runner.run(Migrations.all);
  
  // Create and validate data with changesets
  final changeset = AccountChangeset({
    'username': 'alice',
    'email': 'alice@example.com',
  })
    ..validateRequired('username')
    ..validateRequired('email')
    ..validateLength('username', min: 3, max: 20);
  
  if (changeset.isValid) {
    final account = await repo.insert(changeset);
    print('Created account: $account');
  } else {
    print('Validation errors: ${changeset.errors}');
  }
  
  // Query with type-safe builders
  final query = AccountQuery()
    ..whereUsername('alice');
  
  final account = await repo.get(query);
  print('Found account: $account');
  
  // Get all accounts
  final allAccounts = await repo.getAll(AccountQuery());
  print('All accounts: ${allAccounts.length}');
  
  await repo.close();
}
```

## Usage Guide

### Database Connection

The `SqliteAdapter` manages the SQLite database connection:

```dart
// In-memory database (for testing)
final adapter = SqliteAdapter(path: ':memory:');

// File-based database
final adapter = SqliteAdapter(path: 'app.db');

// Full path
final adapter = SqliteAdapter(path: '/path/to/database.db');
```

### SQL Migrations

The recommended approach is to use SQL migration files with the code generator (Ecto-style).

#### Creating SQL Migrations

```bash
dart run strata_builder:create_migration add_age_to_accounts
```

This creates `migrations/20241115110000_add_age_to_accounts.sql`:

```sql
-- @Up()
ALTER TABLE accounts ADD COLUMN age INTEGER;

-- @Down()
-- SQLite doesn't support DROP COLUMN easily
-- This migration is irreversible (no down statements)
```

#### Migration Features

- **Timestamp-based versions** (YYYYMMDDHHmmss) prevent merge conflicts
- **Optional rollback** with `@Down()` sections (Ecto-style)
- **Protobuf-style generation**: SQL files → CLI → committed Dart file
- **Version tracking** in `schema_migrations` table

#### Running SQL Migrations

```dart
import 'migrations.dart';  // Generated from SQL files, committed to source control

// Create adapter and initialize
final adapter = SqliteAdapter(path: 'app.db');
await adapter.initialize();

// Create migration runner using the adapter's executor
final runner = SqlMigrationRunner(execute: adapter.executor);

// Run all pending migrations
await runner.run(Migrations.all);
```

The runner:
- Creates a `schema_migrations` table to track applied migrations
- Only runs migrations with versions greater than the current version
- Executes migrations in ascending version order
- Records each migration after successful execution

#### Rollback Support

To rollback a migration:

```dart
final migration = Migrations.all.last;

// Only works if migration has @Down() section
await migration.down(executor);
```

Migrations without `@Down()` sections are irreversible (like Ecto).

#### Alternative: Programmatic Migrations

You can also create migrations programmatically by implementing `Migration<T>`:

```dart
import 'package:strata/strata.dart';
import 'package:strata_sqlite/strata_sqlite.dart';

class AddAgeToAccounts implements Migration<SqlExecutor> {
  @override
  int get version => 20241115110000;

  @override
  Future<void> up(SqlExecutor executor) async {
    await executor('ALTER TABLE accounts ADD COLUMN age INTEGER', null);
  }

  @override
  Future<void> down(SqlExecutor executor) async {
    // Not supported by SQLite - irreversible
  }
}
```

However, SQL files with code generation are the recommended approach.

### CRUD Operations

#### Insert

```dart
final changeset = AccountChangeset(params)
  ..validateRequired('username')
  ..validateRequired('email');

if (changeset.isValid) {
  final account = await repo.insert(changeset);
}
```

#### Query

```dart
// Get one record
final account = await repo.get(
  AccountQuery().whereId(1)
);

// Get all matching records
final accounts = await repo.getAll(
  AccountQuery().whereUsername('alice')
);

// Get all records
final allAccounts = await repo.getAll(AccountQuery());
```

#### Update

```dart
// Update a user's email
final query = AccountQuery().whereId(1);
final changeset = AccountChangeset({'email': 'newemail@example.com'})
  ..validateRequired('email')
  ..validateFormat('email', emailRegex);

if (changeset.isValid) {
  final updatedAccounts = await repo.update(query, changeset);
  print('Updated ${updatedAccounts.length} accounts');
}
```

#### Delete

```dart
// Delete a specific account
final query = AccountQuery().whereId(1);
final deletedCount = await repo.delete(query);
print('Deleted $deletedCount accounts');
```

### Query Building

The generated query builders support fluent API chaining:

```dart
final query = AccountQuery()
  .whereUsername('alice')
  .whereAge(25);
  
// The adapter translates this to SQL:
// SELECT * FROM accounts WHERE username = ? AND age = ?
```

### Timestamp Fields

For high-precision timestamps, use `@Timestamp` on `DateTime` fields. The generator creates two database columns (`_seconds` and `_nanos`) and DateTime-specific query methods:

```dart
// Schema definition
@StrataSchema(table: 'events')
class Event with Schema {
  final int id;
  final String name;
  
  @Timestamp()
  final DateTime occurredAt;

  Event({required this.id, required this.name, required this.occurredAt});
}

// Migration
// CREATE TABLE events (
//   id INTEGER PRIMARY KEY AUTOINCREMENT,
//   name TEXT NOT NULL,
//   occurred_at_seconds INTEGER NOT NULL,
//   occurred_at_nanos INTEGER NOT NULL
// );

// Query with DateTime-specific methods
final recentEvents = await repo.getAll(
  EventQuery()
      .whereOccurredAtAfter(DateTime.now().subtract(Duration(hours: 24)))
      .orderByOccurredAt(ascending: false)
);
```

#### Optional Timestamp Fields

The generator supports optional `DateTime?` fields with `@Timestamp`, useful for nullable date fields:

```dart
@StrataSchema(table: 'subscriptions')
class Subscription with Schema {
  final int id;
  
  @Timestamp()
  final DateTime startDate;    // Required
  
  @Timestamp()
  final DateTime? endDate;     // Optional - null for ongoing subscriptions

  Subscription({required this.id, required this.startDate, this.endDate});
}

// Migration - allow NULL for optional timestamp columns
// CREATE TABLE subscriptions (
//   id INTEGER PRIMARY KEY AUTOINCREMENT,
//   start_date_seconds INTEGER NOT NULL,
//   start_date_nanos INTEGER NOT NULL,
//   end_date_seconds INTEGER,      -- NULL allowed
//   end_date_nanos INTEGER         -- NULL allowed
// );
```

The generated code correctly handles null values when reading from the database and when inserting via changesets.

## Production Ready

✅ **Fully Implemented**: This adapter is production-ready with a complete, tested implementation of all core features.

### Features
- ✅ Full CRUD operations (Create, Read, Update, Delete)
- ✅ Database connection and lifecycle management
- ✅ Type-safe query translation from Query objects to SQL
- ✅ Support for WHERE clauses with multiple operators (`=`, `!=`, `<`, `>`, `<=`, `>=`, `IN`, `NOT IN`, `LIKE`)
- ✅ ORDER BY and LIMIT support
- ✅ **Transaction support** with automatic rollback
- ✅ SQL migration system with `SqlMigration` and `SqlMigrationRunner`
- ✅ Timestamp-based migration versioning (Ecto-style)
- ✅ Optional rollback support with `@Down()` sections
- ✅ Comprehensive test coverage

### Future Enhancements
- Association preloading
- Advanced query features (JOIN, GROUP BY, aggregates)
- Connection pooling
- Query result streaming

## Transactions

Wrap multiple operations in a transaction for atomic execution:

```dart
// Using repo.transaction() - recommended
await repo.transaction(() async {
  // All operations here are atomic
  final user = await repo.insert(userChangeset);
  
  final todoChangeset = TodoChangeset({
    'title': 'First todo',
    'user_id': user.id,
  })..cast(['title', 'user_id']);
  
  await repo.insert(todoChangeset);
});
// If any operation fails, all changes are rolled back
```

You can also use the adapter directly for lower-level control:

```dart
await adapter.beginTransaction();
try {
  await adapter.insert('users', userData);
  await adapter.insert('todos', todoData);
  await adapter.commit();
} catch (e) {
  await adapter.rollback();
  rethrow;
}
```

## Testing

For testing, use an in-memory database:

```dart
import 'package:test/test.dart';
import 'migrations.dart';  // Generated from SQL files

void main() {
  late StrataRepo repo;
  late SqlMigrationRunner runner;
  
  setUp(() async {
    final adapter = SqliteAdapter(path: ':memory:');
    repo = StrataRepo(adapter: adapter);
    await repo.initialize();
    
    // Run migrations using the adapter's executor
    runner = SqlMigrationRunner(execute: adapter.executor);
    await runner.run(Migrations.all);
  });
  
  tearDown(() async {
    await repo.close();
  });
  
  test('can insert and retrieve accounts', () async {
    final changeset = AccountChangeset({
      'username': 'test',
      'email': 'test@example.com',
    })..validateRequired('username')..validateRequired('email');
    
    final account = await repo.insert(changeset);
    expect(account.username, 'test');
    
    final found = await repo.get(AccountQuery().whereId(account.id));
    expect(found?.username, 'test');
  });
}
```

## Architecture

```
┌─────────────────┐
│   Your App      │
├─────────────────┤
│  StrataRepo     │  ← High-level API
├─────────────────┤
│ SqliteAdapter   │  ← This package
├─────────────────┤
│   sqlite3       │  ← Native SQLite
└─────────────────┘
```

The `SqliteAdapter` translates between Strata's database-agnostic API and SQLite-specific operations.

## Contributing

Contributions are welcome! This package is part of the Strata monorepo. Please submit issues and pull requests to the main repository.

## License

See the LICENSE file for details.