import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradual/core/models/concept_model.dart';
import 'package:gradual/core/services/read_aloud_text.dart';
import 'package:gradual/core/theme/app_theme.dart';
import 'package:gradual/features/daily_word/auto_scroll_logic.dart';
import 'package:gradual/features/daily_word/concept_flip_card.dart';
import 'package:gradual/features/daily_word/read_along_text.dart';

class AutoScrollHarness extends StatefulWidget {
  final String text;
  final bool isReadingAloud;
  final int? highlightStart;
  final int? highlightEnd;
  final bool disableAnimations;
  final double textScale;

  const AutoScrollHarness({
    super.key,
    required this.text,
    this.isReadingAloud = true,
    this.highlightStart,
    this.highlightEnd,
    this.disableAnimations = false,
    this.textScale = 1.0,
  });

  @override
  State<AutoScrollHarness> createState() => AutoScrollHarnessState();
}

class AutoScrollHarnessState extends State<AutoScrollHarness> {
  final ScrollController scrollController = ScrollController();
  final GlobalKey scrollViewKey = GlobalKey();
  bool autoScrollPaused = false;
  Timer? userScrollTimer;
  Rect? lastWordRect;

  @override
  void dispose() {
    userScrollTimer?.cancel();
    scrollController.dispose();
    super.dispose();
  }

  void _onUserScroll() {
    autoScrollPaused = true;
    userScrollTimer?.cancel();
    userScrollTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          autoScrollPaused = false;
        });
      }
    });
  }

  void _onWordRect(Rect wordRect) {
    lastWordRect = wordRect;
    if (!widget.isReadingAloud) return;
    if (autoScrollPaused) return;
    if (!scrollController.hasClients) return;

    final scrollContext = scrollViewKey.currentContext;
    if (scrollContext == null) return;
    final renderBox = scrollContext.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final viewportTopLeft = renderBox.localToGlobal(Offset.zero);
    final viewportTop = viewportTopLeft.dy;
    final viewportBottom = viewportTop + renderBox.size.height;

    final target = computeAutoScrollTarget(
      currentOffset: scrollController.offset,
      maxExtent: scrollController.position.maxScrollExtent,
      viewportTop: viewportTop,
      viewportBottom: viewportBottom,
      wordTop: wordRect.top,
      wordBottom: wordRect.bottom,
    );

    if (target != null) {
      if (MediaQuery.disableAnimationsOf(scrollContext)) {
        scrollController.jumpTo(target);
      } else {
        scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(
            disableAnimations: widget.disableAnimations,
            textScaler: TextScaler.linear(widget.textScale),
          ),
          child: Center(
            child: SizedBox(
              width: 300,
              height: 200,
              child: NotificationListener<ScrollStartNotification>(
                onNotification: (notification) {
                  if (notification.dragDetails != null) {
                    _onUserScroll();
                  }
                  return false;
                },
                child: SingleChildScrollView(
                  key: scrollViewKey,
                  controller: scrollController,
                  child: ReadAlongText(
                    text: widget.text,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                    highlightStart: widget.highlightStart,
                    highlightEnd: widget.highlightEnd,
                    onCurrentWordRect: _onWordRect,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  final longText = List.generate(40, (i) => 'Line $i has some sample words to create height.').join('\n');

  int getLineStart(int lineIndex) {
    return longText.indexOf('Line $lineIndex');
  }

  int getLineEnd(int lineIndex) {
    return getLineStart(lineIndex) + 'Line $lineIndex'.length;
  }

  testWidgets('while the highlight range moves down through the text, offset increases and word stays inside viewport', (tester) async {
    await tester.pumpWidget(AutoScrollHarness(
      text: longText,
      highlightStart: getLineStart(0),
      highlightEnd: getLineEnd(0),
    ));
    await tester.pump(const Duration(milliseconds: 400));

    final state = tester.state<AutoScrollHarnessState>(find.byType(AutoScrollHarness));
    expect(state.scrollController.offset, 0.0);

    // Move highlight down to Line 20
    await tester.pumpWidget(AutoScrollHarness(
      text: longText,
      highlightStart: getLineStart(20),
      highlightEnd: getLineEnd(20),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final offset1 = state.scrollController.offset;
    expect(offset1, greaterThan(0.0));

    // Check that current word stays inside viewport
    final scrollBox = tester.renderObject<RenderBox>(find.byType(SingleChildScrollView));
    final viewTop = scrollBox.localToGlobal(Offset.zero).dy;
    final viewBottom = viewTop + scrollBox.size.height;

    final textBox = tester.renderObject<RenderBox>(find.byType(ReadAlongText));
    final textPainter = TextPainter(
      text: TextSpan(text: longText, style: const TextStyle(fontSize: 16, height: 1.5)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: textBox.size.width);
    final box20 = textPainter.getBoxesForSelection(
      TextSelection(baseOffset: getLineStart(20), extentOffset: getLineEnd(20)),
    ).first;
    final wordTop20 = textBox.localToGlobal(box20.toRect().topLeft).dy;
    final wordBottom20 = wordTop20 + box20.toRect().height;

    expect(wordTop20, greaterThanOrEqualTo(viewTop - 1.0));
    expect(wordBottom20, lessThanOrEqualTo(viewBottom + 1.0));

    // Move further down to Line 35
    await tester.pumpWidget(AutoScrollHarness(
      text: longText,
      highlightStart: getLineStart(35),
      highlightEnd: getLineEnd(35),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final offset2 = state.scrollController.offset;
    expect(offset2, greaterThan(offset1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('with a null range nothing scrolls', (tester) async {
    await tester.pumpWidget(AutoScrollHarness(
      text: longText,
      highlightStart: null,
      highlightEnd: null,
    ));
    await tester.pump(const Duration(milliseconds: 400));

    final state = tester.state<AutoScrollHarnessState>(find.byType(AutoScrollHarness));
    expect(state.scrollController.offset, 0.0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('with isReadingAloud false nothing scrolls', (tester) async {
    await tester.pumpWidget(AutoScrollHarness(
      text: longText,
      isReadingAloud: false,
      highlightStart: getLineStart(25),
      highlightEnd: getLineEnd(25),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final state = tester.state<AutoScrollHarnessState>(find.byType(AutoScrollHarness));
    expect(state.scrollController.offset, 0.0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('after a user drag the offset does not change for new word ranges until timer elapses', (tester) async {
    await tester.pumpWidget(AutoScrollHarness(
      text: longText,
      highlightStart: getLineStart(0),
      highlightEnd: getLineEnd(0),
    ));
    await tester.pump(const Duration(milliseconds: 400));

    final state = tester.state<AutoScrollHarnessState>(find.byType(AutoScrollHarness));
    expect(state.scrollController.offset, 0.0);

    // User drags scroll view up by 50 px
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -50));
    await tester.pump();
    final postDragOffset = state.scrollController.offset;
    expect(postDragOffset, greaterThan(0.0));
    expect(state.autoScrollPaused, isTrue);

    // Try moving highlight down while paused
    await tester.pumpWidget(AutoScrollHarness(
      text: longText,
      highlightStart: getLineStart(25),
      highlightEnd: getLineEnd(25),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Offset should not have changed
    expect(state.scrollController.offset, postDragOffset);

    // Advance 4 seconds
    await tester.pump(const Duration(seconds: 4));
    expect(state.autoScrollPaused, isFalse);

    // Now moving highlight resumes auto-scroll
    await tester.pumpWidget(AutoScrollHarness(
      text: longText,
      highlightStart: getLineStart(30),
      highlightEnd: getLineEnd(30),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(state.scrollController.offset, greaterThan(postDragOffset));
    expect(tester.takeException(), isNull);
  });

  testWidgets('with disableAnimationsOf true the offset changes immediately after pump()', (tester) async {
    await tester.pumpWidget(AutoScrollHarness(
      text: longText,
      disableAnimations: true,
      highlightStart: getLineStart(0),
      highlightEnd: getLineEnd(0),
    ));
    await tester.pump();

    final state = tester.state<AutoScrollHarnessState>(find.byType(AutoScrollHarness));
    expect(state.scrollController.offset, 0.0);

    await tester.pumpWidget(AutoScrollHarness(
      text: longText,
      disableAnimations: true,
      highlightStart: getLineStart(25),
      highlightEnd: getLineEnd(25),
    ));
    // Immediately after pump(), without awaiting 350ms duration
    await tester.pump();
    expect(state.scrollController.offset, greaterThan(0.0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('text scale 1.3 throws nothing', (tester) async {
    await tester.pumpWidget(AutoScrollHarness(
      text: longText,
      textScale: 1.3,
      highlightStart: getLineStart(15),
      highlightEnd: getLineEnd(15),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
  });

  testWidgets('ConceptFlipCard auto-scrolls definition when reading aloud', (tester) async {
    final concept = Concept(
      id: 'test_card',
      term: 'Long Term',
      category: 'General',
      level: 'Beginner',
      definition: longText,
      analogy: 'Analogy',
      realWorldExample: 'Example',
      confusedWith: '',
      related: [],
      quiz: const ConceptQuiz(
        question: 'Q',
        options: ['A', 'B'],
        answerIndex: 0,
        explanation: 'E',
      ),
    );

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 500,
          child: ConceptFlipCard(
            concept: concept,
            index: 0,
            isRead: false,
            isLastWord: false,
            onMarkRead: () {},
            isReadingAloud: true,
            readingSection: ReadSectionKind.definition,
            readingWordStart: getLineStart(0),
            readingWordEnd: getLineEnd(0),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 400));

    final scrollView = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView).first,
    );
    expect(scrollView.controller!.offset, 0.0);

    // Update with word deeper in the definition
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 500,
          child: ConceptFlipCard(
            concept: concept,
            index: 0,
            isRead: false,
            isLastWord: false,
            onMarkRead: () {},
            isReadingAloud: true,
            readingSection: ReadSectionKind.definition,
            readingWordStart: getLineStart(25),
            readingWordEnd: getLineEnd(25),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(scrollView.controller!.offset, greaterThan(0.0));
    expect(tester.takeException(), isNull);
  });
}
