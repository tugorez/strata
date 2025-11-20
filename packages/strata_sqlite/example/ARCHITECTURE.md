# Architecture Diagram

## Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                     Application Layer                        │
│                        (main.dart)                           │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   Create     │  │    Query     │  │   Update     │     │
│  │   Users &    │  │    Todos     │  │   & Delete   │     │
│  │   Todos      │  │   by User    │  │    Todos     │     │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘     │
│         │                  │                  │              │
│         └──────────────────┼──────────────────┘              │
│                            ▼                                 │
└────────────────────────────┬─────────────────────────────────┘
                             │
                             │ uses
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                   Repository Pattern                         │
│                      (StrataRepo)                            │
│                                                              │
│  • insert(changeset)      → Creates records                 │
│  • get(query)             → Fetches single record           │
│  • getAll(query)          → Fetches multiple records        │
│  • update(query, changes) → Updates records                 │
│  • delete(query)          → Deletes records                 │
│                                                              │
└────────────────────────────┬─────────────────────────────────┘
                             │
                             │ delegates to
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                    Adapter Layer                            │
│                   (SqliteAdapter)                           │
│                                                              │
│  • Translates Strata queries to SQL                         │
│  • Executes SQL statements                                  │
│  • Maps results back to Dart objects                        │
│  • Manages database connection                              │
│                                                              │
└────────────────────────────┬─────────────────────────────────┘
                             │
                             │ executes SQL on
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                    Database Layer                           │
│                       (SQLite)                              │
│                                                              │
│  ┌─────────────────┐    ┌─────────────────┐               │
│  │  users table    │    │  todos table    │               │
│  ├─────────────────┤    ├─────────────────┤               │
│  │ id              │    │ id              │               │
│  │ name            │    │ user_id  ───────┼──► users.id   │
│  │ email           │    │ title           │               │
│  │ created_at      │    │ description     │               │
│  └─────────────────┘    │ completed       │               │
│                         │ due_date        │               │
│                         │ created_at      │               │
│                         └─────────────────┘               │
└─────────────────────────────────────────────────────────────┘
```

## Schema & Code Generation Flow

```
┌──────────────────┐
│  Source Files    │
│  ──────────────  │
│  user.dart       │  Define schemas
│  todo.dart       │  with @StrataSchema
└────────┬─────────┘
         │
         │ input to
         ▼
┌──────────────────┐
│  build_runner    │
│  ──────────────  │
│  Runs code gen   │  Generates:
│  via build.yaml  │  • Query builders
└────────┬─────────┘  • Changesets
         │            • Type-safe APIs
         │
         │ generates
         ▼
┌──────────────────┐
│  Generated Code  │
│  ──────────────  │
│  user.g.dart     │  Contains:
│  todo.g.dart     │  • UserQuery()
└──────────────────┘  • TodoQuery()
                      • UserChangeset()
                      • TodoChangeset()
```

## Migration Flow

```
┌─────────────────────────────────────────────────┐
│  Migration Files (migrations/*.sql)             │
│  ─────────────────────────────────────────      │
│  20241117100000_create_users_table.sql          │
│  20241117101000_create_todos_table.sql          │
└────────────────┬────────────────────────────────┘
                 │
                 │ scanned by
                 ▼
┌─────────────────────────────────────────────────┐
│  strata_builder (migrations generator)          │
│  ─────────────────────────────────────────      │
│  Parses SQL files and extracts:                 │
│  • Version (from filename timestamp)            │
│  • Name (from filename)                         │
│  • Up statements (after @Up())                  │
│  • Down statements (after @Down())              │
└────────────────┬────────────────────────────────┘
                 │
                 │ dart run strata_builder:generate_migrations
                 ▼
┌─────────────────────────────────────────────────┐
│  migrations.dart (COMMITTED)                    │
│  ─────────────────────────────────────────      │
│  class Migrations {                             │
│    static List<SqlMigration> get all => [...];  │
│  }                                              │
└────────────────┬────────────────────────────────┘
                 │
                 │ used by
                 ▼
┌─────────────────────────────────────────────────┐
│  SqlMigrationRunner                             │
│  ─────────────────────────────────────────      │
│  • Tracks applied migrations                    │
│  • Runs pending migrations in order             │
│  • Updates schema_migrations table              │
└────────────────┬────────────────────────────────┘
                 │
                 │ executes SQL on
                 ▼
┌─────────────────────────────────────────────────┐
│  SQLite Database                                │
└─────────────────────────────────────────────────┘
```

## Validation Flow (Changesets)

```
┌─────────────────┐
│  Untrusted      │
│  Data (params)  │  e.g., from user input,
│  {'name': 'A',  │  form submission, API
│   'email': ''}  │
└────────┬────────┘
         │
         │ input to
         ▼
┌─────────────────────────────────────────┐
│  UserChangeset(params)                  │
│  ─────────────────────────────────      │
│  1. cast(['name', 'email'])             │  ◄─ Security: Whitelist
│  2. validateRequired('name')            │  ◄─ Validation
│  3. validateRequired('email')           │  ◄─ Validation
│  4. validateLength('name', min: 2)      │  ◄─ Validation
└────────┬────────────────────────────────┘
         │
         ├──► if invalid ──► errors map
         │                    └─► Display to user
         │
         └──► if valid
              │
              ▼
┌──────────────────────────────────────────┐
│  changeset.changes                       │
│  ───────────────────────────────          │
│  {'name': 'Alice',                       │  ◄─ Sanitized
│   'email': 'alice@example.com',          │     & validated
│   'createdAt': 1700000000000}            │
└────────┬─────────────────────────────────┘
         │
         │ passed to
         ▼
┌──────────────────────────────────────────┐
│  repo.insert(changeset)                  │
│  ───────────────────────────────          │
│  Safely persists to database             │
└──────────────────────────────────────────┘
```

## Query Building Flow

```
┌──────────────────┐
│  Build Query     │
│  ──────────────  │
│  TodoQuery()     │  1. Create query object
│    ..whereUserId(1)                     │  2. Add WHERE clause
│    ..whereCompleted(0)                  │  3. Add another WHERE
│    ..orderBy('dueDate', ascending: true)│  4. Add ORDER BY
│    ..limit(10)                          │  5. Add LIMIT
└────────┬─────────┘
         │
         │ passed to
         ▼
┌──────────────────────────────────────────┐
│  repo.getAll(query)                      │
└────────┬─────────────────────────────────┘
         │
         │ delegates to
         ▼
┌──────────────────────────────────────────┐
│  SqliteAdapter                           │
│  ───────────────────────────────          │
│  Translates to SQL:                      │
│                                          │
│  SELECT * FROM todos                     │
│  WHERE user_id = ? AND completed = ?     │
│  ORDER BY due_date ASC                   │
│  LIMIT 10                                │
└────────┬─────────────────────────────────┘
         │
         │ executes on
         ▼
┌──────────────────────────────────────────┐
│  SQLite Database                         │
└────────┬─────────────────────────────────┘
         │
         │ returns rows
         ▼
┌──────────────────────────────────────────┐
│  SqliteAdapter                           │
│  ───────────────────────────────          │
│  Maps rows to Todo objects               │
└────────┬─────────────────────────────────┘
         │
         │ returns
         ▼
┌──────────────────────────────────────────┐
│  List<Todo>                              │
│  ───────────────────────────────          │
│  [                                       │
│    Todo(id: 1, userId: 1, ...),          │
│    Todo(id: 2, userId: 1, ...),          │
│  ]                                       │
└──────────────────────────────────────────┘
```

## Key Components

### 1. Schema Layer
- **Purpose**: Define data structure
- **Files**: `lib/models/*.dart`
- **Generated**: `*.g.dart` (query builders, changesets via build_runner)

### 2. Migration Layer
- **Purpose**: Version database schema
- **Source**: `migrations/*.sql`
- **Generated**: `lib/migrations.dart` (via CLI, committed to source control)

### 3. Repository Layer
- **Purpose**: Business logic API
- **Package**: `strata`
- **Class**: `StrataRepo`

### 4. Adapter Layer
- **Purpose**: Database-specific operations
- **Package**: `strata_sqlite`
- **Class**: `SqliteAdapter`

### 5. Database Layer
- **Purpose**: Data persistence
- **Package**: `sqlite3`
- **Type**: SQLite

## Separation of Concerns

```
┌────────────────────────────────────────────┐
│  Application Logic (main.dart)            │  ◄─ What to do
├────────────────────────────────────────────┤
│  Repository (StrataRepo)                   │  ◄─ How to do it
├────────────────────────────────────────────┤
│  Adapter (SqliteAdapter)                   │  ◄─ Database-specific
├────────────────────────────────────────────┤
│  Database (SQLite)                         │  ◄─ Storage
└────────────────────────────────────────────┘
```

This architecture allows:
- **Swapping databases** - Change adapter, keep app logic
- **Testing** - Mock adapter for unit tests
- **Portability** - Write once, run on multiple databases
