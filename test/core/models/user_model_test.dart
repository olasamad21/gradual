import 'package:flutter_test/flutter_test.dart';
import 'package:gradual/core/models/user_model.dart';
import 'package:gradual/core/services/streak_engine.dart';

void main() {
  group('AppUser.fromJson tests', () {
    test('1. activity_log populates rawActivityLog correctly', () {
      final json = {
        'activity_log': {
          '2026-10-03': {
            'concepts_read': ['a', 'b']
          }
        }
      };
      
      final user = AppUser.fromJson('u1', json);
      
      expect(user.rawActivityLog, {
        '2026-10-03': {
          'concepts_read': ['a', 'b']
        }
      });
    });

    test('2. user.streakAt returns 1 for the populated log', () {
      final json = {
        'activity_log': {
          '2026-10-03': {
            'concepts_read': ['a', 'b']
          }
        }
      };
      
      final user = AppUser.fromJson('u1', json);
      
      expect(user.streakAt(DateTime(2026, 10, 3)), 1);
    });

    test('3. StreakEngine.conceptsReadInWeek returns correctly', () {
      final json = {
        'activity_log': {
          '2026-10-03': {
            'concepts_read': ['a', 'b']
          }
        }
      };
      
      final user = AppUser.fromJson('u1', json);
      
      final concepts = StreakEngine.conceptsReadInWeek(user.rawActivityLog, DateTime(2026, 10, 4));
      
      expect(concepts, {'a', 'b'});
    });

    test('4. json with no activity_log gives empty rawActivityLog and does not throw', () {
      final json = <String, dynamic>{
        'email': 'test@test.com',
      };
      
      final user = AppUser.fromJson('u1', json);
      
      expect(user.rawActivityLog, isEmpty);
    });

    test('5. log entry with quiz and concepts keeps both in rawActivityLog', () {
      final json = {
        'activity_log': {
          '2026-10-03': {
            'concepts_read': ['a', 'b'],
            'quiz_score': 8,
            'quiz_total': 10,
            'quiz_tier': 'bronze'
          }
        }
      };
      
      final user = AppUser.fromJson('u1', json);
      
      expect(user.rawActivityLog, {
        '2026-10-03': {
          'concepts_read': ['a', 'b'],
          'quiz_score': 8,
          'quiz_total': 10,
          'quiz_tier': 'bronze'
        }
      });
    });
  });
}
