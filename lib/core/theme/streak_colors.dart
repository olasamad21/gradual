import 'package:flutter/material.dart';
import '../services/streak_engine.dart';

class StreakColors {
  static Color colorFor(HeatmapCell cell) {
    switch (cell) {
      case HeatmapCell.none: return const Color(0xFFEAECEF);
      case HeatmapCell.partial: return const Color(0xFFC8E6C9);
      case HeatmapCell.perfect: return const Color(0xFF388E3C);
      case HeatmapCell.quizExcellent: return const Color(0xFF22C55E);
      case HeatmapCell.quizGood: return const Color(0xFFF59E0B);
      case HeatmapCell.quizFair: return const Color(0xFFF97316);
      case HeatmapCell.quizFailed: return const Color(0xFFEF4444);
    }
  }

  static String labelFor(HeatmapCell cell) {
    switch (cell) {
      case HeatmapCell.none: return 'None';
      case HeatmapCell.partial: return 'Read today';
      case HeatmapCell.perfect: return 'All 3 done';
      case HeatmapCell.quizExcellent: return 'Quiz: Excellent';
      case HeatmapCell.quizGood: return 'Quiz: Good';
      case HeatmapCell.quizFair: return 'Quiz: Fair';
      case HeatmapCell.quizFailed: return 'Quiz: Failed';
    }
  }
}
