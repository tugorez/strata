/// Code generator for the Strata data mapping library.
///
/// This library provides the builder that generates type-safe query builders
/// and changesets for classes annotated with `@StrataSchema`.
///
/// ## Usage
///
/// Add this package as a dev dependency and configure `build_runner`:
///
/// ```yaml
/// dev_dependencies:
///   build_runner: ^2.4.0
///   strata_builder: ^0.1.0
/// ```
///
/// Then annotate your models and run the generator:
///
/// ```bash
/// dart run build_runner build
/// ```
///
/// The generator will create `.g.dart` files with query builders and changesets.
library strata_builder;

import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/schema_generator.dart';

export 'src/schema_generator.dart' show schemaBuilder, SchemaGenerator;

/// Creates the schema builder for code generation.
///
/// This builder processes [@StrataSchema] annotations and generates type-safe
/// query builders, changesets, and `fromMap` functions.
///
/// Note: Migrations use a separate CLI tool (`bin/generate_migrations.dart`)
/// following the protobuf pattern: SQL files → CLI script → committed Dart file.
Builder strataBuilder(BuilderOptions options) {
  return PartBuilder(
    [SchemaGenerator()],
    '.g.dart',
    header: '// GENERATED CODE - DO NOT MODIFY BY HAND\n',
  );
}
