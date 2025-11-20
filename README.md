# Strata

An Ecto-inspired data mapping and validation library for Dart.

Strata provides a robust, type-safe, and extensible API for interacting with your database. It is inspired by the best patterns from Elixir's Ecto, focusing on explicit data validation through changesets, composable queries, and a clean separation between your application logic and database implementation.

## Packages

This monorepo contains the following packages:

| Package | Description | Version |
|---------|-------------|---------|
| [strata](packages/strata/) | Core library with abstractions, changesets, and repo API | 0.1.0 |
| [strata_builder](packages/strata_builder/) | Code generator for schemas and migrations | 0.1.0 |
| [strata_sqlite](packages/strata_sqlite/) | SQLite adapter implementation | 0.1.0 |
| [strata_in_memory](packages/strata_in_memory/) | In-memory adapter for testing | 0.1.0 |

## Features

- **Ecto-style Changesets** - Validate and cast untrusted data before persistence
- **Type-safe Queries** - Generated query builders with compile-time safety
- **Transactions** - Atomic operations with automatic rollback on error
- **Associations** - Define relationships with `@HasMany`, `@BelongsTo`, `@HasOne`
- **Migrations** - SQL file-based migrations with rollback support
- **Adapter Pattern** - Swap databases without changing application code

## Quick Start

### 1. Add Dependencies

```yaml
dependencies:
  strata: ^0.1.0
  strata_sqlite: ^0.1.0
  sqlite3: ^2.9.0

dev_dependencies:
  build_runner: ^2.4.13
  strata_builder: ^0.1.0
```

### 2. Define Your Schema

```dart
import 'package:strata/strata.dart';

part 'user.g.dart';

@StrataSchema(table: 'users')
class User with Schema {
  final int id;
  final String name;
  final String email;

  User({required this.id, required this.name, required this.email});
}
```

### 3. Generate Code

```bash
dart run build_runner build
```

### 4. Use the Repository

```dart
import 'package:strata/strata.dart';
import 'package:strata_sqlite/strata_sqlite.dart';

void main() async {
  final adapter = SqliteAdapter(path: 'app.db');
  final repo = StrataRepo(adapter: adapter);
  await repo.initialize();

  // Insert with validation
  final changeset = UserChangeset({
    'name': 'Alice',
    'email': 'alice@example.com',
  })
    ..cast(['name', 'email'])
    ..validateRequired('name')
    ..validateRequired('email');

  if (changeset.isValid) {
    final user = await repo.insert(changeset);
    print('Created: ${user.name}');
  }

  // Type-safe queries
  final user = await repo.get(UserQuery().whereName('Alice'));
  
  // Transactions
  await repo.transaction(() async {
    await repo.update(UserQuery().whereId(1), updateChangeset);
    await repo.insert(anotherChangeset);
  });

  await repo.close();
}
```

## Documentation

- [Core Library (strata)](packages/strata/README.md) - Schemas, changesets, queries, transactions
- [Code Generator (strata_builder)](packages/strata_builder/README.md) - Schema and migration generation
- [SQLite Adapter (strata_sqlite)](packages/strata_sqlite/README.md) - Production SQLite implementation
- [In-Memory Adapter (strata_in_memory)](packages/strata_in_memory/README.md) - Testing adapter

## Examples

See the [strata_sqlite example](packages/strata_sqlite/example/) for a complete working application demonstrating:
- Schema definitions with associations
- SQL migrations
- CRUD operations
- Transactions

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

See the [LICENSE](LICENSE) file for details.
