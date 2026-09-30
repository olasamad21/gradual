import re

with open('lib/features/daily_word/daily_word_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# I accidentally removed _getGreeting and _isSaturday by matching too greedily. Let's re-add them inside the class.
class_decl = "class DailyWordScreen extends ConsumerWidget {"
methods_to_add = """
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  bool get _isSaturday => DateTime.now().weekday == DateTime.saturday;
"""
if "_getGreeting" not in content:
    content = content.replace(class_decl, class_decl + "\n" + methods_to_add)

# Fix valueOrNull -> whenOrNull
content = content.replace(".valueOrNull", ".whenOrNull(data: (d) => d)")

with open('lib/features/daily_word/daily_word_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

with open('lib/features/daily_word/today_concepts_controller.dart', 'r', encoding='utf-8') as f:
    c2 = f.read()
c2 = c2.replace(".valueOrNull", ".whenOrNull(data: (d) => d)")
with open('lib/features/daily_word/today_concepts_controller.dart', 'w', encoding='utf-8') as f:
    f.write(c2)
