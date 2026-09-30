import 'package:flutter_test/flutter_test.dart';
import 'package:gradual/core/utils/date_utils.dart';

void main() {
  group('DateUtilsGradual Local Date Functions', () {
    test('localDateId formats correctly', () {
      final dt = DateTime(2026, 10, 5, 23, 59);
      expect(DateUtilsGradual.localDateId(dt), '2026-10-05');
      
      final dt2 = DateTime(2026, 1, 1, 0, 0);
      expect(DateUtilsGradual.localDateId(dt2), '2026-01-01');
    });

    test('todayLocalDateId returns valid format', () {
      final id = DateUtilsGradual.todayLocalDateId();
      expect(id.length, 10);
      expect(id[4], '-');
      expect(id[7], '-');
    });

    test('dateFromId parses correctly to local midnight', () {
      final dt = DateUtilsGradual.dateFromId('2026-10-05');
      expect(dt.year, 2026);
      expect(dt.month, 10);
      expect(dt.day, 5);
      expect(dt.hour, 0);
      expect(dt.minute, 0);
      expect(dt.isUtc, false);
    });
  });
}
