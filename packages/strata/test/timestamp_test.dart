import 'package:test/test.dart';
import '../testing/models/post.dart';

void main() {
  group('Timestamp annotation', () {
    test('timestamp where methods work correctly', () {
      // Use the generated _fromMap indirectly through PostQuery
      final query = PostQuery();
      expect(query.table, equals('posts'));

      // Test the timestamp where methods exist and have correct types
      final now = DateTime.now();
      final filtered = PostQuery()
          .whereCreatedAtAfter(now.subtract(Duration(days: 7)))
          .whereUpdatedAtBefore(now);

      expect(filtered.whereClauses.length, equals(2));
      expect(filtered.whereClauses[0].field, equals('created_at_seconds'));
      expect(filtered.whereClauses[0].operator, equals('>'));
      expect(filtered.whereClauses[1].field, equals('updated_at_seconds'));
      expect(filtered.whereClauses[1].operator, equals('<'));
    });

    test('orderBy methods use _seconds column for timestamp fields', () {
      final query = PostQuery()
          .orderByCreatedAt(ascending: false)
          .orderByUpdatedAt();

      expect(query.orderByClauses.length, equals(2));
      expect(query.orderByClauses[0].field, equals('created_at_seconds'));
      expect(query.orderByClauses[0].ascending, equals(false));
      expect(query.orderByClauses[1].field, equals('updated_at_seconds'));
      expect(query.orderByClauses[1].ascending, equals(true));
    });

    test('Post model can be created with DateTime fields', () {
      final now = DateTime.now().toUtc();
      final post = Post(
        id: 1,
        title: 'Test',
        content: 'Content',
        createdAt: now,
        updatedAt: now,
      );

      expect(post.id, equals(1));
      expect(post.createdAt, equals(now));
      expect(post.updatedAt, equals(now));
    });

    test('copyWith works with DateTime fields', () {
      final now = DateTime.now().toUtc();
      final later = now.add(Duration(hours: 1));

      final post = Post(
        id: 1,
        title: 'Test',
        content: 'Content',
        createdAt: now,
        updatedAt: now,
      );

      final updated = post.copyWith(updatedAt: later);

      expect(updated.createdAt, equals(now));
      expect(updated.updatedAt, equals(later));
    });

    test('changeset cast converts DateTime to seconds/nanos columns', () {
      final now = DateTime.utc(2024, 1, 15, 10, 30, 0, 123, 456);

      final changeset = PostChangeset({
        'title': 'Test Post',
        'content': 'Test content',
        'createdAt': now,
        'updatedAt': now,
      })..cast(['title', 'content', 'createdAt', 'updatedAt']);

      // DateTime fields should be converted to _seconds and _nanos
      expect(changeset.changes.containsKey('createdAt'), isFalse);
      expect(changeset.changes.containsKey('updatedAt'), isFalse);
      expect(changeset.changes['created_at_seconds'], isA<int>());
      expect(changeset.changes['created_at_nanos'], isA<int>());
      expect(changeset.changes['updated_at_seconds'], isA<int>());
      expect(changeset.changes['updated_at_nanos'], isA<int>());

      // Verify the conversion is correct
      final expectedSeconds = now.millisecondsSinceEpoch ~/ 1000;
      expect(changeset.changes['created_at_seconds'], equals(expectedSeconds));
    });

    test('changeset cast works with mixed DateTime and regular fields', () {
      final now = DateTime.now().toUtc();

      final changeset = PostChangeset({
        'title': 'My Title',
        'content': 'My Content',
        'createdAt': now,
        'updatedAt': now,
      })..cast(['title', 'createdAt']);

      // Only cast fields should be in changes
      expect(changeset.changes['title'], equals('My Title'));
      expect(changeset.changes.containsKey('content'), isFalse);
      expect(changeset.changes['created_at_seconds'], isA<int>());
      expect(changeset.changes['created_at_nanos'], isA<int>());
      // updatedAt was not cast
      expect(changeset.changes.containsKey('updated_at_seconds'), isFalse);
    });
  });
}
