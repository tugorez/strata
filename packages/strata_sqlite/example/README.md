# Strata SQLite Todo App Example

A complete example demonstrating all features of the Strata data mapping library with SQLite.

## Features Demonstrated

- ✅ **Schema Definitions** - Define models with `@StrataSchema`
- ✅ **Code Generation** - Auto-generate query builders and changesets
- ✅ **Migrations** - Version-controlled database schema management
- ✅ **Repository Pattern** - Clean CRUD operations through `StrataRepo`
- ✅ **Changesets** - Type-safe validation and data casting
- ✅ **Queries** - Composable queries with filtering, ordering, and limiting
- ✅ **Relationships** - Todo items belong to users

## What This App Does

A simple CLI todo application that:
- Creates and manages users
- Creates and manages todo items for users
- Demonstrates filtering, updating, and deleting records
- Shows proper validation with changesets
- Uses migrations for schema management

## Project Structure

```
example/
├── README.md
├── pubspec.yaml
├── build.yaml
├── main.dart                    # Main application entry point
├── migrations/                  # Database migrations
│   ├── 20241117100000_create_users_table.sql
│   └── 20241117101000_create_todos_table.sql
└── lib/
    └── models/
        ├── user.dart            # User schema definition
        ├── user.g.dart          # Generated code
        ├── todo.dart            # Todo schema definition
        └── todo.g.dart          # Generated code
```

## Running the Example

1. **Install dependencies:**
   ```bash
   dart pub get
   ```

2. **Generate migrations file** (protobuf pattern: SQL → CLI → committed Dart):
   ```bash
   dart run strata_builder:generate_migrations
   ```

3. **Generate schema code:**
   ```bash
   dart run build_runner build
   ```

4. **Run the app:**
   ```bash
   dart run main.dart
   ```

**Note:** The `migrations.dart` file is already committed. Step 2 is only needed when you add/modify SQL migrations.

The app will:
- Run migrations to set up the database
- Create sample users
- Create and manipulate todo items
- Demonstrate queries, updates, and deletions
- Show validation in action

## Key Concepts

### 1. Schema Definition

```dart
@StrataSchema(table: 'users')
class User with Schema {
  final int id;
  final String name;
  final String email;
  
  User({required this.id, required this.name, required this.email});
}
```

### 2. Migrations

SQL-based migrations with up/down support:

```sql
-- @Up()
CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE
);

-- @Down()
DROP TABLE IF EXISTS users;
```

### 3. Repository Pattern

```dart
final repo = StrataRepo(adapter: SqliteAdapter(db));
await repo.initialize();

// Insert
final user = await repo.insert(changeset);

// Query
final users = await repo.getAll(UserQuery());

// Update
final updated = await repo.update(query, changeset);

// Delete
await repo.delete(query);
```

### 4. Changesets & Validation

```dart
final changeset = UserChangeset(params)
  ..cast(['name', 'email'])
  ..validateRequired('name')
  ..validateRequired('email')
  ..validateLength('name', min: 2, max: 50);

if (changeset.isValid) {
  final user = await repo.insert(changeset);
}
```

### 5. Queries

```dart
final query = TodoQuery()
  ..whereUserId(userId)
  ..whereCompleted(false)
  ..orderBy('dueDate', ascending: true)
  ..limit(10);

final todos = await repo.getAll(query);
```

## Next Steps

- Explore the source code in `main.dart`
- Try modifying the models in `lib/models/`
- Create your own migrations
- Experiment with different queries and validations

## Learn More

- [Strata Documentation](https://github.com/tugorez/strata)
- [Strata SQLite Adapter](../README.md)
- [Migrations Guide](../../strata/example/MIGRATIONS.md)
