import 'package:strata/src/strata_adapter.dart';
import 'package:strata/src/query.dart';
import 'package:strata/src/changeset.dart';
import 'package:strata/src/schema.dart';
import 'package:strata/src/exceptions.dart';
import 'package:strata/src/query_parts.dart';

/// The main public API for interacting with the database.
///
/// `StrataRepo` provides a type-safe, database-agnostic interface for all
/// CRUD (Create, Read, Update, Delete) operations. It coordinates the
/// underlying [StrataAdapter] and handles the mapping between raw database
/// records and your `Schema` objects.
///
/// ## Separation of Concerns
///
/// The repository is responsible for **business logic and data operations** only.
/// Schema management (migrations) should be handled separately using
/// migration-specific tools like `SqlMigrationRunner`.
class StrataRepo {
  final StrataAdapter _adapter;

  /// Creates a new [StrataRepo] instance.
  ///
  /// - [adapter]: The database-specific adapter that will handle all raw
  ///   database operations.
  StrataRepo({required StrataAdapter adapter}) : _adapter = adapter;

  /// Initializes the underlying adapter.
  ///
  /// This method must be called before any other operations are performed.
  /// It ensures the database connection is open and ready.
  Future<void> initialize() => _adapter.initialize();

  /// Closes the adapter's underlying database connection.
  Future<void> close() => _adapter.close();

  /// Retrieves a single record matching the [query].
  ///
  /// Returns the mapped `Schema` object of type [T] if a record is found,
  /// otherwise returns `null`.
  ///
  /// If the [query] includes preload associations, they will be loaded
  /// and populated on the returned object.
  Future<T?> get<T extends Schema>(Query<T> query) async {
    final map = await _adapter.getOne(query);
    if (map == null) return null;

    var result = query.fromMap(map);

    // Preload associations if any
    if (query.associationsToPreload.isNotEmpty) {
      final results = [result];
      await _preloadAssociations(results, query);
      result = results.first;
    }

    return result;
  }

  /// Retrieves all records matching the [query].
  ///
  /// Returns a `List` of mapped `Schema` objects of type [T].
  ///
  /// If the [query] includes preload associations, they will be loaded
  /// and populated on all returned objects.
  Future<List<T>> getAll<T extends Schema>(Query<T> query) async {
    final maps = await _adapter.getAll(query);
    final results = maps.map((map) => query.fromMap(map)).toList();

    // Preload associations if any
    if (query.associationsToPreload.isNotEmpty) {
      await _preloadAssociations(results, query);
    }

    return results;
  }

  /// Preloads associations for a list of schema objects.
  ///
  /// This method iterates through each association marked for preloading
  /// and loads the related data. For `HasMany` and `HasOne` associations,
  /// it queries the related table using the foreign key. For `BelongsTo`
  /// associations, it queries the parent table by ID.
  ///
  /// The loaded associations are then populated onto the result objects
  /// using the generated `copyWith` extension methods.
  Future<void> _preloadAssociations<T extends Schema>(
    List<T> results,
    Query<T> query,
  ) async {
    if (results.isEmpty) return;

    for (final association in query.associationsToPreload) {
      switch (association.type) {
        case AssociationType.hasMany:
          await _preloadHasMany(results, association);
        case AssociationType.hasOne:
          await _preloadHasOne(results, association);
        case AssociationType.belongsTo:
          await _preloadBelongsTo(results, association);
      }
    }
  }

  /// Preloads a has-many association.
  ///
  /// For each parent object, loads all related child objects where
  /// the foreign key matches the parent's ID.
  Future<void> _preloadHasMany<T extends Schema>(
    List<T> results,
    AssociationInfo association,
  ) async {
    // Get all parent IDs using the association's getPrimaryKeyValue function
    final parentIds = results
        .map((r) => association.getPrimaryKeyValue(r))
        .toList();
    if (parentIds.isEmpty) return;

    // Build a query for the related table
    final relatedQuery = association.queryFactory();
    final queryWithWhere = Query.copy(
      table: relatedQuery.table,
      fromMap: relatedQuery.fromMap,
      whereClauses: [WhereClause(association.foreignKey, 'IN', parentIds)],
      orderByClauses: relatedQuery.orderByClauses,
      limitCount: null,
      preloadAssociations: [],
    );

    // Load all related records
    final relatedMaps = await _adapter.getAll(queryWithWhere);
    final relatedRecords = relatedMaps
        .map((m) => association.fromMap(m))
        .toList();

    // Group related records by foreign key value
    final recordsByParentId = <dynamic, List<Schema>>{};
    for (final record in relatedRecords) {
      // Get the foreign key value from the related record
      final fkValue = association.getForeignKeyValue(record);
      recordsByParentId.putIfAbsent(fkValue, () => []).add(record);
    }

    // Populate each parent with its related records
    for (var i = 0; i < results.length; i++) {
      final parent = results[i];
      final parentId = association.getPrimaryKeyValue(parent);
      final relatedList = recordsByParentId[parentId] ?? [];

      // Use copyWithAssociation to set the association field
      results[i] = association.copyWithAssociation(parent, relatedList) as T;
    }
  }

  /// Preloads a has-one association.
  ///
  /// For each parent object, loads the single related child object where
  /// the foreign key matches the parent's ID.
  Future<void> _preloadHasOne<T extends Schema>(
    List<T> results,
    AssociationInfo association,
  ) async {
    // Get all parent IDs
    final parentIds = results
        .map((r) => association.getPrimaryKeyValue(r))
        .toList();
    if (parentIds.isEmpty) return;

    // Build a query for the related table
    final relatedQuery = association.queryFactory();
    final queryWithWhere = Query.copy(
      table: relatedQuery.table,
      fromMap: relatedQuery.fromMap,
      whereClauses: [WhereClause(association.foreignKey, 'IN', parentIds)],
      orderByClauses: relatedQuery.orderByClauses,
      limitCount: null,
      preloadAssociations: [],
    );

    // Load all related records
    final relatedMaps = await _adapter.getAll(queryWithWhere);
    final relatedRecords = relatedMaps
        .map((m) => association.fromMap(m))
        .toList();

    // Map related records by foreign key value
    final recordByParentId = <dynamic, Schema>{};
    for (final record in relatedRecords) {
      final fkValue = association.getForeignKeyValue(record);
      recordByParentId[fkValue] = record;
    }

    // Populate each parent with its related record
    for (var i = 0; i < results.length; i++) {
      final parent = results[i];
      final parentId = association.getPrimaryKeyValue(parent);
      final related = recordByParentId[parentId];

      if (related != null) {
        results[i] = association.copyWithAssociation(parent, related) as T;
      }
    }
  }

  /// Preloads a belongs-to association.
  ///
  /// For each child object, loads the parent object where
  /// the parent's ID matches the child's foreign key value.
  Future<void> _preloadBelongsTo<T extends Schema>(
    List<T> results,
    AssociationInfo association,
  ) async {
    // Get all foreign key values from the children
    // For BelongsTo, the FK is on the current schema (child)
    final parentIds = results
        .map((r) => association.getForeignKeyValue(r))
        .toSet()
        .toList();
    if (parentIds.isEmpty) return;

    // Build a query for the parent table
    final relatedQuery = association.queryFactory();
    final queryWithWhere = Query.copy(
      table: relatedQuery.table,
      fromMap: relatedQuery.fromMap,
      whereClauses: [WhereClause('id', 'IN', parentIds)],
      orderByClauses: relatedQuery.orderByClauses,
      limitCount: null,
      preloadAssociations: [],
    );

    // Load all parent records
    final relatedMaps = await _adapter.getAll(queryWithWhere);
    final relatedRecords = relatedMaps
        .map((m) => association.fromMap(m))
        .toList();

    // Map parent records by ID
    final recordById = <dynamic, Schema>{};
    for (final record in relatedRecords) {
      final id = association.getPrimaryKeyValue(record);
      recordById[id] = record;
    }

    // Populate each child with its parent
    for (var i = 0; i < results.length; i++) {
      final child = results[i];
      final fkValue = association.getForeignKeyValue(child);
      final parent = recordById[fkValue];

      if (parent != null) {
        results[i] = association.copyWithAssociation(child, parent) as T;
      }
    }
  }

  /// Inserts a new record using the data from a [changeset].
  ///
  /// If the [changeset] is invalid, a [ChangesetException] is thrown.
  ///
  /// On success, returns the newly created and mapped `Schema` object of type [T],
  /// including any values generated by the database (like a primary key).
  Future<T> insert<T extends Schema>(Changeset<T> changeset) async {
    if (!changeset.isValid) {
      throw ChangesetException(changeset);
    }
    final map = await _adapter.insert(changeset.table, changeset.changes);
    return changeset.fromMap(map);
  }

  /// Updates records matching the [query] with data from the [changeset].
  ///
  /// If the [changeset] is invalid, a [ChangesetException] is thrown.
  ///
  /// Returns a list of updated `Schema` objects of type [T]. The list may be
  /// empty if no records matched the query.
  ///
  /// Example:
  /// ```dart
  /// final query = UserQuery()..whereId(1);
  /// final changeset = UserChangeset({'email': 'newemail@example.com'})
  ///   ..validateRequired('email')
  ///   ..validateFormat('email', emailRegex);
  ///
  /// if (changeset.isValid) {
  ///   final updated = await repo.update(query, changeset);
  ///   print('Updated ${updated.length} users');
  /// }
  /// ```
  Future<List<T>> update<T extends Schema>(
    Query<T> query,
    Changeset<T> changeset,
  ) async {
    if (!changeset.isValid) {
      throw ChangesetException(changeset);
    }
    final maps = await _adapter.update(query, changeset.changes);
    return maps.map((map) => query.fromMap(map)).toList();
  }

  /// Deletes all records matching the [query].
  ///
  /// Returns the number of records deleted.
  ///
  /// Example:
  /// ```dart
  /// // Delete a specific user
  /// final query = UserQuery()..whereId(1);
  /// final count = await repo.delete(query);
  /// print('Deleted $count users');
  ///
  /// // Delete all inactive users
  /// final inactiveQuery = UserQuery()..whereActive(false);
  /// await repo.delete(inactiveQuery);
  /// ```
  Future<int> delete<T extends Schema>(Query<T> query) async {
    return await _adapter.delete(query);
  }

  /// Executes a function within a database transaction.
  ///
  /// A transaction ensures that all operations succeed together or none
  /// of them take effect. This is essential for maintaining data consistency
  /// when performing multiple related operations.
  ///
  /// If [callback] completes successfully, the transaction is committed.
  /// If an error is thrown, the transaction is automatically rolled back
  /// and the error is rethrown.
  ///
  /// Example:
  /// ```dart
  /// // Transfer money between accounts atomically
  /// final result = await repo.transaction(() async {
  ///   // Deduct from source account
  ///   final sourceQuery = AccountQuery()..whereId(sourceId);
  ///   final sourceChangeset = AccountChangeset({'balance': sourceBalance - amount});
  ///   await repo.update(sourceQuery, sourceChangeset);
  ///
  ///   // Add to destination account
  ///   final destQuery = AccountQuery()..whereId(destId);
  ///   final destChangeset = AccountChangeset({'balance': destBalance + amount});
  ///   await repo.update(destQuery, destChangeset);
  ///
  ///   return 'Transfer complete';
  /// });
  /// ```
  Future<T> transaction<T>(Future<T> Function() callback) async {
    await _adapter.beginTransaction();
    try {
      final result = await callback();
      await _adapter.commit();
      return result;
    } catch (e) {
      await _adapter.rollback();
      rethrow;
    }
  }
}
