import re

with open('lib/features/daily_word/daily_word_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix isPerfectDay parameter in StreakSuccessModal
content = content.replace("isPerfectDay: false,", "")

# Fix the dangling return 'No concept for today yet.'; }
content = re.sub(r"    return 'No concept for today yet\.';\s*\}", "", content)

with open('lib/features/daily_word/daily_word_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
