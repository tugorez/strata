## Strata

An Ecto-inspired data mapping and changeset validation library for Dart.

`strata` provides a robust, type-safe, and extensible API for interacting with your database. It is inspired by the best patterns from Elixir's Ecto, focusing on explicit data validation through changesets and a composable query API.

## Features

*   **Ecto-style Changesets:** A powerful `Changeset` class for validating and casting untrusted data before it ever hits your database.
*   **Repo & Adapter Pattern:** The main `StrataRepo` class provides a single, clean API for all database operations. It delegates the database-specific work to a `StrataAdapter`, so your application logic remains decoupled.
*   **Codegen for Queries:** Define your data models using `@StrataSchema` annotations. A code generator creates type-safe `Query` and `Changeset` classes for you, eliminating "magic strings" and providing editor autocompletion.
*   **Transactions:** Wrap multiple operations in a transaction for atomic execution with automatic rollback on failure.
*   **Associations:** Define relationships between models using `@HasMany`, `@BelongsTo`, and `@HasOne` annotations.
*   **Timestamp Fields:** Use `@Timestamp` annotation on `DateTime` fields for high-precision storage using separate seconds and nanoseconds columns.
*   **Migration Support:** A database-agnostic `Migration<T>` interface that adapters implement for their specific migration needs. SQL-based adapters can use file-based migrations with code generation (Ecto-style).

## The Adapter Model

`strata` is a "bring-your-own-database" library. **This core package (strata) contains no database-specific code.**

It only defines the contracts (like `StrataAdapter`) and the core logic (like `Changeset` and `StrataRepo`).

To use `strata` with a real database, you must use a specific adapter package:

*   **strata_sqlite** - SQLite adapter (currently in development)
*   **strata_postgres** - PostgreSQL adapter (planned)
*   ...or create your own by implementing the `StrataAdapter` interface!

This model keeps the core library lightweight and allows you to swap out your data layer without rewriting your application logic.

## Getting Started

### 1. Add Dependencies

Add `strata`, the code generator, and a database adapter to your `pubspec.yaml`:

```yaml
name: my_app
description: A new Dart application.

environment:
  sdk: ^3.9.0

dependencies:
  strata: ^0.1.0
  strata_sqlite: ^0.1.0  # Or another adapter
  sqlite3: ^2.9.0        # Required for SQLite adapter

dev_dependencies:
  build_runner: ^2.4.13
  strata_builder: ^0.1.0
  lints: ^6.0.0
  test: ^1.25.0
```

### 2. Configure the Code Generator

Create a `build.yaml` file in your project root:

```yaml
targets:
  $default:
    builders:
      strata_builder|schemaBuilder:
        enabled: true
```

## Usage

### Define Your Schema

Create a file like `lib/models/account.dart`. Use the `@StrataSchema` annotation and `Schema` mixin to mark it for code generation:

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

  @override
  String toString() => 'Account(id: $id, username: $username, email: $email)';
}
```

### Generate Helper Code

Run the code generator to create query builders and changesets:

```bash
dart run build_runner build --delete-conflicting-outputs
```

This creates an `account.g.dart` file containing:
- `AccountQuery` - Type-safe query builder
- `AccountChangeset` - Validation helper
- `_fromMap()` - Deserialization function

### Use the Repository

```dart
import 'package:strata/strata.dart';
import 'package:strata_sqlite/strata_sqlite.dart';
import 'models/account.dart';

void main() async {
  // 1. Create an adapter and repository
  final adapter = SqliteAdapter(path: 'my_app.db');
  final repo = StrataRepo(adapter: adapter);
  
  await repo.initialize();
  
  // 2. Create a changeset with Ecto-style cast + validate
  final changeset = AccountChangeset({
    'username': 'john_doe',
    'email': 'john@example.com',
  })
    ..cast(['username', 'email'])           // Whitelist allowed fields
    ..validateRequired('username')          // Validate required fields
    ..validateRequired('email')
    ..validateLength('username', min: 3, max: 20);
  
  // 3. Insert if valid
  if (changeset.isValid) {
    final account = await repo.insert(changeset);
    print('Created: $account');
  } else {
    print('Validation errors: ${changeset.errors}');
  }
  
  // 4. Query with type-safe builders
  final query = AccountQuery()
    ..whereUsername('john_doe');
    
  final account = await repo.get(query);
  print('Found: $account');
  
  // 5. Get all matching records
  final allAccounts = await repo.getAll(AccountQuery());
  print('All accounts: $allAccounts');
  
  await repo.close();
}
```

## Core Concepts

### Schemas

A schema is a Dart class that represents a database table. It must:
- Have the `@StrataSchema` annotation with a table name
- Mix in the `Schema` mixin
- Declare a `part` file for generated code
- Use only named constructor parameters

### Changesets

Changesets validate and transform untrusted data before persistence. Following Ecto's philosophy, you **cast** (whitelist) fields first, then **validate** them:

#### Ecto-style (Recommended)

```dart
// Explicitly cast only the fields you want to allow
final changeset = UserChangeset(params)
  ..cast(['username', 'email', 'age'])        // Whitelist fields
  ..validateRequired('username')              // Validate required
  ..validateRequired('email')
  ..validateLength('username', min: 3, max: 20);

if (changeset.isValid) {
  final user = await repo.insert(changeset);
} else {
  print('Errors: ${changeset.errors}');
}
```

This two-step approach provides important security benefits:
1. **Explicit whitelisting**: Only fields you explicitly `cast` can enter your database
2. **Mass assignment protection**: Prevents attackers from injecting unexpected fields
3. **Clear intent**: Separates "what fields are allowed" from "what rules they follow"

#### Backward Compatible Style

For convenience, `validateRequired` will auto-cast fields if you don't call `cast` first:

```dart
final changeset = UserChangeset(params)
  ..validateRequired('username')
  ..validateLength('username', min: 3, max: 20)
  ..validateRequired('email');

if (changeset.isValid) {
  final user = await repo.insert(changeset);
}
```

### Queries

Generated query classes provide type-safe filtering:

```dart
final query = UserQuery()
  ..whereAge(25)
  ..whereUsername('alice');

final user = await repo.get(query);
```

#### Query Operators

The generated query classes support multiple comparison operators:

```dart
// Equality
final query = UserQuery().whereId(1);

// Not equal
final query = UserQuery().whereIdNotEq(1);

// Comparison operators
final query = UserQuery()
  .whereAgeGreaterThan(18)
  .whereAgeLessThanOrEq(65);

// IN and NOT IN
final query = UserQuery().whereIdIn([1, 2, 3]);
final query = UserQuery().whereStatusNotIn(['deleted', 'banned']);

// LIKE (for string fields)
final query = UserQuery().whereUsernameLike('%john%');
```

#### Ordering and Limits

```dart
// Order by a field
final query = UserQuery()
  .orderByCreatedAt(ascending: false)  // Newest first
  .limit(10);

final recentUsers = await repo.getAll(query);
```

### Transactions

Wrap multiple operations in a transaction for atomic execution. If any operation fails, all changes are rolled back:

```dart
// Transfer funds between accounts
await repo.transaction(() async {
  // Deduct from source
  final sourceQuery = AccountQuery().whereId(sourceId);
  final sourceUpdate = AccountChangeset({'balance': sourceBalance - amount})
    ..cast(['balance']);
  await repo.update(sourceQuery, sourceUpdate);

  // Add to destination
  final destQuery = AccountQuery().whereId(destId);
  final destUpdate = AccountChangeset({'balance': destBalance + amount})
    ..cast(['balance']);
  await repo.update(destQuery, destUpdate);
});
// Both updates succeed or both are rolled back
```

Transactions automatically:
- Begin when the callback starts
- Commit when the callback completes successfully
- Rollback when an error is thrown

```dart
// Transactions can return values
final newUserId = await repo.transaction(() async {
  final user = await repo.insert(userChangeset);
  await repo.insert(profileChangeset);
  return user.id;
});
```

### Associations

Define relationships between models using association annotations:

#### HasMany

A parent model that has many children:

```dart
@StrataSchema(table: 'users')
class User with Schema {
  final int id;
  final String name;
  
  @HasMany(Todo, foreignKey: 'user_id')
  final List<Todo>? todos;

  User({required this.id, required this.name, this.todos});
}
```

#### BelongsTo

A child model that belongs to a parent:

```dart
@StrataSchema(table: 'todos')
class Todo with Schema {
  final int id;
  final String title;
  final int userId;
  
  @BelongsTo(User, foreignKey: 'user_id')
  final User? user;

  Todo({required this.id, required this.title, required this.userId, this.user});
}
```

#### HasOne

A model that has exactly one related model:

```dart
@StrataSchema(table: 'users')
class User with Schema {
  final int id;
  final String name;
  
  @HasOne(Profile, foreignKey: 'user_id')
  final Profile? profile;

  User({required this.id, required this.name, this.profile});
}
```

#### Preloading Associations

The code generator creates preload methods for associations. Each association annotation generates a corresponding `preload*()` method:

```dart
// Preload a HasMany association
final userQuery = UserQuery().preloadTodos();
final user = await repo.get(userQuery);
print(user.todos); // List of todos is populated

// Preload a BelongsTo association
final todoQuery = TodoQuery().preloadUser();
final todos = await repo.all(todoQuery);
for (final todo in todos) {
  print('${todo.title} by ${todo.user?.name}');
}

// Chain multiple preloads
final query = UserQuery()
    .preloadTodos()
    .preloadProfile();
```

Preloading works with both `get()` and `all()` repository methods. The preloaded data is populated in the returned model instances.

### Timestamp Fields

Use the `@Timestamp` annotation on `DateTime` fields for high-precision timestamp storage. The field is stored as two database columns: `{field}_seconds` (seconds since Unix epoch) and `{field}_nanos` (nanoseconds component).

```dart
@StrataSchema(table: 'posts')
class Post with Schema {
  final int id;
  final String title;
  
  @Timestamp()
  final DateTime createdAt;
  
  @Timestamp()
  final DateTime updatedAt;

  Post({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });
}
```

#### Database Schema

For `@Timestamp` fields, create two columns in your migration:

```sql
-- @Up()
CREATE TABLE posts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  created_at_seconds INTEGER NOT NULL,
  created_at_nanos INTEGER NOT NULL,
  updated_at_seconds INTEGER NOT NULL,
  updated_at_nanos INTEGER NOT NULL
);
```

#### Generated Query Methods

The code generator creates DateTime-specific comparison methods:

```dart
// Filter by timestamp
final recentPosts = PostQuery()
    .whereCreatedAtAfter(DateTime.now().subtract(Duration(days: 7)))
    .whereUpdatedAtBefore(DateTime.now())
    .orderByCreatedAt(ascending: false);

// Available methods for timestamp fields:
// - whereCreatedAt(DateTime)        - equality
// - whereCreatedAtNotEq(DateTime)   - not equal
// - whereCreatedAtAfter(DateTime)   - greater than
// - whereCreatedAtAtOrAfter(DateTime) - greater than or equal
// - whereCreatedAtBefore(DateTime)  - less than
// - whereCreatedAtAtOrBefore(DateTime) - less than or equal
// - orderByCreatedAt({bool ascending})
```

### Migrations

Strata provides a database-agnostic `Migration<T>` interface that adapters implement.

#### The Migration Interface

The core `Migration<T>` abstract class defines the contract:

```dart
abstract class Migration<T> {
  /// A unique, increasing version number (typically a timestamp)
  int get version;

  /// Apply the migration
  Future<void> up(T db);

  /// Rollback the migration (optional)
  Future<void> down(T db);
}
```

The generic type `T` represents the database connection provided by the adapter, allowing each adapter to implement migrations appropriate for their database.

#### SQL-Based Migrations (Recommended)

For SQL databases like SQLite and PostgreSQL, use file-based migrations with code generation:

**1. Create a migration file:**
```bash
dart run strata_builder:create_migration create_users_table
```

**2. Edit the generated SQL file** (`migrations/20241115100000_create_users_table.sql`):
```sql
-- @Up()
CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT NOT NULL,
  email TEXT NOT NULL
);

-- @Down()
DROP TABLE IF EXISTS users;
```

**3. Generate Dart code:**
```bash
dart run strata_builder:generate_migrations
```

**4. Run migrations:**
```dart
import 'migrations.dart';  // Generated file, committed to source control
import 'package:strata_sqlite/strata_sqlite.dart';

// Initialize adapter
final adapter = SqliteAdapter(path: 'app.db');
await adapter.initialize();

// Run migrations using the adapter's executor
final runner = SqlMigrationRunner(execute: adapter.executor);
await runner.run(Migrations.all);
```

**Features:**
- Protobuf-style generation: SQL files → CLI → committed Dart file
- Timestamp-based versions (YYYYMMDDHHmmss) prevent merge conflicts
- Optional `@Down()` sections for rollback support (Ecto-style)
- Works with any SQL database adapter

See `strata_builder` and `strata_sqlite` documentation for details.#### Programmatic Migrations (Alternative)

You can also implement migrations programmatically:

```dart
import 'package:strata/strata.dart';
import 'package:strata_sqlite/strata_sqlite.dart';

class CreateUsersTable implements Migration<SqlExecutor> {
  @override
  int get version => 20241115100000;

  @override
  Future<void> up(SqlExecutor executor) async {
    await executor(
      'CREATE TABLE users (id INTEGER PRIMARY KEY, username TEXT NOT NULL)',
      null,
    );
  }

  @override
  Future<void> down(SqlExecutor executor) async {
    await executor('DROP TABLE users', null);
  }
}

// Run migrations
await runner.run([CreateUsersTable()]);
```

However, SQL files with code generation are the recommended approach for SQL databases.

## Project Structure

This is a monorepo containing multiple packages:

- **strata** - Core library with abstractions and APIs
- **strata_builder** - Code generator for `build_runner`
- **strata_sqlite** - SQLite adapter implementation

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

See the LICENSE file for details.
