/// In-memory adapter for Strata data mapping library.
///
/// This package provides a lightweight, in-memory implementation of the
/// `StrataAdapter` interface. It's perfect for:
/// - Unit testing your application without a real database
/// - Integration testing with fast, isolated test runs
/// - Rapid prototyping and development
///
/// ## Usage
///
/// ```dart
/// import 'package:strata/strata.dart';
/// import 'package:strata_in_memory/strata_in_memory.dart';
/// import 'package:test/test.dart';
///
/// void main() {
///   late StrataRepo repo;
///
///   setUp(() async {
///     final adapter = InMemoryAdapter();
///     repo = StrataRepo(adapter: adapter);
///     await repo.initialize();
///   });
///
///   test('can insert and retrieve data', () async {
///     final changeset = UserChangeset({'username': 'test'})
///       ..validateRequired('username');
///
///     final user = await repo.insert(changeset);
///     expect(user.username, 'test');
///   });
/// }
/// ```
library;

export 'src/in_memory_adapter.dart';
