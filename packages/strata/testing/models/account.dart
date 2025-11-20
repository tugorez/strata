import 'package:strata/strata.dart';

part 'account.g.dart';

@StrataSchema(table: 'accounts')
class Account with Schema {
  final int id;
  final String username;

  Account({required this.id, required this.username});
}
