import 'package:flutter/services.dart';

class AppHaptics {
  const AppHaptics._();

  static Future<void> tap() => HapticFeedback.selectionClick();

  static Future<void> light() => HapticFeedback.lightImpact();

  static Future<void> success() => HapticFeedback.mediumImpact();

  static Future<void> warning() => HapticFeedback.heavyImpact();
}
