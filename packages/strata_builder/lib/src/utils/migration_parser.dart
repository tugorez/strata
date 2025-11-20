/// A utility class for parsing SQL migration files.
///
/// This parser extracts migration metadata (version, name) from filenames
/// and separates SQL statements into `up` and `down` sections based on
/// `@Up()` and `@Down()` markers in the SQL file.
class MigrationParser {
  /// Parses a migration filename to extract version and name.
  ///
  /// Expected format: `YYYYMMDDHHmmss_migration_name.sql`
  ///
  /// Returns a map with 'version' (int) and 'name' (String), or null if invalid.
  static Map<String, dynamic>? parseFilename(String fileName) {
    // Extract timestamp from filename (e.g., "20231115102030" from "20231115102030_create_users.sql")
    // Format: YYYYMMDDHHmmss (Ecto-style)
    final timestampMatch = RegExp(r'^(\d{14})_').firstMatch(fileName);
    if (timestampMatch == null) {
      return null;
    }

    final timestampStr = timestampMatch.group(1)!;
    final version = int.parse(timestampStr);
    final name = fileName
        .replaceFirst(RegExp(r'^\d{14}_'), '')
        .replaceFirst('.sql', '');

    return {'version': version, 'name': name};
  }

  /// Parses a migration SQL file and extracts up/down statements.
  ///
  /// The file should contain `-- @Up()` and optionally `-- @Down()` markers
  /// to separate the upgrade and rollback SQL statements.
  ///
  /// Returns a map with:
  /// - 'up': List<String> - List of SQL statements for upgrade
  /// - 'down': List<String>? - List of SQL statements for rollback (optional)
  static Map<String, List<String>?> parseMigrationFile(String content) {
    final lines = content.split('\n');
    final upStatements = <String>[];
    List<String>? downStatements;

    String? currentSection; // 'up' or 'down'
    final buffer = StringBuffer();

    for (var line in lines) {
      final trimmed = line.trim();

      // Check for section markers (case-insensitive)
      if (RegExp(r'--\s*@Up\(\)', caseSensitive: false).hasMatch(trimmed)) {
        // Save any buffered content from previous section
        if (buffer.isNotEmpty) {
          _addStatement(
            currentSection,
            buffer.toString(),
            upStatements,
            downStatements,
          );
          buffer.clear();
        }
        currentSection = 'up';
        continue;
      } else if (RegExp(
        r'--\s*@Down\(\)',
        caseSensitive: false,
      ).hasMatch(trimmed)) {
        // Save any buffered content from UP section
        if (buffer.isNotEmpty) {
          _addStatement(
            currentSection,
            buffer.toString(),
            upStatements,
            downStatements,
          );
          buffer.clear();
        }
        currentSection = 'down';
        downStatements ??= [];
        continue;
      }

      // Skip comment-only lines and empty lines
      if (trimmed.isEmpty || trimmed.startsWith('--')) {
        continue;
      }

      // If we haven't hit a marker yet, default to 'up'
      currentSection ??= 'up';

      // Append the line to the buffer
      buffer.writeln(line);

      // If the line ends with a semicolon, it's the end of a statement
      if (trimmed.endsWith(';')) {
        _addStatement(
          currentSection,
          buffer.toString(),
          upStatements,
          downStatements,
        );
        buffer.clear();
      }
    }

    // Add any remaining buffered content
    if (buffer.isNotEmpty) {
      _addStatement(
        currentSection,
        buffer.toString(),
        upStatements,
        downStatements,
      );
    }

    return {'up': upStatements, 'down': downStatements};
  }

  /// Adds a statement to the appropriate list (up or down).
  static void _addStatement(
    String? section,
    String statement,
    List<String> upStatements,
    List<String>? downStatements,
  ) {
    final trimmed = statement.trim();
    if (trimmed.isEmpty) return;

    if (section == 'up') {
      upStatements.add(trimmed);
    } else if (section == 'down' && downStatements != null) {
      downStatements.add(trimmed);
    }
  }

  /// Escapes a string for use in generated Dart code.
  ///
  /// Handles backslashes, single quotes, dollar signs, and special characters.
  static String escapeString(String str) {
    // Escape backslashes first, then single quotes, then dollar signs, then newlines
    final escaped = str
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll(r'$', r'\$')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r')
        .replaceAll('\t', r'\t');
    return "'$escaped'";
  }
}
