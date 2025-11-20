# Strata Migration System Implementation Summary

## Overview
Implemented a complete database-agnostic migration system for Strata, inspired by Ecto's migration approach. The system allows developers to manage database schema changes using files (e.g., SQL files) that are automatically compiled into Dart code.

## Architecture Decision: Ecto-Inspired Design

**Key Principle**: Following Elixir's Ecto pattern, all migrations implement a common interface.

### Ecto's Pattern (What We Followed):
In Ecto, all migrations implement the same behavior with `up/0` and `down/0` functions.
Whether you write migrations in Elixir code or generate them from SQL files, they
all follow the same interface.

### Strata's Implementation:

#### In `strata` (database-agnostic):
- `Migration<T>` abstract class with `version`, `up(T)`, and `down(T)`
- Generic interface that works for any database type

#### In `strata_sqlite` (SQL-specific):
- `SqlMigration` **implements** `Migration<SqlExecutor>`
- Takes SQL statements and provides `up()` method to execute them
- Provides consistent interface with custom `Migration` classes
- `SqlMigrationRunner` handles tracking and orchestration

#### In `strata_builder`:
- Generates `SqlMigration` instances from `.sql` files
- Output is executable code, not just data

### Why This Design?

1. **Follows Ecto's proven pattern** - Consistent interface for all migrations
2. **`Migration<T>` is the universal contract** - All migrations implement it
3. **Type-safe execution** - `SqlMigration.up()` knows how to run itself
4. **Adapter-specific** - Each database type can have its own migration implementation
5. **Unified tracking** - Migration runner works with any `Migration<T>`

### Comparison with Ecto:

**Ecto (Elixir)**:
```elixir
defmodule MyApp.Repo.Migrations.CreateUsers do
  use Ecto.Migration
  
  def up do
    create table(:users) do
      add :name, :string
    end
  end
end
```

**Strata (Dart + SQL files)**:
```sql
-- migrations/20241115100000_create_users.sql
CREATE TABLE users (name TEXT);
```

Generated as:
```dart
SqlMigration(
  version: 20241115100000,
  name: 'create_users',
  statements: ['CREATE TABLE users (name TEXT)'],
) // implements Migration<SqlExecutor>
```

## Components Implemented

### 1. **Migration Generator CLI** (`strata_builder`)
- **File**: `packages/strata_builder/bin/generate_migrations.dart`
- **Purpose**: Scans `migrations/` directory for `.sql` files and generates a Dart file
- **Pattern**: Protobuf-style (SQL source → CLI → committed Dart output)
- **Features**:
  - Automatic discovery of migration files
  - Version number extraction from filenames
  - SQL statement parsing
  - Generates `lib/migrations.dart` (committed to source control)

### 2. **CLI Tool** (`strata_builder`)
- **File**: `packages/strata_builder/bin/create_migration.dart`
- **Purpose**: Creates new migration files with proper naming and templates
- **Usage**: `dart run strata_builder:create_migration <name>`
- **Features**:
  - Auto-increments version numbers
  - Zero-padded version formatting (001, 002, etc.)
  - Template generation with helpful comments
  - Custom directory support via `--path` option

### 3. **Migration Types**
- **`strata`**: `Migration<T>` abstract class for custom programmatic migrations
- **`strata_sqlite`**: `SqlMigration` class (SQL-specific data structure)
- **Purpose**: `SqlMigration` represents a SQL migration with version, name, and SQL statements
- **Why in strata_sqlite?**: SQL is database-specific; other adapters can define their own migration types

### 4. **SQL Migration Runner** (`strata_sqlite`)
- **File**: `packages/strata_sqlite/lib/src/sql_migration_runner.dart`
- **Purpose**: Executes SQL migrations against SQL databases
- **Features**:
  - Creates `schema_migrations` tracking table
  - Tracks which migrations have been applied
  - Only runs pending migrations
  - Records version, name, and timestamp
- **Why in strata_sqlite?**: SQL-specific functionality belongs in SQL adapters

### 5. **Adapter Interface** (`strata`)
- **File**: `packages/strata/lib/src/strata_adapter.dart`
- **Note**: Kept database-agnostic - no `execute()` method
- **Purpose**: Abstract interface that all adapters implement

### 6. **Migration CLI Script** (Protobuf Pattern)
- **File**: `packages/strata_builder/bin/generate_migrations.dart`
- **Pattern**: `migrations/*.sql` → CLI → `lib/migrations.dart` (committed)
- **Why**: Migrations are source files, not runtime-generated code

## File Structure

```
packages/
  strata/                           # Core - 100% Database Agnostic
    lib/
      src/
        migration.dart              # ONLY Migration<T> abstract class
        strata_adapter.dart         # No database-specific methods
  
  strata_sqlite/                    # SQL-Specific
    lib/
      src/
        sql_migration.dart          # SqlMigration data class
        sql_migration_runner.dart   # SQL migration execution
        sqlite_adapter.dart         # SQLite implementation
  
  strata_builder/                   # Code Generation
    bin/
      create_migration.dart         # CLI tool for creating .sql files
      generate_migrations.dart      # CLI tool for generating migrations.dart
```

## Usage Flow

1. **Create Migration**:
   ```bash
   dart run strata_builder:create_migration create_users_table
   ```

2. **Edit SQL File**:
   ```sql
   -- migrations/20241115100000_create_users_table.sql
   CREATE TABLE users (
     id INTEGER PRIMARY KEY AUTOINCREMENT,
     username TEXT NOT NULL
   );
   ```

3. **Generate Dart Code**:
   ```bash
   dart run build_runner build
   ```

4. **Run Migrations**:
   ```dart
   import 'package:your_app/migrations.dart';
   import 'package:strata_sqlite/strata_sqlite.dart';
   
   final runner = SqlMigrationRunner(
     execute: (sql, [args]) async => await db.rawQuery(sql, args ?? []),
   );
   await runner.run(Migrations.all);
   ```

## Key Features

✅ **Truly Database-Agnostic Core**: `strata` has ZERO database-specific code
✅ **Adapter-Specific Migrations**: Each adapter defines its own migration format
✅ **Automatic Code Generation**: SQL files automatically converted to Dart `SqlMigration` objects
✅ **Version Tracking**: System tracks which migrations have been applied
✅ **Idempotent**: Safe to run multiple times - only applies pending migrations
✅ **CLI Tool**: Easy migration creation with proper naming conventions
✅ **Template Generation**: New migrations include helpful comments and structure
✅ **Build System Integration**: Works seamlessly with `build_runner`
✅ **Type-Safe**: Generated code is fully type-safe
✅ **Extensible**: Easy to add support for other databases (Postgres, MongoDB, etc.)

## Naming Convention

Migrations follow the pattern: `{timestamp}_{description}.sql`
- Timestamp: YYYYMMDDHHmmss format (e.g., 20241115100000)
- Description: Snake_case description
- Examples: `20241115100000_create_users.sql`, `20241115110000_add_email_index.sql`

This timestamp-based approach (borrowed from Ecto) prevents merge conflicts when multiple developers create migrations simultaneously.

## Generated Code Example

```dart
// lib/migrations.dart (generated by CLI, committed to source control)
import 'package:strata_sqlite/strata_sqlite.dart';

class Migrations {
  static List<SqlMigration> get all => [
    SqlMigration(
      version: 20241115100000,
      name: 'create_users_table',
      upStatements: [
        'CREATE TABLE users (...)',
        'CREATE INDEX idx_users_email ON users(email)',
      ],
    ),
    // ... more migrations
  ];
}
```

Note: The generated code imports from `strata_sqlite`, not `strata`, because
`SqlMigration` is SQL-specific and belongs in the SQL adapter package.

## Dependencies Added

- `glob`: ^2.1.2 - For finding migration files
- `path`: ^1.9.1 - For path manipulation
- `args`: ^2.6.0 - For CLI argument parsing

## Testing

- Updated fake adapter to support `execute()` method
- Added example migrations for testing
- All type checks pass with no errors

## Documentation

- Updated README with migration system documentation
- Created comprehensive MIGRATIONS.md guide
- Added inline code documentation
- Included usage examples

## Similar to Ecto

This implementation is similar to Phoenix/Ecto's migration system:
- SQL-based migrations in a dedicated directory
- Version-based tracking
- Automatic code generation
- CLI tool for creating migrations
- Idempotent execution
