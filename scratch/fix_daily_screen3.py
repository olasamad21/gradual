with open('lib/features/daily_word/daily_word_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

print("Contains build?", "Widget build" in content)
print("Contains _getGreeting?", "_getGreeting" in content)
print("Contains _isSaturday?", "_isSaturday" in content)

with open('lib/features/daily_word/concept_card.dart', 'r', encoding='utf-8') as f:
    card = f.read()

card = card.replace("border: BorderSide", "border: Border.all")
with open('lib/features/daily_word/concept_card.dart', 'w', encoding='utf-8') as f:
    f.write(card)
