import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'quiz_models.dart';

class QuizResultCacheService {
  Future<void> saveAnswers(String sessionDateId, List<QuizAnswer> answers) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'quiz_results_$sessionDateId';
      final toSave = answers.map((a) => a.toJson()).toList();
      await prefs.setString(key, jsonEncode(toSave));
    } catch (_) {
      // Ignored
    }
  }

  Future<List<QuizAnswer>?> loadAnswers(String sessionDateId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'quiz_results_$sessionDateId';
      final raw = prefs.getString(key);
      if (raw == null) return null;
      
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((item) => QuizAnswer.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }
}

final quizResultCacheProvider = Provider<QuizResultCacheService>((ref) {
  return QuizResultCacheService();
});