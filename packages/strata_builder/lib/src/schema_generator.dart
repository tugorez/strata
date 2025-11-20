import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:strata/strata.dart';

/// Creates the schema builder for use with `build_runner`.
///
/// This function is called by the build system to instantiate the code generator.
/// It creates a [PartBuilder] that generates `.g.dart` files for classes
/// annotated with [@StrataSchema].
Builder schemaBuilder(BuilderOptions options) {
  return PartBuilder(
    [SchemaGenerator()],
    '.g.dart',
    header: '// GENERATED CODE - DO NOT MODIFY BY HAND\n',
  );
}

/// A code generator that creates query builders and changesets for Strata schemas.
///
/// This generator processes classes annotated with [@StrataSchema] and generates:
/// - A type-safe query builder class (e.g., `AccountQuery`)
/// - A changeset class for validation (e.g., `AccountChangeset`)
/// - A `fromMap` helper function to deserialize database records
///
/// The generated code is written to `.g.dart` part files.
class SchemaGenerator extends GeneratorForAnnotation<StrataSchema> {
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    // 1. Make sure we are annotating a class
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        '@StrataSchema can only be used on classes.',
        element: element,
      );
    }

    // 2. Read the annotation values
    final String tableName = annotation.read('table').stringValue;

    // 3. Generate the three components + helper function
    final queryClass = _buildQueryClass(element, tableName);
    final changesetClass = _buildChangesetClass(element, tableName);
    final fromMapFunction = _buildFromMapFunction(element);
    final extensionClass = _buildSchemaExtension(element);

    // 4. Combine them into one file
    final library = Library(
      (b) => b
        ..body.addAll([
          queryClass,
          changesetClass,
          fromMapFunction,
          extensionClass,
        ]),
    );

    // 5. Format and return the final code string
    final emitter = DartEmitter();
    return DartFormatter(
      languageVersion: DartFormatter.latestLanguageVersion,
    ).format('${library.accept(emitter)}');
  }

  /// Generates the `_$$AccountFromMap` helper function.
  Method _buildFromMapFunction(ClassElement element) {
    final className = element.name!;

    // Find the default (unnamed) constructor
    final constructor = element.unnamedConstructor;
    if (constructor == null) {
      throw InvalidGenerationSourceError(
        'The class $className must have an unnamed constructor.',
        element: element,
      );
    }

    // Build the list of named parameters for the constructor call
    // e.g., { 'id': map['id'], 'username': map['username'] }
    final namedArgs = <String, Expression>{};
    for (final param in constructor.formalParameters) {
      if (!param.isNamed) {
        throw InvalidGenerationSourceError(
          'The $className constructor must use only named parameters.',
          element: param,
        );
      }
      final fieldName = param.name!;

      // Association fields (optional fields) should be set to null in fromMap
      // They will be populated separately when preloaded
      if (!param.isRequired) {
        namedArgs[fieldName] = literalNull;
        continue;
      }

      final columnName = _toSnakeCase(fieldName);
      // Map from DB column (snake_case) to Dart field (camelCase)
      namedArgs[fieldName] = refer('map').index(literalString(columnName));
    }

    return Method(
      (b) => b
        ..name = '_fromMap'
        ..returns = refer(className)
        ..requiredParameters.add(
          Parameter(
            (b) => b
              ..name = 'map'
              ..type = refer('Map<String, dynamic>'),
          ),
        )
        ..body = refer(className)
            .call([], namedArgs) // e.g., Account(id: map['id'], ...)
            .returned
            .statement,
    );
  }

  /// Generates the `AccountQuery` class
  Class _buildQueryClass(ClassElement element, String tableName) {
    final className = element.name!;
    final queryClassName = '${className}Query';
    final queryMethods = _buildQueryMethods(element, queryClassName);
    final orderByMethods = _buildOrderByMethods(element, queryClassName);
    final preloadMethods = _buildPreloadMethods(element, queryClassName);

    return Class(
      (b) => b
        ..name = queryClassName
        ..extend = refer('Query<$className>')
        ..constructors.addAll([
          // Public constructor
          Constructor(
            (b) => b
              ..initializers.add(
                refer(
                  'super',
                ).call([literalString(tableName), refer('_fromMap')]).code,
              ),
          ),
          // Private copy constructor
          Constructor(
            (b) => b
              ..name = '_'
              ..requiredParameters.add(
                Parameter(
                  (b) => b
                    ..name = 'query'
                    ..type = refer('Query<$className>'),
                ),
              )
              ..initializers.add(
                refer('super.copy').call([], {
                  'table': refer('query').property('table'),
                  'fromMap': refer('query').property('fromMap'),
                  'whereClauses': refer('query').property('whereClauses'),
                  'orderByClauses': refer('query').property('orderByClauses'),
                  'limitCount': refer('query').property('limitCount'),
                  'preloadAssociations': refer(
                    'query',
                  ).property('preloadAssociations'),
                }).code,
              ),
          ),
        ])
        // Add all the generated `where...`, `orderBy...`, and `preload...` methods
        ..methods.addAll([
          ...queryMethods,
          ...orderByMethods,
          ...preloadMethods,
        ]),
    );
  }

  /// Generates the `where[FieldName]` methods for the Query class.
  List<Method> _buildQueryMethods(ClassElement element, String queryClassName) {
    final methods = <Method>[];

    final constructor = element.unnamedConstructor;
    if (constructor == null) return []; // Should have been caught earlier

    for (final param in constructor.formalParameters) {
      // Only generate where methods for required fields (data fields)
      // Association fields are optional and shouldn't have where clauses
      if (!param.isRequired) continue;

      final fieldName = param.name!;
      final columnName = _toSnakeCase(fieldName);
      // Get the type, e.g., "int", "String?"
      final fieldType = param.type.getDisplayString();
      final baseType = fieldType.replaceAll('?', ''); // Remove nullable marker
      // "id" -> "Id", "username" -> "Username"
      final capitalizedFieldName =
          fieldName[0].toUpperCase() + fieldName.substring(1);

      // Generate whereFieldName (equality operator) - works for all types
      methods.add(
        _buildWhereMethod(
          queryClassName,
          fieldName,
          columnName,
          capitalizedFieldName,
          fieldType,
          '=',
          '',
        ),
      );

      // Generate whereFieldNameNotEq - works for all types
      methods.add(
        _buildWhereMethod(
          queryClassName,
          fieldName,
          columnName,
          capitalizedFieldName,
          fieldType,
          '!=',
          'NotEq',
        ),
      );

      // Generate comparison operators for numeric types
      if (_isNumericType(baseType)) {
        methods.add(
          _buildWhereMethod(
            queryClassName,
            fieldName,
            columnName,
            capitalizedFieldName,
            fieldType,
            '>',
            'GreaterThan',
          ),
        );
        methods.add(
          _buildWhereMethod(
            queryClassName,
            fieldName,
            columnName,
            capitalizedFieldName,
            fieldType,
            '>=',
            'GreaterThanOrEq',
          ),
        );
        methods.add(
          _buildWhereMethod(
            queryClassName,
            fieldName,
            columnName,
            capitalizedFieldName,
            fieldType,
            '<',
            'LessThan',
          ),
        );
        methods.add(
          _buildWhereMethod(
            queryClassName,
            fieldName,
            columnName,
            capitalizedFieldName,
            fieldType,
            '<=',
            'LessThanOrEq',
          ),
        );
      }

      // Generate IN operator for all types (accepts a List)
      methods.add(
        _buildWhereInMethod(
          queryClassName,
          fieldName,
          columnName,
          capitalizedFieldName,
          fieldType,
          'IN',
          'In',
        ),
      );

      // Generate NOT IN operator for all types (accepts a List)
      methods.add(
        _buildWhereInMethod(
          queryClassName,
          fieldName,
          columnName,
          capitalizedFieldName,
          fieldType,
          'NOT IN',
          'NotIn',
        ),
      );

      // Generate LIKE operator for String types
      if (baseType == 'String') {
        methods.add(
          _buildWhereMethod(
            queryClassName,
            fieldName,
            columnName,
            capitalizedFieldName,
            fieldType,
            'LIKE',
            'Like',
          ),
        );
      }
    }
    return methods;
  }

  /// Generates the `orderBy[FieldName]` methods for the Query class.
  List<Method> _buildOrderByMethods(
    ClassElement element,
    String queryClassName,
  ) {
    final methods = <Method>[];

    final constructor = element.unnamedConstructor;
    if (constructor == null) return [];

    for (final param in constructor.formalParameters) {
      // Only generate orderBy methods for required fields (data fields)
      // Association fields are optional and shouldn't have orderBy clauses
      if (!param.isRequired) continue;

      final fieldName = param.name!;
      final columnName = _toSnakeCase(fieldName);
      final capitalizedFieldName =
          fieldName[0].toUpperCase() + fieldName.substring(1);

      // Generate orderByFieldName method with optional ascending parameter
      methods.add(
        Method(
          (b) => b
            ..name = 'orderBy$capitalizedFieldName'
            ..returns = refer(queryClassName)
            ..optionalParameters.add(
              Parameter(
                (b) => b
                  ..name = 'ascending'
                  ..type = refer('bool')
                  ..named = true
                  ..defaultTo = Code('true'),
              ),
            )
            ..body = refer(queryClassName)
                .newInstanceNamed('_', [
                  refer('copyWithOrderByClause').call([
                    refer('OrderByClause').call(
                      [literalString(columnName)],
                      {'ascending': refer('ascending')},
                    ),
                  ]),
                ])
                .returned
                .statement,
        ),
      );
    }
    return methods;
  }

  /// Generates the `preload[AssociationName]` methods for the Query class.
  List<Method> _buildPreloadMethods(
    ClassElement element,
    String queryClassName,
  ) {
    final methods = <Method>[];

    // Get required constructor fields - these are data fields
    final constructor = element.unnamedConstructor;
    final requiredFields = <String>{};
    if (constructor != null) {
      for (final param in constructor.formalParameters) {
        if (param.isRequired) {
          requiredFields.add(param.name!);
        }
      }
    }

    // Look through all fields in the class for association fields
    for (final field in element.fields) {
      // Skip if it's a required field (data field, not association)
      if (requiredFields.contains(field.name)) continue;

      // Association fields are optional fields that are nullable or Lists
      final fieldType = field.type.getDisplayString();
      final isListType = fieldType.startsWith('List<');
      final isNullable = fieldType.endsWith('?');

      // Only generate preload methods for optional nullable or list fields
      if (isListType || isNullable) {
        final fieldName = field.name;
        if (fieldName == null || fieldName.isEmpty) continue;

        final capitalizedFieldName =
            fieldName[0].toUpperCase() + fieldName.substring(1);

        methods.add(
          Method(
            (b) => b
              ..name = 'preload$capitalizedFieldName'
              ..returns = refer(queryClassName)
              ..body = refer(queryClassName)
                  .newInstanceNamed('_', [
                    refer('copyWithPreload').call([literalString(fieldName)]),
                  ])
                  .returned
                  .statement,
          ),
        );
      }
    }

    return methods;
  }

  /// Helper method to build a where clause method with a specific operator.
  Method _buildWhereMethod(
    String queryClassName,
    String fieldName,
    String columnName,
    String capitalizedFieldName,
    String fieldType,
    String operator,
    String methodSuffix,
  ) {
    return Method(
      (b) => b
        ..name = 'where$capitalizedFieldName$methodSuffix'
        ..returns = refer(queryClassName)
        ..requiredParameters.add(
          Parameter(
            (b) => b
              ..name = fieldName
              ..type = refer(fieldType),
          ),
        )
        ..body = refer(queryClassName)
            .newInstanceNamed('_', [
              refer('copyWithWhereClause').call([
                refer('WhereClause').call([
                  literalString(
                    columnName,
                  ), // Use snake_case column name for SQL
                  literalString(operator),
                  refer(fieldName), // Use camelCase field name for Dart
                ]),
              ]),
            ])
            .returned
            .statement,
    );
  }

  /// Helper method to build a where IN/NOT IN clause method.
  Method _buildWhereInMethod(
    String queryClassName,
    String fieldName,
    String columnName,
    String capitalizedFieldName,
    String fieldType,
    String operator,
    String methodSuffix,
  ) {
    // Remove nullable marker for the list type
    final baseType = fieldType.replaceAll('?', '');

    return Method(
      (b) => b
        ..name = 'where$capitalizedFieldName$methodSuffix'
        ..returns = refer(queryClassName)
        ..requiredParameters.add(
          Parameter(
            (b) => b
              ..name = 'values'
              ..type = refer('List<$baseType>'),
          ),
        )
        ..body = refer(queryClassName)
            .newInstanceNamed('_', [
              refer('copyWithWhereClause').call([
                refer('WhereClause').call([
                  literalString(
                    columnName,
                  ), // Use snake_case column name for SQL
                  literalString(operator),
                  refer('values'),
                ]),
              ]),
            ])
            .returned
            .statement,
    );
  }

  /// Checks if a type is numeric (int, double, num).
  bool _isNumericType(String type) {
    return type == 'int' || type == 'double' || type == 'num';
  }

  /// Generates an extension with copyWith for the schema class
  Extension _buildSchemaExtension(ClassElement element) {
    final className = element.name!;
    final constructor = element.unnamedConstructor;
    if (constructor == null) {
      throw InvalidGenerationSourceError(
        'The class $className must have an unnamed constructor.',
        element: element,
      );
    }

    final fields = constructor.formalParameters;

    return Extension(
      (b) => b
        ..name = '${className}Extension'
        ..on = refer(className)
        ..methods.add(_buildCopyWithMethod(className, fields)),
    );
  }

  /// Generates the copyWith method
  Method _buildCopyWithMethod(String className, List<dynamic> fields) {
    final optionalParams = <Parameter>[];
    final constructorArgs = <String, Expression>{};

    for (final field in fields) {
      final fieldName = field.name!;
      final fieldType = field.type.getDisplayString();

      // Make each parameter optional and nullable
      // If the field is already nullable, don't add another '?'
      final paramType = fieldType.endsWith('?') ? fieldType : '$fieldType?';

      optionalParams.add(
        Parameter(
          (b) => b
            ..name = fieldName
            ..type = refer(paramType)
            ..named = true,
        ),
      );

      // Use provided value or current value: fieldName ?? this.fieldName
      constructorArgs[fieldName] = refer(
        fieldName,
      ).ifNullThen(refer('this').property(fieldName));
    }

    return Method(
      (b) => b
        ..name = 'copyWith'
        ..returns = refer(className)
        ..optionalParameters.addAll(optionalParams)
        ..body = refer(className).call([], constructorArgs).returned.statement,
    );
  }

  /// Generates the `AccountChangeset` class
  Class _buildChangesetClass(ClassElement element, String tableName) {
    final className = element.name!;
    return Class(
      (b) => b
        ..name = '${className}Changeset'
        ..extend = refer('Changeset<$className>')
        ..constructors.add(
          Constructor(
            (b) => b
              ..requiredParameters.add(
                Parameter(
                  (b) => b
                    ..name = 'params'
                    ..toSuper = true,
                ),
              )
              ..initializers.add(
                refer('super').call(
                  [], // Pass 'params' as a positional arg
                  {
                    // Pass 'table' and 'fromMap' as named args
                    'table': literalString(tableName),
                    'fromMap': refer('_fromMap'),
                  },
                ).code,
              ),
          ),
        ),
    );
  }

  /// Converts camelCase field names to snake_case for SQL column names.
  ///
  /// Examples:
  /// - userId -> user_id
  /// - createdAt -> created_at
  /// - id -> id (already lowercase)
  String _toSnakeCase(String camelCase) {
    if (camelCase.isEmpty) return camelCase;

    final result = camelCase.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => '_${match.group(0)!.toLowerCase()}',
    );

    // Remove leading underscore if the string started with a capital letter
    return result.startsWith('_') ? result.substring(1) : result;
  }
}
