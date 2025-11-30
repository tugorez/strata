import 'package:test/test.dart';

import '../testing/models/event.dart';

void main() {
  group('Optional Timestamp Fields', () {
    group('_fromMap', () {
      test('correctly reads required timestamp from map', () {
        final startDate = DateTime.utc(2025, 11, 29, 10, 30, 0);
        final map = {
          'id': 1,
          'name': 'Test Event',
          'start_date_seconds': startDate.millisecondsSinceEpoch ~/ 1000,
          'start_date_nanos': 0,
          'end_date_seconds': null,
          'end_date_nanos': null,
        };

        final event = EventQuery().fromMap(map);

        expect(event.id, equals(1));
        expect(event.name, equals('Test Event'));
        expect(event.startDate.year, equals(2025));
        expect(event.startDate.month, equals(11));
        expect(event.startDate.day, equals(29));
      });

      test('correctly reads optional timestamp when present', () {
        final startDate = DateTime.utc(2025, 11, 29, 10, 0, 0);
        final endDate = DateTime.utc(2025, 12, 31, 23, 59, 59);
        final map = {
          'id': 1,
          'name': 'Bounded Event',
          'start_date_seconds': startDate.millisecondsSinceEpoch ~/ 1000,
          'start_date_nanos': 0,
          'end_date_seconds': endDate.millisecondsSinceEpoch ~/ 1000,
          'end_date_nanos': 0,
        };

        final event = EventQuery().fromMap(map);

        expect(event.endDate, isNotNull);
        expect(event.endDate!.year, equals(2025));
        expect(event.endDate!.month, equals(12));
        expect(event.endDate!.day, equals(31));
      });

      test('correctly reads optional timestamp as null when absent', () {
        final startDate = DateTime.utc(2025, 11, 29, 10, 0, 0);
        final map = {
          'id': 1,
          'name': 'Open-Ended Event',
          'start_date_seconds': startDate.millisecondsSinceEpoch ~/ 1000,
          'start_date_nanos': 0,
          'end_date_seconds': null,
          'end_date_nanos': null,
        };

        final event = EventQuery().fromMap(map);

        expect(event.endDate, isNull);
      });
    });

    group('Changeset cast', () {
      test('converts required DateTime to seconds/nanos columns', () {
        final startDate = DateTime.utc(2025, 11, 29, 10, 30, 0);
        final changeset = EventChangeset({
          'id': 1,
          'name': 'Test',
          'startDate': startDate,
        });

        changeset.cast(['id', 'name', 'startDate']);

        expect(changeset.params.containsKey('startDate'), isFalse);
        expect(changeset.params['start_date_seconds'], isNotNull);
        expect(changeset.params['start_date_nanos'], isNotNull);
        expect(
          changeset.params['start_date_seconds'],
          equals(startDate.millisecondsSinceEpoch ~/ 1000),
        );
      });

      test(
        'converts optional DateTime to seconds/nanos columns when present',
        () {
          final startDate = DateTime.utc(2025, 11, 29, 10, 0, 0);
          final endDate = DateTime.utc(2025, 12, 31, 23, 59, 59);
          final changeset = EventChangeset({
            'id': 1,
            'name': 'Bounded Event',
            'startDate': startDate,
            'endDate': endDate,
          });

          changeset.cast(['id', 'name', 'startDate', 'endDate']);

          expect(changeset.params.containsKey('endDate'), isFalse);
          expect(changeset.params['end_date_seconds'], isNotNull);
          expect(changeset.params['end_date_nanos'], isNotNull);
          expect(
            changeset.params['end_date_seconds'],
            equals(endDate.millisecondsSinceEpoch ~/ 1000),
          );
        },
      );

      test('does not add end_date columns when endDate is not in params', () {
        final startDate = DateTime.utc(2025, 11, 29, 10, 0, 0);
        final changeset = EventChangeset({
          'id': 1,
          'name': 'Open Event',
          'startDate': startDate,
        });

        changeset.cast(['id', 'name', 'startDate']);

        expect(changeset.params.containsKey('end_date_seconds'), isFalse);
        expect(changeset.params.containsKey('end_date_nanos'), isFalse);
      });

      test('handles null endDate gracefully', () {
        final startDate = DateTime.utc(2025, 11, 29, 10, 0, 0);
        final changeset = EventChangeset({
          'id': 1,
          'name': 'Open Event',
          'startDate': startDate,
          'endDate': null,
        });

        // Should not throw
        changeset.cast(['id', 'name', 'startDate', 'endDate']);

        // null is not a DateTime, so endDate key remains (won't be converted)
        // This is the expected behavior - null values are passed through as-is
        expect(changeset.params.containsKey('end_date_seconds'), isFalse);
      });
    });

    group('timestamp precision', () {
      test('preserves microsecond precision through round-trip', () {
        // Create a DateTime with microseconds
        final original = DateTime.utc(2025, 11, 29, 10, 30, 45, 123, 456);

        // Convert to timestamp (seconds/nanos)
        final utc = original.toUtc();
        final micros = utc.microsecondsSinceEpoch;
        final seconds = micros ~/ 1000000;
        final nanos = (micros % 1000000) * 1000;

        // Convert back
        final restored = DateTime.fromMicrosecondsSinceEpoch(
          seconds * 1000000 + nanos ~/ 1000,
          isUtc: true,
        );

        expect(restored.year, equals(original.year));
        expect(restored.month, equals(original.month));
        expect(restored.day, equals(original.day));
        expect(restored.hour, equals(original.hour));
        expect(restored.minute, equals(original.minute));
        expect(restored.second, equals(original.second));
        expect(restored.millisecond, equals(original.millisecond));
        expect(restored.microsecond, equals(original.microsecond));
      });
    });
  });
}
