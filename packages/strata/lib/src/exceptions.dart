import 'package:strata/src/changeset.dart';

/// An exception thrown when a repository operation (e.g., `insert` or `update`)
/// is attempted with an invalid [Changeset].
///
/// This exception provides access to the `changeset` that failed validation,
/// allowing for detailed error reporting.
class ChangesetException implements Exception {
  /// The [Changeset] that caused the exception.
  final Changeset changeset;

  /// Creates a new [ChangesetException].
  const ChangesetException(this.changeset);

  @override
  String toString() {
    return 'ChangesetException: Validation failed. Errors: ${changeset.errors}';
  }
}
