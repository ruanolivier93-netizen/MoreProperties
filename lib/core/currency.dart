import 'package:intl/intl.dart';

/// South African Rand formatter that matches local conventions:
/// `R 1 250 000` for full amounts and `R 1.25m` for compact display.
class ZAR {
  static final NumberFormat _full = NumberFormat.currency(
    locale: 'en_ZA',
    symbol: 'R ',
    decimalDigits: 0,
  );

  static String format(num value) => _full.format(value);

  /// Compact ZAR — R 850k, R 1.25m, R 12.4m, R 1.2b.
  static String compact(num value) {
    final abs = value.abs();
    String formatted;
    if (abs >= 1000000000) {
      formatted = '${(value / 1000000000).toStringAsFixed(2)}b';
    } else if (abs >= 1000000) {
      formatted = '${(value / 1000000).toStringAsFixed(2)}m';
    } else if (abs >= 1000) {
      formatted = '${(value / 1000).toStringAsFixed(0)}k';
    } else {
      formatted = value.toStringAsFixed(0);
    }
    return 'R $formatted';
  }

  /// `R 18 450 pm` for rentals.
  static String perMonth(num value) => '${format(value)} pm';

  /// Per square metre rate for commercial display.
  static String perSqm(num value) => '${format(value)}/m²';
}
