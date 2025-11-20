import 'package:strata_sqlite/strata_sqlite.dart';
import 'package:test/test.dart';

void main() {
  group('SqlMigrationRunner', () {
    late List<String> executedStatements;
    late Map<String, List<Map<String, dynamic>>> queryResults;

    Future<List<Map<String, dynamic>>> createExecutor(
      String sql,
      List<Object?>? args,
    ) async {
      executedStatements.add(sql);

      // Return mock results for specific queries
      if (sql.contains('MAX(version)')) {
        return queryResults['max_version'] ?? [];
      }

      return [];
    }

    setUp(() {
      executedStatements = [];
      queryResults = {};
    });

    test('creates migrations tracking table on first run', () async {
      final runner = SqlMigrationRunner(execute: createExecutor);
      final migrations = <SqlMigration>[];

      await runner.run(migrations);

      // Should create the schema_migrations table
      expect(
        executedStatements.any(
          (s) => s.contains('CREATE TABLE IF NOT EXISTS schema_migrations'),
        ),
        isTrue,
      );
    });

    test('uses custom migrations table name when provided', () async {
      final runner = SqlMigrationRunner(
        execute: createExecutor,
        migrationsTable: 'custom_migrations',
      );

      await runner.run([]);

      expect(
        executedStatements.any(
          (s) => s.contains('CREATE TABLE IF NOT EXISTS custom_migrations'),
        ),
        isTrue,
      );
    });

    test('queries current version from migrations table', () async {
      final runner = SqlMigrationRunner(execute: createExecutor);

      await runner.run([]);

      expect(
        executedStatements.any(
          (s) =>
              s.contains('SELECT MAX(version)') &&
              s.contains('FROM schema_migrations'),
        ),
        isTrue,
      );
    });

    test('runs no migrations when list is empty', () async {
      final runner = SqlMigrationRunner(execute: createExecutor);

      await runner.run([]);

      // Should only create table and check version
      expect(
        executedStatements.where((s) => s.contains('INSERT INTO')),
        isEmpty,
      );
    });

    test('runs pending migrations in order', () async {
      queryResults['max_version'] = [
        {'max_version': null}, // No migrations run yet
      ];

      final migration1 = SqlMigration(
        version: 20241115100000,
        name: 'create_users',
        upStatements: ['CREATE TABLE users (id INTEGER PRIMARY KEY)'],
      );

      final migration2 = SqlMigration(
        version: 20241115110000,
        name: 'create_posts',
        upStatements: ['CREATE TABLE posts (id INTEGER PRIMARY KEY)'],
      );

      final migration3 = SqlMigration(
        version: 20241115120000,
        name: 'add_index',
        upStatements: ['CREATE INDEX idx_users_id ON users(id)'],
      );

      final runner = SqlMigrationRunner(execute: createExecutor);
      await runner.run([migration1, migration2, migration3]);

      // Should execute all three migrations
      expect(
        executedStatements.where((s) => s.contains('CREATE TABLE users')),
        isNotEmpty,
      );
      expect(
        executedStatements.where((s) => s.contains('CREATE TABLE posts')),
        isNotEmpty,
      );
      expect(
        executedStatements.where((s) => s.contains('CREATE INDEX')),
        isNotEmpty,
      );

      // Should record all three migrations
      final inserts = executedStatements
          .where((s) => s.contains('INSERT INTO'))
          .toList();
      expect(inserts.length, equals(3));
    });

    test('skips migrations with version <= current version', () async {
      queryResults['max_version'] = [
        {'max_version': 20241115110000}, // Migration 2 already run
      ];

      final migration1 = SqlMigration(
        version: 20241115100000,
        name: 'create_users',
        upStatements: ['CREATE TABLE users (id INTEGER PRIMARY KEY)'],
      );

      final migration2 = SqlMigration(
        version: 20241115110000,
        name: 'create_posts',
        upStatements: ['CREATE TABLE posts (id INTEGER PRIMARY KEY)'],
      );

      final migration3 = SqlMigration(
        version: 20241115120000,
        name: 'add_index',
        upStatements: ['CREATE INDEX idx_users_id ON users(id)'],
      );

      final runner = SqlMigrationRunner(execute: createExecutor);
      await runner.run([migration1, migration2, migration3]);

      // Should NOT execute migration1 or migration2
      expect(
        executedStatements.where((s) => s.contains('CREATE TABLE users')),
        isEmpty,
      );
      expect(
        executedStatements.where((s) => s.contains('CREATE TABLE posts')),
        isEmpty,
      );

      // Should execute migration3
      expect(
        executedStatements.where((s) => s.contains('CREATE INDEX')),
        isNotEmpty,
      );

      // Should record only migration3
      final inserts = executedStatements
          .where((s) => s.contains('INSERT INTO'))
          .toList();
      expect(inserts.length, equals(1));
    });

    test('records migration with version, name, and timestamp', () async {
      queryResults['max_version'] = [
        {'max_version': null},
      ];

      final migration = SqlMigration(
        version: 20241115100000,
        name: 'create_users',
        upStatements: ['CREATE TABLE users (id INTEGER PRIMARY KEY)'],
      );

      final runner = SqlMigrationRunner(execute: createExecutor);
      await runner.run([migration]);

      // Should record the migration
      final insertStatement = executedStatements.firstWhere(
        (s) => s.contains('INSERT INTO schema_migrations'),
      );

      expect(insertStatement, contains('version'));
      expect(insertStatement, contains('name'));
      expect(insertStatement, contains('applied_at'));
    });

    test('handles migrations with multiple statements', () async {
      queryResults['max_version'] = [
        {'max_version': null},
      ];

      final migration = SqlMigration(
        version: 20241115100000,
        name: 'create_schema',
        upStatements: [
          'CREATE TABLE users (id INTEGER PRIMARY KEY)',
          'CREATE TABLE posts (id INTEGER PRIMARY KEY, user_id INTEGER)',
          'CREATE INDEX idx_posts_user_id ON posts(user_id)',
        ],
      );

      final runner = SqlMigrationRunner(execute: createExecutor);
      await runner.run([migration]);

      // All three statements should be executed
      expect(
        executedStatements.where((s) => s.contains('CREATE TABLE users')),
        isNotEmpty,
      );
      expect(
        executedStatements.where((s) => s.contains('CREATE TABLE posts')),
        isNotEmpty,
      );
      expect(
        executedStatements.where((s) => s.contains('CREATE INDEX')),
        isNotEmpty,
      );
    });

    test('runs migrations with timestamp-based versions', () async {
      queryResults['max_version'] = [
        {'max_version': null},
      ];

      // Ecto-style timestamp versions
      final migration = SqlMigration(
        version: 20241115102030, // YYYYMMDDHHmmss
        name: 'create_users',
        upStatements: ['CREATE TABLE users (id INTEGER PRIMARY KEY)'],
      );

      final runner = SqlMigrationRunner(execute: createExecutor);
      await runner.run([migration]);

      // Should handle large timestamp-based version numbers
      final insertStatement = executedStatements.firstWhere(
        (s) => s.contains('INSERT INTO schema_migrations'),
      );

      expect(insertStatement, isNotEmpty);
    });

    test(
      'processes migrations in correct order even if provided unordered',
      () async {
        queryResults['max_version'] = [
          {'max_version': null},
        ];

        // Provide migrations out of order
        final migration3 = SqlMigration(
          version: 20241115120000,
          name: 'third',
          upStatements: ['CREATE TABLE third (id INTEGER PRIMARY KEY)'],
        );

        final migration1 = SqlMigration(
          version: 20241115100000,
          name: 'first',
          upStatements: ['CREATE TABLE first (id INTEGER PRIMARY KEY)'],
        );

        final migration2 = SqlMigration(
          version: 20241115110000,
          name: 'second',
          upStatements: ['CREATE TABLE second (id INTEGER PRIMARY KEY)'],
        );

        final runner = SqlMigrationRunner(execute: createExecutor);
        // Pass migrations in wrong order
        await runner.run([migration3, migration1, migration2]);

        // Find the index of each CREATE TABLE in execution order
        final firstIndex = executedStatements.indexWhere(
          (s) => s.contains('CREATE TABLE first'),
        );
        final secondIndex = executedStatements.indexWhere(
          (s) => s.contains('CREATE TABLE second'),
        );
        final thirdIndex = executedStatements.indexWhere(
          (s) => s.contains('CREATE TABLE third'),
        );

        // They should be executed in version order (1, 2, 3)
        expect(firstIndex, lessThan(secondIndex));
        expect(secondIndex, lessThan(thirdIndex));
      },
    );
  });
}
