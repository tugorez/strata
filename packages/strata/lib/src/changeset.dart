import 'package:strata/src/schema.dart';

/// A mechanism for validating and casting untrusted data before it is persisted.
///
/// Changesets provide a fluent API for defining a pipeline of validations
/// and transformations to be applied to a `Map` of parameters. Following Ecto's
/// philosophy, you first **cast** (whitelist) fields, then **validate** them.
///
/// ## Usage
///
/// ```dart
/// final changeset = UserChangeset(params)
///   ..cast(['username', 'email', 'age'])      // Whitelist allowed fields
///   ..validateRequired(['username', 'email']) // Validate required fields
///   ..validateLength('username', min: 3);     // Add other validations
///
/// if (changeset.isValid) {
///   final user = await repo.insert(changeset);
/// }
/// ```
///
/// The [cast] step ensures only explicitly allowed fields from the untrusted
/// [params] map make it into the [changes] map, providing a security layer.
class Changeset<T extends Schema> {
  /// The database table this changeset targets.
  final String table;

  /// The untrusted data, typically from a form or JSON payload.
  final Map<String, dynamic> params;

  /// A factory function to build the model object [T] on success.
  final T Function(Map<String, dynamic>) fromMap;

  /// The sanitized data that has been cast and validated.
  final Map<String, dynamic> _changes = {};

  /// A map of validation errors, where the key is the field name.
  final Map<String, List<String>> _errors = {};

  /// Creates a new [Changeset] for the given [params].
  Changeset(this.params, {required this.table, required this.fromMap});

  /// An unmodifiable view of the sanitized data that has been cast and validated.
  Map<String, dynamic> get changes => Map.unmodifiable(_changes);

  /// An unmodifiable view of the validation errors.
  Map<String, List<String>> get errors => Map.unmodifiable(_errors);

  /// Whether the changeset is valid (i.e., has no errors).
  bool get isValid => _errors.isEmpty;

  /// Adds a validation error for a given [field].
  ///
  /// This also removes the [field] from the [_changes] map to prevent it
  /// from being persisted.
  void _addError(String field, String message) {
    _changes.remove(field);
    _errors.putIfAbsent(field, () => []).add(message);
  }

  // --- Casting & Validation Helpers ---

  /// Casts (whitelists) the specified [fields] from [params] into [changes].
  ///
  /// This is the Ecto-style first step: explicitly declare which fields
  /// you want to allow from the untrusted params map. Only the fields
  /// listed here will be copied into the [changes] map, making it safe
  /// to then run validations.
  ///
  /// Example:
  /// ```dart
  /// final changeset = UserChangeset(params)
  ///   ..cast(['username', 'email', 'age'])
  ///   ..validateRequired(['username', 'email'])
  ///   ..validateLength('username', min: 3);
  /// ```
  ///
  /// Returns the [Changeset] instance for method chaining.
  Changeset<T> cast(List<String> fields) {
    for (final field in fields) {
      if (params.containsKey(field)) {
        _changes[field] = params[field];
      }
    }
    return this;
  }

  /// Validates that the specified [field] is present and not empty.
  ///
  /// This validation operates on fields that have already been cast into
  /// the [changes] map. If the field is missing from [changes], or if its
  /// value is `null` or an empty string, an error message is added.
  ///
  /// For backward compatibility, if the field is not in [changes] but exists
  /// in [params], it will be cast automatically. However, the preferred
  /// Ecto-style approach is to call [cast] first, then [validateRequired].
  ///
  /// Returns the [Changeset] instance for method chaining.
  Changeset<T> validateRequired(String field) {
    // Backward compatibility: if field isn't cast yet, try to cast it from params
    if (!_changes.containsKey(field) && params.containsKey(field)) {
      _changes[field] = params[field];
    }

    final value = _changes[field];
    if (value == null || (value is String && value.isEmpty)) {
      _addError(field, 'is required');
    }
    return this;
  }

  /// Validates the length of a string [field] that has already been cast.
  ///
  /// This validation only runs if the [field] is already present in the [changes] map.
  ///
  /// - If [min] is provided, the string's length must be at least [min].
  /// - If [max] is provided, the string's length must be at most [max].
  ///
  /// If the field is not a string or fails length validation, an error message is added.
  /// Returns the [Changeset] instance for method chaining.
  Changeset<T> validateLength(String field, {int? min, int? max}) {
    if (!_changes.containsKey(field)) return this; // Only validate if cast

    final value = _changes[field];
    if (value is! String) {
      _addError(field, 'must be a string');
      return this;
    }
    if (min != null && value.length < min) {
      _addError(field, 'must be at least $min characters');
    }
    if (max != null && value.length > max) {
      _addError(field, 'must be at most $max characters');
    }
    return this;
  }
}
