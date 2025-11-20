# Immutable Query Builder

The Strata query builder is immutable, following the Ecto philosophy. Every method call returns a new `Query` instance with the updated state, making queries composable and reusable without side effects.

## Benefits

### 1. Composable Queries

You can build base queries and extend them without modifying the original:

```dart
// Create a base query for active users
final activeUsers = UserQuery().whereActive(true);

// Branch from the base query - activeUsers is not modified
final activeAdmins = activeUsers.whereRole('admin');
final activeGuests = activeUsers.whereRole('guest');

// activeUsers still only has one where clause
print(activeUsers.whereClauses.length); // 1
print(activeAdmins.whereClauses.length); // 2
print(activeGuests.whereClauses.length); // 2
```

### 2. Reusable Query Fragments

Build reusable query fragments that can be combined:

```dart
// Common query fragments
final recentItems = ItemQuery().whereDateGreaterThan(DateTime.now().subtract(Duration(days: 7)));
final expensiveItems = ItemQuery().wherePriceGreaterThan(100.0);

// Combine them in different ways
final recentAndExpensive = recentItems.wherePriceGreaterThan(100.0);
final cheapRecent = recentItems.wherePriceLessThan(50.0);

// Original fragments are unchanged
```

### 3. No Side Effects

Since each method returns a new instance, you can't accidentally modify a query:

```dart
final baseQuery = ProductQuery();
final query1 = baseQuery.whereCategory('electronics');
final query2 = baseQuery.whereCategory('books');

// baseQuery is still empty - no where clauses
// query1 and query2 are independent
final electronics = await repo.getAll(query1);
final books = await repo.getAll(query2);
```

### 4. Value Equality

Queries with the same conditions are considered equal:

```dart
final activeQuery = UserQuery().whereActive(true);
final activeAdmins1 = activeQuery.whereRole('admin');
final activeAdmins2 = activeQuery.whereRole('admin');

// Different instances but equal values
assert(activeAdmins1 == activeAdmins2); // ✓ passes
assert(identical(activeAdmins1, activeAdmins2) == false); // ✓ passes

// Can use as map keys or in sets
final queriesRun = <Query<User>, List<User>>{};
queriesRun[activeAdmins1] = await repo.getAll(activeAdmins1);
// Later, can check if we already ran this query
if (queriesRun.containsKey(activeAdmins2)) {
  print('Already ran this query!'); // This will print
}
```

Note: Query equality compares table name, where clauses, order by clauses, and limit. The order of conditions matters.

## Migration from Mutable Pattern

If you were using the cascade operator (`..`) with queries, you'll need to update your code:

### Before (Mutable):
```dart
final query = AccountQuery()
  ..whereId(1)
  ..whereUsername('alice');
final accounts = await repo.getAll(query);
```

### After (Immutable):
```dart
final query = AccountQuery()
    .whereId(1)
    .whereUsername('alice');
final accounts = await repo.getAll(query);
```

The difference is subtle but important: the cascade operator (`..`) returns the original object, while method chaining (`.`) returns the new instance with the updated state.

## Implementation Details

Each generated query class (e.g., `AccountQuery`) extends the immutable `Query<T>` base class and includes a private copy constructor that wraps the parent's `Query.copy` constructor:

```dart
class AccountQuery extends Query<Account> {
  AccountQuery() : super('accounts', _fromMap);
  
  // Private copy constructor
  AccountQuery._(query)
    : super.copy(
        table: query.table,
        fromMap: query.fromMap,
        whereClauses: query.whereClauses,
        orderByClauses: query.orderByClauses,
        limitCount: query.limitCount,
      );

  // Each where method returns a new instance
  AccountQuery whereId(int id) {
    return AccountQuery._(copyWithWhereClause(WhereClause('id', '=', id)));
  }
}
```

This ensures that:
1. Query objects are fully immutable
2. All where clauses are preserved when creating new instances
3. The API is fluent and chainable
4. Queries can be safely shared and reused
