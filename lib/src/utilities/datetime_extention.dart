import 'package:intl/intl.dart';

extension DateTimeExtension on DateTime {

  String toMMMdy(String? locale) {
    return DateFormat('MMM d, y', locale).format(this);
  }

  String toYyyyMMdd(String? locale) {
    return DateFormat('yyyy-MM-dd', locale).format(this);
  }
}
