import '../../core/models/concept_model.dart';
import '../daily_word/word_card.dart' show cardSummaryFor;

/// Reminder time and on/off switch, saved on the device.
class ReminderSettings {
  const ReminderSettings({this.enabled = false, this.hour = 9, this.minute = 0});

  final bool enabled;
  final int hour;
  final int minute;

  ReminderSettings copyWith({bool? enabled, int? hour, int? minute}) => ReminderSettings(
        enabled: enabled ?? this.enabled,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
      );

  @override
  bool operator ==(Object other) =>
      other is ReminderSettings && other.enabled == enabled && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(enabled, hour, minute);
}

/// What one day's notification says.
class ReminderMessage {
  const ReminderMessage({required this.title, required this.body, required this.expandedBody});

  /// Bold first line, such as "Today: SQL vs NoSQL".
  final String title;

  /// One line shown when the notification is collapsed.
  final String body;

  /// Longer text shown when the notification is expanded.
  final String expandedBody;
}

/// The words a given day will show, as far as the app knows in advance.
class DayContent {
  const DayContent({
    this.concepts = const [],
    this.readIds = const {},
    this.isWeekendReview = false,
    this.isScheduled = true,
  });

  final List<Concept> concepts;
  final Set<String> readIds;
  final bool isWeekendReview;

  /// False when no set exists yet for that date, so the app would repeat an
  /// older day. The reminder then stays generic instead of naming old words.
  final bool isScheduled;

  bool get isComplete => concepts.isNotEmpty && concepts.every((c) => readIds.contains(c.id));
}

class PlannedReminder {
  const PlannedReminder({required this.id, required this.when, required this.message});

  final int id;
  final DateTime when;
  final ReminderMessage message;
}

/// One notification ID per weekday, so a 7-day window never collides and
/// today's reminder can be found again to update or cancel it.
int reminderIdFor(DateTime date) => 1000 + date.weekday;

/// The one-off test reminder; kept apart from the daily IDs.
const testReminderId = 999;

/// All reminder IDs the app may have scheduled.
const allReminderIds = [1001, 1002, 1003, 1004, 1005, 1006, 1007];

/// Builds the notification text for one day.
ReminderMessage buildReminderMessage(DayContent day) {
  if (!day.isScheduled || day.concepts.isEmpty) {
    return const ReminderMessage(
      title: 'Your words are waiting',
      body: 'Three concepts, about five minutes. Keep your streak going.',
      expandedBody: 'Three concepts, about five minutes. Keep your streak going.',
    );
  }

  if (day.isWeekendReview) {
    final count = day.concepts.length;
    final preview = day.concepts.take(3).map((c) => c.term).join(', ');
    return ReminderMessage(
      title: 'Weekend review',
      body: '$count words from this week. A quick pass keeps them fresh.',
      expandedBody: '$count words from this week, including $preview. A quick pass keeps them fresh.',
    );
  }

  final unread = day.concepts.where((c) => !day.readIds.contains(c.id)).toList();
  final next = unread.isNotEmpty ? unread.first : day.concepts.first;
  final summary = cardSummaryFor(next);
  final others = unread.skip(1).map((c) => c.term).toList();

  if (day.readIds.isNotEmpty && unread.isNotEmpty) {
    final left = unread.length;
    return ReminderMessage(
      title: left == 1 ? '1 word left today: ${next.term}' : '$left words left today',
      body: left == 1 ? summary : 'Next up: ${next.term}. $summary',
      expandedBody: left == 1
          ? '$summary\n\nFinish it for a perfect day.'
          : 'Next up: ${next.term}. $summary\n\nAlso today: ${others.join(' and ')}.',
    );
  }

  final rest = others.isEmpty ? '' : '\n\nAlso today: ${_joinTerms(others)}.';
  return ReminderMessage(
    title: 'Today: ${next.term}',
    body: summary,
    expandedBody: '$summary$rest',
  );
}

String _joinTerms(List<String> terms) {
  if (terms.length <= 1) return terms.join();
  return '${terms.sublist(0, terms.length - 1).join(', ')} and ${terms.last}';
}

/// Decides which reminders to schedule for the next [days] days.
///
/// Skips today when the reminder time has already passed or today's words
/// are all read, and returns nothing when reminders are off.
List<PlannedReminder> planReminders({
  required DateTime now,
  required ReminderSettings settings,
  required DayContent Function(DateTime date) contentFor,
  int days = 7,
}) {
  if (!settings.enabled) return const [];
  final today = DateTime(now.year, now.month, now.day);
  final plan = <PlannedReminder>[];
  for (var i = 0; i < days; i++) {
    final date = DateTime(today.year, today.month, today.day + i);
    final when = DateTime(date.year, date.month, date.day, settings.hour, settings.minute);
    if (!when.isAfter(now)) continue;
    final day = contentFor(date);
    if (day.isComplete) continue;
    plan.add(PlannedReminder(id: reminderIdFor(date), when: when, message: buildReminderMessage(day)));
  }
  return plan;
}
