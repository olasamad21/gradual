import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/streak_engine.dart';

class RewardTracker {
  RewardTracker([this._prefs]);

  final SharedPreferences? _prefs;

  static const String _countedKey = 'reward_counted_date';
  static const String _perfectKey = 'reward_perfect_date';

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ?? await SharedPreferences.getInstance();
  }

  Future<bool> shouldShow(DayReward kind, String dateId) async {
    if (kind == DayReward.none) return false;
    try {
      final prefs = await _getPrefs();
      final key = kind == DayReward.perfect ? _perfectKey : _countedKey;
      final raw = prefs.get(key);
      final stored = raw is String ? raw : null;
      return stored != dateId;
    } catch (_) {
      return false;
    }
  }

  Future<void> markShown(DayReward kind, String dateId) async {
    if (kind == DayReward.none) return;
    try {
      final prefs = await _getPrefs();
      if (kind == DayReward.perfect) {
        await prefs.setString(_perfectKey, dateId);
        await prefs.setString(_countedKey, dateId);
      } else {
        await prefs.setString(_countedKey, dateId);
      }
    } catch (_) {
      // Never throw
    }
  }
}
