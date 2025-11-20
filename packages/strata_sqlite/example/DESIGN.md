# Sample App Design: Strata SQLite Todo Application

## Overview

This is a comprehensive example application demonstrating all features of the Strata data mapping library with the SQLite adapter.

## Design Goals

1. **Comprehensive** - Show every major feature of Strata
2. **Realistic** - Use a real-world scenario (todo app)
3. **Educational** - Clearly demonstrate best practices
4. **Runnable** - Fully functional, not just code snippets

## Application Architecture

### Domain Model

The app uses two entities with a one-to-many relationship:

```
User (1) ----< (N) Todo
```

- **User**: Represents a person who owns todos
  - Fields: id, name, email, createdAt
  
- **Todo**: Represents a task item
  - Fields: id, userId, title, description, completed, dueDate, createdAt
  - Belongs to User via userId foreign key

### Technology Stack

- **Core**: Strata data mapping library
- **Database**: SQLite via sqlite3 package
- **Adapter**: strata_sqlite
- **Code Generation**: strata_builder with build_runner
- **Migration**: SQL-based file migrations

## Features Demonstrated

### 1. Schema Definition ✅

**Files**: `lib/models/user.dart`, `lib/models/todo.dart`

Shows how to:
- Use `@StrataSchema` annotation
- Include `Schema` mixin
- Define fields that map to database columns
- Add custom methods (e.g., `Todo.isCompleted`)
- Override `toString()` for better debugging

### 2. Migrations ✅

**Files**: `migrations/20241117100000_create_users_table.sql`, `migrations/20241117101000_create_todos_table.sql`

Shows how to:
- Name migrations with timestamps
- Use `@Up()` and `@Down()` markers
- Create tables with proper types
- Add indexes for performance
- Define foreign key constraints
- Handle cascading deletes

### 3. Code Generation ✅

**Config**: `build.yaml`

Shows how to:
- Configure build_runner
- Enable schema and migrations builders
- Generate query builders and changesets
- Generate migrations file

### 4. Repository Pattern ✅

**File**: `main.dart` (setupDatabase function)

Shows how to:
- Create and initialize adapter
- Create repository instance
- Run migrations on startup
- Properly close connections

### 5. Changesets & Validation ✅

**File**: `main.dart` (createUser, createTodo, demonstrateValidation functions)

Shows how to:
- Cast (whitelist) fields for security
- Validate required fields
- Validate field lengths
- Handle validation errors
- Catch `ChangesetException`
- Display error messages

### 6. CRUD Operations ✅

**File**: `main.dart` (throughout main function)

Shows how to:
- **Create**: Insert users and todos
- **Read**: Get single records and lists
- **Update**: Modify existing records
- **Delete**: Remove records

### 7. Queries ✅

**File**: `main.dart` (throughout main function)

Shows how to:
- Query all records
- Filter by foreign key (`whereUserId`)
- Filter by boolean (`whereCompleted`)
- Order results (`orderBy`)
- Limit results (`limit`)
- Combine multiple conditions

### 8. Error Handling ✅

**File**: `main.dart` (demonstrateValidation function)

Shows how to:
- Check changeset validity
- Handle validation errors gracefully
- Catch and display exceptions
- Prevent invalid data from being persisted

## Example Workflow

The app follows this flow:

```
1. Setup
   └─> Delete old database
   └─> Create SqliteAdapter
   └─> Initialize adapter
   └─> Run migrations
   └─> Create StrataRepo

2. Create Data
   └─> Create users (Alice, Bob)
   └─> Demonstrate validation errors
   └─> Create todos for users

3. Query Data
   └─> Get all todos
   └─> Get todos by user
   └─> Get incomplete todos sorted by due date
   └─> Limit results

4. Modify Data
   └─> Complete a todo
   └─> Update todo title
   └─> Delete a todo

5. Summarize
   └─> Show final state
   └─> Count todos by user
   
6. Cleanup
   └─> Close connections
```

## Output

The app produces formatted output showing:
- Progress indicators (🚀, ✓, 📋, etc.)
- Created records with their data
- Query results
- Validation errors (intentional)
- Summary statistics

Example output:
```
🚀 Strata SQLite Todo App Example
============================================================
🗑️  Deleted existing database
📂 Opening database: example_todo.db
🔄 Running migrations...
✓ Migrations completed

📝 Creating users...
✓ Created users: Alice and Bob

🔍 Demonstrating validation...
  ✗ Validation failed (as expected):
    - name: must be at least 2 characters
    - email: must be at least 5 characters
  ✓ ChangesetException caught correctly

📋 Creating todos for Alice...
✓ Created 3 todos for Alice
...
```

## File Structure

```
example/
├── README.md              # Overview and features
├── QUICKSTART.md          # Step-by-step tutorial
├── DESIGN.md             # This file - architecture details
├── pubspec.yaml          # Dependencies
├── build.yaml            # Code generation config
├── run.sh                # Convenience script
├── main.dart             # Main application
├── lib/
│   └── models/
│       ├── user.dart      # User schema
│       ├── user.g.dart    # Generated (git-ignored)
│       ├── todo.dart      # Todo schema
│       └── todo.g.dart    # Generated (git-ignored)
└── migrations/
    ├── 20241117100000_create_users_table.sql
    └── 20241117101000_create_todos_table.sql
```

## Why This Design?

### Todo App as Example Domain

**Pros:**
- Universally understood
- Complex enough to show features
- Simple enough to stay focused
- Realistic use case

**Alternatives Considered:**
- Blog (Posts/Comments) - Similar but more content-heavy
- E-commerce (Products/Orders) - Too complex
- Address Book - Too simple

### One-to-Many Relationship

Shows how to:
- Model relationships with foreign keys
- Query related data
- Maintain referential integrity
- Use cascade deletes

### CLI Over Web/GUI

**Advantages:**
- No UI framework needed
- Focuses on Strata features
- Easy to run and modify
- Clear, sequential output
- Can be run in CI/CD

### Comprehensive Over Simple

This example intentionally shows **everything** rather than just one or two features. This makes it:
- A complete reference
- A template for new projects
- A test of all integrations
- Documentation through code

## Extension Ideas

Developers can extend this example to learn more:

1. **Add Categories**
   - Create Category model
   - Add foreign key to Todo
   - Query todos by category

2. **Add Priority**
   - Add priority field to Todo
   - Filter and sort by priority
   - Show priority in output

3. **Add Tags (Many-to-Many)**
   - Create Tag and TodoTag models
   - Demonstrate join queries
   - Tag-based filtering

4. **Add Search**
   - Search todos by title
   - Search across users
   - Demonstrate LIKE queries

5. **Add Statistics**
   - Count by status
   - Group by user
   - Date-based analytics

## Testing

While this example doesn't include tests, developers can:
- Study the test files in `strata_sqlite/test/`
- Write integration tests for the example
- Use this as a reference for their own tests

## Performance Considerations

The example demonstrates:
- Proper use of indexes in migrations
- Efficient queries (single query per operation)
- Connection management (initialize once, close on exit)
- Batch operations where appropriate

## Security Considerations

The example demonstrates:
- Input validation with changesets
- Field whitelisting with `cast()`
- SQL injection prevention (adapter handles)
- Required field validation

## Best Practices Shown

1. **Separation of Concerns**
   - Models in `lib/models/`
   - Migrations in `migrations/`
   - Business logic in functions

2. **Error Handling**
   - Check `isValid` before insert/update
   - Catch and handle exceptions
   - Provide meaningful error messages

3. **Code Organization**
   - Helper functions for common operations
   - Clear, descriptive names
   - Comments explaining intent

4. **Database Management**
   - Migrations for schema changes
   - Indexes for performance
   - Foreign keys for integrity

5. **Type Safety**
   - Generated query builders
   - Schema-based types
   - Compile-time checks

## Comparison to Other Frameworks

This example would be implemented differently in:

### Ecto (Elixir)
```elixir
# Very similar! Strata is inspired by Ecto
changeset = User.changeset(%User{}, params)
{:ok, user} = Repo.insert(changeset)
```

### Django ORM (Python)
```python
# More class-based
user = User.objects.create(name="Alice", email="alice@example.com")
todos = Todo.objects.filter(user=user, completed=False)
```

### TypeORM (TypeScript)
```typescript
// More decorator-heavy
@Entity()
class User {
  @PrimaryGeneratedColumn()
  id: number;
}
```

### ActiveRecord (Ruby)
```ruby
# More magic, less explicit
user = User.create(name: "Alice", email: "alice@example.com")
todos = user.todos.where(completed: false)
```

Strata strikes a balance between explicitness and convenience, similar to Ecto's philosophy.

## Conclusion

This example serves as:
- **Documentation** - Shows how to use every feature
- **Template** - Starting point for new projects
- **Test** - Validates all components work together
- **Reference** - Demonstrates best practices

By studying and running this example, developers should understand how to build data-driven applications with Strata.
