import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase/firebase_providers.dart';
import '../models/concept_model.dart';
import '../repositories/content_repository.dart';
import '../utils/date_utils.dart';

/// Keeps each day's words on the phone, so Today still works without a
/// signal. Stores a few weeks of days and drops the oldest.
class OfflineContentCache {
  static const _key = 'content_cache_v1';
  static const maxDays = 21;

  Future<Map<String, dynamic>> _readAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return {};
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      return {};
    }
  }

  Future<void> save(String dateId, TodaysConceptsResult result) async {
    if (result.concepts.isEmpty) return;
    try {
      final all = await _readAll();
      all[dateId] = {
        'concepts': [for (final c in result.concepts) c.toJson()],
        'fallback': result.isFallback,
        'weekend': result.isWeekendReview,
      };
      final keys = all.keys.toList()..sort();
      for (final old in keys.take((keys.length - maxDays).clamp(0, keys.length))) {
        all.remove(old);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(all));
    } catch (_) {
      // A cache that fails to save only means less offline support.
    }
  }

  /// The saved copy for [dateId], marked as coming from the cache.
  Future<TodaysConceptsResult?> load(String dateId) async {
    final entry = (await _readAll())[dateId];
    if (entry is! Map) return null;
    final list = entry['concepts'];
    if (list is! List) return null;
    final concepts = [
      for (final c in list)
        if (c is Map) Concept.fromJson(Map<String, dynamic>.from(c)),
    ];
    if (concepts.isEmpty) return null;
    return TodaysConceptsResult(
      concepts: concepts,
      isFallback: entry['fallback'] == true,
      isWeekendReview: entry['weekend'] == true,
      fromCache: true,
    );
  }

  /// True when [dateId] is saved with its real words, not a fallback.
  Future<bool> hasScheduled(String dateId) async {
    final entry = (await _readAll())[dateId];
    return entry is Map && entry['fallback'] != true;
  }
}

final offlineContentCacheProvider = Provider<OfflineContentCache>((ref) => OfflineContentCache());

/// Fetches and stores the coming week's words while online, so tomorrow
/// works offline too. Days already stored with real words are skipped.
final contentPrefetcherProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    if (kIsWeb) return;
    final user = ref.read(appUserProvider).asData?.value;
    if (user == null) return;
    final cache = ref.read(offlineContentCacheProvider);
    final repo = ref.read(contentRepositoryProvider);
    final now = DateTime.now();
    for (var i = 1; i <= 7; i++) {
      final id = DateUtilsGradual.localDateId(DateTime(now.year, now.month, now.day + i));
      if (await cache.hasScheduled(id)) continue;
      try {
        await cache.save(id, await repo.getTodaysConcepts(user.fieldOfStudy, id));
      } catch (_) {
        return; // Offline: try again next time the app opens.
      }
    }
  };
});
