import 'package:strata_sqlite/strata_sqlite.dart';
import 'package:test/test.dart';

void main() {
  group('SqliteAdapter', () {
    test('can be instantiated', () {
      final adapter = SqliteAdapter(path: ':memory:');

      expect(adapter, isNotNull);
      expect(adapter, isA<SqliteAdapter>());
    });
  });
}
