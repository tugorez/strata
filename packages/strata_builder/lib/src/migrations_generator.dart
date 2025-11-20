import 'dart:async';
import 'package:build/build.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:source_gen/source_gen.dart';
import 'package:strata/strata.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;

/// Creates the migrations builder for use with `build_runner`.
///
/// This function is called by the build system to instantiate the code generator.
/// It scans for @StrataMigrations() annotations and generates part `.g.dart` files.
Builder migrationsBuilder(BuilderOptions options) {
  return PartBuilder(
    [MigrationsGenerator()],
    '.g.dart',
    header: '// GENERATED CODE - DO NOT MODIFY BY HAND\n',
  );
}

/// A code generator that creates migration lists from SQL files.
///
/// This generator processes fields annotated with [@StrataMigrations] and generates
/// a list of [SqlMigration] objects by scanning the specified migrations directory
/// for `.sql` files.
///
/// The generated code is written to standalone `.g.dart` files.
class MigrationsGenerator extends GeneratorForAnnotation<StrataMigrations> {
  @override
  Future<String> generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) async {
    // 1. Make sure we are annotating a field
    if (element is! TopLevelVariableElement && element is! FieldElement) {
      throw InvalidGenerationSourceError(
        '@Migrations can only be used on fields.',
        element: element,
      );
    }

    // 2. Read the annotation values
    final String migrationsPath = annotation.read('path').stringValue;

    // 3. Look for migration files in the specified directory
    final migrationsGlob = Glob('$migrationsPath/**.sql');
    log.info(
      'Looking for migrations with glob pattern: $migrationsPath/**.sql',
    );
    log.info('Package: ${buildStep.inputId.package}');
    final migrationAssets = await buildStep.findAssets(migrationsGlob).toList();
    log.info('Found ${migrationAssets.length} migration files');
    for (final asset in migrationAssets) {
      log.info('  - ${asset.path}');
    }

    if (migrationAssets.isEmpty) {
      log.warning(
        'No migrations found in $migrationsPath/ directory. '
        'The generated list will be empty.',
      );
    }

    // Sort the migration files by name (which should include version numbers)
    migrationAssets.sort((a, b) => a.path.compareTo(b.path));

    final buffer = StringBuffer();
    buffer.writeln('// Migration list generated from $migrationsPath/');
    buffer.writeln();
    buffer.writeln('/// Auto-generated list of SQL migrations.');
    buffer.writeln('const _\$${element.name} = <SqlMigration>[');

    for (final asset in migrationAssets) {
      final content = await buildStep.readAsString(asset);
      final fileName = p.basename(asset.path);

      // Extract timestamp from filename (e.g., "20231115102030" from "20231115102030_create_users.sql")
      // Format: YYYYMMDDHHmmss (Ecto-style)
      final timestampMatch = RegExp(r'^(\d{14})_').firstMatch(fileName);
      if (timestampMatch == null) {
        log.warning(
          'Migration file $fileName does not start with a timestamp (YYYYMMDDHHmmss format). Skipping.',
        );
        continue;
      }

      final timestampStr = timestampMatch.group(1)!;
      final version = int.parse(timestampStr);
      final name = fileName
          .replaceFirst(RegExp(r'^\d{14}_'), '')
          .replaceFirst('.sql', '');

      // Parse SQL content, looking for @Up() and @Down() markers
      final sections = _parseMigrationFile(content);
      final upStatements = sections['up'] ?? [];
      final downStatements = sections['down'];

      buffer.writeln('  SqlMigration(');
      buffer.writeln('    version: $version,');
      buffer.writeln('    name: ${_escapeString(name)},');
      buffer.writeln('    upStatements: [');
      for (final statement in upStatements) {
        buffer.writeln('      ${_escapeString(statement)},');
      }
      buffer.writeln('    ],');

      if (downStatements != null && downStatements.isNotEmpty) {
        buffer.writeln('    downStatements: [');
        for (final statement in downStatements) {
          buffer.writeln('      ${_escapeString(statement)},');
        }
        buffer.writeln('    ],');
      }

      buffer.writeln('  ),');
    }

    buffer.writeln('];');

    return buffer.toString();
  }

  String _escapeString(String str) {
    return "'${str.replaceAll("'", r"\'").replaceAll(r'$', r'\$')}'";
  }

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

      // Only add lines after we've seen a section marker
      if (currentSection == 'up') {
        upLines.add(line);
      } else if (currentSection == 'down') {
        downLines.add(line);
      }
      // Don't add lines if currentSection is null (preamble comments)
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
}
