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
}
