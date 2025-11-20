# Quick Start Guide - Strata SQLite Todo App

## Overview

This example app demonstrates a complete todo application using Strata with SQLite. It's the best way to see all the features working together in a real-world scenario.

## What You'll Learn

By studying this example, you'll understand:

1. **How to structure a Strata project**
2. **How to define schemas and generate code**
3. **How to write and manage migrations**
4. **How to use the Repository pattern**
5. **How to validate data with changesets**
6. **How to write queries with filtering and ordering**

## Step-by-Step Setup

### 1. Install Dependencies

From the `example` directory:

```bash
cd packages/strata_sqlite/example
dart pub get
```

### 2. Generate Code

Run the build_runner to generate query builders and changesets:

```bash
dart run build_runner build
```

This will create:
- `lib/models/user.g.dart` - User query builder and changeset
- `lib/models/todo.g.dart` - Todo query builder and changeset

**Note:** `lib/migrations.dart` is generated separately using `dart run strata_builder:generate_migrations` and should be committed to source control.

### 3. Run the App

```bash
dart run main.dart
```

## Code Walkthrough

### 1. Schema Definitions

Located in `lib/models/`, schemas define your data structure:

```dart
@StrataSchema(table: 'users')
class User with Schema {
  final int id;
  final String name;
  final String email;
  final int createdAt;
  
  User({...});
}
```

**Key Points:**
- `@StrataSchema` annotation marks classes for code generation
- `Schema` mixin is required
- Fields map directly to database columns
- Use snake_case in migrations, camelCase in Dart (auto-converted)

### 2. Migrations

Located in `migrations/`, SQL files define database schema changes:

```sql
-- @Up()
CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  created_at INTEGER NOT NULL
);

-- @Down()
DROP TABLE IF EXISTS users;
```

**Key Points:**
- Filename format: `YYYYMMDDHHmmss_description.sql`
- `-- @Up()` marks statements for applying migration
- `-- @Down()` marks statements for rollback (optional)
- Migrations run in order, tracking applied versions

### 3. Repository Pattern

The app creates a single repo instance:

```dart
final adapter = SqliteAdapter(path: 'example_todo.db');
await adapter.initialize();

final repo = StrataRepo(adapter: adapter);
await repo.initialize();
```

**Key Points:**
- Adapter handles database-specific operations
- Repository provides high-level CRUD operations
- Always initialize before use

### 4. Changesets & Validation

Validate data before inserting/updating:

```dart
final changeset = UserChangeset({
  'name': name,
  'email': email,
  'createdAt': DateTime.now().millisecondsSinceEpoch,
})
  ..cast(['name', 'email', 'createdAt'])
  ..validateRequired('name')
  ..validateRequired('email')
  ..validateLength('name', min: 2, max: 50);

if (changeset.isValid) {
  final user = await repo.insert(changeset);
}
```

**Key Points:**
- `cast()` whitelists allowed fields (security)
- `validateRequired()` ensures fields are present
- `validateLength()` checks string length
- Check `isValid` before insert/update

### 5. Queries

Filter, order, and limit results:

```dart
// Get all incomplete todos for a user, sorted by due date
final todos = await repo.getAll(
  TodoQuery()
    ..whereUserId(userId)
    ..whereCompleted(0)
    ..orderBy('dueDate', ascending: true)
    ..limit(10)
);
```

**Key Points:**
- Query builders are generated from schemas
- Chainable API for composing queries
- Type-safe field names
- Supports WHERE, ORDER BY, and LIMIT

### 6. CRUD Operations

```dart
// Create
final user = await repo.insert(changeset);

// Read
final user = await repo.get(UserQuery().whereId(id));
final users = await repo.getAll(UserQuery());

// Update
await repo.update(
  TodoQuery().whereId(todoId),
  changeset,
);

// Delete
await repo.delete(TodoQuery().whereId(todoId));
```

## Example App Flow

1. **Setup** - Delete old database, create adapter, run migrations
2. **Create Users** - Demonstrate validation and insert operations
3. **Show Validation** - Attempt invalid inserts, handle exceptions
4. **Create Todos** - Create todos for multiple users
5. **Query All** - Retrieve all todos
6. **Query Filtered** - Filter by user, completion status
7. **Update** - Complete a todo, update title
8. **Delete** - Remove a todo
9. **Summary** - Show final state with counts

## Common Patterns

### Creating Records

```dart
Future<Todo> createTodo(StrataRepo repo, {...}) async {
  final params = {...};
  
  final changeset = TodoChangeset(params)
    ..cast(['userId', 'title', 'description', ...])
    ..validateRequired('userId')
    ..validateRequired('title')
    ..validateLength('title', min: 1, max: 200);

  if (!changeset.isValid) {
    throw Exception('Invalid todo data: ${changeset.errors}');
  }

  return await repo.insert(changeset);
}
```

### Querying with Filters

```dart
// Find Alice's incomplete todos
final aliceTodos = await repo.getAll(
  TodoQuery()
    .whereUserId(alice.id)
    .whereCompleted(0)
);
```

### Updating Records

```dart
final changeset = TodoChangeset({'completed': 1})
  ..cast(['completed']);

await repo.update(
  TodoQuery().whereId(todoId),
  changeset,
);
```

## Next Steps

### Experiment with the Code

Try modifying the example to:

1. **Add a new field to Todo** (e.g., `priority`)
   - Update the schema in `lib/models/todo.dart`
   - Create a migration to alter the table
   - Regenerate code with build_runner
   - Query by priority

2. **Add a new model** (e.g., `Category`)
   - Create `lib/models/category.dart`
   - Create a migration for the categories table
   - Link todos to categories with a foreign key
   - Query todos by category

3. **Add custom validation**
   - Validate email format with regex
   - Ensure due dates are in the future
   - Check for duplicate titles

4. **Add more queries**
   - Find overdue todos
   - Get todos by date range
   - Count todos by user

### Build Your Own App

Use this example as a template for your own applications:

1. Define your schemas
2. Write migrations
3. Generate code
4. Build your business logic with the repository

## Troubleshooting

### Code generation errors

If you get errors about missing `.g.dart` files:
```bash
dart run build_runner build --delete-conflicting-outputs
```

### Migration errors

If migrations fail:
- Check SQL syntax
- Ensure `-- @Up()` and `-- @Down()` markers are present
- Verify table/column names match schema definitions

### Runtime errors

If you get errors at runtime:
- Ensure you called `initialize()` on adapter and repo
- Check that all fields in changesets match schema
- Verify foreign key constraints are satisfied

## Resources

- [Strata README](../../../strata/README.md)
- [Migration Guide](../../../strata/example/MIGRATIONS.md)
- [Changeset Documentation](../../../strata/lib/src/changeset.dart)
- [Repository API](../../../strata/lib/src/strata_repo.dart)

## Getting Help

If you encounter issues or have questions:

1. Check the error message carefully
2. Review the README files in each package
3. Look at the test files for usage examples
4. Open an issue on GitHub

Happy coding with Strata! 🚀
