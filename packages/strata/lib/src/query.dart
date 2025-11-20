import 'package:meta/meta.dart';
import 'package:strata/src/schema.dart';
import 'package:strata/src/query_parts.dart';

/// An abstract, database-agnostic representation of a database query.
///
/// A [Query] object holds all the information necessary to retrieve data,
/// such as the target [table], `WHERE` clauses, and `ORDER BY` clauses.
/// It is constructed by generated query builder classes and then passed to a
/// [StrataAdapter], which translates it into a native database query (e.g., SQL).
///
/// Query objects are immutable. Each method that adds a condition returns a
/// new [Query] instance with the updated state, making queries composable
/// and reusable without side effects.
class Query<T extends Schema> {
  /// The name of the table to query.
  final String table;

  /// A factory function that can build a model of type [T] from a database map.
  /// This is typically provided by the code generator.
  final T Function(Map<String, dynamic>) fromMap;

  /// The list of `WHERE` clauses for this query.
  final List<WhereClause> whereClauses;

  /// The list of `ORDER BY` clauses for this query.
  final List<OrderByClause> orderByClauses;

  /// The maximum number of records to return. A `null` value means no limit.
  final int? limitCount;

  /// The list of associations to preload.
  final List<String> preloadAssociations;

  /// Creates a new [Query] for a given [table] and [fromMap] factory.
  Query(this.table, this.fromMap)
    : whereClauses = [],
      orderByClauses = [],
      limitCount = null,
      preloadAssociations = [];

  /// Internal constructor for creating a copy of a query with modified state.
  /// This constructor is used by generated query classes.
  @protected
  Query.copy({
    required this.table,
    required this.fromMap,
    required this.whereClauses,
    required this.orderByClauses,
    required this.limitCount,
    required this.preloadAssociations,
  });

  /// Creates a new [Query] with an additional WHERE clause.
  ///
  /// This method is intended for use by generated query classes only.
  /// Do not call this method directly.
  @protected
  Query<T> copyWithWhereClause(WhereClause clause) {
    return Query.copy(
      table: table,
      fromMap: fromMap,
      whereClauses: [...whereClauses, clause],
      orderByClauses: orderByClauses,
      limitCount: limitCount,
      preloadAssociations: preloadAssociations,
    );
  }

  /// Creates a new [Query] with an additional ORDER BY clause.
  ///
  /// This method is intended for use by generated query classes only.
  /// Do not call this method directly.
  @protected
  Query<T> copyWithOrderByClause(OrderByClause clause) {
    return Query.copy(
      table: table,
      fromMap: fromMap,
      whereClauses: whereClauses,
      orderByClauses: [...orderByClauses, clause],
      limitCount: limitCount,
      preloadAssociations: preloadAssociations,
    );
  }

  /// Creates a new [Query] with a modified limit.
  ///
  /// This method is intended for use by generated query classes only.
  /// Do not call this method directly.
  @protected
  Query<T> copyWithLimit(int? limit) {
    return Query.copy(
      table: table,
      fromMap: fromMap,
      whereClauses: whereClauses,
      orderByClauses: orderByClauses,
      limitCount: limit,
      preloadAssociations: preloadAssociations,
    );
  }

  /// Creates a new [Query] with an additional association to preload.
  ///
  /// This method is intended for use by generated query classes only.
  /// Do not call this method directly.
  @protected
  Query<T> copyWithPreload(String association) {
    return Query.copy(
      table: table,
      fromMap: fromMap,
      whereClauses: whereClauses,
      orderByClauses: orderByClauses,
      limitCount: limitCount,
      preloadAssociations: [...preloadAssociations, association],
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Query<T>) return false;
    if (runtimeType != other.runtimeType) return false;
    if (table != other.table) return false;
    if (limitCount != other.limitCount) return false;

    // Compare whereClauses
    if (whereClauses.length != other.whereClauses.length) return false;
    for (var i = 0; i < whereClauses.length; i++) {
      if (whereClauses[i] != other.whereClauses[i]) return false;
    }

    // Compare orderByClauses
    if (orderByClauses.length != other.orderByClauses.length) return false;
    for (var i = 0; i < orderByClauses.length; i++) {
      if (orderByClauses[i] != other.orderByClauses[i]) return false;
    }

    // Compare preloadAssociations
    if (preloadAssociations.length != other.preloadAssociations.length) {
      return false;
    }
    for (var i = 0; i < preloadAssociations.length; i++) {
      if (preloadAssociations[i] != other.preloadAssociations[i]) return false;
    }

    return true;
  }

  @override
  int get hashCode {
    var hash = Object.hash(
      table,
      limitCount,
      whereClauses.length,
      orderByClauses.length,
      preloadAssociations.length,
    );
    // Include first few clauses in hash for better distribution
    if (whereClauses.isNotEmpty) {
      hash = Object.hash(hash, whereClauses.first);
    }
    if (orderByClauses.isNotEmpty) {
      hash = Object.hash(hash, orderByClauses.first);
    }
    if (preloadAssociations.isNotEmpty) {
      hash = Object.hash(hash, preloadAssociations.first);
    }
    return hash;
  }
}
