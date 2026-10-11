import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradual/features/daily_word/read_along_text.dart';

void main() {
  Widget buildApp(Widget child, {double textScale = 1.0}) {
    return MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Center(
            child: SizedBox(
              width: 300,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('valid range renders RichText with three spans', (tester) async {
    await tester.pumpWidget(buildApp(
      const ReadAlongText(
        text: 'Hello world test',
        style: TextStyle(fontSize: 20, color: Color(0xFF374151)),
        highlightStart: 6,
        highlightEnd: 11, // "world"
      ),
    ));

    // Find the Text widget that has the rich textSpan
    final textWidget = find.byWidgetPredicate((w) {
      if (w is! Text) return false;
      final span = w.textSpan;
      if (span is! TextSpan) return false;
      final children = span.children;
      if (children == null || children.length != 3) return false;
      // Before: "Hello " in green
      final before = children[0] as TextSpan;
      expect(before.text, 'Hello ');
      expect(before.style?.color, const Color(0xFF388E3C));
      // Current: "world" bold green with underline
      final current = children[1] as TextSpan;
      expect(current.text, 'world');
      expect(current.style?.color, const Color(0xFF388E3C));
      expect(current.style?.fontWeight, FontWeight.w700);
      expect(current.style?.decoration, TextDecoration.underline);
      // After: " test" in original colour
      final after = children[2] as TextSpan;
      expect(after.text, ' test');
      expect(after.style?.color, const Color(0xFF374151));
      return true;
    });
    expect(textWidget, findsOneWidget);
  });

  testWidgets('null range shows plain text, no RichText spans', (tester) async {
    await tester.pumpWidget(buildApp(
      const ReadAlongText(
        text: 'Hello world',
        style: TextStyle(fontSize: 20),
      ),
    ));

    expect(find.text('Hello world'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('out-of-range shows plain text and throws nothing', (tester) async {
    await tester.pumpWidget(buildApp(
      const ReadAlongText(
        text: 'Hello world',
        style: TextStyle(fontSize: 20),
        highlightStart: 20,
        highlightEnd: 25,
      ),
    ));

    expect(find.text('Hello world'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('text scale 1.3 throws nothing', (tester) async {
    await tester.pumpWidget(buildApp(
      const ReadAlongText(
        text: 'Hello world this is a test',
        style: TextStyle(fontSize: 20),
        highlightStart: 6,
        highlightEnd: 11,
      ),
      textScale: 1.3,
    ));

    expect(tester.takeException(), isNull);
  });

  testWidgets('empty text works', (tester) async {
    await tester.pumpWidget(buildApp(
      const ReadAlongText(
        text: '',
        style: TextStyle(fontSize: 20),
        highlightStart: 0,
        highlightEnd: 0,
      ),
    ));

    expect(tester.takeException(), isNull);
  });

  testWidgets('highlight at start of text produces two spans', (tester) async {
    await tester.pumpWidget(buildApp(
      const ReadAlongText(
        text: 'Hello world',
        style: TextStyle(fontSize: 20, color: Color(0xFF374151)),
        highlightStart: 0,
        highlightEnd: 5, // "Hello"
      ),
    ));

    final textWidget = find.byWidgetPredicate((w) {
      if (w is! Text) return false;
      final span = w.textSpan;
      if (span is! TextSpan) return false;
      final children = span.children;
      if (children == null || children.length != 2) return false;
      // Current: "Hello" bold green
      final current = children[0] as TextSpan;
      expect(current.text, 'Hello');
      expect(current.style?.fontWeight, FontWeight.w700);
      // After: " world" original
      final after = children[1] as TextSpan;
      expect(after.text, ' world');
      return true;
    });
    expect(textWidget, findsOneWidget);
  });

  testWidgets('highlight at end of text produces two spans', (tester) async {
    await tester.pumpWidget(buildApp(
      const ReadAlongText(
        text: 'Hello world',
        style: TextStyle(fontSize: 20, color: Color(0xFF374151)),
        highlightStart: 6,
        highlightEnd: 11, // "world"
      ),
    ));

    final textWidget = find.byWidgetPredicate((w) {
      if (w is! Text) return false;
      final span = w.textSpan;
      if (span is! TextSpan) return false;
      final children = span.children;
      if (children == null || children.length != 2) return false;
      // Before: "Hello " green
      final before = children[0] as TextSpan;
      expect(before.text, 'Hello ');
      expect(before.style?.color, const Color(0xFF388E3C));
      // Current: "world" bold green
      final current = children[1] as TextSpan;
      expect(current.text, 'world');
      expect(current.style?.fontWeight, FontWeight.w700);
      return true;
    });
    expect(textWidget, findsOneWidget);
  });

  testWidgets('sectionActive true adds green tint container', (tester) async {
    await tester.pumpWidget(buildApp(
      const ReadAlongText(
        text: 'Hello',
        style: TextStyle(fontSize: 20),
        sectionActive: true,
      ),
    ));

    final container = find.byWidgetPredicate((w) {
      if (w is! AnimatedContainer) return false;
      final dec = w.decoration;
      if (dec is! BoxDecoration) return false;
      return dec.color != Colors.transparent;
    });
    expect(container, findsOneWidget);
  });
}
