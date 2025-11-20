import 'package:test/test.dart';
import 'package:strata/strata.dart';
import 'package:strata_sqlite/strata_sqlite.dart';

import 'models/product.dart';

void main() {
  late SqliteAdapter adapter;
  late StrataRepo repo;

  setUp(() async {
    adapter = SqliteAdapter(path: ':memory:');
    repo = StrataRepo(adapter: adapter);
    await repo.initialize();

    // Create products table
    adapter.database.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        stock INTEGER NOT NULL
      )
    ''');

    // Insert test data
    await adapter.insert('products', {
      'name': 'Laptop',
      'price': 999.99,
      'stock': 5,
    });
    await adapter.insert('products', {
      'name': 'Mouse',
      'price': 29.99,
      'stock': 50,
    });
    await adapter.insert('products', {
      'name': 'Keyboard',
      'price': 79.99,
      'stock': 30,
    });
    await adapter.insert('products', {
      'name': 'Monitor',
      'price': 299.99,
      'stock': 10,
    });
    await adapter.insert('products', {
      'name': 'Mousepad',
      'price': 14.99,
      'stock': 100,
    });
  });

  tearDown(() async {
    await repo.close();
  });

  group('SQLite Query Operators', () {
    test('wherePriceGreaterThan filters correctly', () async {
      final query = ProductQuery().wherePriceGreaterThan(100.0);
      final products = await repo.getAll(query);

      expect(products.length, equals(2));
      expect(products.map((p) => p.name), containsAll(['Laptop', 'Monitor']));
    });

    test('wherePriceLessThan filters correctly', () async {
      final query = ProductQuery().wherePriceLessThan(50.0);
      final products = await repo.getAll(query);

      expect(products.length, equals(2));
      expect(products.map((p) => p.name), containsAll(['Mouse', 'Mousepad']));
    });

    test('whereIdIn filters with list', () async {
      final query = ProductQuery().whereIdIn([1, 3, 5]);
      final products = await repo.getAll(query);

      expect(products.length, equals(3));
      expect(
        products.map((p) => p.name),
        containsAll(['Laptop', 'Keyboard', 'Mousepad']),
      );
    });

    test('whereIdNotIn filters with list', () async {
      final query = ProductQuery().whereIdNotIn([1, 3, 5]);
      final products = await repo.getAll(query);

      expect(products.length, equals(2));
      expect(products.map((p) => p.name), containsAll(['Mouse', 'Monitor']));
    });

    test('whereNameLike filters with pattern', () async {
      final query = ProductQuery().whereNameLike('Mouse%');
      final products = await repo.getAll(query);

      expect(products.length, equals(2));
      expect(products.map((p) => p.name), containsAll(['Mouse', 'Mousepad']));
    });

    test('multiple operators can be chained', () async {
      final query = ProductQuery()
          .wherePriceGreaterThan(20.0)
          .wherePriceLessThan(100.0);
      final products = await repo.getAll(query);

      expect(products.length, equals(2));
      expect(products.map((p) => p.name), containsAll(['Mouse', 'Keyboard']));
    });

    test('IN with empty list returns no results', () async {
      final query = ProductQuery().whereIdIn([]);
      final products = await repo.getAll(query);

      expect(products.length, equals(0));
    });

    test('NOT IN with empty list returns all results', () async {
      final query = ProductQuery().whereIdNotIn([]);
      final products = await repo.getAll(query);

      expect(products.length, equals(5));
    });
  });
}
