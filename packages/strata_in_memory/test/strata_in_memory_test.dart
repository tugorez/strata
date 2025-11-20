import 'package:strata_in_memory/strata_in_memory.dart';
import 'package:test/test.dart';

void main() {
  group('InMemoryAdapter', () {
    late InMemoryAdapter adapter;

    setUp(() async {
      adapter = InMemoryAdapter();
      await adapter.initialize();
    });

    tearDown(() async {
      await adapter.close();
    });

    test('initializes successfully and is open', () {
      // Verify adapter can perform operations after initialization
      expect(() => adapter.insert('test_table', {'id': 1}), returnsNormally);
    });

    test('exports InMemoryAdapter publicly', () {
      // This test ensures the export is working
      expect(InMemoryAdapter, isNotNull);
    });
  });
}
