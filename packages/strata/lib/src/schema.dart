/// A mixin that marks a class as a data model schema.
///
/// Applying this mixin to a class signals to the `strata` code generator
/// that it should produce helper code (e.g., query builders, changesets,
/// and mapping functions) for this entity.
///
/// The class must also be annotated with `@StrataSchema` to provide the
/// corresponding database table name.
///
/// ### Example
///
/// ```dart
/// @StrataSchema(table: 'users')
/// class User with Schema {
///   final int id;
///   final String username;
///
///   User({required this.id, required this.username});
/// }
/// ```
mixin Schema {}
