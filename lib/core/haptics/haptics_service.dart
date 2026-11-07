import 'package:flutter/services.dart';

/// Central haptic control; respects the in-game haptics setting.
class HapticsService {
  bool enabled = true;

  void light() {
    if (enabled) HapticFeedback.lightImpact();
  }

  void medium() {
    if (enabled) HapticFeedback.mediumImpact();
  }

  void error() {
    if (enabled) HapticFeedback.vibrate();
  }

  void selection() {
    if (enabled) HapticFeedback.selectionClick();
  }
}
