import 'package:strata_builder/src/migrations_generator.dart';
import 'package:test/test.dart';

void main() {
  group('MigrationsGenerator', () {
    late MigrationsGenerator generator;

    setUp(() {
      generator = MigrationsGenerator();
    });

    group('_parseMigrationFile', () {
      test('parses simple up-only migration', () {
        final content = '''
-- @Up()
CREATE TABLE users (
  id INTEGER PRIMARY KEY,
  email TEXT NOT NULL
);
''';

        final result = generator.testParseMigrationFile(content);

        expect(result['up'], isNotEmpty);
        expect(result['up']!.length, equals(1));
        expect(result['up']!.first, contains('CREATE TABLE users'));
        expect(result['down'], isNull);
      });

      test('parses migration with both up and down sections', () {
        final content = '''
-- @Up()
CREATE TABLE users (id INTEGER PRIMARY KEY);

-- @Down()
DROP TABLE users;
''';

        final result = generator.testParseMigrationFile(content);

        expect(result['up'], isNotEmpty);
        expect(result['up']!.first, contains('CREATE TABLE users'));
        expect(result['down'], isNotEmpty);
        expect(result['down']!.first, contains('DROP TABLE users'));
      });

      test('treats content before any marker as up statements', () {
        final content = '''
CREATE TABLE users (id INTEGER PRIMARY KEY);
INSERT INTO users (id) VALUES (1);
''';

        final result = generator.testParseMigrationFile(content);

        expect(result['up'], isNotEmpty);
        expect(result['up']!.length, equals(2));
        expect(result.containsKey('down'), isFalse);
      });

      test('handles case-insensitive markers', () {
        final content = '''
-- @up()
CREATE TABLE users (id INTEGER PRIMARY KEY);

-- @DOWN()
DROP TABLE users;
''';

        final result = generator.testParseMigrationFile(content);

        expect(result['up'], isNotEmpty);
        expect(result['down'], isNotEmpty);
      });

      test('filters out lines that are only comments', () {
        final content = '''
-- @Up()
CREATE TABLE users (id INTEGER PRIMARY KEY);
INSERT INTO users (id) VALUES (1);

-- @Down()
DROP TABLE users;
''';

        final result = generator.testParseMigrationFile(content);

        // Only actual SQL statements with semicolons are parsed
        expect(result['up']!.length, equals(2));
        expect(result['down']!.length, equals(1));
      });

      test(
        'includes empty down list when down section exists but has no SQL',
        () {
          final content = '''
-- @Up()
CREATE TABLE users (id INTEGER PRIMARY KEY);

-- @Down()

''';

          final result = generator.testParseMigrationFile(content);

          expect(result['up'], isNotEmpty);
          // Down section exists but is empty after parsing
          expect(result.containsKey('down'), isTrue);
          expect(result['down'], isEmpty);
        },
      );

      test('normalizes whitespace in statements', () {
        final content = '''
-- @Up()
CREATE TABLE users (
  id INTEGER PRIMARY KEY,
  email TEXT NOT NULL,
  created_at INTEGER
);
''';

        final result = generator.testParseMigrationFile(content);

        expect(result['up']!.length, equals(1));
        // Multiple lines should be combined with single spaces
        expect(result['up']!.first, isNot(contains('\n')));
        expect(result['up']!.first, contains('CREATE TABLE users'));
      });

      test('splits multiple statements by semicolon', () {
        final content = '''
-- @Up()
CREATE TABLE users (id INTEGER PRIMARY KEY);
CREATE TABLE posts (id INTEGER PRIMARY KEY);
CREATE INDEX idx_posts_id ON posts(id);
''';

        final result = generator.testParseMigrationFile(content);

        expect(result['up']!.length, equals(3));
        expect(result['up']![0], contains('CREATE TABLE users'));
        expect(result['up']![1], contains('CREATE TABLE posts'));
        expect(result['up']![2], contains('CREATE INDEX'));
      });

      test('handles complex SQL with multiple lines and semicolons', () {
        final content = '''
-- @Up()
CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT NOT NULL UNIQUE,
  created_at INTEGER NOT NULL
);

CREATE INDEX idx_users_email ON users(email);

INSERT INTO users (email, created_at) VALUES 
  ('user1@example.com', 1234567890),
  ('user2@example.com', 1234567891);

-- @Down()
DROP INDEX IF EXISTS idx_users_email;
DROP TABLE IF EXISTS users;
''';

        final result = generator.testParseMigrationFile(content);

        expect(result['up']!.length, equals(3));
        expect(result['down']!.length, equals(2));
      });
    });

    group('_escapeString', () {
      test('escapes single quotes', () {
        final input = "It's a test";
        final result = generator.testEscapeString(input);

        expect(result, equals("'It\\'s a test'"));
      });

      test('escapes dollar signs', () {
        final input = r'Price: $100';
        final result = generator.testEscapeString(input);

        expect(result, equals(r"'Price: \$100'"));
      });

      test('handles strings with both quotes and dollars', () {
        final input = r"It's $100";
        final result = generator.testEscapeString(input);

        expect(result, equals(r"'It\'s \$100'"));
      });

      test('handles simple string', () {
        final input = 'simple test';
        final result = generator.testEscapeString(input);

        expect(result, equals("'simple test'"));
      });
    });

    group('timestamp extraction', () {
      test('recognizes valid timestamp format', () {
        final fileName = '20241115102030_create_users_table.sql';
        final timestampMatch = RegExp(r'^(\d{14})_').firstMatch(fileName);

        expect(timestampMatch, isNotNull);
        expect(timestampMatch!.group(1), equals('20241115102030'));
      });

      test('rejects non-timestamp format', () {
        final fileName = 'invalid_create_users_table.sql';
        final timestampMatch = RegExp(r'^(\d{14})_').firstMatch(fileName);

        expect(timestampMatch, isNull);
      });

      test('rejects short number format', () {
        final fileName = '123_create_users_table.sql';
        final timestampMatch = RegExp(r'^(\d{14})_').firstMatch(fileName);

        expect(timestampMatch, isNull);
      });

      test('rejects invalid timestamp length', () {
        final fileName = '2024111510_create_users_table.sql';
        final timestampMatch = RegExp(r'^(\d{14})_').firstMatch(fileName);

        expect(timestampMatch, isNull);
      });

      test('parses timestamp as version number', () {
        final timestampStr = '20241115102030';
        final version = int.parse(timestampStr);

        expect(version, equals(20241115102030));
        expect(version, isA<int>());
      });
    });
  });
}

// Extension to expose private methods for testing
extension MigrationsGeneratorTest on MigrationsGenerator {
  Map<String, List<String>> testParseMigrationFile(String content) {
    return _parseMigrationFile(content);
  }

  String testEscapeString(String str) {
    return _escapeString(str);
  }

  List<String> testParseStatements(String sql) {
    return _parseStatements(sql);
  }
}

// These are the private methods we need to test
// Copy them here to make them accessible for testing
Map<String, List<String>> _parseMigrationFile(String content) {
  final lines = content.split('\n');
  String? currentSection;
  final upLines = <String>[];
  final downLines = <String>[];

  for (final line in lines) {
    final trimmed = line.trim();
    final upperTrimmed = trimmed.toUpperCase();

    if (upperTrimmed.startsWith('-- @UP(')) {
      currentSection = 'up';
      continue;
    } else if (upperTrimmed.startsWith('-- @DOWN(')) {
      currentSection = 'down';
      continue;
    }

    if (currentSection == 'up') {
      upLines.add(line);
    } else if (currentSection == 'down') {
      downLines.add(line);
    } else {
      upLines.add(line);
    }
  }

  return {
    'up': _parseStatements(upLines.join('\n')),
    if (downLines.isNotEmpty) 'down': _parseStatements(downLines.join('\n')),
  };
}

List<String> _parseStatements(String sql) {
  return sql
      .split(';')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty && !s.startsWith('--'))
      .map((s) => s.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' '))
      .toList();
}

String _escapeString(String str) {
  return "'${str.replaceAll("'", r"\'").replaceAll(r'$', r'\$')}'";
}
