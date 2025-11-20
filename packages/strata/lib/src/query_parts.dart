/// Lightweight data classes used to compose a [Query].
///
/// These classes represent individual components of a query, such as `WHERE`
/// and `ORDER BY` clauses. They are assembled into a `Query` object, which is
/// then translated by a `StrataAdapter` into a platform-specific query.
library;

/// Represents a single `WHERE` clause in a query.
class WhereClause {
  /// The database field to apply the condition to.
  final String field;

  /// The comparison operator (e.g., "=", ">", "IN").
  final String operator;

  /// The value to compare against.
  final dynamic value;

  /// Creates a [WhereClause] with a given [field], [operator], and [value].
  WhereClause(this.field, this.operator, this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WhereClause &&
          runtimeType == other.runtimeType &&
          field == other.field &&
          operator == other.operator &&
          value == other.value;

  @override
  int get hashCode => Object.hash(field, operator, value);
}

/// Represents a single `ORDER BY` clause in a query.
class OrderByClause {
  /// The database field to order by.
  final String field;

  /// The sort direction. `true` for ascending, `false` for descending.
  final bool ascending;

  /// Creates an [OrderByClause] for a given [field].
  ///
  /// Defaults to ascending order.
  OrderByClause(this.field, {this.ascending = true});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderByClause &&
          runtimeType == other.runtimeType &&
          field == other.field &&
          ascending == other.ascending;

  @override
  int get hashCode => Object.hash(field, ascending);
}
