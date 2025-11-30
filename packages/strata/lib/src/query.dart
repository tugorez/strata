import 'package:meta/meta.dart';
import 'package:strata/src/schema.dart';
import 'package:strata/src/query_parts.dart';

/// The type of association between two schemas.
enum AssociationType {
  /// A has-many relationship (e.g., User has many Todos).
  hasMany,

  /// A belongs-to relationship (e.g., Todo belongs to User).
  belongsTo,

  /// A has-one relationship (e.g., User has one Profile).
  hasOne,
}

/// Metadata about an association between two schemas.
///
/// This class holds all the information needed to load an association,
/// including the related table, foreign key, and how to construct the
/// related query.
///
/// The type parameter [T] represents the type of the *related* schema
/// (the one being loaded), not the parent schema.
class AssociationInfo<T extends Schema> {
  /// The name of the field on the parent schema that holds this association.
  final String fieldName;

  /// The type of association (hasMany, belongsTo, hasOne).
  final AssociationType type;

  /// The name of the related table.
  final String relatedTable;

  /// The foreign key column name (snake_case).
  final String foreignKey;

  /// The foreign key field name (camelCase) on the schema that contains the FK.
  /// For HasMany/HasOne, this is on the related schema.
  /// For BelongsTo, this is on the parent schema.
  final String foreignKeyField;

  /// A factory function that creates a query for the related schema.
  final Query<T> Function() queryFactory;

  /// A factory function that creates a model from a database map.
  final T Function(Map<String, dynamic>) fromMap;

  /// A function to get the foreign key value from an object.
  /// For HasMany/HasOne, extracts the FK from related objects.
  /// For BelongsTo, extracts the FK from parent objects.
  final dynamic Function(dynamic obj) getForeignKeyValue;

  /// A function to get the primary key (id) from an object.
  final dynamic Function(dynamic obj) getPrimaryKeyValue;

  /// A function to copy a parent object with a new association value.
  /// Returns the parent object with the association field populated.
  /// The return type is dynamic because the parent type varies.
  final dynamic Function(dynamic obj, dynamic value) copyWithAssociation;

  /// Creates a new [AssociationInfo].
  const AssociationInfo({
    required this.fieldName,
    required this.type,
    required this.relatedTable,
    required this.foreignKey,
    required this.foreignKeyField,
    required this.queryFactory,
    required this.fromMap,
    required this.getForeignKeyValue,
    required this.getPrimaryKeyValue,
    required this.copyWithAssociation,
  });
}

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

  /// The list of association names to preload (for backward compatibility).
  final List<String> preloadAssociations;

  /// The list of associations with full metadata to preload.
  final List<AssociationInfo> associationsToPreload;

  /// Creates a new [Query] for a given [table] and [fromMap] factory.
  Query(this.table, this.fromMap)
    : whereClauses = [],
      orderByClauses = [],
      limitCount = null,
      preloadAssociations = [],
      associationsToPreload = [];

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
    List<AssociationInfo>? associationsToPreload,
  }) : associationsToPreload = associationsToPreload ?? [];

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
      associationsToPreload: associationsToPreload,
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
      associationsToPreload: associationsToPreload,
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
      associationsToPreload: associationsToPreload,
    );
  }

  /// Creates a new [Query] with an additional association to preload (legacy).
  ///
  /// This method is deprecated. Use [copyWithAssociationPreload] instead.
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
      associationsToPreload: associationsToPreload,
    );
  }

  /// Creates a new [Query] with an additional association to preload.
  ///
  /// This method is intended for use by generated query classes only.
  /// Do not call this method directly.
  @protected
  Query<T> copyWithAssociationPreload(AssociationInfo association) {
    return Query.copy(
      table: table,
      fromMap: fromMap,
      whereClauses: whereClauses,
      orderByClauses: orderByClauses,
      limitCount: limitCount,
      preloadAssociations: [...preloadAssociations, association.fieldName],
      associationsToPreload: [...associationsToPreload, association],
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
