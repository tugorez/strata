import 'package:strata/strata.dart';

class CreateAccountsMigration extends Migration {
  @override
  int get version => 1;

  @override
  Future<void> up(dynamic db) async {
    (db as Map<String, List<Map<String, dynamic>>>).putIfAbsent(
      'accounts',
      () => <Map<String, dynamic>>[],
    );
  }

  @override
  Future<void> down(dynamic db) async {
    (db as Map<String, List<Map<String, dynamic>>>).remove('accounts');
  }
}
