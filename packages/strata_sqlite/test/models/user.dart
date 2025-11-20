import 'package:strata/strata.dart';

part 'user.g.dart';

@StrataSchema(table: 'users')
class User with Schema {
  final int id;
  final String name;
  final String email;
  final int age;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.age,
  });
}
