enum DifficultyLevel {
  junior,
  senior,
  techLead,
}

extension DifficultyLevelX on DifficultyLevel {
  String get label {
    switch (this) {
      case DifficultyLevel.junior:
        return 'Junior';
      case DifficultyLevel.senior:
        return 'Senior';
      case DifficultyLevel.techLead:
        return 'Tech Lead';
    }
  }

  String get id {
    switch (this) {
      case DifficultyLevel.junior:
        return 'junior';
      case DifficultyLevel.senior:
        return 'senior';
      case DifficultyLevel.techLead:
        return 'lead';
    }
  }

  static DifficultyLevel fromId(String raw) {
    switch (raw) {
      case 'junior':
        return DifficultyLevel.junior;
      case 'senior':
        return DifficultyLevel.senior;
      case 'lead':
      case 'tech_lead':
        return DifficultyLevel.techLead;
      default:
        return DifficultyLevel.junior;
    }
  }
}

