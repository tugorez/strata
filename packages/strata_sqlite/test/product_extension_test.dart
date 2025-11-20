import 'package:test/test.dart';
import 'models/product.dart';

void main() {
  group('Product Extension', () {
    test('copyWith creates new instance with updated fields', () {
      final product = Product(id: 1, name: 'Laptop', price: 999.99, stock: 5);

      final updated = product.copyWith(price: 1299.99, stock: 3);

      expect(updated.id, equals(1)); // unchanged
      expect(updated.name, equals('Laptop')); // unchanged
      expect(updated.price, equals(1299.99)); // changed
      expect(updated.stock, equals(3)); // changed
    });

    test('copyWith with no parameters returns copy with same values', () {
      final product = Product(id: 1, name: 'Laptop', price: 999.99, stock: 5);

      final copy = product.copyWith();

      expect(copy.id, equals(product.id));
      expect(copy.name, equals(product.name));
      expect(copy.price, equals(product.price));
      expect(copy.stock, equals(product.stock));
      expect(identical(copy, product), isFalse); // Different instances
    });

    test('copyWith maintains immutability', () {
      final original = Product(id: 1, name: 'Laptop', price: 999.99, stock: 5);

      final modified = original.copyWith(price: 1299.99);

      // Original is unchanged
      expect(original.price, equals(999.99));
      // Modified has new value
      expect(modified.price, equals(1299.99));
    });

    test('copyWith can update single field', () {
      final product = Product(id: 1, name: 'Laptop', price: 999.99, stock: 5);

      final renamed = product.copyWith(name: 'Gaming Laptop');

      expect(renamed.id, equals(1));
      expect(renamed.name, equals('Gaming Laptop'));
      expect(renamed.price, equals(999.99));
      expect(renamed.stock, equals(5));
    });

    test('copyWith can chain multiple updates', () {
      final product = Product(id: 1, name: 'Laptop', price: 999.99, stock: 5);

      final updated = product
          .copyWith(price: 1299.99)
          .copyWith(stock: 3)
          .copyWith(name: 'Gaming Laptop');

      expect(updated.id, equals(1));
      expect(updated.name, equals('Gaming Laptop'));
      expect(updated.price, equals(1299.99));
      expect(updated.stock, equals(3));

      // Original is unchanged
      expect(product.name, equals('Laptop'));
      expect(product.price, equals(999.99));
      expect(product.stock, equals(5));
    });
  });
}
