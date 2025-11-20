import 'package:test/test.dart';

import '../testing/models/account.dart';

void main() {
  group('Changeset', () {
    group('Ecto-style cast + validate', () {
      test('cast whitelists only specified fields', () {
        final changeset = AccountChangeset({
          'username': 'testuser',
          'email': 'test@test.com',
          'malicious_field': 'hacker',
        })..cast(['username', 'email']);

        expect(
          changeset.changes,
          equals({'username': 'testuser', 'email': 'test@test.com'}),
        );
        expect(changeset.changes.containsKey('malicious_field'), isFalse);
      });

      test('validateRequired works on cast fields', () {
        final changeset =
            AccountChangeset({'username': 'testuser', 'email': 'test@test.com'})
              ..cast(['username', 'email'])
              ..validateRequired('username');

        expect(changeset.isValid, isTrue);
        expect(
          changeset.changes,
          equals({'username': 'testuser', 'email': 'test@test.com'}),
        );
      });

      test('validateRequired fails when cast field is missing', () {
        final changeset = AccountChangeset({'email': 'test@test.com'})
          ..cast(['email'])
          ..validateRequired('username');

        expect(changeset.isValid, isFalse);
        expect(changeset.errors['username'], contains('is required'));
      });

      test('validateRequired fails when cast field is null', () {
        final changeset =
            AccountChangeset({'username': null, 'email': 'test@test.com'})
              ..cast(['username', 'email'])
              ..validateRequired('username');

        expect(changeset.isValid, isFalse);
        expect(changeset.errors['username'], contains('is required'));
      });

      test('validateRequired fails when cast field is empty string', () {
        final changeset =
            AccountChangeset({'username': '', 'email': 'test@test.com'})
              ..cast(['username', 'email'])
              ..validateRequired('username');

        expect(changeset.isValid, isFalse);
        expect(changeset.errors['username'], contains('is required'));
      });

      test('cast + validate + validateLength pipeline', () {
        final changeset =
            AccountChangeset({'username': 'testuser', 'email': 'test@test.com'})
              ..cast(['username', 'email'])
              ..validateRequired('username')
              ..validateLength('username', min: 3, max: 20);

        expect(changeset.isValid, isTrue);
        expect(changeset.changes['username'], 'testuser');
      });

      test('validation removes invalid fields from changes', () {
        final changeset =
            AccountChangeset({
                'username': 'ab', // Too short
                'email': 'test@test.com',
              })
              ..cast(['username', 'email'])
              ..validateRequired('username')
              ..validateLength('username', min: 3);

        expect(changeset.isValid, isFalse);
        expect(
          changeset.errors['username'],
          contains('must be at least 3 characters'),
        );
        expect(
          changeset.changes.containsKey('username'),
          isFalse,
          reason: 'Invalid field should be removed from changes',
        );
        expect(
          changeset.changes['email'],
          'test@test.com',
          reason: 'Valid fields should remain in changes',
        );
      });
    });

    group('Backward compatibility (no explicit cast)', () {
      test('is valid when all validations pass', () {
        final changeset =
            AccountChangeset({'username': 'testuser', 'email': 'test@test.com'})
              ..validateRequired('username')
              ..validateLength('username', min: 3);

        expect(changeset.isValid, isTrue);
        expect(changeset.errors, isEmpty);
        expect(changeset.changes, equals({'username': 'testuser'}));
      });

      test('is invalid when a validation fails', () {
        final changeset = AccountChangeset({'username': 'aa'})
          ..validateRequired('username')
          ..validateLength('username', min: 3);

        expect(changeset.isValid, isFalse);
        expect(changeset.errors['username'], isNotEmpty);
        expect(
          changeset.errors['username']!.first,
          'must be at least 3 characters',
        );
        expect(
          changeset.changes,
          isEmpty,
          reason: 'The invalid value should not be added to changes',
        );
      });

      test('is invalid when required field is missing', () {
        final changeset = AccountChangeset({})
          ..validateRequired('username')
          ..validateLength('username', min: 3);

        expect(changeset.isValid, isFalse);
        expect(changeset.errors['username']!.single, 'is required');
      });

      test('is invalid when required field is null', () {
        final changeset = AccountChangeset({'username': null})
          ..validateRequired('username');

        expect(changeset.isValid, isFalse, reason: 'null check');
      });

      test('is invalid when required field is empty', () {
        final changeset = AccountChangeset({'username': ''})
          ..validateRequired('username');

        expect(changeset.isValid, isFalse, reason: 'empty string check');
      });
    });
  });
}
