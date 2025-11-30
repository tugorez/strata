# strata_builder

Code generator for the `strata` package. This package provides:

1. **Schema Code Generation** (`build_runner`) - Generates type-safe query builders, changesets, and helper functions for classes annotated with `@StrataSchema`
2. **Migration Generation** (CLI tool) - Generates Dart migration files from SQL sources using the protobuf pattern

## Features

- Generates type-safe query builder classes with `where` methods for each field
- Creates changeset classes for data validation
- Produces `fromMap` helper functions for deserialization
- **Generates migrations from SQL files** (protobuf-style: SQL → CLI → committed Dart)
- Integrates seamlessly with `build_runner` for schemas
- Generates clean, formatted Dart code

## Installation

Add `strata_builder` as a dev dependency in your `pubspec.yaml`:

```yaml
dependencies:
  strata: ^0.1.0

dev_dependencies:
  build_runner: ^2.4.13
  strata_builder: ^0.1.0
```

## Configuration

Create a `build.yaml` file in your project root to configure the schema generator:

```yaml
targets:
  $default:
    builders:
      strata_builder|schemaBuilder:
        enabled: true
```

## Usage

### 1. Define Your Schema

Create a model class with the `@StrataSchema` annotation:

```dart
// lib/models/user.dart
import 'package:strata/strata.dart';

part 'user.g.dart';

@StrataSchema(table: 'users')
class User with Schema {
  final int id;
  final String username;
  final String email;
  final int age;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.age,
  });
}
```

### 2. Run the Generator

Execute the build runner to generate the code:

```bash
dart run build_runner build
```

Or use watch mode for continuous generation during development:

```bash
dart run build_runner watch
```

To resolve conflicts, use the `--delete-conflicting-outputs` flag:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 3. Generated Code

The generator creates a `user.g.dart` file with:

#### Query Builder

For each field, the generator creates multiple where methods supporting different operators:

```dart
class UserQuery extends Query<User> {
  UserQuery() : super('users', _fromMap);
  
  // Equality
  UserQuery whereId(int id) { ... }
  UserQuery whereIdNotEq(int id) { ... }
  
  // Comparison (for numeric fields)
  UserQuery whereIdGreaterThan(int id) { ... }
  UserQuery whereIdGreaterThanOrEq(int id) { ... }
  UserQuery whereIdLessThan(int id) { ... }
  UserQuery whereIdLessThanOrEq(int id) { ... }
  
  // Collection operators
  UserQuery whereIdIn(List<int> values) { ... }
  UserQuery whereIdNotIn(List<int> values) { ... }
  
  // String operators (for String fields)
  UserQuery whereUsernameLike(String pattern) { ... }
  
  // Ordering (for all fields)
  UserQuery orderById({bool ascending = true}) { ... }
  UserQuery orderByUsername({bool ascending = true}) { ... }
  UserQuery orderByAge({bool ascending = true}) { ... }
  
  // ... similar methods for all fields
}
```

#### Association Support

When you define associations using `@HasMany`, `@BelongsTo`, or `@HasOne`, the generator creates preload methods:

```dart
// Given this schema:
@StrataSchema(table: 'users')
class User with Schema {
  final int id;
  final String name;
  
  @HasMany(Todo, foreignKey: 'user_id')
  final List<Todo>? todos;

  User({required this.id, required this.name, this.todos});
}

// The generator creates:
class UserQuery extends Query<User> {
  // ... where methods ...
  
  UserQuery preloadTodos() {
    return UserQuery._(copyWithPreload('todos'));
  }
}
```

#### Timestamp Support

Use `@Timestamp` on `DateTime` fields for high-precision storage. The generator maps a single `DateTime` field to two database columns (`_seconds` and `_nanos`):

```dart
// Given this schema:
@StrataSchema(table: 'posts')
class Post with Schema {
  final int id;
  final String title;
  
  @Timestamp()
  final DateTime createdAt;
  
  @Timestamp()
  final DateTime updatedAt;

  Post({required this.id, required this.title, required this.createdAt, required this.updatedAt});
}

// The generator creates DateTime-specific query methods:
class PostQuery extends Query<Post> {
  // Equality
  PostQuery whereCreatedAt(DateTime createdAt) { ... }
  PostQuery whereCreatedAtNotEq(DateTime createdAt) { ... }
  
  // Comparison (semantic names for DateTime)
  PostQuery whereCreatedAtAfter(DateTime createdAt) { ... }      // >
  PostQuery whereCreatedAtAtOrAfter(DateTime createdAt) { ... }  // >=
  PostQuery whereCreatedAtBefore(DateTime createdAt) { ... }     // <
  PostQuery whereCreatedAtAtOrBefore(DateTime createdAt) { ... } // <=
  
  // Ordering (uses _seconds column)
  PostQuery orderByCreatedAt({bool ascending = true}) { ... }
}

// And helper functions for conversion:
DateTime _timestampToDateTime(int seconds, int nanos) { ... }
Map<String, int> _dateTimeToTimestamp(DateTime dateTime) { ... }

// The _fromMap reads from seconds/nanos columns:
Post _fromMap(Map<String, dynamic> map) {
  return Post(
    id: map['id'],
    title: map['title'],
    createdAt: _timestampToDateTime(map['created_at_seconds'], map['created_at_nanos']),
    updatedAt: _timestampToDateTime(map['updated_at_seconds'], map['updated_at_nanos']),
  );
}
```

**Database Schema:** For `@Timestamp` fields, create two INTEGER columns:
```sql
created_at_seconds INTEGER NOT NULL,
created_at_nanos INTEGER NOT NULL
```

#### Optional Timestamp Fields

The generator also supports optional `DateTime?` fields with `@Timestamp`. This is useful for fields like `endDate` that may be null:

```dart
@StrataSchema(table: 'events')
class Event with Schema {
  final int id;
  final String name;
  
  @Timestamp()
  final DateTime startDate;    // Required
  
  @Timestamp()
  final DateTime? endDate;     // Optional - can be null

  Event({required this.id, required this.name, required this.startDate, this.endDate});
}
```

The generated `_fromMap` correctly handles null values:
```dart
Event _fromMap(Map<String, dynamic> map) {
  return Event(
    id: map['id'],
    name: map['name'],
    startDate: _timestampToDateTime(map['start_date_seconds'], map['start_date_nanos']),
    // Optional timestamp: checks for null before conversion
    endDate: map['end_date_seconds'] != null
        ? _timestampToDateTime(map['end_date_seconds'], map['end_date_nanos'])
        : null,
  );
}
```

The changeset `cast` method also handles optional timestamps, converting `DateTime?` values to their column representations when present.

**Database Schema:** For optional `@Timestamp` fields, allow NULL:
```sql
end_date_seconds INTEGER,  -- NULL allowed
end_date_nanos INTEGER     -- NULL allowed
```

#### Changeset

```dart
class UserChangeset extends Changeset<User> {
  UserChangeset(super.params) 
    : super(table: 'users', fromMap: _fromMap);
}
```

#### Deserialization Helper

```dart
User _fromMap(Map<String, dynamic> map) {
  return User(
    id: map['id'],
    username: map['username'],
    email: map['email'],
    age: map['age'],
  );
}
```

### 4. Use the Generated Code

```dart
import 'package:strata/strata.dart';
import 'models/user.dart';

Future<void> example(StrataRepo repo) async {
  // Use the generated query builder
  final query = UserQuery()
    .whereUsername('alice')
    .whereAge(25);
  
  final user = await repo.get(query);
  
  // Use the generated changeset
  final changeset = UserChangeset({
    'username': 'bob',
    'email': 'bob@example.com',
    'age': 30,
  })
    ..validateRequired('username')
    ..validateRequired('email');
  
  if (changeset.isValid) {
    await repo.insert(changeset);
  }
}
```

## How It Works

The generator uses Dart's analyzer to inspect classes annotated with `@StrataSchema`. For each annotated class, it:

1. Extracts the table name from the annotation
2. Analyzes the constructor parameters to identify fields
3. Generates a Query class with type-safe `where` methods for each field
4. Generates a Changeset class for data validation
5. Creates a `fromMap` function that constructs instances from database records

All generated code is formatted using `dart_style` for consistency.

## Requirements

- Dart SDK: ^3.9.0
- The annotated class must have the `Schema` mixin
- The constructor must use only named parameters
- A `part` directive pointing to the generated file (e.g., `part 'user.g.dart';`)

## Troubleshooting

### "Could not find part file"

Make sure you have the `part` directive in your model file:

```dart
part 'user.g.dart';
```

### "Must have unnamed constructor"

Ensure your class has a default constructor with named parameters:

```dart
// ✅ Good
User({required this.id, required this.username});

// ❌ Bad - positional parameters
User(this.id, this.username);
```

### Conflicting outputs

If you see conflicts, use the `--delete-conflicting-outputs` flag:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## SQL Migrations

The builder provides a CLI tool for generating migrations from SQL files, following the **protobuf pattern**:

```
migrations/*.sql  →  bin/generate_migrations.dart  →  lib/migrations.dart (committed)
```

This is similar to how protobuf works:
- `protos/*.proto` → `protoc` → `lib/src/*.pb.dart` (committed)

**Why this pattern?**
- SQL files are the source of truth
- Generated Dart file is derived output that gets committed
- No `build_runner` needed for migrations (they're not in `lib/`)
- Fast, explicit generation when you modify migrations

### Creating Migrations

Use the provided CLI tool to create a new migration:

```bash
dart run strata_builder:create_migration create_users_table
```

This creates a file like `migrations/20241115102030_create_users_table.sql` with a template:

```sql
-- Migration: create_users_table
-- Timestamp: 20241115102030
-- Created: 2024-11-15T10:20:30.000Z

-- @Up()
CREATE TABLE example (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL
);

-- @Down()
DROP TABLE IF EXISTS example;
```

### Generating the Dart File

After creating or modifying SQL migrations, generate the Dart file:

```bash
dart run strata_builder:generate_migrations
```

This scans `migrations/` and generates `lib/migrations.dart`:

```dart
// GENERATED CODE - DO NOT MODIFY BY HAND
// Generated by bin/generate_migrations.dart

import 'package:strata_sqlite/strata_sqlite.dart';

class Migrations {
  static List<SqlMigration> get all => [
    SqlMigration(
      version: 20241115102030,
      name: 'create_users_table',
      upStatements: [...],
      downStatements: [...],
    ),
  ];
}
```

**Commit both the SQL files AND the generated Dart file.**

### Custom Paths

```bash
# Custom migrations directory and output path
dart run strata_builder:generate_migrations db/migrations lib/db/migrations.dart
```

### Migration Naming Convention

Migrations follow Ecto's timestamp-based naming pattern: `{timestamp}_{description}.sql`

- `timestamp`: YYYYMMDDHHmmss format (e.g., `20241115102030`)
- `description`: A snake_case description

**Why timestamps?**
- Prevents merge conflicts when multiple developers create migrations
- Shows chronological order naturally
- Industry standard (used by Ecto, Rails, Django)

**Examples:**
- `20241115100000_create_users_table.sql`
- `20241115110000_add_email_index.sql`
- `20241115120000_create_posts_table.sql`

### Up and Down Sections

Migrations can include optional rollback logic using `@Up()` and `@Down()` markers:

```sql
-- @Up()
CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT NOT NULL UNIQUE,
  created_at INTEGER NOT NULL
);

CREATE INDEX idx_users_email ON users(email);

-- @Down()
DROP INDEX IF EXISTS idx_users_email;
DROP TABLE IF EXISTS users;
```

**Key points:**
- `-- @Up()` defines statements to apply the migration
- `-- @Down()` defines statements to rollback (optional, like Ecto)
- Markers are case-insensitive (`@up()`, `@UP()` all work)
- Down sections are optional - migrations without them are irreversible
- Multiple statements are separated by semicolons

### Irreversible Migrations

Some migrations cannot or should not be reversed (e.g., data transformations). Simply omit the `@Down()` section:

```sql
-- @Up()
INSERT INTO users (email, created_at) 
SELECT email, strftime('%s', 'now') 
FROM legacy_users;

-- No @Down() section = irreversible migration (Ecto-style)
```

### Complete Workflow

```bash
# 1. Create a migration
dart run strata_builder:create_migration add_user_status

# 2. Edit the SQL file
# migrations/20241115103000_add_user_status.sql

# 3. Generate migrations.dart
dart run strata_builder:generate_migrations

# 4. Commit both files
git add migrations/ lib/migrations.dart
git commit -m "Add user status migration"
```

### Using Generated Migrations

Access and run migrations using the adapter-specific migration runner.

For SQL databases (SQLite), use `SqlMigrationRunner` from `strata_sqlite`:

```dart
import 'package:your_app/migrations.dart';  // Generated & committed
import 'package:strata_sqlite/strata_sqlite.dart';

Future<void> runMigrations(SqliteAdapter adapter) async {
  // Create a migration runner using the adapter's executor
  final runner = SqlMigrationRunner(execute: adapter.executor);
  
  // Run all pending migrations (automatically sorted by version)
  await runner.run(Migrations.all);
}
```

The runner:
- Creates a `schema_migrations` table to track applied migrations
- Only runs migrations with versions greater than the current version
- Executes migrations in ascending version order
- Records each migration after successful execution

### Rollback Support

To rollback a migration, call the `down()` method:

```dart
// Rollback a specific migration
final migration = Migrations.all.last;
await migration.down(executor);
```

**Note:** If a migration has no `downStatements`, calling `down()` does nothing (Ecto-style behavior).

### Migration Options

Customize the migrations directory using the `--path` option:

```bash
dart run strata_builder:create_migration add_user_status --path=db/migrations
```

### Complete Workflow Example

1. **Create a migration:**
   ```bash
   dart run strata_builder:create_migration create_posts_table
   ```

2. **Edit the generated file** (`migrations/20241115103000_create_posts_table.sql`):
   ```sql
   -- @Up()
   CREATE TABLE posts (
     id INTEGER PRIMARY KEY AUTOINCREMENT,
     title TEXT NOT NULL,
     user_id INTEGER NOT NULL,
     FOREIGN KEY (user_id) REFERENCES users(id)
   );
   
   -- @Down()
   DROP TABLE IF EXISTS posts;
   ```

3. **Generate Dart code:**
   ```bash
   dart run strata_builder:generate_migrations
   ```

4. **Commit the files:**
   ```bash
   git add migrations/ lib/migrations.dart
   ```

5. **Run migrations in your app:**
   ```dart
   import 'package:your_app/migrations.dart';
   
   await runner.run(Migrations.all);
   ```



## Contributing

Contributions are welcome! This package is part of the Strata monorepo. Please submit issues and pull requests to the main repository.

## License

See the LICENSE file in the main repository.