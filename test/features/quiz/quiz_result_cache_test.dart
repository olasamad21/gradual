import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gradual/features/quiz/quiz_models.dart';
import 'package:gradual/features/quiz/quiz_result_cache_provider.dart';

void main() {
  test('QuizResultCacheService saves and loads by session id', () async {
    SharedPreferences.setMockInitialValues({});
    
    final service = QuizResultCacheService();
    final answers = [
      QuizAnswer(
        question: QuizQuestion(
          id: 'q1',
          text: 'Q1',
          options: ['A', 'B'],
          correctIndex: 0,
          explanation: '',
          sourceWord: '',
          type: 'mcq'
        ),
        selectedIndex: 1,
      )
    ];

    await service.saveAnswers('2026-10-10', answers);

    // Load with same session date
    final loaded = await service.loadAnswers('2026-10-10');
    expect(loaded, isNotNull);
    expect(loaded!.length, 1);
    expect(loaded[0].selectedIndex, 1);
    expect(loaded[0].question.id, 'q1');

    // Missing returns null
    final missing = await service.loadAnswers('2026-10-11');
    expect(missing, isNull);

    // Corrupt returns null
    SharedPreferences.setMockInitialValues({
      'quiz_results_corrupt': 'not a json map'
    });
    final corrupt = await service.loadAnswers('corrupt');
    expect(corrupt, isNull);
  });

  test('QuizResultCacheService pending operations', () async {
    SharedPreferences.setMockInitialValues({});
    final service = QuizResultCacheService();
    final answers = [
      QuizAnswer(
        question: QuizQuestion(
          id: 'pending_q',
          text: 'Q',
          options: ['A', 'B'],
          correctIndex: 0,
          explanation: '',
          sourceWord: '',
          type: 'mcq'
        ),
        selectedIndex: 1,
      )
    ];

    // savePending then loadPending
    await service.savePending('session1', answers);
    final loaded = await service.loadPending('session1');
    expect(loaded, isNotNull);
    expect(loaded!.length, 1);
    expect(loaded[0].selectedIndex, 1);
    expect(loaded[0].question.id, 'pending_q');

    // Missing returns null
    final missing = await service.loadPending('session_missing');
    expect(missing, isNull);

    // Corrupt returns null
    SharedPreferences.setMockInitialValues({
      'quiz_results_pending_corrupt': 'invalid json'
    });
    final corrupt = await service.loadPending('corrupt');
    expect(corrupt, isNull);
    
    SharedPreferences.setMockInitialValues({});
    
    // clearPending removes the value
    await service.savePending('session_to_clear', answers);
    await service.clearPending('session_to_clear');
    final cleared = await service.loadPending('session_to_clear');
    expect(cleared, isNull);

    // listPendingSessionIds returns only pending ids
    await service.savePending('pending1', answers);
    await service.savePending('pending2', answers);
    await service.saveAnswers('normal1', answers); // normal result
    
    final pendingIds = await service.listPendingSessionIds();
    expect(pendingIds, unorderedEquals(['pending1', 'pending2']));

    // separation: pending session != normal result
    final normalFromPending = await service.loadPending('normal1');
    expect(normalFromPending, isNull);
    
    final pendingFromNormal = await service.loadAnswers('pending1');
    expect(pendingFromNormal, isNull);

    // check key prefix
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (final key in keys) {
      expect(key.startsWith('quiz_results_'), isTrue, reason: 'Key $key should start with quiz_results_');
    }
  });
}
