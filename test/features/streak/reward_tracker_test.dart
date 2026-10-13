import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gradual/core/services/streak_engine.dart';
import 'package:gradual/features/streak/reward_tracker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RewardTracker tests', () {
    test('shouldShow is true first, false after markShown for same date, true for another date', () async {
      SharedPreferences.setMockInitialValues({});
      final tracker = RewardTracker();

      const date1 = '2026-10-10';
      const date2 = '2026-10-11';

      expect(await tracker.shouldShow(DayReward.counted, date1), isTrue);
      await tracker.markShown(DayReward.counted, date1);
      expect(await tracker.shouldShow(DayReward.counted, date1), isFalse);
      expect(await tracker.shouldShow(DayReward.counted, date2), isTrue);
    });

    test('perfect marks counted too', () async {
      SharedPreferences.setMockInitialValues({});
      final tracker = RewardTracker();

      const date1 = '2026-10-10';

      expect(await tracker.shouldShow(DayReward.perfect, date1), isTrue);
      expect(await tracker.shouldShow(DayReward.counted, date1), isTrue);

      await tracker.markShown(DayReward.perfect, date1);

      expect(await tracker.shouldShow(DayReward.perfect, date1), isFalse);
      expect(await tracker.shouldShow(DayReward.counted, date1), isFalse);
    });

    test('corrupt values do not throw', () async {
      SharedPreferences.setMockInitialValues({
        'reward_counted_date': 12345,
        'reward_perfect_date': true,
      });
      final tracker = RewardTracker();

      expect(() async => await tracker.shouldShow(DayReward.counted, '2026-10-10'), returnsNormally);
      expect(() async => await tracker.shouldShow(DayReward.perfect, '2026-10-10'), returnsNormally);
      expect(await tracker.shouldShow(DayReward.counted, '2026-10-10'), isTrue);
      expect(await tracker.shouldShow(DayReward.perfect, '2026-10-10'), isTrue);

      expect(() async => await tracker.markShown(DayReward.counted, '2026-10-10'), returnsNormally);
      expect(() async => await tracker.markShown(DayReward.perfect, '2026-10-10'), returnsNormally);
    });
  });
}
