import 'package:strata/strata.dart';

part 'product.g.dart';

@StrataSchema(table: 'products')
class Product with Schema {
  final int id;
  final String name;
  final double price;
  final int stock;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
  });
}
