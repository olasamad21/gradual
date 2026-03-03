import 'package:flutter_riverpod/legacy.dart';

import 'quiz_models.dart';

final quizResultCacheProvider =
StateProvider<Map<String, List<QuizAnswer>>>((ref) => {});