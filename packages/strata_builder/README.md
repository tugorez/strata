# strata_builder

Code generator for the `strata` package. This package provides the build system integration that generates type-safe query builders, changesets, and helper functions for classes annotated with `@StrataSchema`. It also generates SQL migrations from `.sql` files.

## Features

- Generates type-safe query builder classes with `where` methods for each field
- Creates changeset classes for data validation
- Produces `fromMap` helper functions for deserialization
- **Generates migrations from SQL files in the `migrations/` directory**
- Integrates seamlessly with `build_runner`
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

Create a `build.yaml` file in your project root to configure the generator:

```yaml
targets:
  $default:
    builders:
      strata_builder|schemaBuilder:
        enabled: true
      strata_builder|migrationsBuilder:
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

```dart
class UserQuery extends Query<User> {
  UserQuery() : super('users', _fromMap);
  
  UserQuery whereId(int id) {
    whereClauses.add(WhereClause('id', '=', id));
    return this;
  }
  
  UserQuery whereUsername(String username) {
    whereClauses.add(WhereClause('username', '=', username));
    return this;
  }
  
  UserQuery whereEmail(String email) {
    whereClauses.add(WhereClause('email', '=', email));
    return this;
  }
  
  UserQuery whereAge(int age) {
    whereClauses.add(WhereClause('age', '=', age));
    return this;
  }
}
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
    ..whereUsername('alice')
    ..whereAge(25);
  
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

The builder supports generating migrations from SQL files, inspired by Ecto's migration system. Migrations are tracked by timestamp-based versions and can include optional rollback logic.

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

-- Add your SQL statements here.
-- Use @Up() and @Down() annotations to support rollback.

-- @Up()
CREATE TABLE example (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL
);

-- @Down()
DROP TABLE IF EXISTS example;
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

### Running the Generator

There are two ways to generate your `migrations.g.dart` file:

#### Option 1: Using build_runner (Standard)

After creating or modifying migration files, run the build_runner:

```bash
dart run build_runner build
```

**Note:** This requires migration files to be in a standard location that build_runner scans (typically `lib/`).

#### Option 2: Using the generate_migrations script (Recommended)

For migration files outside of `lib/` (like a `migrations/` directory at the project root), use the dedicated script:

```bash
# Generate from default locations
dart run strata_builder:generate_migrations

# Specify custom paths
dart run strata_builder:generate_migrations path/to/migrations lib/migrations.g.dart
```

**Arguments:**
- `migrations_dir` (optional): Directory containing `.sql` files. Defaults to `migrations/`
- `output_file` (optional): Output file path. Defaults to `lib/migrations.g.dart`

**When to use this approach:**
- Migrations directory is outside `lib/` (e.g., `migrations/` or `db/migrations/`)
- You want faster generation without running full build_runner
- You're integrating into a custom build pipeline

**Example workflow:**
```bash
# 1. Create a migration
dart run strata_builder:create_migration add_user_status

# 2. Edit the SQL file
# migrations/20241115103000_add_user_status.sql

# 3. Generate migrations.g.dart
dart run strata_builder:generate_migrations

# Done! Your migrations are ready to use
```

**Integration tip:** Add it to your build script:
```bash
#!/usr/bin/env bash
set -e

# Generate migrations first
dart run strata_builder:generate_migrations

# Then run build_runner for schemas
dart run build_runner build --delete-conflicting-outputs
```

Both approaches generate `lib/migrations.g.dart` containing all your migrations:

```dart
// GENERATED CODE - DO NOT MODIFY BY HAND
// Generated by strata_builder

import 'package:strata_sqlite/strata_sqlite.dart';

/// Auto-generated migrations from the migrations/ directory.
class Migrations {
  /// List of all migrations in order.
  static List<SqlMigration> get all => [
    SqlMigration(
      version: 20241115100000,
      name: 'create_users_table',
      upStatements: [
        'CREATE TABLE users (id INTEGER PRIMARY KEY AUTOINCREMENT, email TEXT NOT NULL UNIQUE)',
      ],
      downStatements: [
        'DROP TABLE IF EXISTS users',
      ],
    ),
    // ... more migrations
  ];
}
```

### Using Generated Migrations

Access and run migrations using the adapter-specific migration runner.

For SQL databases (SQLite), use `SqlMigrationRunner` from `strata_sqlite`:

```dart
import 'package:your_app/migrations.g.dart';
import 'package:strata_sqlite/strata_sqlite.dart';

Future<void> runMigrations(Database db) async {
  // Create a migration runner
  final runner = SqlMigrationRunner(
    execute: (sql, args) async {
      return await db.rawQuery(sql, args ?? []);
    },
  );
  
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
   dart run build_runner build
   ```

4. **Run migrations in your app:**
   ```dart
   import 'migrations.g.dart';
   
   await runner.run(Migrations.all);
   ```



## Contributing

Contributions are welcome! This package is part of the Strata monorepo. Please submit issues and pull requests to the main repository.

## License

See the LICENSE file in the main repository.

