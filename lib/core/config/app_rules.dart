abstract final class AppRules {
  static const int conceptsPerDay = 3;
  static const int quizMinConceptsThisWeek = 5;
  static const int quizMaxQuestions = 10;
  static const Set<int> quizWindowWeekdays = {DateTime.saturday, DateTime.sunday};
  static const int currentStatsVersion = 2;
}
