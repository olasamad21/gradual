import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'quiz_models.dart';

class QuizResultCacheService {
  static const _prefixNormal = 'quiz_results_';
  static const _prefixPending = 'quiz_results_pending_';

  Future<void> saveAnswers(String sessionDateId, List<QuizAnswer> answers) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefixNormal$sessionDateId';
      final toSave = answers.map((a) => a.toJson()).toList();
      await prefs.setString(key, jsonEncode(toSave));
    } catch (_) {
      // Ignored
    }
  }

  Future<List<QuizAnswer>?> loadAnswers(String sessionDateId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefixNormal$sessionDateId';
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

  Future<void> savePending(String sessionDateId, List<QuizAnswer> answers) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefixPending$sessionDateId';
      final toSave = answers.map((a) => a.toJson()).toList();
      await prefs.setString(key, jsonEncode(toSave));
    } catch (_) {}
  }

  Future<List<QuizAnswer>?> loadPending(String sessionDateId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefixPending$sessionDateId';
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

  Future<void> clearPending(String sessionDateId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefixPending$sessionDateId';
      await prefs.remove(key);
    } catch (_) {}
  }

  Future<List<String>> listPendingSessionIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final pendingSessionIds = <String>[];
      for (final key in keys) {
        if (key.startsWith(_prefixPending)) {
          pendingSessionIds.add(key.substring(_prefixPending.length));
        }
      }
      return pendingSessionIds;
    } catch (_) {
      return [];
    }
  }
}

final quizResultCacheProvider = Provider<QuizResultCacheService>((ref) {
  return QuizResultCacheService();
});