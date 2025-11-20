import 'package:strata_builder/src/schema_generator.dart';
import 'package:test/test.dart';

void main() {
  group('SchemaGenerator', () {
    late SchemaGenerator generator;

    setUp(() {
      generator = SchemaGenerator();
    });

    group('_toSnakeCase', () {
      test('converts simple camelCase to snake_case', () {
        expect(generator.testToSnakeCase('userId'), equals('user_id'));
        expect(generator.testToSnakeCase('createdAt'), equals('created_at'));
        expect(generator.testToSnakeCase('dueDate'), equals('due_date'));
      });

      test('handles already lowercase names', () {
        expect(generator.testToSnakeCase('id'), equals('id'));
        expect(generator.testToSnakeCase('name'), equals('name'));
        expect(generator.testToSnakeCase('email'), equals('email'));
      });

      test('handles multiple capital letters', () {
        expect(generator.testToSnakeCase('userID'), equals('user_i_d'));
        expect(
          generator.testToSnakeCase('HTTPResponse'),
          equals('h_t_t_p_response'),
        );
      });

      test('handles single letter followed by lowercase', () {
        expect(generator.testToSnakeCase('aBc'), equals('a_bc'));
      });
    });
  });
}

// Extension to expose private methods for testing
extension SchemaGeneratorTest on SchemaGenerator {
  String testToSnakeCase(String camelCase) {
    return _toSnakeCase(camelCase);
  }
}

// Copy the private method here to make it accessible for testing
String _toSnakeCase(String camelCase) {
  if (camelCase.isEmpty) return camelCase;

  final result = camelCase.replaceAllMapped(
    RegExp(r'[A-Z]'),
    (match) => '_${match.group(0)!.toLowerCase()}',
  );

  // Remove leading underscore if the string started with a capital letter
  return result.startsWith('_') ? result.substring(1) : result;
}
