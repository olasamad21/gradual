import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gradual/core/models/concept_model.dart';
import 'package:gradual/core/theme/app_theme.dart';
import 'package:gradual/features/daily_word/daily_word_screen.dart';
import 'package:gradual/features/daily_word/day_complete_card.dart';
import 'package:gradual/features/daily_word/today_header.dart';
import 'package:gradual/features/daily_word/word_card.dart';

const _concept = Concept(
  id: 'c1',
  term: 'Mutex',
  category: 'synchronization',
  level: 'intermediate',
  definition: 'A lock that lets one thread at a time into a critical section. Others wait.',
  summary: 'A lock only one thread can hold at a time.',
  analogy: 'A single key to a shared bathroom.',
  realWorldExample: 'Guarding a shared counter.',
  confusedWith: 'Semaphore',
  related: ['Lock'],
  quiz: ConceptQuiz(question: 'Q', options: ['A', 'B'], answerIndex: 0, explanation: ''),
);

Widget _host(Widget child, {ThemeData? theme}) => MaterialApp(
      theme: theme ?? AppTheme.light,
      home: Scaffold(body: Center(child: SizedBox(width: 380, height: 560, child: child))),
    );

void main() {
  group('nextPageAfterRead', () {
    const ids = ['a', 'b', 'c'];

    test('moves to the next word when it is unread', () {
      expect(nextPageAfterRead(readIds: {'a'}, conceptIds: ids, index: 0), 1);
    });

    test('skips back to the first unread word', () {
      expect(nextPageAfterRead(readIds: {'c', 'b'}, conceptIds: ids, index: 2), 0);
      expect(nextPageAfterRead(readIds: {'a', 'b'}, conceptIds: ids, index: 0), 2);
    });

    test('goes to the completion page once every word is read', () {
      expect(nextPageAfterRead(readIds: {'a', 'b', 'c'}, conceptIds: ids, index: 1), 3);
    });
  });

  group('cardSummaryFor', () {
    Concept withText({String? summary, required String definition}) => Concept(
          id: 'x',
          term: 'X',
          category: 'c',
          level: 'beginner',
          definition: definition,
          summary: summary,
          realWorldExample: 'e',
          related: const [],
          quiz: const ConceptQuiz(question: 'Q', options: ['A'], answerIndex: 0, explanation: ''),
        );

    test('uses the summary when there is one', () {
      expect(cardSummaryFor(withText(summary: 'Short line.', definition: 'Long. Text.')), 'Short line.');
    });

    test('falls back to the first sentence of the definition', () {
      expect(cardSummaryFor(withText(definition: 'First idea here. Second idea.')), 'First idea here.');
    });

    test('does not split on dots inside numbers or names', () {
      expect(
        cardSummaryFor(withText(definition: 'Versions look like 2.4.1 in practice. More detail.')),
        'Versions look like 2.4.1 in practice.',
      );
    });

    test('cuts a long first sentence at a word boundary with an ellipsis', () {
      final long = '${List.filled(40, 'word').join(' ')}.';
      final result = cardSummaryFor(withText(definition: long), maxChars: 60);
      expect(result.endsWith('\u2026'), isTrue);
      expect(result.length, lessThanOrEqualTo(61));
      expect(result.contains('wor\u2026'), isFalse);
    });
  });

  group('WordCard', () {
    testWidgets('shows term, category and level, summary and what is inside', (tester) async {
      await tester.pumpWidget(_host(WordCard(
        concept: _concept,
        index: 0,
        total: 3,
        isRead: false,
        isSaved: false,
        onOpen: () {},
        onMarkRead: () {},
        onToggleSaved: () {},
      )));

      expect(find.text('Mutex'), findsOneWidget);
      expect(find.text('SYNCHRONIZATION · INTERMEDIATE'), findsOneWidget);
      expect(find.text('A lock only one thread can hold at a time.'), findsOneWidget);
      // The full definition and analogy live in the reader, not on the card.
      expect(find.textContaining('critical section'), findsNothing);
      expect(find.text('A single key to a shared bathroom.'), findsNothing);
      for (final label in ['Analogy', 'Example', 'Mix-ups']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Got it, Read more, card tap and bookmark call their callbacks', (tester) async {
      var read = 0, open = 0, saved = 0;
      await tester.pumpWidget(_host(WordCard(
        concept: _concept,
        index: 1,
        total: 3,
        isRead: false,
        isSaved: false,
        onOpen: () => open++,
        onMarkRead: () => read++,
        onToggleSaved: () => saved++,
      )));

      await tester.tap(find.widgetWithText(FilledButton, 'Got it'));
      await tester.tap(find.text('Read more'));
      await tester.tap(find.text('Mutex'));
      await tester.tap(find.byTooltip('Save word'));

      expect(read, 1);
      expect(open, 2);
      expect(saved, 1);
    });

    testWidgets('read words show a done state instead of the Got it button', (tester) async {
      await tester.pumpWidget(_host(WordCard(
        concept: _concept,
        index: 0,
        total: 3,
        isRead: true,
        isSaved: true,
        onOpen: () {},
        onMarkRead: () {},
        onToggleSaved: () {},
      )));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.widgetWithText(FilledButton, 'Got it'), findsNothing);
      expect(find.text('Got it'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsWidgets);
      expect(find.byTooltip('Remove from saved'), findsOneWidget);
    });

    testWidgets('renders in dark mode and at large text without overflow', (tester) async {
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: _host(
          WordCard(
            concept: _concept,
            index: 2,
            total: 3,
            isRead: false,
            isSaved: false,
            onOpen: () {},
            onMarkRead: () {},
            onToggleSaved: () {},
          ),
          theme: AppTheme.dark,
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('TodayHeader', () {
    testWidgets('shows progress toward a perfect day on weekdays', (tester) async {
      await tester.pumpWidget(_host(TodayHeader(
        greeting: 'Good morning',
        firstName: 'Ada',
        streak: 5,
        readCount: 1,
        total: 3,
        rawActivityLog: const {},
        today: DateTime(2026, 11, 18),
      )));
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('Good morning'), findsOneWidget);
      expect(find.text('Ada'), findsOneWidget);
      expect(find.text('1 of 3 words read'), findsOneWidget);
      expect(find.text('2 more for a perfect day'), findsOneWidget);
      expect(find.text('1/3'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('switches to Day complete with a star when all words are read', (tester) async {
      await tester.pumpWidget(_host(TodayHeader(
        greeting: 'Good evening',
        firstName: 'Ada',
        streak: 1,
        readCount: 3,
        total: 3,
        rawActivityLog: const {},
        today: DateTime(2026, 11, 18),
      )));
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('Day complete'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    });

    testWidgets('week strip marks days with activity and shows Monday to Sunday', (tester) async {
      await tester.pumpWidget(_host(WeekStrip(
        rawActivityLog: const {
          '2026-11-16': {'concepts_read': ['a', 'b', 'c']},
          // A day only counts when it reads a word not seen before.
          '2026-11-17': {'concepts_read': ['d']},
        },
        today: DateTime(2026, 11, 18),
      )));

      expect(find.text('M'), findsOneWidget);
      expect(find.text('W'), findsOneWidget);
      expect(find.text('S'), findsNWidgets(2));
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });
  });

  group('DayCompleteCard', () {
    testWidgets('lists the words, opens one on tap and offers the quiz when open', (tester) async {
      int? opened;
      var quiz = 0;
      await tester.pumpWidget(_host(DayCompleteCard(
        concepts: const [_concept],
        streak: 2,
        isWeekendReview: false,
        onOpenWord: (i) => opened = i,
        quizCta: () => quiz++,
      )));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('2 day streak'), findsOneWidget);
      await tester.tap(find.text('Mutex'));
      await tester.tap(find.text("Take this week's quiz"));
      expect(opened, 0);
      expect(quiz, 1);
      expect(find.text('New words tomorrow'), findsNothing);
    });
  });
}
