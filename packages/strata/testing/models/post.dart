import 'package:strata/strata.dart';

part 'post.g.dart';

@StrataSchema(table: 'posts')
class Post with Schema {
  final int id;
  final String title;
  final String content;

  @Timestamp()
  final DateTime createdAt;

  @Timestamp()
  final DateTime updatedAt;

  Post({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });
}
