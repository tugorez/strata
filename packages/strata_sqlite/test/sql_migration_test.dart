import 'package:strata_sqlite/strata_sqlite.dart';
import 'package:test/test.dart';

void main() {
  group('SqlMigration', () {
    test('creates migration with version, name, and up statements', () {
      final migration = SqlMigration(
        version: 20241115100000,
        name: 'create_users_table',
        upStatements: [
          'CREATE TABLE users (id INTEGER PRIMARY KEY, email TEXT NOT NULL)',
        ],
      );

      expect(migration.version, equals(20241115100000));
      expect(migration.name, equals('create_users_table'));
      expect(migration.upStatements.length, equals(1));
      expect(migration.downStatements, isNull);
    });

    test('creates migration with optional down statements', () {
      final migration = SqlMigration(
        version: 20241115100000,
        name: 'create_users_table',
        upStatements: ['CREATE TABLE users (id INTEGER PRIMARY KEY)'],
        downStatements: ['DROP TABLE users'],
      );

      expect(migration.downStatements, isNotNull);
      expect(migration.downStatements!.length, equals(1));
      expect(migration.downStatements!.first, equals('DROP TABLE users'));
    });

    test('executes up statements in order', () async {
      final executedStatements = <String>[];

      Future<List<Map<String, dynamic>>> executor(
        String sql,
        List<Object?>? args,
      ) async {
        executedStatements.add(sql);
        return [];
      }

      final migration = SqlMigration(
        version: 1,
        name: 'test',
        upStatements: [
          'CREATE TABLE users (id INTEGER PRIMARY KEY)',
          'CREATE INDEX idx_users_id ON users(id)',
          'INSERT INTO users (id) VALUES (1)',
        ],
      );

      await migration.up(executor);

      expect(executedStatements.length, equals(3));
      expect(
        executedStatements[0],
        equals('CREATE TABLE users (id INTEGER PRIMARY KEY)'),
      );
      expect(
        executedStatements[1],
        equals('CREATE INDEX idx_users_id ON users(id)'),
      );
      expect(
        executedStatements[2],
        equals('INSERT INTO users (id) VALUES (1)'),
      );
    });

    test('executes down statements in order when available', () async {
      final executedStatements = <String>[];

      Future<List<Map<String, dynamic>>> executor(
        String sql,
        List<Object?>? args,
      ) async {
        executedStatements.add(sql);
        return [];
      }

      final migration = SqlMigration(
        version: 1,
        name: 'test',
        upStatements: ['CREATE TABLE users (id INTEGER PRIMARY KEY)'],
        downStatements: ['DELETE FROM users', 'DROP TABLE users'],
      );

      await migration.down(executor);

      expect(executedStatements.length, equals(2));
      expect(executedStatements[0], equals('DELETE FROM users'));
      expect(executedStatements[1], equals('DROP TABLE users'));
    });

    test(
      'down does nothing when no down statements provided (Ecto-style)',
      () async {
        final executedStatements = <String>[];

        Future<List<Map<String, dynamic>>> executor(
          String sql,
          List<Object?>? args,
        ) async {
          executedStatements.add(sql);
          return [];
        }

        final migration = SqlMigration(
          version: 1,
          name: 'irreversible_migration',
          upStatements: ['INSERT INTO users (id) VALUES (1)'],
          // No downStatements - migration is irreversible
        );

        // Should not throw, should just return
        await migration.down(executor);

        // No statements should have been executed
        expect(executedStatements, isEmpty);
      },
    );

    test('down does nothing when down statements is empty list', () async {
      final executedStatements = <String>[];

      Future<List<Map<String, dynamic>>> executor(
        String sql,
        List<Object?>? args,
      ) async {
        executedStatements.add(sql);
        return [];
      }

      final migration = SqlMigration(
        version: 1,
        name: 'irreversible_migration',
        upStatements: ['INSERT INTO users (id) VALUES (1)'],
        downStatements: [], // Empty list
      );

      await migration.down(executor);

      expect(executedStatements, isEmpty);
    });

    test('toString returns readable representation', () {
      final migration = SqlMigration(
        version: 20241115100000,
        name: 'create_users_table',
        upStatements: ['CREATE TABLE users (id INTEGER PRIMARY KEY)'],
      );

      expect(
        migration.toString(),
        equals(
          'SqlMigration(version: 20241115100000, name: create_users_table)',
        ),
      );
    });

    test('equality is based on version and name', () {
      final migration1 = SqlMigration(
        version: 1,
        name: 'test',
        upStatements: ['CREATE TABLE users (id INTEGER PRIMARY KEY)'],
      );

      final migration2 = SqlMigration(
        version: 1,
        name: 'test',
        upStatements: ['CREATE TABLE accounts (id INTEGER PRIMARY KEY)'],
      );

      final migration3 = SqlMigration(
        version: 2,
        name: 'test',
        upStatements: ['CREATE TABLE users (id INTEGER PRIMARY KEY)'],
      );

      expect(migration1, equals(migration2)); // Same version and name
      expect(migration1, isNot(equals(migration3))); // Different version
    });

    test('hashCode is based on version and name', () {
      final migration1 = SqlMigration(
        version: 1,
        name: 'test',
        upStatements: ['CREATE TABLE users (id INTEGER PRIMARY KEY)'],
      );

      final migration2 = SqlMigration(
        version: 1,
        name: 'test',
        upStatements: ['CREATE TABLE accounts (id INTEGER PRIMARY KEY)'],
      );

      expect(migration1.hashCode, equals(migration2.hashCode));
    });
  });
}
