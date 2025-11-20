import 'package:test/test.dart';
import 'package:strata_builder/src/utils/migration_parser.dart';

void main() {
  group('MigrationParser.parseFilename', () {
    test('parses valid migration filename', () {
      final result = MigrationParser.parseFilename(
        '20241117100000_create_users_table.sql',
      );

      expect(result, isNotNull);
      expect(result!['version'], equals(20241117100000));
      expect(result['name'], equals('create_users_table'));
    });

    test('parses filename with underscores in name', () {
      final result = MigrationParser.parseFilename(
        '20241117101000_add_user_email_index.sql',
      );

      expect(result, isNotNull);
      expect(result!['version'], equals(20241117101000));
      expect(result['name'], equals('add_user_email_index'));
    });

    test('returns null for invalid filename format', () {
      final result = MigrationParser.parseFilename('invalid_migration.sql');
      expect(result, isNull);
    });

    test('returns null for filename without timestamp', () {
      final result = MigrationParser.parseFilename('create_users.sql');
      expect(result, isNull);
    });

    test('returns null for filename with short timestamp', () {
      final result = MigrationParser.parseFilename('20241117_create_users.sql');
      expect(result, isNull);
    });
  });

  group('MigrationParser.parseMigrationFile', () {
    test('parses migration with up and down sections', () {
      const content = '''
-- Migration: create_users_table
-- Description: Creates the users table

-- @Up()
CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL
);

CREATE INDEX idx_users_name ON users(name);

-- @Down()
DROP INDEX IF EXISTS idx_users_name;
DROP TABLE IF EXISTS users;
''';

      final result = MigrationParser.parseMigrationFile(content);

      expect(result['up'], isNotNull);
      expect(result['up']!.length, equals(2));
      expect(result['up']![0], contains('CREATE TABLE users'));
      expect(result['up']![1], contains('CREATE INDEX idx_users_name'));

      expect(result['down'], isNotNull);
      expect(result['down']!.length, equals(2));
      expect(result['down']![0], contains('DROP INDEX'));
      expect(result['down']![1], contains('DROP TABLE'));
    });

    test('parses migration with only up section', () {
      const content = '''
-- @Up()
CREATE TABLE users (
  id INTEGER PRIMARY KEY
);
''';

      final result = MigrationParser.parseMigrationFile(content);

      expect(result['up'], isNotNull);
      expect(result['up']!.length, equals(1));
      expect(result['up']![0], contains('CREATE TABLE users'));
      expect(result['down'], isNull);
    });

    test('handles case-insensitive markers', () {
      const content = '''
-- @up()
CREATE TABLE test1 (id INTEGER);

-- @down()
DROP TABLE test1;
''';

      final result = MigrationParser.parseMigrationFile(content);

      expect(result['up'], isNotNull);
      expect(result['up']!.length, equals(1));
      expect(result['down'], isNotNull);
      expect(result['down']!.length, equals(1));
    });

    test('ignores comments and empty lines', () {
      const content = '''
-- This is a comment before the marker

-- @Up()
-- This is a comment in the up section
CREATE TABLE users (id INTEGER);

-- Another comment

-- @Down()
-- Comment in down section
DROP TABLE users;
''';

      final result = MigrationParser.parseMigrationFile(content);

      expect(result['up'], isNotNull);
      expect(result['up']!.length, equals(1));
      expect(result['down'], isNotNull);
      expect(result['down']!.length, equals(1));
    });

    test('handles multi-line statements', () {
      const content = '''
-- @Up()
CREATE TABLE users (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT UNIQUE
);

-- @Down()
DROP TABLE users;
''';

      final result = MigrationParser.parseMigrationFile(content);

      expect(result['up'], isNotNull);
      expect(result['up']!.length, equals(1));
      expect(result['up']![0], contains('CREATE TABLE users'));
      expect(result['up']![0], contains('id INTEGER PRIMARY KEY'));
    });
  });

  group('MigrationParser.escapeString', () {
    test('escapes single quotes', () {
      final result = MigrationParser.escapeString("It's a test");
      expect(result, equals("'It\\'s a test'"));
    });

    test('escapes dollar signs', () {
      final result = MigrationParser.escapeString('Price: \$100');
      expect(result, equals("'Price: \\\$100'"));
    });

    test('escapes backslashes', () {
      final result = MigrationParser.escapeString('Path: C:\\Users');
      expect(result, equals("'Path: C:\\\\Users'"));
    });

    test('escapes newlines', () {
      final result = MigrationParser.escapeString('Line 1\nLine 2');
      expect(result, equals("'Line 1\\nLine 2'"));
    });

    test('escapes tabs', () {
      final result = MigrationParser.escapeString('Col1\tCol2');
      expect(result, equals("'Col1\\tCol2'"));
    });

    test('escapes multiple special characters', () {
      final result = MigrationParser.escapeString("It's \$100\nTotal");
      expect(result, equals("'It\\'s \\\$100\\nTotal'"));
    });

    test('handles string without special characters', () {
      final result = MigrationParser.escapeString('Hello World');
      expect(result, equals("'Hello World'"));
    });
  });
}
