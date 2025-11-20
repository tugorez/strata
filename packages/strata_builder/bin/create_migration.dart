import 'dart:io';
import 'package:args/args.dart';

void main(List<String> arguments) {
  const migrationsDir = 'migrations';

  final parser = ArgParser()
    ..addOption(
      'path',
      abbr: 'p',
      defaultsTo: migrationsDir,
      help: 'The directory to create the migration in.',
    )
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show usage information.',
    );

  final ArgResults argResults;

  try {
    argResults = parser.parse(arguments);
  } catch (e) {
    stderr.writeln('❌ Error: ${e.toString()}');
    stderr.writeln(parser.usage);
    exit(1);
  }

  if (argResults['help'] == true) {
    print(
      'Usage: dart run strata_builder:create_migration <migration_name> [options]',
    );
    print('');
    print('Creates a new SQL migration file in the migrations/ directory.');
    print('');
    print('Options:');
    print(parser.usage);
    exit(0);
  }

  // 1. Check for the migration name
  if (argResults.rest.isEmpty) {
    stderr.writeln('❌ Error: Please provide a migration name.');
    stderr.writeln(
      'Usage: dart run strata_builder:create_migration <migration_name>',
    );
    stderr.writeln('');
    stderr.writeln('Example:');
    stderr.writeln(
      '  dart run strata_builder:create_migration create_users_table',
    );
    exit(1);
  }

  // 2. Get name and path
  final migrationName = argResults.rest.first;
  final targetDir = argResults['path'] as String;

  // 3. Ensure the directory exists
  final dir = Directory(targetDir);
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  // 3. Get timestamp (YYYYMMDDHHmmss format like Ecto)
  final now = DateTime.now().toUtc();
  final timestamp = [
    now.year.toString(),
    now.month.toString().padLeft(2, '0'),
    now.day.toString().padLeft(2, '0'),
    now.hour.toString().padLeft(2, '0'),
    now.minute.toString().padLeft(2, '0'),
    now.second.toString().padLeft(2, '0'),
  ].join('');

  // 4. Construct filename with timestamp prefix (Ecto-style)
  final filename = '$targetDir/${timestamp}_$migrationName.sql';

  // 5. Create the file with placeholder content
  File(filename).writeAsStringSync('''-- Migration: $migrationName
-- Timestamp: $timestamp
-- Created: ${now.toIso8601String()}

-- Add your SQL statements here.
-- Use @Up() and @Down() annotations to support rollback.

-- @Up()
CREATE TABLE example (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL
);

-- @Down()
DROP TABLE IF EXISTS example;

''');

  // 6. Print success
  print('✅ Created migration: $filename');
  print('');
  print('Next steps:');
  print('  1. Edit the migration file and add your SQL statements');
  print('  2. Use -- @Up() and -- @Down() sections to define rollback logic');
  print('  3. Run: dart run build_runner build');
  print('  4. The migration will be available in lib/migrations.dart');
}
