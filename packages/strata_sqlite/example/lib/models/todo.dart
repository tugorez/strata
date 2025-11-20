import 'package:strata/strata.dart';
import 'user.dart';

part 'todo.g.dart';

/// Represents a todo item in the application.
@StrataSchema(table: 'todos')
class Todo with Schema {
  final int id;
  final int userId;
  final String title;
  final String? description;
  final int completed;
  final int? dueDate;
  final int createdAt;

  /// The user who owns this todo. This association is loaded when preloaded.
  @BelongsTo(User, foreignKey: 'user_id')
  User? user;

  Todo({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.completed,
    this.dueDate,
    required this.createdAt,
    this.user,
  });

  bool get isCompleted => completed == 1;

  @override
  String toString() {
    final status = isCompleted ? '✓' : '○';
    final due = dueDate != null
        ? ' (due: ${DateTime.fromMillisecondsSinceEpoch(dueDate!)})'
        : '';
    final owner = user != null ? ' [${user!.name}]' : '';
    return '$status Todo(id: $id, title: $title$due)$owner';
  }
}
