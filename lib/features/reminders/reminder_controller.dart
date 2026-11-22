import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/firebase/firebase_providers.dart';
import '../../core/utils/date_utils.dart';
import '../daily_word/today_concepts_controller.dart';
import 'reminder_plan.dart';
import 'reminder_platform.dart';

final reminderPlatformProvider = Provider<ReminderPlatform>((ref) => LocalNotificationsReminderPlatform());

/// "Now" for reminder planning; tests pin it.
final reminderClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

const _enabledKey = 'reminder_enabled';
const _hourKey = 'reminder_hour';
const _minuteKey = 'reminder_minute';

/// Reminder settings plus keeping the next week of notifications in step
/// with them and with today's progress.
class ReminderController extends AsyncNotifier<ReminderSettings> {
  /// Future days' words don't change during a session, so fetch them once.
  final Map<String, DayContent> _futureCache = {};

  @override
  Future<ReminderSettings> build() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return ReminderSettings(
        enabled: prefs.getBool(_enabledKey) ?? false,
        hour: prefs.getInt(_hourKey) ?? 9,
        minute: prefs.getInt(_minuteKey) ?? 0,
      );
    } catch (_) {
      return const ReminderSettings();
    }
  }

  bool get isSupported => ref.read(reminderPlatformProvider).isSupported;

  /// Turns reminders on or off. Turning on asks for notification permission
  /// and returns false, leaving reminders off, if the user declines.
  Future<bool> setEnabled(bool enabled) async {
    final current = await future;
    if (enabled) {
      final granted = await ref.read(reminderPlatformProvider).requestPermission();
      if (!granted) return false;
    }
    await _save(current.copyWith(enabled: enabled));
    if (enabled) {
      await sync();
    } else {
      await _cancelAll();
    }
    return true;
  }

  Future<void> setTime(int hour, int minute) async {
    final current = await future;
    await _save(current.copyWith(hour: hour, minute: minute));
    await sync();
  }

  /// Schedules a one-off reminder a minute from now, through the same path
  /// as the daily ones, so the user can lock the phone and see it arrive.
  /// Returns when it will fire, or null if reminders aren't supported here.
  Future<DateTime?> sendTest({Duration delay = const Duration(minutes: 1)}) async {
    final platform = ref.read(reminderPlatformProvider);
    if (!platform.isSupported) return null;
    final today = ref.read(todayConceptsControllerProvider).asData?.value;
    final message = buildReminderMessage(today == null
        ? const DayContent(isScheduled: false)
        : DayContent(
            concepts: today.concepts,
            isWeekendReview: today.isWeekendReview,
            isScheduled: !today.isFallback,
          ));
    final when = ref.read(reminderClockProvider)().add(delay);
    await platform.schedule(PlannedReminder(id: testReminderId, when: when, message: message));
    return when;
  }

  /// Opens the system page for exact alarms, then reschedules so the
  /// reminders pick up the new timing.
  Future<void> allowExactTiming() async {
    await ref.read(reminderPlatformProvider).requestExact();
    ref.invalidate(reminderDeliveryProvider);
    await sync();
  }

  /// Reschedules the next seven days from the current settings and progress.
  Future<void> sync() async {
    final platform = ref.read(reminderPlatformProvider);
    if (!platform.isSupported) return;
    final settings = await future;
    // Reminders off: nothing was scheduled, so leave the plugin untouched.
    if (!settings.enabled) return;
    try {
      for (final id in allReminderIds) {
        await platform.cancel(id);
      }

      final now = ref.read(reminderClockProvider)();
      final content = await _loadWeek(now);
      final plan = planReminders(
        now: now,
        settings: settings,
        contentFor: (date) => content[DateUtilsGradual.localDateId(date)] ?? const DayContent(isScheduled: false),
      );
      for (final reminder in plan) {
        await platform.schedule(reminder);
      }
    } catch (_) {
      // Reminders are best effort; never break the app over them.
    }
  }

  Future<void> _cancelAll() async {
    final platform = ref.read(reminderPlatformProvider);
    if (!platform.isSupported) return;
    try {
      for (final id in allReminderIds) {
        await platform.cancel(id);
      }
    } catch (_) {}
  }

  Future<void> _save(ReminderSettings settings) async {
    state = AsyncData(settings);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, settings.enabled);
      await prefs.setInt(_hourKey, settings.hour);
      await prefs.setInt(_minuteKey, settings.minute);
    } catch (_) {
      // Keep the in-memory choice even if saving fails.
    }
  }

  Future<Map<String, DayContent>> _loadWeek(DateTime now) async {
    final result = <String, DayContent>{};
    final todayId = DateUtilsGradual.localDateId(now);

    final today = ref.read(todayConceptsControllerProvider).asData?.value;
    if (today != null) {
      result[todayId] = DayContent(
        concepts: today.concepts,
        readIds: today.readConceptIds,
        isWeekendReview: today.isWeekendReview,
        isScheduled: !today.isFallback,
      );
    }

    final field = ref.read(appUserProvider).asData?.value?.fieldOfStudy ?? 'software_engineering';
    final repo = ref.read(contentRepositoryProvider);
    for (var i = 1; i < 7; i++) {
      final date = DateTime(now.year, now.month, now.day + i);
      final id = DateUtilsGradual.localDateId(date);
      final cached = _futureCache[id];
      if (cached != null) {
        result[id] = cached;
        continue;
      }
      try {
        final day = await repo.getTodaysConcepts(field, id);
        final content = DayContent(
          concepts: day.concepts,
          isWeekendReview: day.isWeekendReview,
          isScheduled: !day.isFallback && day.concepts.isNotEmpty,
        );
        _futureCache[id] = content;
        result[id] = content;
      } catch (_) {
        // Offline or missing: that day gets the generic reminder.
      }
    }
    return result;
  }
}

final reminderControllerProvider =
    AsyncNotifierProvider<ReminderController, ReminderSettings>(ReminderController.new);

/// What may stop reminders arriving on time on this phone.
class ReminderDelivery {
  const ReminderDelivery({required this.exact, required this.manufacturer});

  /// Exact alarms allowed, so reminders fire at the chosen minute.
  final bool exact;
  final String manufacturer;

  /// The maker stops closed apps' alarms unless autostart is on.
  bool get needsAutostart => needsAutostartFor(manufacturer);
}

bool needsAutostartFor(String manufacturer) => needsAutostart(manufacturer);

final reminderDeliveryProvider = FutureProvider.autoDispose<ReminderDelivery>((ref) async {
  final platform = ref.watch(reminderPlatformProvider);
  if (!platform.isSupported) return const ReminderDelivery(exact: true, manufacturer: '');
  try {
    return ReminderDelivery(exact: await platform.canScheduleExact(), manufacturer: await platform.manufacturer());
  } catch (_) {
    return const ReminderDelivery(exact: true, manufacturer: '');
  }
});
