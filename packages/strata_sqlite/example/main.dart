import 'dart:io';
import 'package:strata/strata.dart';
import 'package:strata_sqlite/strata_sqlite.dart';

import 'lib/models/user.dart';
import 'lib/models/todo.dart';
import 'lib/migrations.dart';

/// A comprehensive example demonstrating all features of Strata with SQLite.
///
/// This example shows:
/// - Running migrations to set up the database schema
/// - Creating records with validated changesets
/// - Querying with filters, ordering, and limits
/// - Updating existing records
/// - Deleting records
/// - Error handling and validation
void main() async {
  print('🚀 Strata SQLite Todo App Example\n');
  print('=' * 60);

  // 1. Set up the database
  final adapter = await setupDatabase();
  final repo = StrataRepo(adapter: adapter);
  await repo.initialize();

  try {
    // 2. Create some users
    print('\n📝 Creating users...');
    final alice = await createUser(repo, 'Alice', 'alice@example.com');
    final bob = await createUser(repo, 'Bob', 'bob@example.com');
    print('✓ Created users: ${alice.name} and ${bob.name}');

    // 3. Show validation in action
    print('\n🔍 Demonstrating validation...');
    await demonstrateValidation(repo);

    // 4. Create todos for Alice
    print('\n📋 Creating todos for Alice...');
    final todo1 = await createTodo(
      repo,
      userId: alice.id,
      title: 'Buy groceries',
      description: 'Milk, eggs, bread',
      dueDate: DateTime.now().add(Duration(days: 1)),
    );
    final todo2 = await createTodo(
      repo,
      userId: alice.id,
      title: 'Finish project',
      description: 'Complete the Strata example app',
      dueDate: DateTime.now().add(Duration(days: 3)),
    );
    final todo3 = await createTodo(
      repo,
      userId: alice.id,
      title: 'Call dentist',
    );
    print('✓ Created ${[todo1, todo2, todo3].length} todos for Alice');

    // 5. Create todos for Bob
    print('\n📋 Creating todos for Bob...');
    await createTodo(
      repo,
      userId: bob.id,
      title: 'Read book',
      description: 'Finish reading Dart docs',
    );
    print('✓ Created todo for Bob');

    // 6. Query all todos
    print('\n📊 Querying all todos...');
    final allTodos = await repo.getAll(TodoQuery());
    print('✓ Found ${allTodos.length} total todos:');
    for (final todo in allTodos) {
      print('  $todo');
    }

    // 7. Query Alice's todos only
    print('\n🔎 Querying Alice\'s todos...');
    final aliceTodos = await repo.getAll(TodoQuery().whereUserId(alice.id));
    print('✓ Found ${aliceTodos.length} todos for Alice:');
    for (final todo in aliceTodos) {
      print('  $todo');
    }

    // 7. Query incomplete todos (without ordering for now)
    print('\n🔎 Querying incomplete todos...');
    final incompleteTodos = await repo.getAll(TodoQuery().whereCompleted(0));
    print('✓ Found ${incompleteTodos.length} incomplete todos:');
    for (final todo in incompleteTodos) {
      print('  $todo');
    }

    // 9. Complete a todo
    print('\n✅ Completing a todo...');
    await completeTodo(repo, todo1.id);
    final completedTodo = await repo.get(TodoQuery().whereId(todo1.id));
    print('✓ Completed: $completedTodo');

    // 10. Update a todo's title
    print('\n✏️  Updating a todo...');
    await updateTodo(repo, todo2.id, title: 'Finish Strata project (URGENT!)');
    final updatedTodo = await repo.get(TodoQuery().whereId(todo2.id));
    print('✓ Updated: $updatedTodo');

    // 11. Delete a todo
    print('\n🗑️  Deleting a todo...');
    final deletedCount = await repo.delete(TodoQuery().whereId(todo3.id));
    print('✓ Deleted $deletedCount todo(s)');

    // 12. Query final state
    print('\n📊 Final state - Alice\'s todos:');
    final finalTodos = await repo.getAll(TodoQuery().whereUserId(alice.id));
    for (final todo in finalTodos) {
      print('  $todo');
    }

    // 13. Count todos by user
    print('\n📈 Summary by user:');
    final users = await repo.getAll(UserQuery());
    for (final user in users) {
      final userTodos = await repo.getAll(TodoQuery().whereUserId(user.id));
      final completed = userTodos.where((t) => t.isCompleted).length;
      final incomplete = userTodos.length - completed;
      print('  ${user.name}: $completed completed, $incomplete incomplete');
    }

    // 14. Demonstrate transactions
    print('\n💼 Demonstrating transactions...');
    await demonstrateTransaction(repo, alice.id);

    // 15. Demonstrate association preloading (like Ecto)
    print('\n🔗 Demonstrating association preloading...');

    // HasMany: Load user with their todos
    print('  Loading user with preloaded todos (HasMany)...');
    final userWithTodos = await repo.get(
      UserQuery().whereId(alice.id).preloadTodos(),
    );
    if (userWithTodos != null && userWithTodos.todos != null) {
      print('  ✓ User: ${userWithTodos.name}');
      print('  ✓ Todos loaded: ${userWithTodos.todos!.length} todos');
      for (final todo in userWithTodos.todos!) {
        print('     - ${todo.title}');
      }
    } else {
      print('  ✗ Failed to load user with todos');
    }

    // BelongsTo: Load todos with their user
    print('\n  Loading todos with preloaded user (BelongsTo)...');
    final todosWithUser = await repo.getAll(
      TodoQuery().whereUserId(alice.id).preloadUser(),
    );
    print('  ✓ Loaded ${todosWithUser.length} todos with user info:');
    for (final todo in todosWithUser) {
      final ownerName = todo.user?.name ?? 'unknown';
      print('     - "${todo.title}" by $ownerName');
    }

    print('\n${'=' * 60}');
    print('✨ Example completed successfully!');
    print('=' * 60);
  } catch (e) {
    print('\n❌ Error: $e');
    rethrow;
  } finally {
    await repo.close();
  }
}

/// Sets up the database and runs migrations.
Future<SqliteAdapter> setupDatabase() async {
  final dbPath = 'example_todo.db';

  // Delete existing database for fresh start
  final dbFile = File(dbPath);
  if (await dbFile.exists()) {
    await dbFile.delete();
    print('🗑️  Deleted existing database');
  }

  print('📂 Opening database: $dbPath');

  // Create adapter and initialize
  final adapter = SqliteAdapter(path: dbPath);
  await adapter.initialize();

  // Run migrations
  print('🔄 Running migrations...');
  final runner = SqlMigrationRunner(execute: adapter.executor);
  await runner.run(Migrations.all);
  print('✓ Migrations completed');

  return adapter;
}

/// Creates a new user with validation.
Future<User> createUser(StrataRepo repo, String name, String email) async {
  final changeset =
      UserChangeset({
          'name': name,
          'email': email,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        })
        ..cast(['name', 'email', 'created_at'])
        ..validateRequired('name')
        ..validateRequired('email')
        ..validateLength('name', min: 2, max: 50)
        ..validateLength('email', min: 5, max: 100);

  if (!changeset.isValid) {
    throw Exception('Invalid user data: ${changeset.errors}');
  }

  return await repo.insert(changeset);
}

/// Creates a new todo with validation.
Future<Todo> createTodo(
  StrataRepo repo, {
  required int userId,
  required String title,
  String? description,
  DateTime? dueDate,
}) async {
  final params = {
    'user_id': userId,
    'title': title,
    'description': description,
    'completed': 0,
    'due_date': dueDate?.millisecondsSinceEpoch,
    'created_at': DateTime.now().millisecondsSinceEpoch,
  };

  final changeset = TodoChangeset(params)
    ..cast([
      'user_id',
      'title',
      'description',
      'completed',
      'due_date',
      'created_at',
    ])
    ..validateRequired('user_id')
    ..validateRequired('title')
    ..validateLength('title', min: 1, max: 200);

  if (description != null && description.isNotEmpty) {
    changeset.validateLength('description', max: 1000);
  }

  if (!changeset.isValid) {
    throw Exception('Invalid todo data: ${changeset.errors}');
  }

  return await repo.insert(changeset);
}

/// Demonstrates validation errors.
Future<void> demonstrateValidation(StrataRepo repo) async {
  // Try to create a user with invalid data
  final invalidChangeset =
      UserChangeset({
          'name': 'A', // Too short
          'email': 'bad', // Too short
        })
        ..cast(['name', 'email'])
        ..validateRequired('name')
        ..validateRequired('email')
        ..validateLength('name', min: 2, max: 50)
        ..validateLength('email', min: 5, max: 100);

  if (!invalidChangeset.isValid) {
    print('  ✗ Validation failed (as expected):');
    invalidChangeset.errors.forEach((field, errors) {
      print('    - $field: ${errors.join(", ")}');
    });
  }

  // Try to insert anyway (will throw)
  try {
    await repo.insert(invalidChangeset);
    print('  ✗ Should have thrown validation error!');
  } on ChangesetException catch (e) {
    print('  ✓ ChangesetException caught correctly');
    print('    $e');
  }
}

/// Marks a todo as completed.
Future<void> completeTodo(StrataRepo repo, int todoId) async {
  final changeset = TodoChangeset({'completed': 1})..cast(['completed']);

  await repo.update(TodoQuery().whereId(todoId), changeset);
}

/// Updates a todo's title.
Future<void> updateTodo(
  StrataRepo repo,
  int todoId, {
  required String title,
}) async {
  final changeset = TodoChangeset({'title': title})
    ..cast(['title'])
    ..validateRequired('title')
    ..validateLength('title', min: 1, max: 200);

  if (!changeset.isValid) {
    throw Exception('Invalid title: ${changeset.errors}');
  }

  await repo.update(TodoQuery().whereId(todoId), changeset);
}

/// Demonstrates transaction support with atomic operations.
Future<void> demonstrateTransaction(StrataRepo repo, int userId) async {
  print('  Creating two todos atomically in a transaction...');

  // This transaction will succeed - both todos created together
  final todosCreated = await repo.transaction(() async {
    final todo1 = await repo.insert(
      TodoChangeset({
        'user_id': userId,
        'title': 'Transaction Todo 1',
        'completed': 0,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      })..cast(['user_id', 'title', 'completed', 'created_at']),
    );

    final todo2 = await repo.insert(
      TodoChangeset({
        'user_id': userId,
        'title': 'Transaction Todo 2',
        'completed': 0,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      })..cast(['user_id', 'title', 'completed', 'created_at']),
    );

    return [todo1, todo2];
  });

  print('  ✓ Created ${todosCreated.length} todos in transaction');

  // Demonstrate rollback - this transaction will fail
  print('  Attempting transaction that will fail and rollback...');
  final countBefore = (await repo.getAll(TodoQuery())).length;

  try {
    await repo.transaction(() async {
      // This insert will succeed initially
      await repo.insert(
        TodoChangeset({
          'user_id': userId,
          'title': 'This should be rolled back',
          'completed': 0,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        })..cast(['user_id', 'title', 'completed', 'created_at']),
      );

      // But then we throw an error
      throw Exception('Simulated failure - rolling back!');
    });
  } catch (e) {
    print('  ✓ Transaction failed as expected: $e');
  }

  final countAfter = (await repo.getAll(TodoQuery())).length;
  if (countBefore == countAfter - 2) {
    // +2 from the successful transaction above
    print('  ✓ Rollback confirmed - todo was not persisted');
  }
}
