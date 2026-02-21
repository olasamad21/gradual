import 'package:cloud_firestore/cloud_firestore.dart';

abstract final class DateUtilsGradual {
  /// Formats a [DateTime] as `yyyy-MM-dd` to be used as `date_id`.
  static String toDateId(DateTime date) {
    final d = DateTime.utc(date.year, date.month, date.day);
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  /// Parses a `yyyy-MM-dd` string into a UTC [DateTime].
  static DateTime fromDateId(String dateId) {
    final parts = dateId.split('-');
    if (parts.length != 3) {
      return DateTime.now().toUtc();
    }
    final year = int.tryParse(parts[0]) ?? DateTime.now().year;
    final month = int.tryParse(parts[1]) ?? 1;
    final day = int.tryParse(parts[2]) ?? 1;
    return DateTime.utc(year, month, day);
  }

  /// Converts a Firestore [Timestamp] to a UTC [DateTime] truncated to date.
  static DateTime? toDateOnly(Timestamp? timestamp) {
    if (timestamp == null) return null;
    final dt = timestamp.toDate().toUtc();
    return DateTime.utc(dt.year, dt.month, dt.day);
  }

  /// Returns true if [timestamp] falls on the same calendar day as [date].
  static bool isSameCalendarDay(Timestamp? timestamp, DateTime date) {
    final tsDate = toDateOnly(timestamp);
    final target = DateTime.utc(date.year, date.month, date.day);
    return tsDate != null &&
        tsDate.year == target.year &&
        tsDate.month == target.month &&
        tsDate.day == target.day;
  }
}

