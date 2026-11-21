import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/streak_engine.dart';
import 'app_colors.dart';

class StreakColors {
  static Color colorFor(HeatmapCell cell, AppColors c) {
    switch (cell) {
      case HeatmapCell.none: return c.heatmapEmpty;
      case HeatmapCell.partial: return c.brandSoft;
      case HeatmapCell.perfect: return c.brand;
      case HeatmapCell.quizExcellent: return c.successBright;
      case HeatmapCell.quizGood: return c.warning;
      case HeatmapCell.quizFair: return c.caution;
      case HeatmapCell.quizFailed: return c.danger;
    }
  }

  static Color tierColor(WeeklyScoreTier tier, AppColors c) {
    switch (tier) {
      case WeeklyScoreTier.excellent: return c.successBright;
      case WeeklyScoreTier.good: return c.warning;
      case WeeklyScoreTier.fair: return c.caution;
      case WeeklyScoreTier.failed: return c.danger;
      case WeeklyScoreTier.missed: return c.textMuted;
      case WeeklyScoreTier.legacy: return c.heatmapEmpty;
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
