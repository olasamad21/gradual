import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'quiz_models.dart';

// ─────────────────────────────────────────────────────────────
// KEYS
// ─────────────────────────────────────────────────────────────

String _todayKey() {
  final now = DateTime.now();
  final dateStr =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  return 'quiz_results_$dateStr';
}

// ─────────────────────────────────────────────────────────────
// NOTIFIER
// ─────────────────────────────────────────────────────────────

class QuizResultCacheNotifier
    extends AsyncNotifier<Map<String, List<QuizAnswer>>> {
  @override
  Future<Map<String, List<QuizAnswer>>> build() async {
    return await _loadFromPrefs();
  }

  /// Load today's cached answers from shared_preferences.
  /// Returns empty map if nothing saved today.
  Future<Map<String, List<QuizAnswer>>> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _todayKey();
      final raw = prefs.getString(key);
      if (raw == null) return {};

      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final result = <String, List<QuizAnswer>>{};

      for (final entry in decoded.entries) {
        final list = entry.value as List<dynamic>;
        result[entry.key] = list
            .map((item) =>
            QuizAnswer.fromJson(item as Map<String, dynamic>))
            .toList();
      }

      return result;
    } catch (_) {
      return {};
    }
  }

  /// Save answers for a difficulty to shared_preferences.
  Future<void> saveAnswers(
      String difficultyId, List<QuizAnswer> answers) async {
    // Update in-memory state first
    final current =
    Map<String, List<QuizAnswer>>.from(state.value ?? {});
    current[difficultyId] = answers;
    state = AsyncData(current);

    // Persist to shared_preferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _todayKey();

      final toSave = <String, dynamic>{};
      for (final entry in current.entries) {
        toSave[entry.key] =
            entry.value.map((a) => a.toJson()).toList();
      }

      await prefs.setString(key, jsonEncode(toSave));
    } catch (_) {
      // Persist failure is non-critical — in-memory still works
    }
  }

  /// Get current answers synchronously from state.
  Map<String, List<QuizAnswer>> get currentAnswers =>
      state.value ?? {};
}

final quizResultCacheProvider = AsyncNotifierProvider<
    QuizResultCacheNotifier, Map<String, List<QuizAnswer>>>(
  QuizResultCacheNotifier.new,
);