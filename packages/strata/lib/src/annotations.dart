/// An annotation to mark a class as a Strata data model.
///
/// When a class is annotated with `@StrataSchema`, the `strata` code generator
/// will produce helper classes for it, including a query builder, a changeset,
/// and a mapping function.
///
/// The associated database [table] name must be provided.
///
/// ### Example
///
/// ```dart
/// @StrataSchema(table: 'accounts')
/// class Account with Schema {
///   // ... fields and constructor
/// }
/// ```
class StrataSchema {
  /// The name of the database table that this schema maps to.
  final String table;

  /// Creates a new [StrataSchema] annotation.
  const StrataSchema({required this.table});
}

/// An annotation to define a has-many relationship between two schemas.
///
/// Use this annotation on a field to indicate that this schema has many
/// instances of another schema. Similar to Ecto's `has_many` association.
///
/// ### Example
///
/// ```dart
/// @StrataSchema(table: 'users')
/// class User with Schema {
///   final int id;
///   final String name;
///
///   @HasMany(Todo, foreignKey: 'user_id')
///   List<Todo>? todos;
/// }
/// ```
class HasMany {
  /// The type of the associated schema.
  final Type type;

  /// The foreign key column in the associated table.
  final String foreignKey;

  /// Creates a new [HasMany] annotation.
  const HasMany(this.type, {required this.foreignKey});
}

/// An annotation to define a belongs-to relationship between two schemas.
///
/// Use this annotation on a field to indicate that this schema belongs to
/// another schema. Similar to Ecto's `belongs_to` association.
///
/// ### Example
///
/// ```dart
/// @StrataSchema(table: 'todos')
/// class Todo with Schema {
///   final int id;
///   final int userId;
///   final String title;
///
///   @BelongsTo(User, foreignKey: 'user_id')
///   User? user;
/// }
/// ```
class BelongsTo {
  /// The type of the associated schema.
  final Type type;

  /// The foreign key column in this table.
  final String foreignKey;

  /// Creates a new [BelongsTo] annotation.
  const BelongsTo(this.type, {required this.foreignKey});
}

/// An annotation to define a has-one relationship between two schemas.
///
/// Use this annotation on a field to indicate that this schema has one
/// instance of another schema. Similar to Ecto's `has_one` association.
///
/// ### Example
///
/// ```dart
/// @StrataSchema(table: 'users')
/// class User with Schema {
///   final int id;
///   final String name;
///
///   @HasOne(Profile, foreignKey: 'user_id')
///   Profile? profile;
/// }
/// ```
class HasOne {
  /// The type of the associated schema.
  final Type type;

  /// The foreign key column in the associated table.
  final String foreignKey;

  /// Creates a new [HasOne] annotation.
  const HasOne(this.type, {required this.foreignKey});
}

/// An annotation to mark a `DateTime` field as a high-precision timestamp.
///
/// When a field is annotated with `@Timestamp()`, the code generator will
/// map it to two database columns: `{field_name}_seconds` and `{field_name}_nanos`.
/// This provides nanosecond precision for timestamps.
///
/// The seconds column stores seconds since Unix epoch (UTC).
/// The nanos column stores the nanoseconds component (0-999,999,999).
///
/// ### Example
///
/// ```dart
/// @StrataSchema(table: 'posts')
/// class Post with Schema {
///   final int id;
///   final String title;
///
///   @Timestamp()
///   final DateTime createdAt;
///
///   @Timestamp()
///   final DateTime updatedAt;
///
///   Post({
///     required this.id,
///     required this.title,
///     required this.createdAt,
///     required this.updatedAt,
///   });
/// }
/// ```
///
/// This will generate code that:
/// - Reads from `created_at_seconds` and `created_at_nanos` columns
/// - Reads from `updated_at_seconds` and `updated_at_nanos` columns
/// - Converts them to/from `DateTime` objects in UTC
class Timestamp {
  /// Creates a new [Timestamp] annotation.
  const Timestamp();
}
