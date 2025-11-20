import 'package:strata/strata.dart';
import 'todo.dart';

part 'user.g.dart';

/// Represents a user in the todo application.
@StrataSchema(table: 'users')
class User with Schema {
  final int id;
  final String name;
  final String email;
  final int createdAt;

  /// The user's todos. This association is loaded when preloaded.
  @HasMany(Todo, foreignKey: 'user_id')
  List<Todo>? todos;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.createdAt,
    this.todos,
  });

  @override
  String toString() => 'User(id: $id, name: $name, email: $email)';
}
