import 'package:strata/strata.dart';

part 'event.g.dart';

/// Test model with both required and optional timestamp fields.
///
/// This model is used to test the generator's handling of:
/// - Required timestamp fields (startDate)
/// - Optional timestamp fields (endDate)
@StrataSchema(table: 'events')
class Event with Schema {
  final int id;
  final String name;

  /// Required timestamp field - must always have a value.
  @Timestamp()
  final DateTime startDate;

  /// Optional timestamp field - can be null for open-ended events.
  @Timestamp()
  final DateTime? endDate;

  Event({
    required this.id,
    required this.name,
    required this.startDate,
    this.endDate,
  });
}
