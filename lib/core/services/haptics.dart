import 'package:flutter/services.dart';

/// One place for the app's haptic vocabulary, so the same kind of action
/// always feels the same.
abstract final class Haptics {
  /// Picking between options: tabs, quiz answers, segmented controls.
  static void selection() => HapticFeedback.selectionClick();

  /// Small toggles such as saving a word.
  static void light() => HapticFeedback.lightImpact();

  /// Confirming a step: marking a word read, submitting a quiz.
  static void medium() => HapticFeedback.mediumImpact();

  /// A win worth celebrating: perfect day, reward overlay.
  static Future<void> success() async {
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await HapticFeedback.lightImpact();
  }
}
